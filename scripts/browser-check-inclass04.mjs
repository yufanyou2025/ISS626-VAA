import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_PATH || 'playwright');
const exercise="04";
const root=path.resolve('_site'), out=path.resolve('In-class_Ex/In-class_Ex04/cache');
fs.mkdirSync(out,{recursive:true});
const types={'.html':'text/html','.css':'text/css','.js':'text/javascript','.png':'image/png','.gif':'image/gif','.svg':'image/svg+xml','.json':'application/json'};
const server=http.createServer((req,res)=>{
 if(req.url==='/favicon.ico'){res.writeHead(204).end();return;}
 const p=path.resolve(root,'.'+decodeURIComponent(new URL(req.url,'http://localhost').pathname));
 if(!p.startsWith(root+path.sep)) {res.writeHead(403).end();return;}
 const file=fs.existsSync(p)&&fs.statSync(p).isDirectory()?path.join(p,'index.html'):p;
 if(!fs.existsSync(file)){res.writeHead(404).end();return;}
 res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');
 fs.createReadStream(file).pipe(res);
});
await new Promise(resolve=>server.listen(8743,'127.0.0.1',resolve));
const browser=await chromium.launch({channel:'chrome',headless:true});
try {
 const page=await browser.newPage({viewport:{width:1440,height:1000}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'&&!m.location().url.endsWith('/favicon.ico'))errors.push(m.text()+' '+m.location().url)});
 const base=process.env.VERIFY_BASE || 'http://127.0.0.1:8743';
 const route='/In-class_Ex/In-class_Ex04/In-class_Ex04.html';
 const response=await page.goto(base+route,{waitUntil:'networkidle'});
 assert.equal(response.status(),200);
 assert((await page.locator('img').count())>=14);
 await page.locator('img').evaluateAll(async imgs=>{await Promise.all(imgs.map(i=>i.decode().catch(()=>{})))});
 assert.equal(await page.locator('img').evaluateAll(imgs=>imgs.filter(i=>!i.complete||!i.naturalWidth).length),0);
 await page.screenshot({path:path.join(out,'desktop-check.png')});
 await page.getByText('In-class Exercise',{exact:true}).first().click();
 const menuTitle='In-class Exercise 4: Geographically Weighted Statistics';
 assert(await page.getByText(menuTitle,{exact:true}).first().isVisible());
 await page.keyboard.press('Escape');
 await page.getByRole('tab',{name:'Selected bandwidths',exact:true}).click();
 assert(await page.getByRole('tabpanel').filter({hasText:'Both searches select'}).isVisible());
 await page.locator('#comparing-five-kernels').scrollIntoViewIfNeeded();
 await page.screenshot({path:path.join(out,'results-check.png')});
 await page.setViewportSize({width:390,height:844});
 await page.reload({waitUntil:'networkidle'});
 await page.screenshot({path:path.join(out,'mobile-check.png')});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+2);
 assert(!overflow,'Mobile page overflows viewport');
 if(exercise==='04') {
   await page.goto(base+'/index.html',{waitUntil:'networkidle'});
   await page.getByRole('link',{name:'Explore In-class Exercise 4',exact:false}).click();
   await page.waitForLoadState('networkidle');
   assert(new URL(page.url()).pathname===route);
 }
 assert.deepEqual(errors,[]);
 console.log(JSON.stringify({base,images:await page.locator('img').count(),navigation:true,tabs:true,mobileOverflow:overflow,errors}));
} finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
