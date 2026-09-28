---
name: playwright
description: Browser automation via Playwright in a persistent container. Use this skill whenever the user wants to screenshot a webpage, check how a page looks, test CSS styling, inspect computed styles, verify colours or layout, validate UI changes after edits, debug visual issues, check responsive design, extract rendered text or attributes, or automate any browser interaction. Also use when the user says things like "open the page in a browser", "what colour is this element", "take a screenshot of my site", "does the styling look right", "check the page at different screen sizes", "render the page", "check if my changes look right", or "test the frontend visually". Use even for quick one-off checks. Runs headless Chromium inside Podman or Docker, no host Node or browser install. Reaches localhost services on Linux.
---

# Playwright

One script per call. The script runs in a container, the result comes back as JSON.

## Run

```bash
cat <<'PWEOF' | ~/.claude/skills/playwright/scripts/run.sh <workspace>   # or the checkout's playwright/scripts/run.sh
const { chromium } = require('playwright-core');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.goto('http://localhost:1313/', { waitUntil: 'networkidle', timeout: 30000 });
  await page.screenshot({ path: '/workspace/page.png' });
  await browser.close();
})();
PWEOF
```

- `<workspace>`: the session scratchpad directory. Not the repo: `.tmp/playwright/` with `node_modules/` lands inside it.
- Script on stdin, always. A call without one exits 2.
- First run pulls the image (~2.5 GB). Container start plus install: ~3 s. Later runs: under 1 s plus the script.
- Container: `pw-<basename>-<hash>`, one per workspace path, stops after 10 min idle, restarts on the next run.

## Read the result

`<workspace>/.tmp/playwright/result.json`:

```json
{ "exitCode": 0, "durationMs": 1523, "stdout": "...", "stderr": "", "screenshots": ["page.png"], "timedOut": false }
```

1. `exitCode` non-zero: read `stderr`.
   The terminal already shows a summary line plus the script's stdout; the file is the full record.
2. Open each screenshot with the Read tool: `<workspace>/.tmp/playwright/<name>`.
3. `console.log` in the script is the channel for data: styles, text, request lists. Print JSON.

## Script rules

- `require('playwright-core')`, CommonJS. `playwright` (full) downloads browsers and fails.
- `chromium.launch({ headless: true, args: ['--no-sandbox'] })`. Root in the container, no display.
- Files: `/workspace/...` only. It is `<workspace>/.tmp/playwright/` on the host.
- Screenshots: no `fullPage: true` on long pages. Images over 8000 px on a side cannot be viewed. Use the viewport, an element (`el.screenshot`), or `clip`.
- Timeout: 120 s per script. `PW_SCRIPT_TIMEOUT_MS=300000 run.sh ...` to raise it. On timeout `exitCode` is 124 and `timedOut` is true.
- One browser per script. Nothing persists between runs: log in inside the script, or save `storageState` to `/workspace/` and load it next run.

## Options

```bash
run.sh --clean <workspace>            # remove the container; also with a script on stdin
CONTAINER_BIN=docker run.sh <ws>      # runtime override; default podman, then docker
```

- Deleted the workspace while the container lived: the next run detects the stale mount and recreates it.
- Version bump: `IMAGE` and `PW_VERSION` in `run.sh` move together, then `--clean`.

## Platform

- Linux: `--network=host`, `localhost` is the host.
- macOS: the host network is the podman machine VM. Use `host.containers.internal` in URLs. Untested.

## Patterns

`references/patterns.md`: computed styles, multiple viewports, DOM plus network plus console verification in one run, element screenshots, storage state.
