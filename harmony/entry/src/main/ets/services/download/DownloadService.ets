import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import type { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log } from '../../common/utils/Log';

/**
 * 文件落盘：带令牌下载 + base64 载荷写入。
 *
 * 对应上游 `_downloadFile`（lib/main_screen.dart）：用 `Authorization: Bearer <token>`
 * 拉取 xlsx/kml/csv/gpx，文件名用「当前毫秒时间戳 + 原后缀」，然后调系统分享面板。
 * 上游 Android 用外部存储目录、其他平台用应用文档目录；鸿蒙侧统一放应用缓存目录下的
 * downloads/，再通过 FileUri + 系统分享把文件交出去——沙箱外的应用拿不到裸路径，
 * 必须走 URI。
 */
export class DownloadService {
  private static readonly DIR_NAME: string = 'downloads';

  /** 对外暴露的下载目录（确保已创建），供 WebDownloadDelegate 使用。 */
  static prepareDir(context: common.UIAbilityContext): string {
    return DownloadService.downloadDir(context);
  }

  private static downloadDir(context: common.UIAbilityContext): string {
    const dir: string = `${context.cacheDir}/${DownloadService.DIR_NAME}`;
    DownloadService.ensureDir(dir);
    return dir;
  }

  /**
   * 创建目录并复核。
   *
   * 实测教训（模拟器 API 26）：`fileIo.accessSync()` 对不存在的目录**不抛异常**，
   * 所以「存在才跳过 mkdir」的旧写法从不创建 downloads/，随后写文件直接失败：
   * `file write failed | path=…/cache/downloads/report.xlsx code=13900002 msg=No such file or directory`。
   * 现在改成「无条件 mkdir（已存在会抛 EEXIST，忽略）→ listFileSync 复核」，
   * 不再信任 accessSync 的存在性判断。
   */
  private static ensureDir(dir: string): boolean {
    try {
      fileIo.mkdirSync(dir, true);
      Log.debug('download dir created', dir);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.debug('download dir mkdir skipped', `code=${failure.code} msg=${failure.message}`);
    }
    try {
      fileIo.listFileSync(dir);
      return true;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('download dir unavailable', `dir=${dir} code=${failure.code} msg=${failure.message}`);
      return false;
    }
  }

  /** 目标文件绝对路径：downloads/ 不可用时兜底写 cacheDir 根目录（必定存在）。 */
  private static targetPath(context: common.UIAbilityContext, fileName: string): string {
    const dir: string = `${context.cacheDir}/${DownloadService.DIR_NAME}`;
    if (DownloadService.ensureDir(dir)) {
      return `${dir}/${fileName}`;
    }
    Log.warn('fallback to cache root', context.cacheDir);
    return `${context.cacheDir}/${fileName}`;
  }

  /** 清洗文件名：去掉路径分隔符与首尾空白，保留原后缀。空名回退 report.bin。 */
  static sanitizeFileName(name: string): string {
    const base: string = name.replace(/[\\/:*?"<>|]/g, '_').trim();
    if (base.length === 0 || base === '.' || base === '..') {
      return 'report.bin';
    }
    return base;
  }

  /** 毫秒时间戳 + 后缀，与上游 `<timestamp>.<ext>` 命名保持一致。 */
  static timestampedName(extension: string): string {
    const suffix: string = extension.length > 0 ? `.${extension}` : '';
    return `${new Date().getTime()}${suffix}`;
  }

  /**
   * 带 Bearer 令牌下载到沙箱缓存目录。
   * @returns 绝对路径；失败返回空串（调用方负责提示，不抛异常）。
   */
  static async downloadWithToken(context: common.UIAbilityContext, url: string, token: string, fileName: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Authorization': `Bearer ${token}`,
        'Accept': '*/*'
      };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 20000,
        readTimeout: 60000
      };
      const response: http.HttpResponse = await request.request(url, options);
      // 上游只认 200；这里放宽到 2xx，避免服务端返回 206（分块）/304 时被误判为失败。
      if (response.responseCode < 200 || response.responseCode >= 300) {
        Log.warn('download rejected', `code=${response.responseCode} url=${url}`);
        return '';
      }
      const payload: ArrayBuffer = response.result as ArrayBuffer;
      return DownloadService.writeBytes(context, payload, DownloadService.sanitizeFileName(fileName));
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('download failed', `code=${failure.code} msg=${failure.message}`);
      return '';
    } finally {
      request.destroy();
    }
  }

  /** 把 Web 侧传来的 base64（xlsx 导出）写成文件。失败返回空串。 */
  static writeBase64Payload(context: common.UIAbilityContext, base64: string, fileName: string): string {
    try {
      const bytes: Uint8Array = new util.Base64Helper().decodeSync(base64);
      const payload: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      return DownloadService.writeBytes(context, payload, DownloadService.sanitizeFileName(fileName));
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('base64 decode/write failed', `code=${failure.code} msg=${failure.message}`);
      return '';
    }
  }

  /** 写入缓存目录并返回绝对路径。 */
  static writeBytes(context: common.UIAbilityContext, payload: ArrayBuffer, fileName: string): string {
    const path: string = DownloadService.targetPath(context, fileName);
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, payload);
      Log.info('file written', `${fileName} ${payload.byteLength}B`);
      return path;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.error('file write failed', `path=${path} code=${failure.code} msg=${failure.message}`);
      return '';
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          // 关闭失败无需处理。
        }
      }
    }
  }

  /** 清空缓存下载目录（避免长期占用；失败静默）。 */
  static clearDownloads(context: common.UIAbilityContext): void {
    const dir: string = DownloadService.downloadDir(context);
    try {
      const names: string[] = fileIo.listFileSync(dir);
      for (const name of names) {
        try {
          fileIo.unlinkSync(`${dir}/${name}`);
        } catch (error) {
          // 单个文件删除失败不影响其它文件。
        }
      }
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      Log.debug('clear downloads skipped', `code=${failure.code}`);
    }
  }
}
