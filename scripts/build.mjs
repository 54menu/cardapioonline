import fs from 'node:fs/promises';
await fs.mkdir('dist',{recursive:true});
for(const file of ['index.html','admin.html','404.html','.nojekyll'])await fs.copyFile(file,'dist/'+file);
for(const dir of ['js','css','images'])await fs.cp(dir,'dist/'+dir,{recursive:true});
console.log('Arquivos públicos preparados em dist/.');
