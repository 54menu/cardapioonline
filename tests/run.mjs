import {createServer} from '../server.js';
import {spawn} from 'node:child_process';
const server=createServer();await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base='http://127.0.0.1:'+server.address().port;
try{
 for(const file of ['tests/verify_endpoints.js','tests/verify_whatsapp_logic.js','tests/regression.test.js','tests/checkout.test.js','tests/auth.test.js']){
  const args=file.endsWith('.test.js')?['--test',file]:[file];
  const code=await new Promise(resolve=>spawn(process.execPath,args,{stdio:'inherit',env:{...process.env,TEST_BASE_URL:base}}).on('exit',resolve));
  if(code!==0){process.exitCode=1;break;}
 }
}finally{await new Promise(resolve=>server.close(resolve));}
