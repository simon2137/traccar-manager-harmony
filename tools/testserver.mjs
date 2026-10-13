// Local Traccar-protocol test server for the HarmonyOS port.
// It serves a page that speaks the same JS bridge protocol as the real Traccar web app,
// and records every bridge call + every HTTP request so the native shell can be verified
// without depending on the real web app (which needs WebGL2 for its map).
//
// Usage: node testserver.mjs [port]
import http from 'node:http';
import fs from 'node:fs';

const PORT = Number(process.argv[2] || 8899);
const LOG = 'D:\\dsh\\Traccar\\shots\\testserver.log';

function log(line) {
  fs.appendFileSync(LOG, `${new Date().toISOString()} ${line}\n`);
}

try {
  fs.unlinkSync(LOG);
} catch {
  // fresh log each run
}

const PAGE = `<!doctype html>
<html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Traccar Harmony Test</title>
<style>
 body{font-family:-apple-system,Segoe UI,sans-serif;margin:0;padding:12px;background:#f7f7f9;color:#111}
 h1{font-size:18px;margin:0 0 4px}
 .k{font-size:12px;color:#666;margin-bottom:8px}
 button{display:block;width:100%;margin:6px 0;padding:12px;font-size:15px;border-radius:10px;border:1px solid #ccd;background:#fff}
 pre{white-space:pre-wrap;word-break:break-all;font-size:11px;background:#101418;color:#7cf;padding:8px;border-radius:8px;min-height:200px}
</style></head><body>
<h1>Traccar Harmony Bridge Test</h1>
<div class="k">server=http://HOST:PORT &middot; native bridge probe</div>
<div id="probe">probe: pending</div>
<script>
  window.__rx = [];
  function show(kind, text) {
    window.__rx.push(kind + ': ' + text);
    var el = document.getElementById('log');
    if (el) { el.textContent = window.__rx.join('\\n'); }
    try { fetch('/report?kind=' + encodeURIComponent(kind) + '&text=' + encodeURIComponent(text)); } catch (e) {}
  }
  function probe() {
    var b = document.getElementById('probe');
    var native = typeof window.__traccarNativeInterface;
    var app = typeof window.appInterface;
    var flag = String(window.__traccarBridgeInstalled);
    var msg = 'native=' + native + ' appInterface=' + app + ' installed=' + flag;
    if (b) { b.textContent = 'probe: ' + msg; }
    show('probe', msg);
  }
  window.handleLoginToken = function (t) { show('handleLoginToken', JSON.stringify(t)); };
  window.updateNotificationToken = function (t) { show('updateNotificationToken', JSON.stringify(t)); };
  window.handleNativeNotification = function (j) { show('handleNativeNotification', JSON.stringify(j)); };
  function send(m) {
    try { window.appInterface.postMessage(m); show('sent', m.length > 60 ? m.slice(0, 60) + '...' : m); }
    catch (e) { show('sendFailed', String(e)); }
  }
  window.__send = send;
  function webgl() {
    var c = document.createElement('canvas');
    var r = { webgl2: false, webgl1: false };
    try { r.webgl2 = !!c.getContext('webgl2'); } catch (e) {}
    try { r.webgl1 = !!c.getContext('webgl'); } catch (e) {}
    show('webgl', JSON.stringify(r));
    return JSON.stringify(r);
  }
  window.__webgl = webgl;
</script>
<button onclick="send('login|TESTTOKEN123')">1. login|TESTTOKEN123</button>
<button onclick="send('authentication')">2. authentication</button>
<button onclick="send('authenticated')">3. authenticated</button>
<button onclick="send('download|aGVsbG8sdHJhY2Nhcg==')">4. download|base64(hello,traccar)</button>
<button onclick="send('logout')">5. logout</button>
<button onclick="send('server|http://10.0.2.2:8899')">6. server|self</button>
<button onclick="probe()">7. probe bridge</button>
<button onclick="webgl()">8. probe webgl</button>
<div id="log"></div>
<script>probe();</script>
</body></html>`;

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  log(`${req.method} ${url.pathname}${url.search} ua=${(req.headers['user-agent'] || '').slice(0, 80)}`);
  if (url.pathname === '/report') {
    log(`REPORT kind=${url.searchParams.get('kind')} text=${url.searchParams.get('text')}`);
    res.writeHead(200, { 'content-type': 'text/plain' });
    res.end('ok');
    return;
  }
  if (url.pathname === '/api/session' || url.pathname === '/api/server') {
    // Minimal Traccar API shape so the shell's own logic can be exercised if needed.
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ id: 1, name: 'Harmony Test Server', version: '6.1.2' }));
    return;
  }
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(PAGE.replace(/HOST:PORT/, `${req.headers.host}`));
});

server.listen(PORT, '0.0.0.0', () => {
  log(`listening on 0.0.0.0:${PORT}`);
  console.log(`listening on 0.0.0.0:${PORT}`);
});
