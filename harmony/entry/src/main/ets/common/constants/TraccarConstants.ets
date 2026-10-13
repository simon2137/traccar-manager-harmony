/**
 * 与上游 Flutter 版本 (traccar-manager 6.1.2) 严格对齐的常量。
 * 任何取值都不应在这里"顺手优化"，否则会破坏与 Traccar Web 端已有的约定。
 */
export class TraccarConstants {
  /** 上游 lib/main_screen.dart:105 的默认服务器地址。 */
  static readonly DEFAULT_SERVER_URL: string = 'https://demo.traccar.org';
  /** 上游 SharedPreferences 中保存服务器地址的 key。 */
  static readonly PREF_KEY_SERVER_URL: string = 'url';
  /** 上游 FlutterSecureStorage 中保存登录 token 的 key。 */
  static readonly SECRET_KEY_TOKEN: string = 'token';
  /** Android/iOS 深链 scheme，鸿蒙沿用同一个，便于服务端与文档复用。 */
  static readonly DEEP_LINK_SCHEME: string = 'org.traccar.manager';
  /** 上游 _isDownloadable(): 这些后缀的请求交给原生下载并分享。 */
  static readonly DOWNLOADABLE_EXTENSIONS: string[] = ['xlsx', 'kml', 'csv', 'gpx'];
  /** 上游 _handleWebMessage() 中 Web 端调用原生使用的消息前缀。 */
  static readonly MESSAGE_LOGIN: string = 'login';
  static readonly MESSAGE_AUTHENTICATION: string = 'authentication';
  static readonly MESSAGE_AUTHENTICATED: string = 'authenticated';
  static readonly MESSAGE_LOGOUT: string = 'logout';
  static readonly MESSAGE_DOWNLOAD: string = 'download';
  static readonly MESSAGE_SERVER: string = 'server';
  /** Web 端注入后，原生回调 Web 的全局函数名（上游 evaluateJavascript 中同名）。 */
  static readonly JS_FN_UPDATE_NOTIFICATION_TOKEN: string = 'updateNotificationToken';
  static readonly JS_FN_HANDLE_LOGIN_TOKEN: string = 'handleLoginToken';
  static readonly JS_FN_HANDLE_NATIVE_NOTIFICATION: string = 'handleNativeNotification';
  /**
   * javaScriptProxy 注册到 window 上的对象名。
   *
   * 刻意不叫 'appInterface'：注入脚本必须把 window.appInterface 覆写成「带队列的稳定入口」
   * （Web 端只认这个名字），若原生对象也用同名，它会被脚本直接覆盖掉，且脚本解析原生对象时
   * 可能解析到自己的入口，造成消息在 JS 内部自环、永远到不了原生。
   */
  static readonly JS_PROXY_NAME: string = '__traccarNativeInterface';
  static readonly JS_PROXY_METHOD: string = 'postMessage';
  /** 注入脚本为 Web 端保留的全局入口名（与上游 flutter_inappwebview 的约定一致）。 */
  static readonly JS_BRIDGE_NAME: string = 'appInterface';
  /** 注入脚本安装标记，防止重复安装。 */
  static readonly JS_BRIDGE_FLAG: string = '__traccarBridgeInstalled';
  /** 上游 login 之后等待 authenticated 的超时（_initNotifications 中 30s）。 */
  static readonly AUTHENTICATED_TIMEOUT_MS: number = 30000;
  /** OAuth authorize 请求必须同时出现的查询参数（上游 shouldOverrideUrlLoading）。 */
  static readonly OAUTH_PARAMS: string[] = ['response_type', 'client_id', 'redirect_uri', 'scope'];
  /**
   * 是否打开 ArkWeb 的 DevTools 调试端口（设备侧 9222）。
   *
   * 上游 Flutter 版在 debug 构建里同样打开 WebView 调试。发布前可置为 false：
   * 关闭后 `hdc fport tcp:9222 tcp:9222` 会连接失败，不影响任何功能。
   */
  static readonly WEB_DEBUGGING_ENABLED: boolean = true;
}
