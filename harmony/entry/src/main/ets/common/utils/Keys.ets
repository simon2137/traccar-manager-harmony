/**
 * AppStorage / Preferences 的键名集中地。任何跨模块传递的状态都必须在这里登记，
 * 避免散落的字符串字面量（ArkDO 的 StorageKeys.ets 是同一思路）。
 */

/** 服务器地址（Preference 存储，键名与上游 SharedPreferences 的 'url' 保持一致）。 */
export const PREF_SERVER_URL: string = 'url';
/** 上次成功登录的显示名。 */
export const PREF_LAST_SERVER_NAME: string = 'lastServerName';

/** Preferences 实例名。 */
export const PREFERENCES_NAME: string = 'traccar_manager_settings';

/** 原生 → Web 待注入的深链地址。 */
export const DEEP_LINK_URL_KEY: string = 'traccarDeepLinkUrl';
/** 深链变化计数器：页面用 @StorageProp 监听它来触发加载（同 ArkDO 的 bumpTick 手法）。 */
export const DEEP_LINK_TICK_KEY: string = 'traccarDeepLinkTick';

/** 计数器自增，用于「只传信号不传值」的事件（深链、返回键等）。 */
export function bumpTick(key: string): void {
  const current: number = AppStorage.get<number>(key) ?? 0;
  AppStorage.setOrCreate(key, current + 1);
}
