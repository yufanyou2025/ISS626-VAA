import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const root=path.resolve('_site');
const pages=['Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02a.html','Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02b.html'];
let references=0;
for(const p of pages) {
 const file=path.join(root,p),html=fs.readFileSync(file,'utf8');
 assert(html.includes('What I learned'));
 assert(!html.includes('This is an AI-assisted worked exercise.'),'Removed closing note reappeared');
 assert(html.includes('<details class="code-fold">'));
 assert(html.includes('Hands-on_Ex02a.html') && html.includes('Hands-on_Ex02b.html'));
 for(const [,ref] of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
   if(/^(https?:|data:|mailto:|#|javascript:)/.test(ref)) continue;
   const local=decodeURIComponent(ref.split(/[?#]/)[0]);
   if(!local) continue;
   const target=local.startsWith('/')?path.join(root,local):path.resolve(path.dirname(file),local);
   assert(fs.existsSync(target),`${p}: missing ${ref}`); references++;
 }
}
const a=fs.readFileSync(path.join(root,pages[0]),'utf8');
assert(a.includes('<iframe') && a.includes('maps/childcare-locations.html'));
const widget=fs.readFileSync(path.join(root,'Hands-on_Ex/Hands-on_Ex02/maps/childcare-locations.html'),'utf8');
assert(widget.includes('leaflet') && widget.includes('htmlwidgets'));
for(const [,ref] of widget.matchAll(/(?:src|href)="([^"]+)"/g)) {
 if(/^(https?:|data:|#)/.test(ref)) continue;
 assert(fs.existsSync(path.resolve(root,'Hands-on_Ex/Hands-on_Ex02/maps',ref)),`Missing widget dependency ${ref}`);
}
assert(!fs.existsSync(path.join(root,'Hands-on_Ex/Hands-on_Ex02/data')));
assert(!fs.existsSync(path.join(root,'Hands-on_Ex/Hands-on_Ex02/cache')));
const stripHeader=s=>s.replace(/<header id="quarto-header"[\s\S]*?<\/header>/,'').replaceAll('\r\n','\n');
for(const name of ['technical-report','executive-summary']) {
 const p=`_site/Take-home_Ex/Take-home_Ex01/${name}.html`;
 const before=execFileSync('git',['show',`HEAD:${p}`],{encoding:'utf8',maxBuffer:20e6});
 const after=fs.readFileSync(p,'utf8');
 assert.equal(stripHeader(after),stripHeader(before),`Existing ${name} body changed`);
 if(after.includes('<header id="quarto-header"')) assert(after.includes('Hands-on_Ex02b.html'));
}
const search=fs.readFileSync(path.join(root,'search.json'),'utf8');
for(const p of pages) assert(search.includes(p),`Missing search entry ${p}`);
console.log(`PASS: both pages, ${references} local resource references, interactive assets, search entries, raw-data exclusions and unchanged Take-home report bodies.`);
