import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_PATH ||
  'C:/Users/Windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = process.env.INCLASS06_BASE_URL || 'http://127.0.0.1:8766';
const route = '/In-class_Ex/In-class_Ex06/In-class_Ex06.html';
const cache = path.resolve('In-class_Ex/In-class_Ex06/cache');
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
  assert(await page.getByRole('heading', {name: /In-class Exercise 6: Emerging Hot Spots Revisited/}).count());
  const imageCount = await page.locator('main img').count();
  assert(imageCount >= 4, `Expected at least four figures, got ${imageCount}`);
  await page.locator('main img').evaluateAll(async images => {
    await Promise.all(images.map(image => image.decode().catch(() => {})));
  });
  const broken = await page.locator('main img').evaluateAll(images =>
    images.filter(image => !image.complete || !image.naturalWidth).map(image => image.src));
  assert.deepEqual(broken, []);
  assert(await page.locator('.plotly .main-svg').count(), 'Interactive plot did not render');
  await page.screenshot({path: path.join(cache, 'desktop.png'), fullPage: true});
  await page.getByText('In-class Exercise', {exact: true}).first().click();
  assert(await page.getByText('In-class Exercise 6: EHSA Sensitivity',
    {exact: true}).first().isVisible());
  await page.keyboard.press('Escape');
  for (const asset of ['analysis.R', 'README.md',
    'figures/ehsa-weight-maps.png', 'outputs/ehsa-results.csv']) {
    const assetResponse = await page.request.get(base + '/In-class_Ex/In-class_Ex06/' + asset);
    assert.equal(assetResponse.status(), 200, asset);
  }
  await page.setViewportSize({width: 390, height: 844});
  await page.reload({waitUntil: 'networkidle'});
  await page.screenshot({path: path.join(cache, 'mobile.png')});
  assert(!(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)),
    'mobile horizontal overflow');
  const home = await page.goto(base + '/index.html', {waitUntil: 'networkidle'});
  assert.equal(home.status(), 200);
  assert(await page.getByRole('link', {name: /Explore In-class Exercise 6/}).count());
  const prior = await page.request.get(base + '/In-class_Ex/In-class_Ex05/In-class_Ex05.html');
  assert.equal(prior.status(), 200);
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({base, route, figures: imageCount, interactivePlot: 'ok',
    navigation: 'ok', mobile: 'ok', priorExercise: 'ok', consoleErrors: 0}));
} finally {
  await browser.close();
}
