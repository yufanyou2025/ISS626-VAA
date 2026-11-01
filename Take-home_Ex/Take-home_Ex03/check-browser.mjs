// Browser QA of the local render by default; set EX03_BASE_URL for public QA.
// Run from the ISS626-VAA project root after rendering report and slides.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_PATH ||
  'C:/Users/Windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = path.resolve('_site');
const output = path.resolve('Take-home_Ex/Take-home_Ex03/cache/browser',
  process.env.EX03_BASE_URL ? 'public' : 'local');
fs.mkdirSync(output, {recursive: true});
let server;
let base = process.env.EX03_BASE_URL?.replace(/\/$/, '');
if (!base) {
  const mime = {'.html': 'text/html; charset=utf-8', '.css': 'text/css',
    '.js': 'application/javascript', '.png': 'image/png', '.svg': 'image/svg+xml',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.json': 'application/json'};
  server = http.createServer((request, response) => {
    let target;
    try { target = path.resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://localhost').pathname)); }
    catch { response.writeHead(400).end(); return; }
    if (target !== root && !target.startsWith(root + path.sep)) {response.writeHead(403).end(); return;}
    if (request.url === '/favicon.ico') {response.writeHead(204).end(); return;}
    if (fs.existsSync(target) && fs.statSync(target).isDirectory()) target = path.join(target, 'index.html');
    if (!fs.existsSync(target)) {response.writeHead(404).end(); return;}
    response.setHeader('Content-Type', mime[path.extname(target)] || 'application/octet-stream');
    fs.createReadStream(target).pipe(response);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
}
const route = '/Take-home_Ex/Take-home_Ex03/';
const browser = await chromium.launch({channel: 'chrome', headless: true});
const errors = [];
const consoleErrors = [];
const failedLocalResources = [];
try {
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') consoleErrors.push(message.text()); });
  page.on('response', response => {
    if (response.url().startsWith(base) && response.status() >= 400) {
      failedLocalResources.push({url: response.url(), status: response.status()});
    }
  });
  assert.equal((await page.goto(base + route + 'technical-report.html', {waitUntil: 'networkidle'})).status(), 200);
  const images = page.locator('main img');
  const imageCount = await images.count();
  assert(imageCount >= 7, 'Expected the seven principal analytical figures.');
  await images.evaluateAll(async items => Promise.all(items.map(item => item.decode())));
  assert.deepEqual(await images.evaluateAll(items => items.filter(item =>
    !item.complete || !item.naturalWidth).map(item => item.src)), []);
  const countWords = text => (text.match(/\b[\p{L}\p{N}]+(?:[-'][\p{L}\p{N}]+)*\b/gu) || []).length;
  const interpretations = (await page.locator('.interpretation').allTextContents()).map(countWords);
  assert(interpretations.length >= imageCount && interpretations.every(n => n <= 200));
  await page.screenshot({path: path.join(output, 'report-top.png')});
  const mapIframe = page.locator('iframe[src*="station-explorer.html"]');
  assert.equal(await mapIframe.count(), 1, 'Expected one station explorer iframe.');
  assert((await mapIframe.getAttribute('title'))?.trim(), 'Map iframe needs an accessible title.');
  await mapIframe.scrollIntoViewIfNeeded();
  const map = page.frameLocator('iframe[src*="station-explorer.html"]');
  await map.locator('.leaflet-container').waitFor({timeout: 15000});
  await map.locator('img.leaflet-tile-loaded').first().waitFor({state: 'visible'});
  const tileSources = await map.locator('img.leaflet-tile-loaded').evaluateAll(items => items.map(item => item.src));
  assert(tileSources.length > 0 && tileSources.every(source => /\/\/(?:[a-z]\.)?tile\.openstreetmap\.org\//.test(source)),
    'Expected the public OpenStreetMap basemap; API-key placeholder tiles are not a valid basemap.');
  const markers = map.locator('.leaflet-interactive');
  assert.equal(await markers.count(), 210, 'Expected 181 existing + 29 new station markers.');
  await markers.first().hover({force: true});
  await map.locator('.leaflet-tooltip').first().waitFor({state: 'visible'});
  const tooltip = await map.locator('.leaflet-tooltip').first().innerText();
  assert(tooltip.trim().length > 0, 'Station hover label is empty.');
  await markers.first().click({force: true});
  await map.locator('.leaflet-popup-content').waitFor({state: 'visible'});
  const popup = await map.locator('.leaflet-popup-content').innerText();
  assert.match(popup, /Expanded scenario/);
  assert.match(popup, /Observed AM entries/);
  assert.match(await map.locator('.leaflet-control-attribution').innerText(), /OpenStreetMap/);
  await page.waitForTimeout(300);
  await page.screenshot({path: path.join(output, 'station-explorer.png')});
  const details = page.locator('details.code-fold, details.workflow-code');
  if (await details.count()) {
    await details.first().locator('summary').click();
    assert(await details.first().evaluate(element => element.open), 'Reproducible code cannot expand.');
  }
  await page.setViewportSize({width: 390, height: 844});
  await page.reload({waitUntil: 'networkidle'});
  await page.evaluate(() => scrollTo(0, 0));
  await page.screenshot({path: path.join(output, 'report-mobile.png')});
  const mobileWidth = await page.evaluate(() => ({width: document.documentElement.scrollWidth, viewport: innerWidth}));
  assert(mobileWidth.width <= mobileWidth.viewport + 2, 'Mobile report has horizontal overflow: ' + JSON.stringify(mobileWidth));
  await page.setViewportSize({width: 1280, height: 720});
  assert.equal((await page.goto(base + route + 'executive-summary.html', {waitUntil: 'networkidle'})).status(), 200);
  await page.waitForFunction(() => window.Reveal?.isReady());
  const slideCount = await page.evaluate(() => Reveal.getTotalSlides());
  assert(slideCount <= 12, 'Maximum: cover + contents + 10 content slides.');
  const overflow = [];
  for (let i = 0; i < slideCount; i++) {
    await page.evaluate(index => Reveal.slide(index), i);
    await page.waitForTimeout(120);
    await page.screenshot({path: path.join(output, `slide-${String(i + 1).padStart(2, '0')}.png`)});
    const clipped = await page.evaluate(() => {
      const stage = document.querySelector('.reveal').getBoundingClientRect();
      return [...Reveal.getCurrentSlide().querySelectorAll('h1,h2,p,li,img,table')].filter(element => {
        const box = element.getBoundingClientRect();
        return box.width > 0 && box.height > 0 &&
          (box.bottom > stage.bottom - 16 || box.right > stage.right + 1 || box.left < stage.left - 1 || box.top < stage.top - 1);
      }).map(element => element.tagName + ': ' + (element.textContent || element.getAttribute('src') || '').slice(0, 90));
    });
    if (clipped.length) overflow.push({slide: i + 1, elements: clipped});
  }
  assert.deepEqual(overflow, [], 'Slide content exceeds the visible stage.');
  const counter = await page.locator('.slide-number').evaluate(element => {
    const box = element.getBoundingClientRect();
    return {text: element.textContent.trim(), bottom: box.bottom, right: box.right,
      scrollWidth: element.scrollWidth, clientWidth: element.clientWidth};
  });
  assert(counter.bottom <= 721 && counter.right <= 1281 && counter.scrollWidth <= counter.clientWidth + 1,
    'Slide counter is clipped: ' + JSON.stringify(counter));
  for (const asset of ['figures/network.png', 'figures/station-explorer.html',
    'outputs/station-results.csv', 'outputs/interactions-existing.csv.gz',
    'outputs/interactions-expanded.csv.gz', 'outputs/package-versions.csv', 'analysis.R']) {
    const response = await page.request.get(base + route + asset);
    assert.equal(response.status(), 200, asset);
    if (asset.endsWith('.csv.gz')) assert((await response.body()).length > 100000, 'Compressed interaction download is empty/truncated.');
  }
  // The explicitly supplied coursework URL must remain accessible after adding Exercise 3.
  assert.equal((await page.goto(base + '/In-class_Ex/In-class_Ex09/In-class_Ex09.html', {waitUntil: 'networkidle'})).status(), 200);
  await page.getByText('Take-home Exercise', {exact: true}).first().click();
  const exercise3 = page.getByRole('link', {name: 'Exercise 3: Technical Report', exact: true});
  assert(await exercise3.isVisible(), 'Exercise 9 has no visible Exercise 3 menu link.');
  await exercise3.click();
  await page.waitForURL(base + route + 'technical-report.html');
  assert.deepEqual(errors, [], 'Browser JavaScript errors.');
  assert.deepEqual(consoleErrors, [], 'Browser console errors.');
  assert.deepEqual(failedLocalResources, [], 'Missing same-origin resources.');
  const result = {base, reportImages: imageCount, interpretationWords: interpretations,
    mapMarkers: 210, tooltip, popupVerified: true, attribution: true, tileSources,
    slides: slideCount, mobileOverflow: false, slideOverflow: overflow, slideCounter: counter,
    exercise9Navigation: true,
    pageErrors: errors, consoleErrors, failedLocalResources};
  fs.writeFileSync(path.join(output, 'checks.json'), JSON.stringify(result, null, 2) + '\n');
  const durable = {...result, base: process.env.EX03_BASE_URL ? base : 'local rendered site',
    tileSources: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png']};
  fs.writeFileSync(path.resolve('Take-home_Ex/Take-home_Ex03/outputs',
    process.env.EX03_BASE_URL ? 'browser-checks-public.json' : 'browser-checks-local.json'),
    JSON.stringify(durable, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
} finally {
  await browser.close();
  if (server) await new Promise(resolve => server.close(resolve));
}
