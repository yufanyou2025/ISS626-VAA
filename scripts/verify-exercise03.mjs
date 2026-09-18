import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=path.resolve('_site');
const rel='Hands-on_Ex/Hands-on_Ex03/Hands-on_Ex03.html';
const file=path.join(root,rel), html=fs.readFileSync(file,'utf8');
for(const text of ['What I learned','741','code-fold','daily-kde.gif','space-time-k.png']) {
 assert(html.includes(text),`Missing content: ${text}`);
}
let checked=0;
for(const [,ref] of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
 if(/^(https?:|data:|mailto:|#|javascript:)/.test(ref)) continue;
 const local=decodeURIComponent(ref.split(/[?#]/)[0]);
 if(!local) continue;
 const target=local.startsWith('/')?path.join(root,local):path.resolve(path.dirname(file),local);
 assert(fs.existsSync(target),`Missing ${ref}`);checked++;
}
for(const name of ['data','cache']) assert(!fs.existsSync(path.join(root,'Hands-on_Ex/Hands-on_Ex03',name)));
for(const p of ['index.html','Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02a.html','Hands-on_Ex/Hands-on_Ex02/Hands-on_Ex02b.html','Take-home_Ex/Take-home_Ex01/technical-report.html'])
 assert(fs.readFileSync(path.join(root,p),'utf8').includes('Hands-on_Ex03.html'),`Missing navigation ${p}`);
assert(fs.readFileSync(path.join(root,'search.json'),'utf8').includes(rel));
const output='Hands-on_Ex/Hands-on_Ex03/outputs/';
assert(fs.readFileSync(output+'audit.csv','utf8').includes('Retained detections,741'));
assert.equal(fs.readFileSync(output+'k-ratio.csv','utf8').trim().split(/\r?\n/).length,901);
console.log(`PASS Exercise 3: content, ${checked} resource references, navigation, search, data exclusions, counts and 900 K ratios.`);
