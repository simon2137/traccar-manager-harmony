import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { Log } from '../common/utils/Log';
import { TraccarConstants } from '../common/constants/TraccarConstants';
import { STATUS_BAR_INSET_KEY } from '../common/utils/Keys';
import { DeepLinkRouter } from '../services/navigation/DeepLinkRouter';
import { PushTokens } from '../services/notification/PushTokens';
import { ServerPrefs } from '../services/storage/ServerPrefs';

/** 跨端接续时传递当前页面地址的键。 */
const CONTINUATION_URL_KEY: string = 'traccarUrl';

/** 窗口底色，与 resources/{base,dark}/element/color.json 的 start_window_background 一致。 */
const WINDOW_BACKGROUND_LIGHT: string = '#F9F9FF';
const WINDOW_BACKGROUND_DARK: string = '#1A1C1E';

/**
 * 应用入口：只做生命周期编排，深链交给 DeepLinkRouter 的单槽邮箱，
 * 页面在 aboutToAppear / @Watch 里消费。
 *
 * 窗口采用**全屏布局**（setWindowLayoutFullScreen(true)）：内容可以画到屏幕最下沿，
 * 否则底部手势导航区会留出一条系统白带。代价是内容会钻进状态栏下面，
 * 所以这里顺手把状态栏高度写进 AppStorage(STATUS_BAR_INSET_KEY)，页面根容器据此给顶部留白。
 * 2in1 有系统窗口装饰（标题栏/最大化按钮），保持非全屏，不做上述处理。
 *
 * 顺序很重要：initializeWebEngine 必须早于任何 Web 组件创建（ArkDO 的同类做法），
 * 否则首个 Web 实例会退化到较慢的初始化路径。
 */
export default class EntryAbility extends UIAbility {
  private pendingUrl: string = '';
  /** 主窗口引用：onConfigurationUpdate 里复用它更新窗口底色与系统栏内容色。 */
  private mainWindow: window.Window | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    ServerPrefs.init(this.context);
    PushTokens.attach(this);
    try {
      webview.WebviewController.initializeWebEngine();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('initializeWebEngine failed', `code=${failure.code} msg=${failure.message}`);
    }
    if (TraccarConstants.WEB_DEBUGGING_ENABLED) {
      try {
        webview.WebviewController.setWebDebuggingAccess(true);
      } catch (error) {
        const failure: BusinessError = error as BusinessError;
        Log.warn('setWebDebuggingAccess failed', `code=${failure.code} msg=${failure.message}`);
      }
    }
    this.resolveWant(want, launchParam);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.applyWindowAppearance(windowStage);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Log.error('loadContent failed', JSON.stringify(err));
        return;
      }
      Log.info('loadContent succeeded');
    });
  }

  /** 深浅色切换时同步窗口底色与系统栏内容色（对应上游 setSystemUIOverlayStyle）。 */
  onConfigurationUpdate(newConfig: Configuration): void {
    Log.info('onConfigurationUpdate', `colorMode=${newConfig.colorMode}`);
    const target: window.Window | undefined = this.mainWindow;
    if (target === undefined) {
      return;
    }
    this.applyWindowStyle(target, this.isDarkMode());
  }

  /**
   * 设置窗口底色（避免深色模式下启动/回前台闪白）与状态栏、导航条内容色。
   * 内容色跟随明暗：上游 `statusBarIconBrightness: dark ? light : dark`。
   */
  private applyWindowAppearance(windowStage: window.WindowStage): void {
    try {
      const main: window.Window = windowStage.getMainWindowSync();
      this.mainWindow = main;
      this.applyWindowStyle(main, this.isDarkMode());
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('window appearance init failed', `code=${failure.code} msg=${failure.message}`);
    }
  }

  private applyWindowStyle(target: window.Window, dark: boolean): void {
    try {
      target.setWindowBackgroundColor(dark ? WINDOW_BACKGROUND_DARK : WINDOW_BACKGROUND_LIGHT);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('setWindowBackgroundColor failed', `code=${failure.code}`);
    }
    // 2in1 不支持系统栏 API、且有系统窗口装饰：跳过（编译期仍会有针对 2in1 的可用性提示）。
    if (deviceInfo.deviceType === '2in1') {
      return;
    }
    try {
      // 全屏布局：窗口覆盖底部手势导航区，消除「最下面一条白色空白」。
      // 必须等布局模式生效后再读安全区：非全屏时窗口不覆盖状态栏，TYPE_SYSTEM 的 topRect 是 0。
      target.setWindowLayoutFullScreen(true).then(() => {
        this.publishStatusBarInset(target);
      }).catch((error: BusinessError) => {
        Log.warn('setWindowLayoutFullScreen failed', `code=${error.code} msg=${error.message}`);
        this.publishStatusBarInset(target);
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('setWindowLayoutFullScreen failed', `code=${failure.code} msg=${failure.message}`);
      this.publishStatusBarInset(target);
    }
    try {
      target.setWindowSystemBarProperties({
        statusBarContentColor: dark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('setWindowSystemBarProperties failed', `code=${failure.code}`);
    }
  }

  /**
   * 把状态栏高度（vp）写进 AppStorage，供页面根容器做顶部内边距。
   * 全屏布局下窗口会画到状态栏下面，页面必须自己让出这一段，否则网页顶栏会被状态栏压住。
   */
  private publishStatusBarInset(target: window.Window, retry: boolean = true): void {
    let insetVp: number = 0;
    try {
      const avoid: window.AvoidArea = target.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const density: number = display.getDefaultDisplaySync().densityPixels;
      if (density > 0) {
        insetVp = Math.round(avoid.topRect.height / density);
      }
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('getWindowAvoidArea failed', `code=${failure.code} msg=${failure.message}`);
    }
    if (insetVp <= 0 && retry) {
      // 布局模式切换后系统栏信息可能晚一帧才更新：稍后重读一次（只重试一次，避免死循环）。
      setTimeout(() => {
        this.publishStatusBarInset(target, false);
      }, 300);
      return;
    }
    AppStorage.setOrCreate(STATUS_BAR_INSET_KEY, insetVp);
    Log.info('status bar inset published', `${insetVp}vp`);
  }

  private isDarkMode(): boolean {
    return this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.resolveWant(want, launchParam);
  }

  /**
   * 跨端接续（多端适配的一部分）：把当前服务器地址带到目标设备。
   * 返回 AGREE 表示允许迁移，目标设备在 onCreate 的 CONTINUATION 分支里取回。
   */
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const url: string = this.pendingUrl.length > 0 ? this.pendingUrl : ServerPrefs.serverUrl();
    wantParam[CONTINUATION_URL_KEY] = url;
    Log.info('onContinue', url);
    return AbilityConstant.OnContinueResult.AGREE;
  }

  onWindowStageDestroy(): void {
    Log.info('onWindowStageDestroy');
  }

  onForeground(): void {
    Log.info('onForeground');
  }

  onBackground(): void {
    Log.info('onBackground');
  }

  onDestroy(): void {
    Log.info('onDestroy');
  }

  /** 把 want 里的深链/接续地址投进邮箱；页面可能还没建好，所以只投递不直接加载。 */
  private resolveWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      const parameters: Record<string, Object> | undefined = want.parameters;
      if (parameters !== undefined) {
        const restored: Object | undefined = parameters[CONTINUATION_URL_KEY];
        if (restored !== undefined && typeof restored === 'string') {
          this.pendingUrl = restored;
          DeepLinkRouter.publish(restored);
          Log.info('continuation url received', restored);
          return;
        }
      }
    }
    // 点通知冷启动：上游读 getInitialMessage() 的 data['eventId'] 跳到 <服务器>/event/<id>
    // （lib/main_screen.dart:155-161）。鸿蒙侧推送点击会把载荷放进 want.parameters，
    // 键名取决于 AGC 配置，所以这里只在真的看到字符串 eventId 时才跳转。
    const parameters: Record<string, Object> | undefined = want.parameters;
    if (parameters !== undefined) {
      const eventId: Object | undefined = parameters['eventId'];
      if (eventId !== undefined && typeof eventId === 'string' && eventId.length > 0) {
        DeepLinkRouter.publishEvent(eventId, ServerPrefs.serverUrl());
        Log.info('notification event received', eventId);
        return;
      }
    }
    const uri: string | undefined = want.uri;
    if (uri !== undefined && uri.length > 0) {
      this.pendingUrl = uri;
      DeepLinkRouter.publish(uri);
      Log.info('deep link received', uri);
    }
  }
}
