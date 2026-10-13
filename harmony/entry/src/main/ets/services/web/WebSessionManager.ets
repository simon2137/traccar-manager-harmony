import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';

/**
 * Web 会话状态（Cookie / UA）。
 *
 * Traccar Web 端的登录态就是一个 JSESSIONID Cookie，因此壳应用必须保证：
 * 1. 接受第一方与第三方 Cookie（Web 端有 iframe 场景）；
 * 2. 进程被回收前把 Cookie 落盘（saveCookieAsync），下次冷启动仍是登录态；
 * 3. UA 里带上应用标识，便于服务端日志区分原生壳与浏览器。
 */
export class WebSessionManager {
  private static userAgent: string = '';

  static init(controller?: webview.WebviewController): void {
    try {
      webview.WebCookieManager.putAcceptCookieEnabled(true);
      webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true);
      Log.info('cookie acceptance enabled');
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('cookie acceptance setup failed', `code=${failure.code}`);
    }
    if (controller !== undefined) {
      WebSessionManager.applyUserAgent(controller);
    }
  }

  /** 在默认 UA 后追加壳标识；重复调用幂等。 */
  static applyUserAgent(controller: webview.WebviewController): void {
    try {
      if (WebSessionManager.userAgent.length === 0) {
        const base: string = controller.getUserAgent();
        WebSessionManager.userAgent = `${base} TraccarManagerHarmony/6.1.2`;
      }
      controller.setCustomUserAgent(WebSessionManager.userAgent);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('set user agent failed', `code=${failure.code}`);
    }
  }

  /** 落盘当前 Cookie（onPageEnd、应用进后台时调用）。 */
  static saveCookies(): void {
    try {
      webview.WebCookieManager.saveCookieAsync().then(() => {
        Log.debug('cookies saved');
      }).catch((error: BusinessError) => {
        Log.debug('cookie save skipped', `code=${error.code}`);
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.debug('cookie save unavailable', `code=${failure.code}`);
    }
  }

  /** 当前站点的 Cookie 串（仅用于诊断输出，不参与请求构造）。 */
  static cookieFor(url: string): string {
    try {
      return webview.WebCookieManager.fetchCookieSync(url, false);
    } catch (error) {
      return '';
    }
  }

  /** 清空登录态（登出/切换服务器）。 */
  static clearCookies(): void {
    try {
      webview.WebCookieManager.clearAllCookiesSync();
      Log.info('cookies cleared');
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('clear cookies failed', `code=${failure.code}`);
    }
  }
}
