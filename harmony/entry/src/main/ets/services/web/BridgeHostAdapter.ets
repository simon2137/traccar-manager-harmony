import { BridgeHost } from './TraccarBridge';

/**
 * 把 BridgeHost 的接口方法转成可赋值的回调字段。
 *
 * ArkTS 的 @Component struct 不能 implements 接口，也不能用带方法的对象字面量，
 * 所以桥接层需要这么一个零逻辑的适配器：页面创建它、填回调，再交给 javaScriptProxy。
 */
export class BridgeHostAdapter implements BridgeHost {
  onLoginHandler: (token: string) => void = () => {
  };
  onAuthenticationHandler: () => void = () => {
  };
  onAuthenticatedHandler: () => void = () => {
  };
  onLogoutHandler: () => void = () => {
  };
  onDownloadHandler: (base64: string) => void = () => {
  };
  onServerChangeHandler: (url: string) => void = () => {
  };

  onLogin(token: string): void {
    this.onLoginHandler(token);
  }

  onAuthenticationRequest(): void {
    this.onAuthenticationHandler();
  }

  onAuthenticated(): void {
    this.onAuthenticatedHandler();
  }

  onLogout(): void {
    this.onLogoutHandler();
  }

  onDownload(base64: string): void {
    this.onDownloadHandler(base64);
  }

  onServerChange(url: string): void {
    this.onServerChangeHandler(url);
  }
}
