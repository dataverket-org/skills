---
name: playwright
description: Browser automation via Playwright in a persistent container. Use this skill whenever the user wants to screenshot a webpage, check how a page looks, test CSS styling, inspect computed styles, verify colours or layout, validate UI changes after edits, debug visual issues, check responsive design, extract rendered text or attributes, or automate any browser interaction. Also use when the user says things like "open the page in a browser", "what colour is this element", "take a screenshot of my site", "does the styling look right", "check the page at different screen sizes", "render the page", "check if my changes look right", or "test the frontend visually". Use even for quick one-off checks. Runs headless Chromium inside Podman or Docker, no host Node or browser install. Reaches localhost services on Linux.
---

# Playwright

Send one script per call. It runs in a container and the result comes back
as JSON.

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

- Pass the session scratchpad directory as `<workspace>`, not the repo:
  `.tmp/playwright/` with `node_modules/` lands inside it.
- Pass the script on stdin. A call without one exits 2.
- Expect the first run to pull the image (~2.5 GB). Container start plus
  install takes ~3 s; later runs take under 1 s plus the script.
- The container is `pw-<basename>-<hash>`, one per workspace path. It stops
  after 10 min idle and restarts on the next run.

## Read the result

`<workspace>/.tmp/playwright/result.json`:

```json
{ "exitCode": 0, "durationMs": 1523, "stdout": "...", "stderr": "", "screenshots": ["page.png"], "timedOut": false }
```

1. If `exitCode` is non-zero, read `stderr`. The terminal already shows a
   summary line plus the script's stdout; the file is the full record.
2. Open each screenshot with the Read tool:
   `<workspace>/.tmp/playwright/<name>`.
3. Get data out with `console.log` in the script: styles, text, request
   lists. Print JSON.

## Script rules

- Use `require('playwright-core')`, CommonJS. The full `playwright` package
  downloads browsers and fails.
- Launch with `chromium.launch({ headless: true, args: ['--no-sandbox'] })`:
  the script is root in the container and has no display.
- Write files under `/workspace/` only. It is `<workspace>/.tmp/playwright/`
  on the host.
- Do not use `fullPage: true` on a long page: an image over 8000 px on a side
  cannot be viewed. Capture the viewport, an element (`el.screenshot`) or a
  `clip`.
- A script times out after 120 s; raise it with
  `PW_SCRIPT_TIMEOUT_MS=300000 run.sh ...`. On timeout `exitCode` is 124 and
  `timedOut` is true.
- Use one browser per script. Nothing persists between runs: log in inside
  the script, or save `storageState` to `/workspace/` and load it next run.

## Options

```bash
run.sh --clean <workspace>            # remove the container; also with a script on stdin
CONTAINER_BIN=docker run.sh <ws>      # runtime override; default podman, then docker
```

- If the workspace was deleted while the container lived, the next run
  detects the stale mount and recreates the container.
- To bump the version, move `IMAGE` and `PW_VERSION` in `run.sh` together,
  then run `--clean`.

## Platform

| Host | Network | Reach a local service at |
|---|---|---|
| Linux | `--network=host` | `localhost` |
| macOS (untested) | the podman machine VM | `host.containers.internal` |

## Patterns

Read `references/patterns.md` for computed styles, multiple viewports, DOM
plus network plus console verification in one run, element screenshots and
storage state.
