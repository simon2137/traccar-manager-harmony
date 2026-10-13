import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';
import { DownloadService } from '../download/DownloadService';

/**
 * ArkWeb 下载接管。
 *
 * 上游只对 xlsx/kml/csv/gpx 主动下载（shouldOverrideUrlLoading → _downloadFile），
 * 其余下载交给 WebView 自己处理。鸿蒙这边两条路都覆盖：
 *   - 已知后缀：由页面 onLoadIntercept 用 http + Bearer token 下载（与上游等价，见 DownloadService）；
 *   - 其它任意下载（PDF、导出的压缩包等）：由 WebDownloadDelegate 接管，
 *     落到缓存目录后调系统打开，避免下载“无声无息”地消失。
 */
export class DownloadHandler {
  private controller: webview.WebviewController;
  private delegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private downloadDir: string;

  constructor(controller: webview.WebviewController, downloadDir: string) {
    this.controller = controller;
    this.downloadDir = downloadDir;
    this.delegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      this.onBeforeDownload(item);
    });
    this.delegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      // 只记日志、不自动拉起打开方：批量导出时连续弹窗会打断用户操作。
      Log.info('web download finished', item.getFullPath());
    });
    this.delegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      Log.warn('web download failed', `url=${item.getUrl()} code=${item.getLastErrorCode()}`);
    });
    this.delegate.onDownloadUpdated((item: webview.WebDownloadItem) => {
      Log.debug('web download progress', `${item.getPercentComplete()}%`);
    });
  }

  /** 挂到 controller 上；重复挂载是幂等的。 */
  attach(): void {
    try {
      this.controller.setDownloadDelegate(this.delegate);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.warn('setDownloadDelegate failed', `code=${failure.code} msg=${failure.message}`);
    }
  }

  private onBeforeDownload(item: webview.WebDownloadItem): void {
    const suggested: string = item.getSuggestedFileName();
    const name: string = DownloadService.sanitizeFileName(
      suggested.length > 0 ? suggested : DownloadService.timestampedName('bin'));
    const path: string = `${this.downloadDir}/${name}`;
    try {
      item.start(path);
      Log.info('web download accepted', `${name} <- ${item.getUrl()}`);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('web download start failed', `code=${failure.code} msg=${failure.message}`);
      item.cancel();
    }
  }
}
