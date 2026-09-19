import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const root=path.resolve('_site'), base='In-class_Ex/In-class_Ex04';
const file=path.join(root,base,'In-class_Ex04.html'), html=fs.readFileSync(file,'utf8');
for(const text of ['In-class Exercise 4','What I learned','bw.gwr','gwss','kernel-comparison.png','GDPPC_LM','Complete script']) assert(html.includes(text),text);
let refs=0;
for(const [,ref] of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
 if(/^(https?:|data:|mailto:|#|javascript:)/.test(ref)) continue;
 const local=decodeURIComponent(ref.split(/[?#]/)[0]); if(!local) continue;
 const target=local.startsWith('/')?path.join(root,local):path.resolve(path.dirname(file),local);
 assert(fs.existsSync(target),`Missing ${ref}`); refs++;
}
for(const folder of ['data','cache']) assert(!fs.existsSync(path.join(root,base,folder)));
for(const csv of ['gw-summary','local-correlations']) assert.equal(fs.readFileSync(`${base}/outputs/${csv}.csv`,'utf8').trim().split(/\r?\n/).length,89);
const old='_site/Hands-on_Ex/Hands-on_Ex04/Hands-on_Ex04.html';
const clean=s=>s.replace(/<header id="quarto-header"[\s\S]*?<\/header>/,'').replaceAll('\r\n','\n');
assert.equal(clean(fs.readFileSync(old,'utf8')),clean(execFileSync('git',['show',`f0e77b8:${old}`],{encoding:'utf8',maxBuffer:20e6})));
for(const p of [file,path.join(root,'index.html'),old]) {
 const h=fs.readFileSync(p,'utf8'); assert(h.includes('In-class Exercise'));assert(h.includes('Hands-on Exercise 4'));
}
console.log(`PASS: new category and old category preserved; 88 aligned rows; ${refs} local assets; original Hands-on 4 body unchanged.`);
