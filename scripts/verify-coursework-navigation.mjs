import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';

const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_PATH ||
  'C:/Users/Windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = path.resolve('_site');
const report = '/Take-home_Ex/Take-home_Ex02/technical-report.html';
const slides = '/Take-home_Ex/Take-home_Ex02/executive-summary.html';
const exercise7 = '/Hands-on_Ex/Hands-on_Ex07/Hands-on_Ex07.html';
const cache = path.resolve('Take-home_Ex/Take-home_Ex02/cache/navigation');
fs.mkdirSync(cache, {recursive: true});
let server;
let base = process.env.COURSEWORK_BASE_URL;
if (!base) {
  const types = {'.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript',
    '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json'};
  server = http.createServer((req, res) => {
    let file = path.resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname));
    if (!file.startsWith(root + path.sep) && file !== root) {res.writeHead(403).end(); return;}
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
    if (!fs.existsSync(file)) {res.writeHead(404).end(); return;}
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
}
const browser = await chromium.launch({channel: 'chrome', headless: true});
const errors = [];
try {
  const page = await browser.newPage({viewport: {width: 1440, height: 950}});
  page.on('pageerror', e => errors.push(e.message));
  assert.equal((await page.goto(base + exercise7, {waitUntil: 'networkidle'})).status(), 200);
  await page.getByText('Take-home Exercise', {exact: true}).first().click();
  await page.getByRole('link', {name: 'Exercise 2: Technical Report', exact: true}).click();
  await page.waitForLoadState('networkidle');
  assert.equal(new URL(page.url()).pathname, report);
  assert.equal(await page.locator('main img').count(), 9);
  await page.locator('main img').evaluateAll(async items => Promise.all(items.map(i => i.decode())));
  await page.getByText('Take-home Exercise', {exact: true}).first().click();
  await page.screenshot({path: path.join(cache, 'take-home-menu.png')});
  const links = await page.locator('#quarto-header a[href]').evaluateAll(items =>
    [...new Set(items.filter(a => !a.getAttribute('href').startsWith('#'))
      .map(a => new URL(a.href)).filter(u => u.origin === location.origin).map(u => u.pathname))]);
  assert(links.length >= 17, 'Expected the complete coursework navigation');
  for (const route of links) assert.equal((await page.request.get(base + route)).status(), 200, route);
  await page.getByRole('link', {name: 'Exercise 2: Executive Summary', exact: true}).click();
  await page.waitForFunction(() => window.Reveal?.isReady());
  assert.equal(new URL(page.url()).pathname, slides);
  assert.equal(await page.evaluate(() => Reveal.getTotalSlides()), 12);
  await page.getByRole('link', {name: 'Coursework home', exact: true}).click();
  await page.waitForLoadState('networkidle');
  assert.equal(new URL(page.url()).pathname, '/index.html');
  assert(await page.getByRole('link', {name: /Explore Exercise 7/}).count());
  assert(await page.getByRole('heading', {name: /Take-home Exercise 2/}).count());
  await page.goto(base + '/Take-home_Ex/Take-home_Ex01/executive-summary.html', {waitUntil: 'networkidle'});
  await page.waitForFunction(() => window.Reveal?.isReady());
  assert(await page.getByRole('link', {name: 'Coursework home', exact: true}).isVisible());
  await page.setViewportSize({width: 390, height: 844});
  await page.goto(base + exercise7, {waitUntil: 'networkidle'});
  await page.locator('.navbar-toggler').click();
  await page.getByText('Take-home Exercise', {exact: true}).first().click();
  assert(await page.getByRole('link', {name: 'Exercise 2: Technical Report', exact: true}).isVisible());
  await page.screenshot({path: path.join(cache, 'mobile-menu.png')});
  const tracked = execFileSync('git', ['ls-files', '_site'], {encoding: 'utf8'}).trim().split('\n');
  let headers = 0;
  for (const file of tracked.filter(f => f.endsWith('.html'))) {
    const html = fs.readFileSync(file, 'utf8');
    const header = html.match(/<header id="quarto-header"[\s\S]*?<\/header>/)?.[0];
    if (!header) continue;
    assert(header.includes(report) && header.includes(slides) && header.includes(exercise7), file);
    if (process.env.COURSEWORK_BASE_URL) {
      const response = await page.request.get(base + '/' + file.slice('_site/'.length));
      assert.equal(response.status(), 200, file);
      const liveHeader = (await response.text()).match(/<header id="quarto-header"[\s\S]*?<\/header>/)?.[0];
      assert(liveHeader?.includes(report) && liveHeader.includes(slides) && liveHeader.includes(exercise7), file);
    }
    headers++;
  }
  assert.deepEqual(errors, []);
  const result = {base, sharedHeaders: headers, menuTargets: links.length,
    exercise7ToReportToSlidesToHome: 'passed', bothSlideDeckHomeLinks: 'passed',
    mobileMenu: 'passed', browserErrors: errors};
  fs.writeFileSync(path.join(cache, 'checks.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
} finally {
  await browser.close();
  if (server) await new Promise(resolve => server.close(resolve));
}
