import { DEEP_LINK_TICK_KEY, DEEP_LINK_URL_KEY, bumpTick } from '../../common/utils/Keys';
import { Log } from '../../common/utils/Log';

/**
 * 深链 / 通知点击的路由中转。
 *
 * EntryAbility 的 onCreate / onNewWant 拿到的 want 可能早于页面创建，也可能迟于页面创建，
 * 因此不能直接调页面方法。这里用 AppStorage 做单槽邮箱：
 *   - 生产者写入地址并自增 tick；
 *   - 消费者（Index 页）用 @StorageProp + @Watch 监听 tick，读到即消费并清空。
 * 这样冷启动与热启动两条路径共用一套代码（上游 app_links 的 uriLinkStream 等价物）。
 */
export class DeepLinkRouter {
  private static pending: string = '';

  /** 投递一个待加载地址。 */
  static publish(url: string): void {
    if (url.length === 0) {
      return;
    }
    DeepLinkRouter.pending = url;
    AppStorage.setOrCreate(DEEP_LINK_URL_KEY, url);
    bumpTick(DEEP_LINK_TICK_KEY);
    Log.info('deep link queued', url);
  }

  /** 取出并清空。 */
  static consume(): string {
    const value: string = AppStorage.get<string>(DEEP_LINK_URL_KEY) ?? DeepLinkRouter.pending;
    DeepLinkRouter.pending = '';
    AppStorage.setOrCreate(DEEP_LINK_URL_KEY, '');
    return value;
  }

  static hasPending(): boolean {
    return (AppStorage.get<string>(DEEP_LINK_URL_KEY) ?? '').length > 0;
  }

  /** 推送通知点击 → 事件详情页（上游：`${url}/event/$eventId`）。 */
  static publishEvent(eventId: string, serverUrl: string): void {
    if (eventId.length === 0) {
      return;
    }
    const base: string = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    DeepLinkRouter.publish(`${base}/event/${eventId}`);
  }
}
