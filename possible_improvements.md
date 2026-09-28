# Possible improvements

## DevTools diagnostics: a simpler route than the shared-browser plan

The old skills repo carried `docs/research/playwright-shared-browser-devtools-mcp.md`
(2026-04-06): one long-lived browser in the container, Playwright attached over
CDP, a DevTools MCP attached to the same browser for console, network, traces,
memory and audits. Not implemented.

Found 2026-09-28: `playwright-cli` (`@playwright/cli`, Microsoft) already ships
that surface as a session daemon with a shipped SKILL.md:
`console`, `requests`, `request <n>`, `tracing-start/stop`, `video-*`,
`route` mocking, `state-save/load`, `run-code`. Sessions persist between calls,
one hour idle. Reference: https://github.com/microsoft/playwright-cli.

Decision: do not build the shared-browser runtime. When the diagnostics need is
real, run `playwright-cli` inside the existing container.

- Install into the container, not the host: keeps the zero-host-deps rule.
- Version coupling: the CLI bundles its own `playwright-core` and expects that
  build's browser revision. Tested 0.1.21 on the v1.52 image: refused, wanted
  `chromium-1246`. Pin `@playwright/cli` to the release whose bundled
  `playwright-core` equals `PW_VERSION` in `run.sh`, or run
  `playwright-cli install-browser chrome-for-testing` once per container.
- Default browser is the `chrome` channel (Google Chrome); pass
  `--browser=chromium` or set it in `.playwright/cli.config.json`.
- Keep `run.sh` for scripted verification. The CLI is for exploration and
  diagnostics; one script call stays cheaper than a step-per-command loop.
- Not yet done: a `scripts/cli.sh` wrapper that execs `playwright-cli` in the
  workspace container with `-s=<workspace>`.

## Firefox

- Playwright's Firefox is already in the image (`/ms-playwright/firefox-*`).
  In a script: `const { firefox } = require('playwright-core'); firefox.launch(...)`.
  No change to `run.sh`.
- Firefox Developer Edition is a branded build. Playwright's native Firefox
  protocol only drives its own patched build; branded Firefox is reachable only
  through the experimental WebDriver BiDi channel. Untested here.
  Reference: https://playwright.dev/docs/browsers#firefox, https://playwright.dev/docs/webdriver-bidi.
- If Dev Edition is required: derive an image `FROM mcr.microsoft.com/playwright:<tag>`,
  add the Dev Edition tarball from mozilla.org under `/opt/firefox-dev`, set
  `IMAGE` in `run.sh` to it, and launch with the BiDi channel and
  `executablePath: '/opt/firefox-dev/firefox'`. Verify before documenting in
  SKILL.md.
