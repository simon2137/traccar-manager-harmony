import { notificationManager } from '@kit.NotificationKit';
import type { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';

/**
 * 通知开关的查询与请求。
 *
 * 上游用 firebase_messaging 的 requestPermission()，并等待 `_authenticated` 完成（30s 超时）
 * 之后才注册令牌刷新与消息回调（lib/main_screen.dart）。鸿蒙侧通知授权不是弹窗式
 * 运行时权限，而是用户在设置里的开关，因此这里的策略是：
 * 查 →（未开）请求跳转设置页 → 再查一次，结果仅用于提示，绝不阻断后续流程。
 */
export class NotificationHelper {
  /** 通知是否已启用。查询失败按未启用处理。 */
  static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.info('notification state unknown', `code=${failure.code}`);
      return false;
    }
  }

  static isEnabledSync(): boolean {
    try {
      return notificationManager.isNotificationEnabledSync();
    } catch (error) {
      return false;
    }
  }

  /**
   * 请求开启通知（会拉起系统半模态设置页）。
   * @returns 用户操作后的实际开关状态。
   */
  static async requestEnable(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.info('requestEnableNotification returned', `code=${failure.code} msg=${failure.message}`);
    }
    return NotificationHelper.isEnabled();
  }

  /**
   * 打开通知设置并读取用户选择（API 26 新增的 readback 能力，
   * `openNotificationSettingsWithResult`）。用户可能顺带关掉横幅/锁屏显示，
   * 这些字段可用于提示「你关了锁屏通知，所以没收到告警」。
   */
  static async openSettingsWithResult(context: common.UIAbilityContext): Promise<notificationManager.NotificationSetting | undefined> {
    try {
      const setting: notificationManager.NotificationSetting = await notificationManager.openNotificationSettingsWithResult(context);
      Log.info('notification setting read back',
        `enabled=${setting.notificationEnabled} banner=${setting.bannerEnabled} lock=${setting.lockScreenEnabled}`);
      return setting;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('openNotificationSettingsWithResult failed', `code=${failure.code} msg=${failure.message}`);
      return undefined;
    }
  }
}
