// Minimal Chrome DevTools Protocol client for the ArkWeb page running in the emulator.
// Usage: node cdp.mjs <ws-url> [file-with-expressions]
// Prints JSON with: console messages, exceptions, log entries, and expression results.
const wsUrl = process.argv[2];
if (!wsUrl) {
  console.error('need ws url');
  process.exit(2);
}
const fs = await import('node:fs');

const expressions = [
  'document.readyState',
  'document.title',
  'location.href',
  'document.body ? document.body.children.length : -1',
  'document.body ? document.body.innerHTML.slice(0, 1200) : ""',
  'typeof window.appInterface',
  'typeof window.__traccarNativeInterface',
  'String(window.__traccarBridgeInstalled)',
  'typeof window.updateNotificationToken',
  'typeof window.handleLoginToken',
  'typeof window.handleNativeNotification',
  'JSON.stringify(performance.getEntriesByType("resource").map(r => r.name.replace(location.origin, "") + " d=" + Math.round(r.duration)))',
  'JSON.stringify(performance.getEntriesByType("navigation").map(n => n.name + " dur=" + Math.round(n.duration)))',
  'document.querySelectorAll("script").length',
  'Array.from(document.querySelectorAll("script")).map(s => s.src || "inline").join(" | ")',
  'document.querySelectorAll("link[rel=stylesheet]").length',
  'typeof window.fetch',
  'window.navigator.userAgent'
];
if (process.argv[3]) {
  const extra = fs.readFileSync(process.argv[3], 'utf8').split('\n').filter((l) => l.trim().length > 0);
  expressions.push(...extra);
}

const ws = new WebSocket(wsUrl);
let id = 0;
const pending = new Map();
const events = [];

function send(method, params) {
  id += 1;
  const message = { id, method, params: params || {} };
  ws.send(JSON.stringify(message));
  return new Promise((resolve) => {
    pending.set(id, resolve);
  });
}

function evaluate(expression) {
  return new Promise((resolve) => {
    id += 1;
    const messageId = id;
    ws.send(JSON.stringify({
      id: messageId,
      method: 'Runtime.evaluate',
      params: { expression, returnByValue: true, awaitPromise: true }
    }));
    pending.set(messageId, (payload) => {
      const result = payload.result || {};
      resolve({
        expression,
        value: result.result ? result.result.value : undefined,
        description: result.result ? result.result.description : undefined,
        exception: result.exceptionDetails ? JSON.stringify(result.exceptionDetails).slice(0, 400) : undefined
      });
    });
  });
}

ws.addEventListener('message', (event) => {
  const payload = JSON.parse(event.data);
  if (payload.id && pending.has(payload.id)) {
    pending.get(payload.id)(payload);
    pending.delete(payload.id);
    return;
  }
  if (payload.method) {
    events.push({ method: payload.method, params: payload.params });
  }
});

ws.addEventListener('open', async () => {
  await send('Runtime.enable', {});
  await send('Log.enable', {});
  await send('Page.enable', {});
  await send('Network.enable', {});
  await new Promise((r) => setTimeout(r, 2500));
  const results = [];
  for (const expression of expressions) {
    results.push(await evaluate(expression));
  }
  const interesting = events.filter((e) => e.method === 'Runtime.consoleAPICalled'
    || e.method === 'Runtime.exceptionThrown'
    || e.method === 'Log.entryAdded'
    || e.method === 'Network.loadingFailed');
  console.log(JSON.stringify({ results, events: interesting.slice(0, 60) }, null, 2));
  ws.close();
  process.exit(0);
});

ws.addEventListener('error', (event) => {
  console.error('ws error', event.message || String(event));
  process.exit(1);
});

setTimeout(() => {
  console.error('timeout');
  process.exit(3);
}, 30000);
