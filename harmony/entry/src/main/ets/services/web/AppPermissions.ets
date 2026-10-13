import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import type { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';

/** 权限名常量，避免在业务代码里散落字符串。只声明真正会申请的三项。 */
export const PERMISSION_LOCATION: Permissions = 'ohos.permission.LOCATION';
export const PERMISSION_APPROXIMATELY_LOCATION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
export const PERMISSION_CAMERA: Permissions = 'ohos.permission.CAMERA';

/**
 * 运行时权限申请。
 *
 * 上游由 permission_handler + WebView 回调驱动（main_screen.dart：
 * onGeolocationPermissionsShowPrompt 申请定位、onPermissionRequest 只放行 CAMERA/VIDEO_CAPTURE）。
 * 鸿蒙侧把「申请」和「判定」集中在这里，Web 回调与悬浮窗等入口共用。
 *
 * 关键约束：`requestPermissionsFromUser` 的 context 必须是 UIAbilityContext（弹窗需要窗口）。
 * 定位权限必须【同时】申请 LOCATION 与 APPROXIMATELY_LOCATION，只申请其一系统会拒绝。
 */
export class AppPermissions {
  private static atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();

  /** 一次性申请一组权限；全部授予才返回 true。用户拒绝不抛异常。 */
  static async request(context: common.UIAbilityContext, names: Permissions[]): Promise<boolean> {
    try {
      // 不写显式类型：PermissionRequestResult 只在 @ohos.abilityAccessCtrl 内部按
      // 类型别名 re-export，@kit.AbilityKit 的 barrel 里取不到这个名字，交给推断。
      const result = await AppPermissions.atManager.requestPermissionsFromUser(context, names);
      const authResults: number[] = result.authResults;
      for (const value of authResults) {
        if (value !== 0) {
          Log.info('permission denied', names.join(','));
          return false;
        }
      }
      return authResults.length > 0;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('permission request failed', `names=${names.join(',')} code=${failure.code} msg=${failure.message}`);
      return false;
    }
  }

  /** 是否已授予（查 token，不弹窗）。 */
  static granted(name: Permissions): boolean {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const status: abilityAccessCtrl.GrantStatus =
        AppPermissions.atManager.checkAccessTokenSync(info.appInfo.accessTokenId, name);
      return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.debug('check access token failed', `name=${name} code=${failure.code}`);
      return false;
    }
  }

  /**
   * 定位权限：上游在网页请求地理位置时才申请（惰性），这里保持一致。
   * 先查再申请，避免已授权时重复弹窗打扰。
   */
  static async ensureLocation(context: common.UIAbilityContext): Promise<boolean> {
    if (AppPermissions.granted(PERMISSION_LOCATION) || AppPermissions.granted(PERMISSION_APPROXIMATELY_LOCATION)) {
      return true;
    }
    return AppPermissions.request(context, [PERMISSION_LOCATION, PERMISSION_APPROXIMATELY_LOCATION]);
  }

  /** 相机权限（网页拍照上传、扫码）。 */
  static async ensureCamera(context: common.UIAbilityContext): Promise<boolean> {
    if (AppPermissions.granted(PERMISSION_CAMERA)) {
      return true;
    }
    return AppPermissions.request(context, [PERMISSION_CAMERA]);
  }

  /**
   * 把网页声明的资源列表映射成鸿蒙权限名。
   * 只认白名单，且只有相机可能被授予（对齐上游 onPermissionRequest：非相机资源一律 DENY），
   * 网页可以声明任意资源串，但不能让它驱动申请任意权限。
   */
  static toPermission(resource: string): Permissions | undefined {
    const normalized: string = resource.toLowerCase();
    if (normalized.indexOf('camera') >= 0 || normalized.indexOf('video_capture') >= 0) {
      return PERMISSION_CAMERA;
    }
    if (normalized.indexOf('geolocation') >= 0 || normalized.indexOf('location') >= 0) {
      return PERMISSION_LOCATION;
    }
    return undefined;
  }
}
