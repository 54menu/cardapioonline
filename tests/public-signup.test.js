import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {parse} from 'acorn';
import {JSDOM} from 'jsdom';
const source=fs.readFileSync('js/admin-supabase.js','utf8');
const tree=parse(source,{ecmaVersion:'latest',sourceType:'module'});
const node=tree.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='initAuth');
const init=source.slice(node.start,node.end);
async function setup(signUp, url='https://example.com/admin.html?signup=1', session=null) {
 const dom=new JSDOM(fs.readFileSync('admin.html','utf8'),{url});
 const logins=[];
 const context=vm.createContext({document:dom.window.document,window:dom.window,console,URLSearchParams,
  setTimeout:(fn,ms)=>ms===4000?0:setTimeout(fn,ms),showLoading(){},showToast(){},
  auth:{onAuthStateChange(){},async getSession(){return session;},signUp},
  async onAuthSuccess(user){logins.push(user.id);}});
 await vm.runInContext(init+';initAuth()',context);
 const form=dom.window.document.getElementById('publicSignupForm');
 dom.window.document.getElementById('publicSignupEmail').value='new@example.com';
 dom.window.document.getElementById('publicSignupPassword').value='test-password';
 const submit=async()=>{form.dispatchEvent(new dom.window.Event('submit',{cancelable:true}));await new Promise(r=>setTimeout(r,10));};
 return {dom,form,logins,submit,el:id=>dom.window.document.getElementById(id)};
}
test('public signup opens directly and a session proceeds to onboarding',async()=>{
 let credentials;
 const h=await setup(async(...args)=>{credentials=args;return {data:{session:{user:{id:'new-owner'}}}};});
 assert.equal(h.form.style.display,'flex');assert.equal(h.el('passwordForm').style.display,'none');
 await h.submit();assert.deepEqual(credentials,['new@example.com','test-password']);
 assert.deepEqual(h.logins,['new-owner']);assert.equal(h.el('publicSignupBtn').disabled,false);h.dom.window.close();
});
test('confirmation without a session never opens the dashboard',async()=>{
 const h=await setup(async()=>({data:{user:{id:'pending'}}}));
 await h.submit();assert.deepEqual(h.logins,[]);assert.match(h.el('publicSignupStatus').textContent,/confirme seu endereço/);
 assert.equal(h.el('publicSignupPassword').value,'');h.dom.window.close();
});
test('network errors restore the form and concurrent submissions are ignored',async()=>{
 let reject, calls=0;
 const h=await setup(()=>{calls++;return new Promise((_,r)=>reject=r);});
 await h.submit();await h.submit();assert.equal(calls,1);assert.equal(h.el('publicSignupBtn').disabled,true);
 reject(new Error('Failed to fetch'));await new Promise(r=>setTimeout(r,10));
 assert.equal(h.el('publicSignupBtn').disabled,false);assert.match(h.el('publicSignupError').textContent,/conexão/);h.dom.window.close();
});
test('existing accounts get a login instruction and login page stays available',async()=>{
 const h=await setup(async()=>({error:{message:'User already registered'}}));
 await h.submit();assert.match(h.el('publicSignupError').textContent,/já possui conta/);h.dom.window.close();
 const login=await setup(()=>{},'https://example.com/admin.html');assert.equal(login.form.style.display,'none');login.dom.window.close();
});
test('existing session bypasses public signup',async()=>{
 const h=await setup(()=>{throw new Error('No signup expected');},undefined,{user:{id:'existing'}});
 assert.deepEqual(h.logins,['existing']);assert.equal(h.form.style.display,'none');h.dom.window.close();
});
