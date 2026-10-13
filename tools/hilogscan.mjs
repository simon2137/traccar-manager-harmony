// Scan persisted hilog gz files for app-domain (0x0FFF / TraccarManager) lines.
// Usage: node hilogscan.mjs <file.gz> [more.gz ...] [--all]
import fs from 'node:fs';
import zlib from 'node:zlib';

const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const all = process.argv.includes('--all');
for (const f of files) {
  let text = '';
  try {
    const buf = fs.readFileSync(f);
    text = f.endsWith('.gz') ? zlib.gunzipSync(buf).toString('utf8') : buf.toString('utf8');
  } catch (e) {
    console.log(`!! ${f}: ${e.message}`);
    continue;
  }
  const lines = text.split('\n').filter((l) => (all ? true : l.includes('TraccarManager') || l.includes('A00fff') || l.includes('A04500')));
  console.log(`===== ${f} (${lines.length} matched / ${text.split('\n').length} total) =====`);
  for (const l of lines) console.log(l.trim());
}
