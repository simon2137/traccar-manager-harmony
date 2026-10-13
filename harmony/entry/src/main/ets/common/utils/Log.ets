import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0FFF;
const TAG: string = 'TraccarManager';

/**
 * 统一日志出口。上游用 dart:developer log()，这里换成 hilog，
 * 便于在 DevEco 的 Log 窗口按 tag 过滤。
 */
export class Log {
  static debug(message: string, detail?: string): void {
    hilog.debug(DOMAIN, TAG, '%{public}s', detail === undefined ? message : `${message} | ${detail}`);
  }

  static info(message: string, detail?: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', detail === undefined ? message : `${message} | ${detail}`);
  }

  static warn(message: string, detail?: string): void {
    hilog.warn(DOMAIN, TAG, '%{public}s', detail === undefined ? message : `${message} | ${detail}`);
  }

  static error(message: string, detail?: string): void {
    hilog.error(DOMAIN, TAG, '%{public}s', detail === undefined ? message : `${message} | ${detail}`);
  }
}
