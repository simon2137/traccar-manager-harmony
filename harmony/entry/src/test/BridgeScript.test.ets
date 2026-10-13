import { describe, it, expect } from '@ohos/hypium';
import { buildBridgeScript } from '../main/ets/services/web/BridgeScript';
import { TraccarConstants } from '../main/ets/common/constants/TraccarConstants';

/**
 * 注入脚本的回归护栏。
 *
 * 脚本本身零依赖（只是一段字符串），却承载着整条 JS→原生消息通道，所以这里对"关键几行"
 * 做断言。最要紧的一条是 resolveProxy 必须排除脚本自己装在 window.appInterface 上的入口：
 * 早期版本用 `window.__traccarNativeInterface || window.appInterface` 懒解析，原生对象尚未
 * 出现时会解析到自己，deliver 递归调用自己直到栈溢出，消息永远到不了原生。
 */
export default function bridgeScriptTest() {
  describe('bridgeScriptTest', () => {
    const script: string = buildBridgeScript();

    it('installsWebFacingEntryOnce', 0, () => {
      expect(script).assertContain('if (window.__traccarBridgeInstalled) return;');
      expect(script).assertContain('window.appInterface = selfEntry');
    });

    it('neverResolvesNativeProxyToItself', 0, () => {
      expect(script).assertContain('window.__traccarNativeInterface');
      expect(script).assertContain('legacy !== selfEntry');
      // 自环写法的特征串，出现即回归。
      expect(script.indexOf('window.__traccarNativeInterface || window.appInterface')).assertEqual(-1);
    });

    it('queuesMessagesUntilNativeIsReady', 0, () => {
      expect(script).assertContain('pending.push(message)');
      expect(script).assertContain('DOMContentLoaded');
      expect(script).assertContain("window.addEventListener('load', scheduleFlush)");
      expect(script).assertContain('setTimeout(scheduleFlush, 100)');
    });

    it('interceptsXlsxBlobExport', 0, () => {
      expect(script).assertContain('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(script).assertContain("deliver('download|'");
      expect(script).assertContain('URL.createObjectURL');
      expect(script).assertContain('readAsDataURL');
    });

    it('exposesProxyMethodName', 0, () => {
      // 原生侧 methodList 只注册了 postMessage，脚本必须用它。
      expect(script).assertContain('typeof native.postMessage');
      expect(TraccarConstants.JS_PROXY_METHOD).assertEqual('postMessage');
    });
  });
}
