import { pushService, pushCommon } from '@kit.PushKit';
import type { UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';

/**
 * 推送令牌与推送消息（HarmonyOS Push Kit）。
 *
 * 上游用 FirebaseMessaging：getToken() 拿到令牌后回填给 Web 端（JS 全局函数
 * updateNotificationToken），onTokenRefresh 时再回填一次；通知消息点击后用
 * data['eventId'] 跳到 `<服务器>/event/<id>`。鸿蒙侧对应 pushService.getToken()、
 * pushService.on('tokenUpdate') 与 pushService.receiveMessage()。
 *
 * 重要：Push Kit 需要在 AGC 控制台创建应用、在 module.json5 的 metadata 里配置
 * app_id / client_id，并在构建 profile 的 capabilities 里声明
 * com.huawei.service.push.base_service。本工程未附带这些云端凭据，因此这里一律按
 * 「能力可能不可用」处理：拿不到令牌就返回空串，调用方跳过回填，
 * 绝不因为推送不可用而阻断登录流程。
 *
 * 注意 Push Kit 的 on/receiveMessage 需要一个 Ability 实例，只有 EntryAbility 拿得到，
 * 因此由 EntryAbility 调 attach(this)，页面通过 setTokenSink 接收令牌。
 */
export class PushTokens {
  private static cached: string = '';
  private static ability: UIAbility | undefined = undefined;
  private static sink: ((token: string) => void) | undefined = undefined;
  private static eventSink: ((eventId: string) => void) | undefined = undefined;
  private static messageSink: ((data: string) => void) | undefined = undefined;
  private static attached: boolean = false;

  /** 由 EntryAbility.onCreate 调用：注册令牌轮换与消息接收。 */
  static attach(ability: UIAbility): void {
    if (PushTokens.attached && PushTokens.ability === ability) {
      // 同一个 ability 重复调用：不重复注册。
      return;
    }
    if (PushTokens.ability !== undefined && PushTokens.ability !== ability) {
      // 旧 ability 已销毁：tokenUpdate 能解绑就先解掉，避免回调指向已销毁对象。
      try {
        pushService.off('tokenUpdate');
      } catch (error) {
        Log.debug('push tokenUpdate unsubscribe skipped');
      }
    }
    PushTokens.ability = ability;
    PushTokens.attached = true;
    try {
      pushService.on('tokenUpdate', ability, (token: string) => {
        if (token.length === 0) {
          return;
        }
        PushTokens.cached = token;
        PushTokens.dispatchToken(token);
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.info('push tokenUpdate subscribe skipped', `code=${failure.code} msg=${failure.message}`);
    }
    try {
      pushService.receiveMessage('DEFAULT', ability, (payload: pushCommon.PushPayload) => {
        const data: string = payload.data;
        // 对应上游 onMessage：把整条消息交给 Web 的 handleNativeNotification，
        // 同时用 eventId 让壳层跳转到 <服务器>/event/<id>。
        const messageSink: ((data: string) => void) | undefined = PushTokens.messageSink;
        if (data !== undefined && data.length > 0 && messageSink !== undefined) {
          messageSink(data);
        }
        const eventId: string = PushTokens.extractEventId(data);
        const sink: ((eventId: string) => void) | undefined = PushTokens.eventSink;
        if (eventId.length > 0 && sink !== undefined) {
          sink(eventId);
        }
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.info('push message subscribe skipped', `code=${failure.code} msg=${failure.message}`);
    }
  }

  /**
   * 说明：Push Kit 只声明了 `off('tokenUpdate', callback?)`，`receiveMessage` 没有对应的
   * off（见 @hms.core.push.pushService.d.ts:228/368/386），因此消息订阅无法解绑。
   * 上面用「ability 实例相同才跳过注册」的守卫保证同一次 ability 生命周期内只注册一次；
   * 页面销毁时用 clearXxxSink() 摘掉消费者闭包，避免静态字段长期持有已销毁的页面实例。
   */
  static detachSinks(): void {
    PushTokens.sink = undefined;
    PushTokens.eventSink = undefined;
    PushTokens.messageSink = undefined;
  }

  /** 页面挂载时注册令牌消费者（拿到令牌后回填给 Web）。 */
  static setTokenSink(sink: (token: string) => void): void {
    PushTokens.sink = sink;
  }

  static clearTokenSink(): void {
    PushTokens.sink = undefined;
  }

  /** 通知消息点击的消费者（eventId）。 */
  static setEventSink(sink: (eventId: string) => void): void {
    PushTokens.eventSink = sink;
  }

  static clearEventSink(): void {
    PushTokens.eventSink = undefined;
  }

  /** 整条通知消息的消费者（对应上游 handleNativeNotification）。 */
  static setMessageSink(sink: (data: string) => void): void {
    PushTokens.messageSink = sink;
  }

  static clearMessageSink(): void {
    PushTokens.messageSink = undefined;
  }

  /** 取当前令牌；未配置 Push Kit 或网络不可用时返回空串。 */
  static async getToken(): Promise<string> {
    if (PushTokens.cached.length > 0) {
      return PushTokens.cached;
    }
    try {
      const token: string = await pushService.getToken();
      if (token.length > 0) {
        PushTokens.cached = token;
        Log.info('push token acquired');
      }
      return token;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.info('push token unavailable', `code=${failure.code} msg=${failure.message}`);
      return '';
    }
  }

  /** 主动把缓存令牌推给消费者（登录成功后调用，对应上游 getToken 后回填）。 */
  static dispatchToken(token: string): void {
    const sink: ((token: string) => void) | undefined = PushTokens.sink;
    if (sink !== undefined && token.length > 0) {
      sink(token);
    }
  }

  private static extractEventId(data: string): string {
    if (data === undefined || data === null || data.length === 0) {
      return '';
    }
    try {
      const parsed: Record<string, string> = JSON.parse(data) as Record<string, string>;
      const candidate: string = parsed.eventId;
      if (candidate === undefined || candidate === null) {
        return '';
      }
      return typeof candidate === 'string' ? candidate : JSON.stringify(candidate);
    } catch (error) {
      Log.warn('push payload is not json');
      return '';
    }
  }
}
