// Build only. Never deploys, connects to Supabase, or updates migration history.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import {execFileSync} from 'node:child_process';
const phase=process.argv[2],baseRef=process.argv[3];
if(!['admin-only','complete'].includes(phase))throw Error('Usage: node scripts/build-achado4.mjs admin-only|complete VERIFIED_PUBLIC_COMMIT');
if(!baseRef)throw Error('Explicit verified public commit required');
const git=args=>execFileSync('git',['-c',`safe.directory=${process.cwd().replaceAll('\\','/')}`,...args]);
const base=git(['rev-parse','--verify','--end-of-options',baseRef+'^{commit}']).toString().trim();
const output=path.resolve('dist');if(output!==path.join(process.cwd(),'dist'))throw Error('Unsafe output');
await fs.rm(output,{recursive:true,force:true});await fs.mkdir(output,{recursive:true});
const publicPaths=['index.html','admin.html','404.html','.nojekyll','js','css','images'];
if(phase==='admin-only'){
 const files=git(['ls-tree','-r','--name-only',base,'--',...publicPaths]).toString().trim().split('\n').filter(Boolean);
 for(const file of files){const dest=path.resolve(output,file);if(!dest.startsWith(output+path.sep))throw Error('Unsafe archive entry');await fs.mkdir(path.dirname(dest),{recursive:true});await fs.writeFile(dest,git(['show',base+':'+file]));}
 for(const file of ['admin.html','js/admin-supabase.js','js/lib/product-prices.js']){await fs.mkdir(path.dirname(path.join(output,file)),{recursive:true});await fs.copyFile(file,path.join(output,file));}
}else{
 for(const file of publicPaths)await fs.cp(file,path.join(output,file),{recursive:true});
}
const manifest={phase,publicBase:base,files:{}};
async function hashes(dir){for(const entry of await fs.readdir(dir,{withFileTypes:true})){const file=path.join(dir,entry.name);if(entry.isDirectory())await hashes(file);else manifest.files[path.relative(output,file).replaceAll('\\','/')]=crypto.createHash('sha256').update(await fs.readFile(file)).digest('hex');}}
await hashes(output);const buildId='achado4-'+crypto.createHash('sha256').update(JSON.stringify(manifest)).digest('hex').slice(0,16);
// Only touch the new admin HTML during admin-only publishing; public files remain identical.
for(const file of phase==='admin-only'?['admin.html']:['admin.html','index.html']){
 let html=await fs.readFile(path.join(output,file),'utf8');html=html.replace('</head>',`<meta name="zapmenu-build" content="${buildId}"></head>`);
 html=html.replace(/(<script[^>]+src=")([^"?]+)(?:\?[^" ]*)?("[^>]*>)/g,(_,a,b,c)=>a+b+'?v='+buildId+c);
 await fs.writeFile(path.join(output,file),html);
}
manifest.files={};await hashes(output);manifest.buildId=buildId;
await fs.writeFile(path.join(output,'deploy-manifest.json'),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({phase,buildId,publicBase:base}));
