import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {parse} from 'acorn';
import {JSDOM} from 'jsdom';
const source=fs.readFileSync('js/admin-supabase.js','utf8');
const tree=parse(source,{ecmaVersion:'latest',sourceType:'module'});
const fn=name=>{const n=tree.body.find(n=>n.type==='FunctionDeclaration'&&n.id.name===name);return source.slice(n.start,n.end);};
test('first login initializes once, waits for store, and repeated auth events are harmless',async()=>{
 const dom=new JSDOM(fs.readFileSync('admin.html','utf8'),{url:'https://example.com/admin.html'});
 let callback, loads=0, release;
 const pending=new Promise(resolve=>release=resolve);
 const context=vm.createContext({document:dom.window.document,window:dom.window,console,URLSearchParams,setTimeout:(f,ms)=>ms===4000?0:setTimeout(f,ms),showLoading(){},showToast(){},onAuthLogout(){},
 auth:{onAuthStateChange(fn){callback=fn;},async getSession(){return null;},async signIn(){callback('SIGNED_IN',{user:{id:'owner'}});return {data:{user:{id:'owner'}}};}},
 async loadAuthenticatedUser(){loads++;await pending;}});
 vm.runInContext('let loadedAuthUserId=null; let authLoadPromise=null;'+fn('onAuthSuccess')+fn('initAuth'),context);
 await vm.runInContext('initAuth()',context);
 dom.window.document.getElementById('passwordEmail').value='owner@example.com';
 dom.window.document.getElementById('passwordForm').dispatchEvent(new dom.window.Event('submit',{cancelable:true}));
 await new Promise(resolve=>setTimeout(resolve,20));
 assert.equal(loads,1);
 assert.equal(dom.window.document.getElementById('passwordBtn').disabled,true);
 release();await new Promise(resolve=>setTimeout(resolve,20));
 assert.equal(dom.window.document.getElementById('passwordBtn').disabled,false);
 callback('SIGNED_IN',{user:{id:'owner'}});
 await new Promise(resolve=>setTimeout(resolve,20));assert.equal(loads,1);
 dom.window.close();
});
test('subscription render never queries without a store',async()=>{
 const context=vm.createContext({currentStoreId:null,document:{getElementById(){throw new Error('Should return before rendering or querying');}}});
 await vm.runInContext(fn('renderSubscription')+';renderSubscription()',context);
});
