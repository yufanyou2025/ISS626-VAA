import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_PATH ||
  'C:/Users/Windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = process.env.INCLASS09_BASE_URL || 'http://127.0.0.1:8769';
const route = '/In-class_Ex/In-class_Ex09/In-class_Ex09.html';
const cache = path.resolve('In-class_Ex/In-class_Ex09/cache');
fs.mkdirSync(cache, {recursive: true});

const browser = await chromium.launch({channel: 'chrome', headless: true});
try {
  const page = await browser.newPage({viewport: {width: 1440, height: 950}});
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const response = await page.goto(base + route, {waitUntil: 'domcontentloaded'});
  assert.equal(response.status(), 200);
  assert(await page.getByRole('heading', {name: /Hands-on Exercise 9: Hedonic pricing across Singapore/}).count());
  const figures = page.locator('main img');
  assert.equal(await figures.count(), 8);
  await figures.evaluateAll(async items => Promise.all(items.map(item => item.decode().catch(() => {}))));
  assert.deepEqual(await figures.evaluateAll(items =>
    items.filter(item => !item.complete || !item.naturalWidth).map(item => item.src)), []);
  const mapFrame = page.frameLocator('iframe[title="Interactive map of 2015 condominium resales"]');
  await page.locator('iframe[title="Interactive map of 2015 condominium resales"]').scrollIntoViewIfNeeded();
  await mapFrame.locator('.leaflet-container').waitFor({timeout: 15000});
  assert(await page.getByRole('heading', {name: /What I learned/}).count());
  await page.screenshot({path: path.join(cache, 'desktop.png'), fullPage: true});
  await page.evaluate(() => scrollTo(0, 0));
  await page.getByText('In-class Exercise', {exact: true}).first().click();
  assert(await page.getByText('Hands-on Exercise 9: Hedonic Pricing',
    {exact: true}).first().isVisible());
  await page.keyboard.press('Escape');

  for (const asset of ['analysis.R', 'prepare.R', 'README.md',
    'figures/local-r2.png', 'figures/local-area-coefficient.png',
    'figures/transaction-interactive.html',
    'outputs/input-audit.csv', 'outputs/model-comparison.csv']) {
    assert.equal((await page.request.get(base + '/In-class_Ex/In-class_Ex09/' + asset)).status(),
      200, asset);
  }
  await page.setViewportSize({width: 390, height: 844});
  await page.reload({waitUntil: 'domcontentloaded'});
  await page.screenshot({path: path.join(cache, 'mobile.png')});
  const mobileWidth = await page.evaluate(() => ({
    actual: document.documentElement.scrollWidth,
    viewport: innerWidth,
    openDetails: [...document.querySelectorAll('details.code-fold')].filter(x => x.open).length,
    codeFoldStyle: (() => {const x=document.querySelector('details.code-fold');return {width:x?.getBoundingClientRect().width, right:x?.getBoundingClientRect().right, overflow:getComputedStyle(x).overflowX}})(),
    offenders: [...document.querySelectorAll('body *')]
      .filter(el => el.getBoundingClientRect().right > innerWidth + 2)
      .slice(0, 6).map(el => `${el.tagName}.${el.className}=${Math.round(el.getBoundingClientRect().right)} [${[...((function* (x) {while (x) {yield x; x=x.parentElement}})(el))].slice(0,7).map(x=>x.tagName+'.'+x.className).join('>')}]`)
  }));
  assert(mobileWidth.actual <= mobileWidth.viewport + 2,
    'mobile horizontal overflow: ' + JSON.stringify(mobileWidth));
  assert.equal((await page.goto(base + '/index.html')).status(), 200);
  assert(await page.getByRole('link', {name: /Explore Hands-on Exercise 9/}).count());
  for (const prior of ['/In-class_Ex/In-class_Ex08/In-class_Ex08.html',
    '/Hands-on_Ex/Hands-on_Ex07/Hands-on_Ex07.html',
    '/Take-home_Ex/Take-home_Ex02/technical-report.html']) {
    assert.equal((await page.request.get(base + prior)).status(), 200, prior);
  }
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({base, route, figures: 8, interactiveMap: 'ok',
    navigation: 'ok', mobile: 'ok', priorProjects: 'ok', pageErrors: 0}));
} finally {
  await browser.close();
}
