import { preferences } from '@kit.ArkData';
import type { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';
import { PREF_LAST_SERVER_NAME, PREF_SERVER_URL, PREFERENCES_NAME } from '../../common/utils/Keys';
import { TraccarConstants } from '../../common/constants/TraccarConstants';
import { isValidServerUrl, normalizeServerUrl } from '../../common/model/UriModel';

/**
 * 轻量设置存储（Preferences）。
 *
 * 上游用 SharedPreferences 存服务器地址与登录名（键名 'url'，见 lib/main_screen.dart:105），
 * 这里保持同名键，方便与既有文档/服务端说明对齐。核心业务设置一律同步读写：
 * 启动路径上必须立即拿到服务器地址，异步抖动会让首帧闪一次默认地址。
 */
export class ServerPrefs {
  private static store: preferences.Preferences | undefined = undefined;

  static init(context: common.Context): void {
    if (ServerPrefs.store !== undefined) {
      return;
    }
    try {
      const options: preferences.Options = { name: PREFERENCES_NAME };
      ServerPrefs.store = preferences.getPreferencesSync(context, options);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('preferences init failed', `code=${failure.code} msg=${failure.message}`);
    }
  }

  private static readString(key: string, fallback: string): string {
    const store: preferences.Preferences | undefined = ServerPrefs.store;
    if (store === undefined) {
      return fallback;
    }
    try {
      const value: preferences.ValueType = store.getSync(key, fallback);
      if (typeof value === 'string') {
        return value;
      }
      return fallback;
    } catch (error) {
      return fallback;
    }
  }

  private static write(key: string, value: preferences.ValueType): void {
    const store: preferences.Preferences | undefined = ServerPrefs.store;
    if (store === undefined) {
      return;
    }
    try {
      store.putSync(key, value);
      store.flush().catch((error: BusinessError) => {
        Log.warn('preferences flush failed', `code=${error.code}`);
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('preferences write failed', `key=${key} code=${failure.code}`);
    }
  }

  /** 当前服务器地址；从未设置或值非法时回退到 demo.traccar.org（上游默认值）。 */
  static serverUrl(): string {
    const stored: string = ServerPrefs.readString(PREF_SERVER_URL, '');
    const normalized: string = normalizeServerUrl(stored);
    if (!isValidServerUrl(normalized)) {
      return TraccarConstants.DEFAULT_SERVER_URL;
    }
    return normalized;
  }

  static setServerUrl(url: string): void {
    const normalized: string = normalizeServerUrl(url);
    ServerPrefs.write(PREF_SERVER_URL, normalized);
    Log.info('server url saved', normalized);
  }

  static setLastServerName(name: string): void {
    ServerPrefs.write(PREF_LAST_SERVER_NAME, name);
  }
}
