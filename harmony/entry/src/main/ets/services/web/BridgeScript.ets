/**
 * 注入到 Traccar Web 页面的桥接脚本。
 *
 * 与上游 lib/main_screen.dart:295-331 的 UserScript 等价，但有两点必须不同：
 * 1. 原生对象由 javaScriptProxy 注册成 window.__traccarNativeInterface，本脚本再把它包成
 *    网页侧稳定入口 window.appInterface（Web 端只认这个名字），原生对象未就绪时先排队补发。
 * 2. 上游监听 flutterInAppWebViewPlatformReady 事件，鸿蒙没有该事件，改为在
 *    DOMContentLoaded / load 以及若干次定时重试中冲刷队列。
 */
export function buildBridgeScript(): string {
  return `
(function () {
  'use strict';
  if (window.__traccarBridgeInstalled) return;
  window.__traccarBridgeInstalled = true;

  var pending = [];
  var proxyRef = null;
  // 本脚本自己装在 window.appInterface 上的入口。resolveProxy() 必须显式跳过它：
  // 否则原生对象还没出现时会把自己当成原生对象，消息在 JS 内部自环（栈溢出）。
  var selfEntry = { postMessage: deliver };

  function resolveProxy() {
    if (proxyRef) return proxyRef;
    var native = window.__traccarNativeInterface;
    if (native && typeof native.postMessage === 'function') {
      proxyRef = native;
      return proxyRef;
    }
    // 兼容路径：若容器把原生对象直接挂在 window.appInterface 上（非本脚本所装），仍然可用。
    var legacy = window.appInterface;
    if (legacy && legacy !== selfEntry && typeof legacy.postMessage === 'function') {
      proxyRef = legacy;
    }
    return proxyRef;
  }

  function deliver(message) {
    var proxy = resolveProxy();
    if (proxy) {
      try {
        proxy.postMessage(message);
      } catch (e) {
        // 原生对象已存在却抛异常（多为参数/状态问题），重投同一消息会造成副作用重复执行：
        // server| 每投一次都会清令牌 + 清 cookie + 重载页面，download| 则是 MB 级载荷。
        // 因此这里只记录，不再入队重试；"原生还没就绪"由下面 proxy 为空的入队分支负责。
        if (window.console && console.warn) console.warn('traccar bridge deliver failed', e);
      }
      return true;
    }
    pending.push(message);
    return false;
  }

  function flush() {
    if (!resolveProxy()) return;
    var backlog = pending;
    pending = [];
    for (var i = 0; i < backlog.length; i++) {
      try {
        proxyRef.postMessage(backlog[i]);
      } catch (e) {
        if (window.console && console.warn) console.warn('traccar bridge flush failed', e);
      }
    }
  }

  // Web 端始终只认 window.appInterface.postMessage，这里保持同名的稳定入口。
  window.appInterface = selfEntry;

  var retries = 0;
  // 原生对象通常在第一帧之前就绪；这里给 30 秒的宽限（100ms × 300），
  // 覆盖慢设备冷启动，避免"原生晚于 4 秒就绪就永久丢消息（含 login 令牌）"。
  function scheduleFlush() {
    flush();
    if (pending.length > 0 && retries < 300) {
      retries++;
      setTimeout(scheduleFlush, 100);
    }
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scheduleFlush);
  }
  window.addEventListener('load', scheduleFlush);
  setTimeout(scheduleFlush, 0);

  // 上游把 xlsx 报表以 Blob 形式导出，鸿蒙侧同样是拦截 createObjectURL 后转 base64 回传。
  var excelType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (window.URL && typeof window.URL.createObjectURL === 'function') {
    var originalCreateObjectURL = window.URL.createObjectURL;
    window.URL.createObjectURL = function (object) {
      try {
        if (object instanceof Blob && object.type === excelType) {
          var reader = new FileReader();
          reader.onload = function () {
            var result = String(reader.result);
            var comma = result.indexOf(',');
            deliver('download|' + (comma >= 0 ? result.substring(comma + 1) : ''));
          };
          reader.readAsDataURL(object);
        }
      } catch (e) {
      }
      return originalCreateObjectURL.apply(this, arguments);
    };
  }
})();
`;
}
