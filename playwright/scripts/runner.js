// Runs /workspace/script.js, writes /workspace/result.json.
// Fields are stable: exitCode, durationMs, stdout, stderr, screenshots, timedOut.
'use strict';
const { spawnSync } = require('child_process');
const { readdirSync, statSync, writeFileSync, closeSync, openSync } = require('fs');
const { join } = require('path');

const WORK = '/workspace';
const RESULT = join(WORK, 'result.json');
const IMG_EXT = new Set(['.png', '.jpg', '.jpeg', '.webp', '.gif']);
const TIMEOUT_MS = Number(process.env.PW_SCRIPT_TIMEOUT_MS) || 120000;

// Idle timer for run.sh's container loop.
try { closeSync(openSync('/tmp/.last_run', 'w')); } catch (_) {}

function scanImages() {
  const out = {};
  for (const f of readdirSync(WORK)) {
    if (!IMG_EXT.has(f.slice(f.lastIndexOf('.')).toLowerCase())) continue;
    try { out[f] = statSync(join(WORK, f)).mtimeMs; } catch (_) {}
  }
  return out;
}

const before = scanImages();
const start = Date.now();

const r = spawnSync('node', ['script.js'], {
  cwd: WORK,
  encoding: 'utf8',
  timeout: TIMEOUT_MS,
  killSignal: 'SIGKILL',
  maxBuffer: 16 * 1024 * 1024,
});
const timedOut = r.error?.code === 'ETIMEDOUT';
let stdout = r.stdout ?? '';
let stderr = r.stderr ?? '';
let exitCode = r.status ?? (timedOut ? 124 : 1);
if (timedOut) {
  stderr += `\nrunner: script exceeded ${TIMEOUT_MS} ms (PW_SCRIPT_TIMEOUT_MS)\n`;
  // The kill hits node only; browsers it launched would outlive it.
  spawnSync('pkill', ['-9', '-f', 'chrom|firefox|webkit'], { stdio: 'ignore' });
} else if (r.error) {
  stderr += `\nrunner: ${r.error.message}\n`;
}

const durationMs = Date.now() - start;
const after = scanImages();
const screenshots = Object.keys(after).filter((f) => !before[f] || after[f] > before[f]).sort();

writeFileSync(RESULT, JSON.stringify({ exitCode, durationMs, stdout, stderr, screenshots, timedOut }, null, 2));

const parts = [`exit=${exitCode}`, `${durationMs}ms`];
if (screenshots.length) parts.push(`screenshots: ${screenshots.join(', ')}`);
if (exitCode !== 0 && stderr) parts.push(`error: ${stderr.trim().split('\n').find((l) => /\S/.test(l) && !/^\s*at /.test(l))}`);
console.log(parts.join(' | '));
if (stdout) process.stdout.write(stdout);
if (exitCode !== 0 && stderr) process.stderr.write(stderr);
process.exit(exitCode);
