// تصوير معاينات الشاشات وفحصها عبر Chrome DevTools. الاستخدام:
//   node render_previews.mjs [العرض=390] [--check-only] [معرّفات...]
// يكتب PNG في previews/ (عند العرض 390 فقط) وتقرير render-checks.json.
import {spawn} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync,mkdtempSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

const ROOT=dirname(fileURLToPath(import.meta.url));
const args=process.argv.slice(2);
const width=Number(args.find(a=>/^\d+$/.test(a))||390);
const checkOnly=args.includes('--check-only');
const only=args.filter(a=>/^[A-H]\d\d$/.test(a));
const CHROME=process.env.CHROME||'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const manifest=JSON.parse(readFileSync(join(ROOT,'manifest.json'),'utf8')).filter(m=>!only.length||only.includes(m.id));
if(width===390&&!checkOnly)mkdirSync(join(ROOT,'previews'),{recursive:true});

const port=9400+Math.floor(Math.random()*400);
const proc=spawn(CHROME,['--headless=new',`--remote-debugging-port=${port}`,`--user-data-dir=${mkdtempSync(join(tmpdir(),'noq-'))}`,'--hide-scrollbars','--no-first-run','--disable-gpu','about:blank'],{stdio:'ignore'});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let tab;
for(let i=0;i<60&&!tab;i++){try{tab=await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'})).json();}catch{await sleep(250);}}
if(!tab)throw new Error('تعذر تشغيل Chrome');
const ws=new WebSocket(tab.webSocketDebuggerUrl);
await new Promise(r=>ws.addEventListener('open',r));
let id=0;const pending=new Map();const waiters=[];
ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id&&pending.has(m.id)){pending.get(m.id)(m);pending.delete(m.id);}else if(m.method)waiters.splice(0).forEach(w=>w(m));});
const send=(method,params={})=>new Promise((res,rej)=>{const i=++id;pending.set(i,m=>m.error?rej(new Error(m.error.message)):res(m.result));ws.send(JSON.stringify({id:i,method,params}));});
const loaded=()=>new Promise(res=>{const h=m=>m.method==='Page.loadEventFired'?res():waiters.push(h);waiters.push(h);});
await send('Page.enable');await send('Runtime.enable');

const CHECK=`(async()=>{
 await document.fonts.ready;
 await Promise.all([...document.images].map(i=>i.complete?1:new Promise(r=>{i.onload=i.onerror=r;})));
 const de=document.documentElement,bs=getComputedStyle(document.body);
 const broken=[...document.images].filter(i=>!i.naturalWidth).length;
 const small=[...document.querySelectorAll('button,.btn,.icon-btn,a.list-row,.chip,.fab')].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&(r.height<32||r.width<32)&&!e.closest('[hidden]')&&getComputedStyle(e).visibility!=='hidden'}).map(e=>(e.getAttribute('aria-label')||e.textContent||e.className).trim().slice(0,24));
 const widest=[...document.querySelectorAll('body *')].filter(e=>e.getBoundingClientRect().right>innerWidth+1&&!e.closest('.ticket-row,.chips.scroll,.photo-strip')).slice(0,3).map(e=>e.className||e.tagName);
 return {overflowX:de.scrollWidth>innerWidth+1,overflowers:widest,broken,font:bs.fontFamily.split(',')[0],tajawal:document.fonts.check('15px Tajawal'),readex:!document.querySelector('h1,h2,.price,.ad-copy strong,.ticket strong')||[...document.fonts].some(f=>f.family.includes('Readex')&&f.status==='loaded'),bg:bs.backgroundColor,size:bs.fontSize,smallTargets:small,height:de.scrollHeight};
})()`;

const results=[];
for(const m of manifest){
  const url=pathToFileURL(join(ROOT,'screens',m.file)).href+'?offer=price';
  await send('Emulation.setDeviceMetricsOverride',{width,height:844,deviceScaleFactor:1,mobile:true});
  const l=loaded();await send('Page.navigate',{url});await l;
  const r=(await send('Runtime.evaluate',{expression:CHECK,awaitPromise:true,returnByValue:true})).result.value;
  await sleep(150);
  if(width===390&&!checkOnly){const shot=await send('Page.captureScreenshot',{format:'png'});writeFileSync(join(ROOT,'previews',m.file+'.png'),Buffer.from(shot.data,'base64'));}
  results.push({id:m.id,theme:m.theme,width,...r});
}
ws.close();proc.kill();
const bad=results.filter(r=>r.overflowX||r.broken||!r.tajawal||!r.readex);
writeFileSync(join(ROOT,`render-checks-${width}.json`),JSON.stringify({width,count:results.length,overflowX:results.filter(r=>r.overflowX).length,brokenImages:results.filter(r=>r.broken).length,fontsMissing:results.filter(r=>!r.tajawal||!r.readex).length,results},null,1));
console.log(JSON.stringify({width,count:results.length,problems:bad.map(b=>({id:b.id,theme:b.theme,overflowX:b.overflowX,overflowers:b.overflowers,broken:b.broken,tajawal:b.tajawal,readex:b.readex}))},null,1));
