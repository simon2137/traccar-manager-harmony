import { UIContext } from '@kit.ArkUI';
import { Log } from './Log';

/** 常规提示时长。 */
export const TOAST_DEFAULT_MS: number = 2000;
/** 短提示，用于紧接动画的即时反馈。 */
export const TOAST_SHORT_MS: number = 1500;

/**
 * 全局 toast。必须传入发起方的 UIContext：多窗口/宽屏分栏下用错实例会把提示弹到另一半屏。
 */
export function showToast(ui: UIContext, message: string, duration: number = TOAST_DEFAULT_MS): void {
  try {
    ui.getPromptAction().showToast({ message: message, duration: duration });
  } catch (error) {
    Log.warn('toast failed', message);
  }
}
