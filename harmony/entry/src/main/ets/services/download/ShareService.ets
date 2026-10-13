import { systemShare } from '@kit.ShareKit';
import { fileUri } from '@kit.CoreFileKit';
import { wantConstant } from '@kit.AbilityKit';
import type { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';

/**
 * 分享 / 交给系统打开。
 *
 * 上游用 share_plus 调起系统分享面板（lib/main_screen.dart 的 `_shareFile`）。
 * 鸿蒙等价物：Share Kit 的 systemShare.ShareController；无匹配应用的兜底是
 * 一个 viewData want（如 xlsx 交给 WPS/表格）。
 *
 * 注意 uri 必须是 `fileUri.getUriFromPath(path)` 的结果：应用沙箱路径对其它应用不可见，
 * 且 want 必须带 FLAG_AUTH_READ_URI_PERMISSION，否则被拉起方读不到文件。
 */
export class ShareService {
  /** 按后缀给统一类型描述符；未知类型退回二进制流。 */
  static utdOf(fileName: string): string {
    const lower: string = fileName.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return 'com.microsoft.excel.xls';
    }
    if (lower.endsWith('.csv')) {
      return 'general.delimited-values-text';
    }
    if (lower.endsWith('.kml')) {
      return 'com.google.earth.kml';
    }
    if (lower.endsWith('.gpx')) {
      return 'com.topografix.gpx';
    }
    if (lower.endsWith('.txt')) {
      return 'general.plain-text';
    }
    if (lower.endsWith('.json')) {
      return 'general.json';
    }
    return 'general.binary';
  }

  static mimeOf(fileName: string): string {
    const lower: string = fileName.toLowerCase();
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }
    if (lower.endsWith('.csv')) {
      return 'text/csv';
    }
    if (lower.endsWith('.kml')) {
      return 'application/vnd.google-earth.kml+xml';
    }
    if (lower.endsWith('.gpx')) {
      return 'application/gpx+xml';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }
    if (lower.endsWith('.json')) {
      return 'application/json';
    }
    return 'application/octet-stream';
  }

  /** 调起系统分享面板；失败返回 false（调用方决定是否再退回“用其他应用打开”）。 */
  static async shareFile(context: common.UIAbilityContext, filePath: string, title: string): Promise<boolean> {
    try {
      const uri: string = fileUri.getUriFromPath(filePath);
      const record: systemShare.SharedRecord = {
        utd: ShareService.utdOf(title),
        uri: uri,
        title: title
      };
      const controller: systemShare.ShareController = new systemShare.ShareController(new systemShare.SharedData(record));
      const options: systemShare.ShareControllerOptions = {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      };
      await controller.show(context, options);
      Log.info('share panel shown', title);
      return true;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('share panel failed', `code=${failure.code} msg=${failure.message}`);
      return false;
    }
  }

  /** 用系统应用打开文件（viewData want）。 */
  static openWithSystem(context: common.UIAbilityContext, filePath: string): void {
    try {
      const uri: string = fileUri.getUriFromPath(filePath);
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: uri,
        type: ShareService.mimeOf(filePath),
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      context.startAbility(want).catch((error: BusinessError) => {
        Log.warn('openWithSystem failed', `code=${error.code} msg=${error.message}`);
      });
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('openWithSystem threw', `code=${failure.code}`);
    }
  }
}
