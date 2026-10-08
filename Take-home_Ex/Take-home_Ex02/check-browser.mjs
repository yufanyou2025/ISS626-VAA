import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_PATH || 'C:/Users/Windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve('_site');
const out=path.resolve('Take-home_Ex/Take-home_Ex02/cache/browser');
fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png','.svg':'image/svg+xml'};
const server=http.createServer((req,res)=>{
  const p=path.resolve(root,'.'+decodeURIComponent(new URL(req.url,'http://localhost').pathname));
  if(!p.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  if(req.url==='/favicon.ico'){res.writeHead(204).end();return;}
  const file=fs.existsSync(p)&&fs.statSync(p).isDirectory()?path.join(p,'index.html'):p;
  if(!fs.existsSync(file)){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
await new Promise(resolve=>server.listen(8748,'127.0.0.1',resolve));
const browser=await chromium.launch({channel:'chrome',headless:true});
const errors=[];
try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  page.on('pageerror',e=>errors.push(e.message));
  const base='http://127.0.0.1:8748/Take-home_Ex/Take-home_Ex02/';
  assert.equal((await page.goto(base+'technical-report.html',{waitUntil:'networkidle'})).status(),200);
  await page.locator('img').evaluateAll(async imgs=>Promise.all(imgs.map(i=>i.decode())));
  assert.equal(await page.locator('main img').count(),9);
  assert.equal(await page.locator('img').evaluateAll(imgs=>imgs.filter(i=>!i.complete||!i.naturalWidth).length),0);
  const countWords=txt=>(txt.match(/\b[\p{L}\p{N}]+(?:[-'][\p{L}\p{N}]+)*\b/gu)||[]).length;
  const interpretations=(await page.locator('.interpretation').allTextContents()).map(countWords);
  const clusters=(await page.locator('.cluster-interpretation').allTextContents()).map(countWords);
  assert(interpretations.length===9&&interpretations.every(n=>n<=200));
  assert(clusters.length===4&&clusters.every(n=>n<=250));
  assert.equal(await page.locator('details.workflow-code').count(),7);
  await page.screenshot({path:path.join(out,'report-top.png')});
  await page.locator('#emerging-hot-spot-analysis').scrollIntoViewIfNeeded();
  await page.screenshot({path:path.join(out,'report-ehsa.png')});
  await page.locator('details.workflow-code').first().locator('summary').click();
  assert(await page.locator('details.workflow-code').first().evaluate(e=>e.open));
  await page.setViewportSize({width:390,height:844});
  await page.reload({waitUntil:'networkidle'});
  await page.screenshot({path:path.join(out,'report-mobile.png')});
  assert(!(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+2)),'Mobile report overflows');
  await page.setViewportSize({width:1280,height:720});
  assert.equal((await page.goto(base+'executive-summary.html',{waitUntil:'networkidle'})).status(),200);
  await page.waitForFunction(()=>window.Reveal?.isReady());
  const slideCount=await page.evaluate(()=>Reveal.getTotalSlides());
  assert.equal(slideCount,12,'Cover + contents + 10 content slides');
  const overflow=[];
  for(let i=0;i<slideCount;i++){
    await page.evaluate(i=>Reveal.slide(i),i);
    await page.waitForTimeout(100);
    await page.screenshot({path:path.join(out,`slide-${String(i+1).padStart(2,'0')}.png`)});
    const bounds=await page.evaluate(()=>{
      const r=document.querySelector('.reveal').getBoundingClientRect();
      const elements=[...Reveal.getCurrentSlide().querySelectorAll('h1,h2,p,li,img')];
      return elements.filter(e=>{const b=e.getBoundingClientRect();return b.width>0&&b.height>0&&(b.bottom>r.bottom-18||b.right>r.right+1||b.left<r.left-1)}).map(e=>e.tagName+': '+e.textContent.slice(0,80));
    });
    if(bounds.length)overflow.push({slide:i+1,elements:bounds});
  }
  assert.deepEqual(overflow,[],'Slide content exceeds visible stage');
  assert.deepEqual(errors,[]);
  const result={reportImages:9,interpretationWords:interpretations,clusterWords:clusters,slides:slideCount,mobileOverflow:false,slideOverflow:overflow,errors};
  fs.writeFileSync(path.join(out,'checks.json'),JSON.stringify(result,null,2));
  console.log(JSON.stringify(result));
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
