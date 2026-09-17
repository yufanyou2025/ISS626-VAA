// Update shared navigation without recomputing archived reports whose raw data
// are intentionally not in Git. Run after rendering index.qmd with Quarto.
import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve('_site');
const headerPattern = /<header id="quarto-header"[\s\S]*?<\/header>/;
const homepage = fs.readFileSync(path.join(root,'index.html'),'utf8');
let header = homepage.match(headerPattern)?.[0];
if (!header || !header.includes('Hands-on_Ex02b.html')) throw Error('Render the updated homepage first');
header = header.replaceAll('href="./','href="/').replaceAll('nav-link active','nav-link').replaceAll(' aria-current="page"','');
let count=0;
function visit(dir) {
  for (const entry of fs.readdirSync(dir,{withFileTypes:true})) {
    const file=path.join(dir,entry.name);
    if(entry.isDirectory()) visit(file);
    else if(entry.name.endsWith('.html')) {
      const html=fs.readFileSync(file,'utf8');
      if(!headerPattern.test(html)) continue;
      const updated=html.replace(headerPattern,header);
      if(updated!==html) {fs.writeFileSync(file,updated);count++;}
    }
  }
}
visit(root);
console.log(`Synchronized shared navigation in ${count} rendered pages; report bodies unchanged.`);
