import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const root=path.resolve('_site'),rel='Hands-on_Ex/Hands-on_Ex04/Hands-on_Ex04.html';
const file=path.join(root,rel),html=fs.readFileSync(file,'utf8');
for(const t of ['What I learned','24,847.2','147,903','448','code-fold','lag-average.png','Spatial window sum'])assert(html.includes(t),`Missing ${t}`);
assert(!html.includes('This is an AI-assisted worked exercise.'));
let count=0;
for(const [,ref] of html.matchAll(/(?:src|href)="([^"]+)"/g)){
 if(/^(https?:|data:|mailto:|#|javascript:)/.test(ref))continue;
 const local=decodeURIComponent(ref.split(/[?#]/)[0]);if(!local)continue;
 const target=local.startsWith('/')?path.join(root,local):path.resolve(path.dirname(file),local);
 assert(fs.existsSync(target),`Missing ${ref}`);count++;
}
assert.equal([...html.matchAll(/<img /g)].length,11);
for(const folder of ['data','cache'])assert(!fs.existsSync(path.join(root,'Hands-on_Ex/Hands-on_Ex04',folder)));
const stripHeader=s=>s.replace(/<header id="quarto-header"[\s\S]*?<\/header>/,'').replaceAll('\r\n','\n');
for(const p of ['Hands-on_Ex/Hands-on_Ex01/Hands-on_Ex01a.html','Hands-on_Ex/Hands-on_Ex01/Hands-on_Ex01b.html','Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02a.html','Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02b.html','Hands-on_Ex/Hands-on_Ex03/Hands-on_Ex03.html','Take-home_Ex/Take-home_Ex01/technical-report.html','Take-home_Ex/Take-home_Ex01/executive-summary.html']){
 const before=execFileSync('git',['show',`f27a4ae:_site/${p}`],{encoding:'utf8',maxBuffer:20e6});
 const after=fs.readFileSync(path.join(root,p),'utf8');assert.equal(stripHeader(after),stripHeader(before),`Existing body changed: ${p}`);
 if(after.includes('<header id="quarto-header"'))assert(after.includes('Hands-on_Ex04.html'));
}
assert(fs.readFileSync(path.join(root,'search.json'),'utf8').includes(rel));
assert.equal(fs.readFileSync('Hands-on_Ex/Hands-on_Ex04/outputs/results4.csv','utf8').trim().split(/\r?\n/).length,89);
console.log(`PASS Exercise 4: 88 results, 11 figures, ${count} local references, navigation, search, data exclusions and unchanged prior assignment bodies.`);
