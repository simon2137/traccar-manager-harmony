import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';
import { TraccarConstants } from '../../common/constants/TraccarConstants';

/**
 * 登录令牌存储。
 *
 * 上游用 FlutterSecureStorage（lib/token_store.dart），鸿蒙等价物是 Asset Store Kit：
 * 密文由系统托管（TEE/加密数据库），应用进程只能通过别名取回，且可声明「需设备解锁」。
 * 别名沿用上游的 key 'token'。
 *
 * 注意：Asset 的 SECRET / ALIAS 是 BYTES 类型标签（TagType.BYTES），必须传 Uint8Array。
 */
const TOKEN_ALIAS: string = TraccarConstants.SECRET_KEY_TOKEN;

function encodeText(text: string): Uint8Array {
  return new util.TextEncoder().encodeInto(text);
}

function decodeText(bytes: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

export class TokenStore {
  /** 写入/覆盖令牌。Asset 已存在同名条目时先 add 失败再 update，避免多一次查询。 */
  static async save(token: string): Promise<void> {
    Log.debug('token save start', `len=${token.length}`);
    const attributes: asset.AssetMap = TokenStore.buildMap();
    attributes.set(asset.Tag.SECRET, encodeText(token));
    try {
      await asset.add(attributes);
      Log.info('token saved');
      return;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      if (failure.code !== asset.ErrorCode.DUPLICATED) {
        Log.error('token add failed', `code=${failure.code} msg=${failure.message}`);
        return;
      }
    }
    try {
      // update 的第一个参数是查询条件（只按别名定位），第二个是要覆盖的属性。
      // 注意 attributesToUpdate 里【不能】再带 ALIAS：别名是查询字段，混进更新集会被判 401。
      const query: asset.AssetMap = TokenStore.aliasMap();
      const changes: asset.AssetMap = new Map<asset.Tag, asset.Value>();
      changes.set(asset.Tag.SECRET, encodeText(token));
      await asset.update(query, changes);
      Log.info('token updated');
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('token update failed', `code=${failure.code} msg=${failure.message}`);
    }
  }

  /**
   * 读取令牌。不存在或查询失败返回空串。
   * 生物识别闸门不在这里做（见 BiometricGate），调用方决定是否需要先验证身份。
   */
  static async read(): Promise<string> {
    const query: asset.AssetMap = TokenStore.aliasMap();
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: asset.AssetMap[] = await asset.query(query);
      if (results.length === 0) {
        return '';
      }
      const secret: asset.Value | undefined = results[0].get(asset.Tag.SECRET);
      if (secret === undefined || !(secret instanceof Uint8Array)) {
        return '';
      }
      return decodeText(secret);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      if (failure.code !== asset.ErrorCode.NOT_FOUND) {
        Log.warn('token query failed', `code=${failure.code} msg=${failure.message}`);
      }
      return '';
    }
  }

  static async hasToken(): Promise<boolean> {
    const token: string = await TokenStore.read();
    return token.length > 0;
  }

  /** 删除令牌（登出、切换服务器时调用）。不存在视为成功。 */
  static async delete(): Promise<void> {
    const query: asset.AssetMap = TokenStore.aliasMap();
    try {
      await asset.remove(query);
      Log.info('token removed');
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      if (failure.code !== asset.ErrorCode.NOT_FOUND) {
        Log.warn('token remove failed', `code=${failure.code} msg=${failure.message}`);
      }
    }
  }

  /** 查询/更新/删除统一只按别名定位：带 ACCESSIBILITY 一起查会多一层过滤，容易查不到。 */
  private static aliasMap(): asset.AssetMap {
    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    attributes.set(asset.Tag.ALIAS, encodeText(TOKEN_ALIAS));
    return attributes;
  }

  private static buildMap(): asset.AssetMap {
    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    attributes.set(asset.Tag.ALIAS, encodeText(TOKEN_ALIAS));
    // DEVICE_FIRST_UNLOCKED：开机首次解锁后即可读，避免重启后未解锁时读不到令牌而误判未登录。
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    return attributes;
  }
}
