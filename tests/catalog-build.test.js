import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {execFileSync} from 'node:child_process';
const git=args=>execFileSync('git',['-c',`safe.directory=${process.cwd().replaceAll('\\','/')}`,...args]);
test('admin-only artifact preserves public catalog bytes from explicit base',()=>{
 execFileSync(process.execPath,['scripts/build-achado4.mjs','admin-only','HEAD']);
 const manifest=JSON.parse(fs.readFileSync('dist/deploy-manifest.json','utf8'));assert.equal(manifest.phase,'admin-only');
 for(const file of ['index.html','js/components/productCard.js','js/components/productModal.js','js/state/store.js'])assert.deepEqual(fs.readFileSync('dist/'+file),git(['show','HEAD:'+file]));
 assert.deepEqual(fs.readFileSync('dist/js/admin-supabase.js'),fs.readFileSync('js/admin-supabase.js'));
 assert.ok(fs.readFileSync('dist/admin.html','utf8').includes(manifest.buildId));
});
test('complete artifact includes corrected catalog and an identifiable build',()=>{
 execFileSync(process.execPath,['scripts/build-achado4.mjs','complete','HEAD']);
 const manifest=JSON.parse(fs.readFileSync('dist/deploy-manifest.json','utf8'));assert.equal(manifest.phase,'complete');
 assert.deepEqual(fs.readFileSync('dist/js/components/productCard.js'),fs.readFileSync('js/components/productCard.js'));
 assert.ok(fs.readFileSync('dist/index.html','utf8').includes(manifest.buildId));
});
test('build requires explicit phase and base; workflow has no push deployment',()=>{
 assert.throws(()=>execFileSync(process.execPath,['scripts/build-achado4.mjs','admin-only'],{stdio:'pipe'}));
 const workflow=fs.readFileSync('.github/workflows/pages.yml','utf8');assert.ok(!/^\s+push:/m.test(workflow));assert.match(workflow,/workflow_dispatch/);
});
