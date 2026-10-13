import { webview } from '@kit.ArkWeb';
import { TraccarConstants } from '../../common/constants/TraccarConstants';
import { Log } from '../../common/utils/Log';

/**
 * 原生侧接收 Web 消息的宿主接口。
 * 页面实现它，桥对象只负责拆消息、不做业务判断。
 */
export interface BridgeHost {
  /** `login|<token>`：Web 端登录成功，交出令牌。 */
  onLogin(token: string): void;
  /** `authentication`：Web 端需要令牌来完成自动登录（原生可先做生物识别）。 */
  onAuthenticationRequest(): void;
  /** `authenticated`：Web 端确认已登录（上游用它结束等待，再挂推送回调）。 */
  onAuthenticated(): void;
  /** `logout`：令牌失效，删除本地令牌。 */
  onLogout(): void;
  /** `download|<base64>`：Web 端以 Blob 形式导出的表格。 */
  onDownload(base64: string): void;
  /** `server|<url>`：用户在 Web 端切换了服务器地址。 */
  onServerChange(url: string): void;
}

/**
 * 暴露给网页的桥对象（javaScriptProxy）。
 *
 * 消息协议与上游 lib/main_screen.dart 的 `_handleWebMessage` 完全一致：`前缀|载荷`，
 * 前缀未知时只记日志——Web 端可能比壳应用新，多出来的消息不能让壳崩掉。
 */
export class TraccarBridgeObject {
  private host: BridgeHost;

  constructor(host: BridgeHost) {
    this.host = host;
  }

  /** 网页调用入口：window.__traccarNativeInterface.postMessage('login|xxx') */
  postMessage(message: string): void {
    // 先记原始入参：模拟器/真机排查"消息到底有没有到原生"时，这行是唯一的锚点（debug 级，随 hilog -L D）。
    Log.debug('bridge in', `len=${message.length}`);
    const raw: string = TraccarBridgeObject.unwrap(message);
    if (raw.length === 0) {
      return;
    }
    const separator: number = raw.indexOf('|');
    const prefix: string = separator >= 0 ? raw.substring(0, separator) : raw;
    const payload: string = separator >= 0 ? raw.substring(separator + 1) : '';
    switch (prefix) {
      case TraccarConstants.MESSAGE_LOGIN:
        this.host.onLogin(payload);
        break;
      case TraccarConstants.MESSAGE_AUTHENTICATION:
        this.host.onAuthenticationRequest();
        break;
      case TraccarConstants.MESSAGE_AUTHENTICATED:
        this.host.onAuthenticated();
        break;
      case TraccarConstants.MESSAGE_LOGOUT:
        this.host.onLogout();
        break;
      case TraccarConstants.MESSAGE_DOWNLOAD:
        this.host.onDownload(payload);
        break;
      case TraccarConstants.MESSAGE_SERVER:
        this.host.onServerChange(payload);
        break;
      default:
        Log.debug('unknown web message', prefix);
        break;
    }
  }

  /**
   * ArkWeb 在部分调用路径下会把字符串参数再 JSON 编码一层（多出首尾引号与转义），
   * 这里做兼容解开；解析失败则原样使用，绝不丢消息。
   */
  private static unwrap(message: string): string {
    if (typeof message !== 'string') {
      return '';
    }
    const trimmed: string = message.trim();
    if (trimmed.length >= 2 && trimmed.charAt(0) === '"' && trimmed.charAt(trimmed.length - 1) === '"') {
      try {
        const parsed: string = JSON.parse(trimmed) as string;
        if (typeof parsed === 'string') {
          return parsed;
        }
      } catch (error) {
        return message;
      }
    }
    return message;
  }
}

/** 构造 javaScriptProxy 配置（在 Web 组件的 .javaScriptProxy() 中使用）。 */
export function buildJavaScriptProxy(host: BridgeHost, controller: webview.WebviewController): JavaScriptProxy {
  const proxy: JavaScriptProxy = {
    object: new TraccarBridgeObject(host),
    name: TraccarConstants.JS_PROXY_NAME,
    methodList: [TraccarConstants.JS_PROXY_METHOD],
    controller: controller
  };
  return proxy;
}
