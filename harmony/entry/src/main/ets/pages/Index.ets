import { webview } from '@kit.ArkWeb';
import { common, Permissions } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIContext } from '@kit.ArkUI';

import { TraccarConstants } from '../common/constants/TraccarConstants';
import { Log } from '../common/utils/Log';
import { showToast } from '../common/utils/Toast';
import { DEEP_LINK_TICK_KEY, STATUS_BAR_INSET_KEY } from '../common/utils/Keys';
import {
  buildUri,
  composeServerUrlFromDeepLink,
  isDownloadable,
  isOAuthAuthorizeRequest,
  isServerRootOrLogin,
  isValidServerUrl,
  lastPathSegment,
  normalizeServerUrl,
  parseUri,
  QueryParam,
  rewriteRedirectToAppScheme,
  UriParts
} from '../common/model/UriModel';
import { ServerPrefs } from '../services/storage/ServerPrefs';
import { TokenStore } from '../services/storage/TokenStore';
import { BiometricGate } from '../services/auth/BiometricGate';
import { PushTokens } from '../services/notification/PushTokens';
import { NotificationHelper } from '../services/notification/NotificationHelper';
import { DownloadService } from '../services/download/DownloadService';
import { ShareService } from '../services/download/ShareService';
import { ExternalLinks } from '../services/navigation/ExternalLinks';
import { DeepLinkRouter } from '../services/navigation/DeepLinkRouter';
import { WebSessionManager } from '../services/web/WebSessionManager';
import { AppPermissions, PERMISSION_CAMERA } from '../services/web/AppPermissions';
import { DownloadHandler } from '../services/web/DownloadHandler';
import { BridgeHostAdapter } from '../services/web/BridgeHostAdapter';
import { buildJavaScriptProxy } from '../services/web/TraccarBridge';
import { buildBridgeScript } from '../services/web/BridgeScript';
import { ErrorScreen } from '../views/components/ErrorScreen';

/** 文档开始注入脚本的匹配规则：所有页面（含 iframe）。 */
const BRIDGE_SCRIPT_RULES: string[] = ['*'];
/** 上游忽略的「用户主动取消导航」类错误码（ArkWeb 为 Chromium net error 负值）。 */
// -3 = ERR_ABORTED（被 sinceOverrideUrlLoading/拦截取消，上游忽略的就是它）；
// -999/102 是 Android/iOS 的取消码，留着不影响；刻意不含 -10（ERR_ACCESS_DENIED，是真失败）。
const IGNORED_LOAD_ERRORS: number[] = [-3, -999, 102];

/**
 * 主界面：1:1 复刻上游 Flutter 主界面（lib/main_screen.dart）。
 *
 * 上游的 build 只有三态，没有标题栏、没有菜单、没有分栏：
 *   1. 设置未就绪 → 屏幕中央一个 CircularProgressIndicator；
 *   2. 加载失败   → ErrorScreen（云图标 + 错误文本 + 服务器地址输入框）；
 *   3. 其余       → 全屏 WebView。
 * 本文件按同样的三态组织；壳层能力（JS 桥、令牌、下载、深链、权限）与上游一一对应，
 * 但都发生在不可见的层，不额外引入上游没有的界面元素。
 */
@Entry
@Component
struct Index {
  private controller: webview.WebviewController = new webview.WebviewController();
  private host: BridgeHostAdapter = new BridgeHostAdapter();
  private downloadHandler: DownloadHandler | undefined = undefined;
  private webAttached: boolean = false;
  /** controller 未附着时收到的推送令牌：附着后补发，避免静默丢弃。 */
  private pendingPushToken: string = '';
  private scriptItems: ScriptItem[] | undefined = undefined;
  private proxy: JavaScriptProxy | undefined = undefined;

  /** 非 UI 状态：这些值不参与渲染，用普通字段即可（避免无谓的重建）。 */
  private currentUrl: string = '';
  private pageTitle: string = '';
  private canGoBack: boolean = false;
  private authenticated: boolean = false;

  @State settingsReady: boolean = false;
  @State serverUrl: string = '';
  @State webSrc: string = '';
  /** 对应上游 `_loadingError`：非空即整屏显示 ErrorScreen。 */
  @State loadingError: string = '';

  @StorageProp(DEEP_LINK_TICK_KEY) @Watch('onDeepLinkTick') deepLinkTick: number = 0;
  /**
   * 状态栏高度（vp），由 EntryAbility 在全屏布局后写入。
   * 全屏布局让窗口画到屏幕最下沿（底部不再有系统白带），但内容会钻进状态栏下面，
   * 所以根容器按这个值给顶部留白。
   */
  @StorageProp(STATUS_BAR_INSET_KEY) statusBarInsetVp: number = 0;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.abilityContext();
    ServerPrefs.init(context);
    this.serverUrl = ServerPrefs.serverUrl();
    this.webSrc = this.serverUrl;
    this.currentUrl = this.serverUrl;

    WebSessionManager.init();
    this.bindHost();

    PushTokens.setTokenSink((token: string) => {
      this.pushTokenToWeb(token);
    });
    PushTokens.setEventSink((eventId: string) => {
      DeepLinkRouter.publishEvent(eventId, ServerPrefs.serverUrl());
    });
    PushTokens.setMessageSink((data: string) => {
      this.onNativeNotification(data);
    });
    PushTokens.getToken().then((token: string) => {
      PushTokens.dispatchToken(token);
    });

    // 冷启动深链：EntryAbility 已把 want.uri 投进 DeepLinkRouter 的单槽邮箱。
    if (DeepLinkRouter.hasPending()) {
      this.navigate(DeepLinkRouter.consume());
    }

    // 对应上游 `_settingsReady = true`：设置读完之前显示加载指示器。
    this.settingsReady = true;
  }

  aboutToDisappear(): void {
    // 静态字段在 PushTokens 里，不清掉就会长期持有已销毁页面的闭包。
    PushTokens.detachSinks();
  }

  build() {
    Stack() {
      if (!this.settingsReady) {
        // 上游：if (!_settingsReady) return const Center(child: CircularProgressIndicator());
        this.loadingIndicator()
      } else if (this.loadingError.length > 0) {
        // 上游：if (_loadingError != null) return ErrorScreen(...)
        ErrorScreen({
          errorMessage: this.loadingError,
          serverUrl: this.serverUrl,
          onSubmit: (url: string) => {
            this.submitServerUrl(url);
          }
        })
      } else {
        this.webArea()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarInsetVp })
    .backgroundColor($r('app.color.surface'))
  }

  /** 屏幕中央的加载指示器（Flutter CircularProgressIndicator 默认 36×36，主题 primary 色）。 */
  @Builder
  loadingIndicator() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color($r('app.color.primary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  webArea() {
    Web({ src: this.webSrc, controller: this.controller })
      .width('100%')
      .height('100%')
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .databaseAccess(true)
      .onlineImageAccess(true)
      .imageAccess(true)
      .mixedMode(MixedMode.All)
      .cacheMode(CacheMode.Default)
      .geolocationAccess(true)
      .zoomAccess(false)
      .horizontalScrollBarAccess(false)
      .verticalScrollBarAccess(false)
      // API 26 新增：网页内输入时键盘使用沉浸样式（仅影响键盘外观，不改变布局）。
      .keyboardAppearance(WebKeyboardAppearanceMode.IMMERSIVE)
      .javaScriptProxy(this.javaScriptProxy())
      .javaScriptOnDocumentStart(this.documentStartScripts())
      .onControllerAttached(() => {
        this.onControllerAttached();
      })
      .onPageBegin((event: OnPageBeginEvent) => {
        this.currentUrl = event.url;
        // 对应上游「加载开始时清空 _loadingError」：上一次的失败不该粘在新页面上。
        this.loadingError = '';
      })
      .onPageEnd((event: OnPageEndEvent) => {
        this.onPageEnd(event.url);
      })
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        this.onErrorReceive(event);
      })
      .onLoadIntercept((event: OnLoadInterceptEvent) => {
        return this.interceptNavigation(event.data.getRequestUrl());
      })
      .onRenderExited((_event: OnRenderExitedEvent) => {
        // 对应上游 onRenderProcessGone：渲染进程被杀后直接重载，用户无感。
        Log.warn('render process exited, reloading');
        this.reload();
      })
      .onGeolocationShow((event: OnGeolocationShowEvent) => {
        this.onGeolocationShow(event);
      })
      .onPermissionRequest((event: OnPermissionRequestEvent) => {
        this.onPermissionRequest(event);
      })
      .onShowFileSelector((event: OnShowFileSelectorEvent) => {
        return this.onShowFileSelector(event);
      })
  }

  onBackPress(): boolean {
    // 上游 ErrorScreen 那一态没有 PopScope：按返回键就是退出应用。
    if (this.loadingError.length > 0) {
      return false;
    }
    // 对应上游 PopScope：在服务器根/登录页时不再后退，交回系统（退出应用）。
    if (this.safeCanGoBack() && !isServerRootOrLogin(this.currentUrl, this.serverUrl)) {
      try {
        this.controller.backward();
      } catch (error) {
        // 控制器未附着，忽略。
      }
      return true;
    }
    return false;
  }

  onDeepLinkTick(): void {
    if (DeepLinkRouter.hasPending()) {
      this.navigate(DeepLinkRouter.consume());
    }
  }

  // ------------------------------------------------------------------ 桥接

  private bindHost(): void {
    this.host.onLoginHandler = (token: string) => {
      this.onLoginToken(token);
    };
    this.host.onAuthenticationHandler = () => {
      this.onAuthenticationRequest();
    };
    this.host.onAuthenticatedHandler = () => {
      this.onAuthenticated();
    };
    this.host.onLogoutHandler = () => {
      this.onLogout();
      TokenStore.delete();
    };
    this.host.onDownloadHandler = (base64: string) => {
      this.onDownloadPayload(base64);
    };
    this.host.onServerChangeHandler = (url: string) => {
      this.handleServerChange(url);
    };
  }

  /** `login|<token>`：存令牌并把推送令牌回填给 Web。 */
  private onLoginToken(token: string): void {
    Log.debug('onLoginToken', `len=${token.length}`);
    if (token.length === 0) {
      return;
    }
    TokenStore.save(token).then(() => {
      Log.info('login token stored');
    }).catch((error: BusinessError) => {
      Log.error('login token store failed', `code=${error.code}`);
    });
    PushTokens.getToken().then((pushToken: string) => {
      this.pushTokenToWeb(pushToken);
    });
  }

  /** `authentication`：Web 端需要已有令牌，读之前先过生物识别。 */
  private onAuthenticationRequest(): void {
    TokenStore.read().then((token: string) => {
      if (token.length === 0) {
        this.callJs(TraccarConstants.JS_FN_HANDLE_LOGIN_TOKEN, '');
        return;
      }
      BiometricGate.authenticate('验证身份以访问登录令牌').then((granted: boolean) => {
        if (!granted) {
          Log.warn('biometric verification rejected');
        }
        this.callJs(TraccarConstants.JS_FN_HANDLE_LOGIN_TOKEN, granted ? token : '');
      });
    }).catch((error: BusinessError) => {
      Log.error('token read failed', `code=${error.code}`);
      this.callJs(TraccarConstants.JS_FN_HANDLE_LOGIN_TOKEN, '');
    });
  }

  private onAuthenticated(): void {
    this.authenticated = true;
    if (this.pageTitle.length > 0) {
      ServerPrefs.setLastServerName(this.pageTitle);
    }
    // 对应上游：认证完成后才请求通知权限（避免首次启动就弹权限框）。
    this.enableNotifications();
  }

  private onLogout(): void {
    this.authenticated = false;
    WebSessionManager.clearCookies();
  }

  private pushTokenToWeb(token: string): void {
    if (token.length === 0) {
      return;
    }
    if (!this.webAttached) {
      // controller 还没附着：先存起来，附着后补发。
      this.pendingPushToken = token;
      return;
    }
    this.callJs(TraccarConstants.JS_FN_UPDATE_NOTIFICATION_TOKEN, token);
  }

  /** 对应上游 onMessage：把整条原生通知交给 Web，并提示用户（上游是 SnackBar）。 */
  private onNativeNotification(data: string): void {
    this.callJs(TraccarConstants.JS_FN_HANDLE_NATIVE_NOTIFICATION, data);
    const body: string = Index.notificationBody(data);
    if (body.length > 0) {
      showToast(this.ui(), body);
    }
  }

  /** 从推送数据里取通知正文（取不到就不弹提示，不影响 Web 回调）。 */
  private static notificationBody(data: string): string {
    try {
      const parsed: Record<string, string> = JSON.parse(data) as Record<string, string>;
      const body: string = parsed.body;
      return body !== undefined && body !== null && typeof body === 'string' ? body : '';
    } catch (error) {
      return '';
    }
  }

  /** `download|<base64>`：Web 端把 xlsx 导出成 base64 交回来（上游固定文件名 report.xlsx）。 */
  private onDownloadPayload(base64: string): void {
    Log.debug('onDownloadPayload', `len=${base64.length}`);
    if (base64.length === 0) {
      return;
    }
    const context: common.UIAbilityContext | undefined = this.tryAbilityContext();
    if (context === undefined) {
      Log.warn('download payload dropped: no ability context');
      return;
    }
    const fileName: string = 'report.xlsx';
    const path: string = DownloadService.writeBase64Payload(context, base64, fileName);
    if (path.length === 0) {
      Log.warn('download payload not written');
      return;
    }
    this.deliverFile(path, fileName);
  }

  private callJs(functionName: string, argument: string): void {
    if (!this.webAttached) {
      return;
    }
    const script: string = `${functionName}?.('${this.escapeJs(argument)}')`;
    try {
      this.controller.runJavaScript(script).catch((error: BusinessError) => {
        Log.warn('runJavaScript rejected', `code=${error.code} msg=${error.message}`);
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('runJavaScript threw', `code=${failure.code} msg=${failure.message}`);
    }
  }

  private escapeJs(value: string): string {
    return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\r?\n/g, '');
  }

  // ------------------------------------------------------------ 导航与拦截

  /** 上游 shouldOverrideUrlLoading 的四条规则，顺序即语义。 */
  private interceptNavigation(url: string): boolean {
    if (url.length === 0 || this.serverUrl.length === 0) {
      // 服务器地址还没就绪时一律放行，否则空串会把所有导航判成"跨站"。
      return false;
    }
    const parts: UriParts = parseUri(url);
    const scheme: string = parts.scheme.toLowerCase();

    // 反向深链（org.traccar.manager://…）在 Web 内出现时按服务器地址还原。
    if (scheme === TraccarConstants.DEEP_LINK_SCHEME) {
      this.navigate(composeServerUrlFromDeepLink(this.serverUrl, url));
      return true;
    }
    if (scheme !== 'http' && scheme !== 'https') {
      if (scheme === 'about' || scheme === 'data' || scheme === 'blob' || scheme === 'javascript') {
        return false;
      }
      // mailto:/tel:/intent:/应用唤起等交给系统。
      ExternalLinks.open(this.abilityContext(), url, this.ui());
      return true;
    }

    // ① OAuth 授权请求：把 redirect_uri 改写成自定义 scheme，交给外部浏览器完成认证。
    if (isOAuthAuthorizeRequest(url, TraccarConstants.OAUTH_PARAMS)) {
      const redirect: string = parts.queryValue('redirect_uri');
      if (redirect.length > 0) {
        const rewritten: string = rewriteRedirectToAppScheme(redirect, TraccarConstants.DEEP_LINK_SCHEME);
        ExternalLinks.open(this.abilityContext(), this.withQueryParam(url, 'redirect_uri', rewritten), this.ui());
        return true;
      }
    }

    // ② 跨站链接：一律外部浏览器打开，避免在壳内迷路。
    // 上游比的是 authority（host:port）而不是 origin：如果服务器被填成 http:// 且 302 到 https://，
    // 用 origin 比较会让此后每一个站内链接都被判成跨站、应用内导航彻底失效。
    if (parts.authority.toLowerCase() !== parseUri(this.serverUrl).authority.toLowerCase()) {
      ExternalLinks.open(this.abilityContext(), url, this.ui());
      return true;
    }

    // ③ 可下载后缀：带令牌原生下载（上游 _downloadFile），而不是让 Web 直接触发下载。
    if (isDownloadable(url, TraccarConstants.DOWNLOADABLE_EXTENSIONS)) {
      this.startTokenDownload(url);
      return true;
    }

    // ④ 其余放行。
    return false;
  }

  /** 替换/追加查询参数（改写 redirect_uri 用）。 */
  private withQueryParam(url: string, name: string, value: string): string {
    const parts: UriParts = parseUri(url);
    const params: QueryParam[] = parts.queryParams();
    const result: QueryParam[] = [];
    let replaced: boolean = false;
    for (const param of params) {
      if (param.name === name) {
        if (!replaced) {
          result.push(new QueryParam(name, value));
          replaced = true;
        }
      } else {
        result.push(param);
      }
    }
    if (!replaced) {
      result.push(new QueryParam(name, value));
    }
    return buildUri(parts.scheme, parts.authority, parts.path, result);
  }

  /** 带 Authorization 头下载，再拉起系统分享（上游 _downloadFile + share_plus）。 */
  private startTokenDownload(url: string): void {
    const context: common.UIAbilityContext = this.abilityContext();
    // 后缀只从路径末段取：直接对整个 URL 找最后一个点会把 `?deviceId=1.5` 里的 `5` 当后缀。
    const segment: string = lastPathSegment(url);
    const dot: number = segment.lastIndexOf('.');
    const extension: string = dot >= 0 ? segment.substring(dot + 1).toLowerCase() : '';
    const fileName: string = DownloadService.timestampedName(extension.length > 0 ? extension : 'bin');
    TokenStore.read().then((token: string) => {
      if (token.length === 0) {
        // 没有令牌时【不能】把同一个 URL 再 loadUrl 一次：那会重新触发 onLoadIntercept，
        // 又落到下载分支，形成死循环。上游此时只会记日志（Bearer 空令牌必然失败）。
        Log.warn('download skipped: no login token');
        return;
      }
      DownloadService.downloadWithToken(context, url, token, fileName).then((path: string) => {
        if (path.length === 0) {
          Log.warn('download failed', url);
          return;
        }
        this.deliverFile(path, fileName);
      });
    }).catch((error: BusinessError) => {
      Log.error('token read failed for download', `code=${error.code}`);
    });
  }

  /** 交给系统分享（上游下载后总是调起分享面板），分享不可用则退回「用其他应用打开」。 */
  private deliverFile(path: string, fileName: string): void {
    const context: common.UIAbilityContext = this.abilityContext();
    ShareService.shareFile(context, path, fileName).then((shown: boolean) => {
      if (!shown) {
        ShareService.openWithSystem(context, path);
      }
    }).catch((error: BusinessError) => {
      Log.warn('share failed', `code=${error.code}`);
      ShareService.openWithSystem(context, path);
    });
  }

  private navigate(target: string): void {
    const normalized: string = normalizeServerUrl(target);
    this.loadingError = '';
    this.currentUrl = normalized;
    if (!this.webAttached) {
      this.webSrc = normalized;
      return;
    }
    try {
      this.controller.loadUrl(normalized);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('loadUrl threw', `code=${failure.code} msg=${failure.message}`);
      this.webSrc = normalized;
    }
  }

  /**
   * 错误屏提交新地址：对应上游 onUrlSubmitted —— 删令牌、存地址、清空错误、
   * 让 WebView 整块重建（上游是靠 `_controller = null` + `ValueKey(_initialUrl)` 达到同样效果）。
   */
  private submitServerUrl(rawUrl: string): void {
    const normalized: string = normalizeServerUrl(rawUrl);
    TokenStore.delete();
    this.authenticated = false;
    ServerPrefs.setServerUrl(normalized);
    this.serverUrl = normalized;
    this.currentUrl = normalized;
    Log.info('server url submitted', normalized);
    // 重建 Web：旧 controller / 代理 / 下载委托都绑在旧 Web 上，必须一起换掉。
    this.webAttached = false;
    this.pendingPushToken = '';
    this.downloadHandler = undefined;
    this.proxy = undefined;
    this.scriptItems = undefined;
    this.controller = new webview.WebviewController();
    this.webSrc = normalized;
    this.loadingError = '';
  }

  /** `server|<url>`：Web 端要求换服务器。上游只删令牌、存地址、loadUrl，不动 WebView。 */
  private handleServerChange(rawUrl: string): void {
    if (rawUrl.length > 0 && !isValidServerUrl(rawUrl)) {
      Log.warn('server change rejected: invalid url', rawUrl);
      return;
    }
    const normalized: string = rawUrl.length > 0 ? normalizeServerUrl(rawUrl) : TraccarConstants.DEFAULT_SERVER_URL;
    TokenStore.delete();
    this.authenticated = false;
    ServerPrefs.setServerUrl(normalized);
    this.serverUrl = normalized;
    this.currentUrl = normalized;
    Log.info('server changed', normalized);
    this.loadingError = '';
    if (this.webAttached) {
      try {
        this.controller.loadUrl(normalized);
        return;
      } catch (error) {
        const failure: BusinessError = error as BusinessError;
        Log.warn('loadUrl threw', `code=${failure.code}`);
      }
    }
    this.webSrc = normalized;
  }

  private reload(): void {
    try {
      this.controller.refresh();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('refresh threw', `code=${failure.code}`);
      this.webSrc = this.serverUrl;
    }
  }

  private safeCanGoBack(): boolean {
    if (!this.webAttached) {
      return false;
    }
    try {
      return this.controller.accessBackward();
    } catch (error) {
      return false;
    }
  }

  // ---------------------------------------------------------------- Web 事件

  private onControllerAttached(): void {
    Log.info('onControllerAttached enter');
    this.webAttached = true;
    WebSessionManager.applyUserAgent(this.controller);
    try {
      // 目录要先建好：WebDownloadDelegate 与 DownloadService 各自拼路径，只有后者会 mkdir。
      const dir: string = DownloadService.prepareDir(this.abilityContext());
      // 复用单实例：重复 setDownloadDelegate 的语义是"最后注册者生效"，没必要每次重建。
      if (this.downloadHandler === undefined) {
        this.downloadHandler = new DownloadHandler(this.controller, dir);
        this.downloadHandler.attach();
      }
    } catch (error) {
      // 拿不到上下文也不能影响 Web 本身可用，只是失去内核下载委托这条兜底路径。
      Log.warn('download delegate attach skipped');
    }
    // 附着前拿到的推送令牌在这里补发。
    if (this.pendingPushToken.length > 0) {
      const pending: string = this.pendingPushToken;
      this.pendingPushToken = '';
      this.callJs(TraccarConstants.JS_FN_UPDATE_NOTIFICATION_TOKEN, pending);
    }
  }

  private onPageEnd(url: string): void {
    this.currentUrl = url;
    this.canGoBack = this.safeCanGoBack();
    try {
      const title: string = this.controller.getTitle();
      if (title.length > 0) {
        this.pageTitle = title;
      }
    } catch (error) {
      // 忽略：拿不到标题不影响使用。
    }
    WebSessionManager.saveCookies();
  }

  private onErrorReceive(event: OnErrorReceiveEvent): void {
    // 取请求/错误信息的两次原生调用各自兜异常：范围放宽会让 try 把真错误一起吞掉，
    // 结果就是加载失败却永远不显示错误页。
    let isMainFrame: boolean = false;
    try {
      isMainFrame = event.request.isMainFrame();
    } catch (error) {
      Log.warn('onErrorReceive: main frame check failed');
      return;
    }
    if (!isMainFrame) {
      return;
    }
    let code: number = 0;
    let info: string = '';
    try {
      code = event.error.getErrorCode();
      info = event.error.getErrorInfo();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('onErrorReceive: error info unavailable', `code=${failure.code}`);
      this.loadingError = '无法加载页面，请检查服务器地址或网络';
      return;
    }
    if (IGNORED_LOAD_ERRORS.indexOf(code) >= 0) {
      // 用户主动取消 / 被拦截的导航，不当作错误。
      return;
    }
    this.loadingError = info.length > 0 ? info : `无法加载页面（错误码 ${code}）`;
    Log.warn('main frame load error', `code=${code} info=${info}`);
  }

  private onGeolocationShow(event: OnGeolocationShowEvent): void {
    const origin: string = event.origin;
    AppPermissions.ensureLocation(this.abilityContext()).then((granted: boolean) => {
      try {
        event.geolocation.invoke(origin, granted, true);
      } catch (error) {
        Log.warn('geolocation invoke failed');
      }
      if (!granted) {
        Log.info('geolocation denied');
      }
    });
  }

  private onPermissionRequest(event: OnPermissionRequestEvent): void {
    const request: PermissionRequest = event.request;
    const resources: string[] = request.getAccessibleResource();
    // 严格对齐上游 onPermissionRequest：网页只可能拿到相机（扫码 / 拍照上传）。
    // 上游把任何非相机资源都视作「未授予」，只要有一项不是相机就整体 DENY，
    // 因此麦克风、受保护媒体、剪贴板之类一律拒绝，网页无法越权驱动本机能力。
    if (resources.length === 0) {
      request.deny();
      return;
    }
    for (const resource of resources) {
      if (AppPermissions.toPermission(resource) !== PERMISSION_CAMERA) {
        Log.info('web permission denied', resource);
        request.deny();
        return;
      }
    }
    AppPermissions.ensureCamera(this.abilityContext()).then((granted: boolean) => {
      try {
        if (granted) {
          request.grant(resources);
        } else {
          request.deny();
        }
      } catch (error) {
        Log.warn('permission request settle failed');
      }
    });
  }

  /** 网页 <input type=file>：用系统选择器选一个文件回填给 Web。 */
  private onShowFileSelector(event: OnShowFileSelectorEvent): boolean {
    const accept: string[] = event.fileSelector.getAcceptType();
    const capture: boolean = event.fileSelector.isCapture();
    let wantsImage: boolean = capture;
    for (const type of accept) {
      if (type.indexOf('image') >= 0) {
        wantsImage = true;
      }
    }
    const context: common.UIAbilityContext = this.abilityContext();
    if (wantsImage) {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      photoPicker.select(options).then((result: photoAccessHelper.PhotoSelectResult) => {
        try {
          event.result.handleFileList(result.photoUris);
        } catch (error) {
          Log.warn('handleFileList failed');
        }
      }).catch((error: BusinessError) => {
        Log.info('photo picker canceled', `code=${error.code}`);
        try {
          event.result.handleFileList([]);
        } catch (inner) {
          // 忽略。
        }
      });
      return true;
    }
    const docOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    docOptions.maxSelectNumber = 1;
    const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    docPicker.select(docOptions).then((uris: string[]) => {
      try {
        event.result.handleFileList(uris);
      } catch (error) {
        Log.warn('handleFileList failed');
      }
    }).catch((error: BusinessError) => {
      Log.info('document picker canceled', `code=${error.code}`);
      try {
        event.result.handleFileList([]);
      } catch (inner) {
        // 忽略。
      }
    });
    return true;
  }

  /** 对应上游：`requestPermission()` 之后才挂推送令牌监听。 */
  private enableNotifications(): void {
    const context: common.UIAbilityContext = this.abilityContext();
    NotificationHelper.isEnabled().then((enabled: boolean) => {
      if (enabled) {
        this.forwardPushToken();
        return;
      }
      NotificationHelper.requestEnable(context).then((granted: boolean) => {
        if (!granted) {
          Log.info('notification permission not granted');
          return;
        }
        this.forwardPushToken();
      });
    }).catch((error: BusinessError) => {
      Log.warn('notification enable check failed', `code=${error.code}`);
    });
  }

  private forwardPushToken(): void {
    PushTokens.getToken().then((token: string) => {
      this.pushTokenToWeb(token);
    });
  }

  // ------------------------------------------------------------------ 工具

  private abilityContext(): common.UIAbilityContext {
    // getContext() 已废弃：改走 UIContext 的宿主上下文。
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /** 拿不到宿主上下文时返回 undefined（桥回调可能落在窗口已销毁的瞬间），调用方需自行兜底。 */
  private tryAbilityContext(): common.UIAbilityContext | undefined {
    try {
      return this.abilityContext();
    } catch (error) {
      Log.warn('ability context unavailable');
      return undefined;
    }
  }

  private ui(): UIContext {
    return this.getUIContext();
  }

  /** 幂等：避免每次 build 都重新注册 JS 代理与注入脚本。 */
  private javaScriptProxy(): JavaScriptProxy {
    if (this.proxy === undefined) {
      this.proxy = buildJavaScriptProxy(this.host, this.controller);
    }
    return this.proxy;
  }

  private documentStartScripts(): ScriptItem[] {
    if (this.scriptItems === undefined) {
      this.scriptItems = [{ script: buildBridgeScript(), scriptRules: BRIDGE_SCRIPT_RULES }];
    }
    return this.scriptItems;
  }
}
