import { pasteboard } from '@kit.BasicServicesKit';
import type { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIContext } from '@kit.ArkUI';
import { Log } from '../../common/utils/Log';
import { showToast } from '../../common/utils/Toast';

/**
 * 外部链接处理。
 *
 * 上游 shouldOverrideUrlLoading 的第二条规则：链接 authority 与当前服务器不一致时，
 * 一律交给外部浏览器（lib/main_screen.dart）。鸿蒙侧：
 *   - 用 `openLink`（appLinkingOnly=false，普通 https 也走系统浏览器）；
 *   - 失败退回 viewData want（entities 带 entity.system.browsable）；
 *   - 再失败则复制链接并提示，绝不静默吞掉用户的点击。
 */
export class ExternalLinks {
  static async open(context: common.UIAbilityContext, url: string, ui?: UIContext): Promise<void> {
    try {
      await context.openLink(url, { appLinkingOnly: false });
      Log.info('external link opened', url);
      return;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('openLink failed, trying viewData', `code=${failure.code} msg=${failure.message}`);
    }
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url,
        entities: ['entity.system.browsable']
      });
      return;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('viewData want failed, copying instead', `code=${failure.code}`);
    }
    try {
      // createPlainTextData 已废弃，改用 createData + MIMETYPE_TEXT_PLAIN。
      const data: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url as pasteboard.ValueType);
      await pasteboard.getSystemPasteboard().setData(data);
      ExternalLinks.notify(ui, '无法打开浏览器，链接已复制');
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('copy link failed', `code=${failure.code}`);
      ExternalLinks.notify(ui, '无法打开该链接');
    }
  }

  private static notify(ui: UIContext | undefined, message: string): void {
    if (ui !== undefined) {
      showToast(ui, message);
    }
  }
}
