import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg'};
export function createServer(){return http.createServer(async(req,res)=>{
 try{
  const url=new URL(req.url,'http://localhost');const relative=decodeURIComponent(url.pathname).replace(/^\//,'')||'index.html';
  if(!/^(index\.html|admin\.html|404\.html|(?:js|css|images)\/.+)$/.test(relative)||relative.split('/').some(p=>p==='..'||p.startsWith('.')))throw Error('Not public');
  const full=path.resolve(root,relative);if(!full.startsWith(root+path.sep))throw Error('Outside root');
  const data=await fs.readFile(full);res.writeHead(200,{'Content-Type':types[path.extname(full)]||'application/octet-stream','X-Content-Type-Options':'nosniff'});res.end(data);
 }catch{res.writeHead(404);res.end('Not found');}
});}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))createServer().listen(3000,'127.0.0.1',()=>console.log('Cardápio: http://localhost:3000'));
