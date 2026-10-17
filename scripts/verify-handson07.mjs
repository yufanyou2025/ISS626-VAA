import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_PATH ||
  'C:/Users/Windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = process.env.HANDSON07_BASE_URL || 'http://127.0.0.1:8767';
const route = '/Hands-on_Ex/Hands-on_Ex07/Hands-on_Ex07.html';
const cache = path.resolve('Hands-on_Ex/Hands-on_Ex07/cache');
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
  const response = await page.goto(base + route, {waitUntil: 'networkidle'});
  assert.equal(response.status(), 200);
  assert(await page.getByRole('heading', {name: /Hands-on Exercise 7: Measuring eldercare accessibility/}).count());
  const images = page.locator('main img');
  const figureCount = await images.count();
  assert(figureCount >= 6, `Expected six figures, got ${figureCount}`);
  await images.evaluateAll(async items => {
    await Promise.all(items.map(item => item.decode().catch(() => {})));
  });
  const broken = await images.evaluateAll(items =>
    items.filter(item => !item.complete || !item.naturalWidth).map(item => item.src));
  assert.deepEqual(broken, []);
  assert(await page.getByRole('heading', {name: /What I learned/}).count());
  await page.screenshot({path: path.join(cache, 'desktop.png'), fullPage: true});
  await page.getByText('Hands-on Exercise', {exact: true}).first().click();
  assert(await page.getByText('Hands-on Exercise 7: Eldercare Accessibility',
    {exact: true}).first().isVisible());
  await page.keyboard.press('Escape');
  for (const asset of ['analysis.R', 'prepare.R', 'README.md',
    'figures/hansen-map.png', 'figures/method-ranks.png',
    'outputs/region-summary.csv']) {
    const assetResponse = await page.request.get(base + '/Hands-on_Ex/Hands-on_Ex07/' + asset);
    assert.equal(assetResponse.status(), 200, asset);
  }
  await page.setViewportSize({width: 390, height: 844});
  await page.reload({waitUntil: 'networkidle'});
  await page.screenshot({path: path.join(cache, 'mobile.png')});
  assert(!(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)),
    'mobile horizontal overflow');
  const home = await page.goto(base + '/index.html', {waitUntil: 'networkidle'});
  assert.equal(home.status(), 200);
  assert(await page.getByRole('link', {name: /Explore Exercise 7/}).count());
  for (const prior of ['/Hands-on_Ex/Hands-on_Ex05/Hands-on_Ex05b.html',
    '/In-class_Ex/In-class_Ex06/In-class_Ex06.html',
    '/Take-home_Ex/Take-home_Ex01/technical-report.html']) {
    assert.equal((await page.request.get(base + prior)).status(), 200, prior);
  }
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({base, route, figures: figureCount,
    navigation: 'ok', mobile: 'ok', priorProjects: 'ok', consoleErrors: 0}));
} finally {
  await browser.close();
}
