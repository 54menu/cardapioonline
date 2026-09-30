import fs from 'node:fs';
import {createClient} from '@supabase/supabase-js';
const source=fs.readFileSync('js/lib/supabase.js','utf8');
const url=source.match(/const SUPABASE_URL = '([^']+)'/)[1];
const key=source.match(/const SUPABASE_ANON_KEY = '([^']+)'/)[1];
const db=createClient(url,key,{auth:{persistSession:false}});
const {error}=await db.from('stores').select('id').limit(1);
if(error){console.error('Falha na conexão:',error.message);process.exitCode=1;}else console.log('Conexão pública com Supabase OK. Nenhum dado foi modificado.');
