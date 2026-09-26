import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_PATH ||
  'C:/Users/Windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = process.env.EX05_BASE_URL || 'http://127.0.0.1:8765';
const routes = [
  '/Hands-on_Ex/Hands-on_Ex05/Hands-on_Ex05a.html',
  '/Hands-on_Ex/Hands-on_Ex05/Hands-on_Ex05b.html'
];
const cache = path.resolve('Hands-on_Ex/Hands-on_Ex05/cache');
fs.mkdirSync(cache, {recursive: true});
const browser = await chromium.launch({channel: 'chrome', headless: true});
try {
  const page = await browser.newPage({viewport: {width: 1440, height: 950}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' && !message.location().url.endsWith('/favicon.ico')) {
      errors.push(message.text());
    }
  });
  const counts = [];
  for (const [i, route] of routes.entries()) {
    const response = await page.goto(base + route, {waitUntil: 'networkidle'});
    assert.equal(response.status(), 200, route);
    assert(await page.getByRole('heading', {name: i ? /Local Spatial Autocorrelation/ : /Global Spatial Autocorrelation/}).count());
    const imageCount = await page.locator('main img').count();
    assert(imageCount >= (i ? 6 : 5), `${route}: too few figures`);
    await page.locator('main img').evaluateAll(async images => {
      await Promise.all(images.map(image => image.decode().catch(() => {})));
    });
    const broken = await page.locator('main img').evaluateAll(images =>
      images.filter(image => !image.complete || !image.naturalWidth).map(image => image.src));
    assert.deepEqual(broken, [], `${route}: broken figures`);
    await page.screenshot({path: path.join(cache, i ? '5b-desktop.png' : '5a-desktop.png')});
    await page.getByText('Hands-on Exercise', {exact: true}).first().click();
    assert(await page.getByText('Hands-on Exercise 5A: Global Spatial Autocorrelation', {exact: true}).first().isVisible());
    assert(await page.getByText('Hands-on Exercise 5B: Local Spatial Autocorrelation', {exact: true}).first().isVisible());
    await page.keyboard.press('Escape');
    counts.push(imageCount);
  }
  for (const asset of ['prepare.R', 'analysis-5a.R', 'analysis-5b.R',
    'figures/lisa-clusters.png', 'figures/global-permutations.png',
    'outputs/sfdep-moran-check.txt']) {
    const response = await page.request.get(base + '/Hands-on_Ex/Hands-on_Ex05/' + asset);
    assert.equal(response.status(), 200, asset);
  }
  await page.setViewportSize({width: 390, height: 844});
  await page.goto(base + routes[1], {waitUntil: 'networkidle'});
  await page.screenshot({path: path.join(cache, '5b-mobile.png')});
  assert(!(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)),
    'mobile horizontal overflow');
  const home = await page.goto(base + '/index.html', {waitUntil: 'networkidle'});
  assert.equal(home.status(), 200);
  assert(await page.getByRole('link', {name: /Explore Exercise 5A/}).count());
  assert(await page.getByRole('link', {name: /Explore Exercise 5B/}).count());
  const existing = await page.request.get(base + '/Take-home_Ex/Take-home_Ex01/technical-report.html');
  assert.equal(existing.status(), 200);
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({base, pages: routes, figures: counts,
    scriptsAndAssets: 'ok', navigation: 'ok', mobile: 'ok',
    existingReport: 'ok', consoleErrors: errors.length}));
} finally {
  await browser.close();
}
