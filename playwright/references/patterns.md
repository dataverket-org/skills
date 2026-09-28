# Patterns

All scripts: `require('playwright-core')`, `headless: true`, `args: ['--no-sandbox']`, files under `/workspace/`.

## Verify a page in one run

DOM facts, failed requests, console errors, screenshots. One call instead of a step per check.

```js
const { chromium } = require('playwright-core');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const failed = [], errors = [];
  page.on('response', r => { if (r.status() >= 400) failed.push(`${r.status()} ${r.url()}`); });
  page.on('requestfailed', r => failed.push(`${r.failure()?.errorText} ${r.url()}`));   // DNS, refused, aborted
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('http://localhost:8123/', { waitUntil: 'networkidle', timeout: 30000 });

  const facts = await page.evaluate(() => ({
    title: document.title,
    h1: document.querySelector('h1')?.textContent.trim(),
    brokenImages: [...document.images].filter(i => i.complete && i.naturalWidth === 0).map(i => i.src),
  }));
  console.log(JSON.stringify({ facts, failed, errors }, null, 1));

  await page.screenshot({ path: '/workspace/desktop.png' });
  await browser.close();
})();
```

## Computed styles

```js
const styles = await page.evaluate(() => {
  const pick = (sel, props) => {
    const el = document.querySelector(sel);
    if (!el) return null;
    const cs = getComputedStyle(el);
    return Object.fromEntries(props.map(p => [p, cs.getPropertyValue(p)]));
  };
  return {
    header: pick('header', ['background-color', 'color', 'height']),
    button: pick('.ds-button', ['font-family', 'border-radius', 'padding']),
  };
});
console.log(JSON.stringify(styles, null, 1));
```

## Multiple viewports

```js
for (const [name, width, height] of [['mobile', 375, 812], ['tablet', 768, 1024], ['desktop', 1440, 900]]) {
  await page.setViewportSize({ width, height });
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.screenshot({ path: `/workspace/${name}.png` });
}
```

## Element screenshot

Element bounds only, no page-size limit problem.

```js
const el = await page.$('#mark');
await el.screenshot({ path: '/workspace/mark.png' });
```

Hidden element (`display: none`): `waitForSelector(sel, { state: 'attached' })`, not the default `visible`.

## Storage state across runs

```js
// run 1: log in, save
await page.context().storageState({ path: '/workspace/state.json' });
// run 2: reuse
const context = await browser.newContext({ storageState: '/workspace/state.json' });
const page = await context.newPage();
```

## Colour scheme and media

```js
const page = await browser.newPage({ colorScheme: 'dark' });
await page.emulateMedia({ media: 'print' });
```
