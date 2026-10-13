import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';

/**
 * 用户身份确认（生物识别 / 锁屏密码）。
 *
 * 上游用 local_auth 在读取登录令牌前要求验证
 * （lib/token_store.dart：LocalAuthentication().authenticate(localizedReason: 'Authenticate to access login token')）。
 * 鸿蒙等价物是 UserAuthentication Kit：先申请一个 UserAuthInstance，注册 result 回调后 start()。
 *
 * 语义与上游一致：**验证失败即视为拿不到令牌**（返回 false），绝不降级放行——
 * 否则 Web 端会拿到令牌自动登录，生物识别的意义就没了。
 */
export class BiometricGate {
  /** 结果码 → 是否需要给用户提示。用户主动取消不算异常。 */
  private static readonly SUCCESS: number = userAuth.UserAuthResultCode.SUCCESS;
  /** 身份确认超时（毫秒）：超时按"未通过"处理，绝不放行。 */
  private static readonly TIMEOUT_MS: number = 60000;

  static async authenticate(reason: string): Promise<boolean> {
    const challenge: Uint8Array = BiometricGate.newChallenge();
    const authParam: userAuth.AuthParam = {
      challenge: challenge,
      // 生物识别不可用时系统会自动回落到锁屏密码，因此三类都声明。
      authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
      authTrustLevel: userAuth.AuthTrustLevel.ATL2
    };
    const widgetParam: userAuth.WidgetParam = { title: reason };
    try {
      const instance: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      const passed: boolean = await new Promise<boolean>((resolve: (value: boolean) => void) => {
        let settled: boolean = false;
        // 超时兜底：系统对话框可能被系统回收（用户按 Home、多窗口切换、弹窗被抢占）而永不回调，
        // 没有这道闸门时 Promise 永不 settle，Web 端既拿不到令牌也收不到失败注入。
        const timer: number = setTimeout(() => {
          if (settled) {
            return;
          }
          settled = true;
          try {
            instance.off('result', callback);
          } catch (error) {
            // 忽略。
          }
          try {
            instance.cancel();
          } catch (error) {
            // 忽略。
          }
          Log.warn('user auth timed out, treating as rejected');
          resolve(false);
        }, BiometricGate.TIMEOUT_MS);
        // on('result') 只接受 IAuthCallback 对象（不是函数），所以必须包一层。
        const callback: userAuth.IAuthCallback = {
          onResult: (result: userAuth.UserAuthResult): void => {
            if (settled) {
              return;
            }
            settled = true;
            clearTimeout(timer);
            try {
              instance.off('result', callback);
            } catch (error) {
              // 取消订阅失败不影响结果判定。
            }
            if (result.result !== BiometricGate.SUCCESS) {
              Log.info('user auth rejected', `code=${result.result}`);
            }
            resolve(result.result === BiometricGate.SUCCESS);
          }
        };
        try {
          instance.on('result', callback);
          instance.start();
        } catch (error) {
          const failure: BusinessError = error as BusinessError;
          Log.warn('user auth start failed', `code=${failure.code} msg=${failure.message}`);
          settled = true;
          clearTimeout(timer);
          resolve(false);
        }
      });
      return passed;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      // 常见：设备未录入任何生物特征/密码（NOT_ENROLLED），此时无闸门可用，只能拒绝。
      Log.warn('user auth unavailable', `code=${failure.code} msg=${failure.message}`);
      return false;
    }
  }

  /** 32 字节随机质询；随机源不可用时退回固定串（仅影响挑战值随机性，不影响验证强度）。 */
  private static newChallenge(): Uint8Array {
    try {
      return cryptoFramework.createRandom().generateRandomSync(32).data;
    } catch (error) {
      const fallback: Uint8Array = new Uint8Array(32);
      for (let index: number = 0; index < fallback.length; index++) {
        fallback[index] = index + 1;
      }
      return fallback;
    }
  }
}
