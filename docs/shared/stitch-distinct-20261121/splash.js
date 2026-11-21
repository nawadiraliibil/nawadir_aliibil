// MOBILE-SPLASH-20261121 — شاشة البداية: حركة المشي مأخوذة من «شاشة تحميل نوادر الإبل» (Nawader_Loading.html) وبعدها انتقال الشعار إلى الرئيسية.
(() => {
const period = 2100, tau = 2 * Math.PI;
 const motion = matchMedia('(prefers-reduced-motion: reduce)');
 const animal = document.querySelector('#animal');
 const upper = document.getElementById('moving-upper');
 const outline = document.getElementById('mark').getAttribute('d');
 const fixed = [];
 const joints = [];
 let end = 0;
 for (const match of outline.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)) {
   const x = Number(match[1]), y = Number(match[2]);
   if (x <= 302 || y >= 295) continue;
   const u = Math.min(1, (x-302)/72) * Math.min(1, (295-y)/38);
   fixed.push(outline.slice(end,match.index));
   joints.push({x,y,weight:u*u*(3-2*u)});
   end = match.index + match[0].length;
 }
 const suffix = outline.slice(end);
 // The shoulder stays anchored. Points on the face share one rigid head rotation.
 function nod(phase) {
   const angle = (.097*Math.sin(tau*2*phase-.48) + .021*Math.sin(tau*phase-.2)) - .013;
   const forward = 3*Math.sin(tau*2*phase-.84);
   const cosine = Math.cos(angle)-1, sine = Math.sin(angle);
   let path = '';
   for (let i=0;i<joints.length;i++) {
     const {x,y,weight}=joints[i], dx=x-314, dy=y-277;
     const px=x+weight*(dx*cosine-dy*sine+forward);
     const py=y+weight*(dx*sine+dy*cosine);
     path+=fixed[i]+px.toFixed(2)+','+py.toFixed(2);
   }
   upper.setAttribute('d',path+suffix);
 }
 const gusts = [
   {id:'breeze-low', x:137,y:380,travel:85,rise:8,delay:.17,opacity:.66},
   {id:'breeze-high',x:424,y:316,travel:66,rise:6,delay:.64,opacity:.58},
   {id:'breeze-dust',x:239,y:421,travel:54,rise:10,delay:.91,opacity:.67}
 ].map(g=>({...g,node:document.getElementById(g.id)}));
 function drift(phase) {
   for(const g of gusts){
     const p=(phase+g.delay)%1;
     const x=g.x-g.travel*p, y=g.y-g.rise*Math.sin(Math.PI*p);
     g.node.setAttribute('transform','translate('+x.toFixed(2)+' '+y.toFixed(2)+')');
     g.node.setAttribute('opacity',(g.opacity*Math.sin(Math.PI*p)**2).toFixed(3));
   }
 }
 // Attachment points follow the original outline. Each foot rolls through stance and swing.
 const legs = [
   {id:'hind-far', back:true, root:[157,295,189,298], foot:170, offset:.46},
   {id:'fore-far', back:false,root:[276,313,312,299],foot:312, offset:.58},
   {id:'hind-near', back:true, root:[149,294,193,297], foot:162, offset:.96},
   {id:'fore-near', back:false,root:[273,315,316,299],foot:296, offset:.08}
 ].map(leg=>({...leg,element:document.getElementById(leg.id)}));
 // Sand advances one repeating strip per gait cycle, opposite the direction of travel.
 const groundTravel=104, stance=.60, leftEdge=48, rightEdge=501;
 const ridgeElement=document.getElementById('sand-ridge');
 const rippleElement=document.getElementById('sand-ripples');
 const shadowElement=document.getElementById('sand-shadow');
 const ridge=[[48,457],[77,461.2],[100,462],[125,461],[150,458],[175,453],[200,448.6],[225,443],[250,437.4],[275,432.6],[300,428.4],[325,425],[350,422.5],[375,422],[402,427.5],[429,437],[460,451],[482,461.5],[501,471]];
 function taper(x){return Math.sin(Math.PI*(x-leftEdge)/(rightEdge-leftEdge))}
 function thickness(x){return 16*taper(x)**.78}
 function ground(x,phase){
   const i=ridge.findIndex(point=>point[0]>=x);
   if(i<=0)return i===0?ridge[0][1]:ridge[ridge.length-1][1];
   const [xa,ya]=ridge[i-1],[xb,yb]=ridge[i];
   const base=ya+(yb-ya)*(x-xa)/(xb-xa);
   const wave=tau*(x/groundTravel+phase);
   return base+taper(x)*(4.9*Math.sin(wave)+1.15*Math.sin(wave*2+.8));
 }
 function rollSand(phase){
   const top=[],bottom=[];
   for(let i=0;i<=96;i++){
     const x=leftEdge+(rightEdge-leftEdge)*i/96;
     const y=ground(x,phase);
     top.push(x.toFixed(2)+','+y.toFixed(2));
     bottom.push(x.toFixed(2)+','+(y+thickness(x)).toFixed(2));
   }
   ridgeElement.setAttribute('d','M'+top.join(' L')+' L'+bottom.reverse().join(' L')+' Z');
   const light=[],shade=[];
   function grain(target,x,length,depth,bend){
     const lo=Math.max(leftEdge+5,x),hi=Math.min(rightEdge-5,x+length);
     if(hi<=lo)return;
     const pts=[];
     for(let j=0;j<=6;j++){
       const px=lo+(hi-lo)*j/6, t=(px-x)/length;
       const py=ground(px,phase)+thickness(px)*(depth+bend*Math.sin(t*Math.PI));
       pts.push(px.toFixed(2)+','+py.toFixed(2));
     }
     target.push('M'+pts.join(' L'));
   }
   for(let i=-1;i<=5;i++){
     const origin=leftEdge+groundTravel*(i-phase);
     grain(light,origin+13,23,.34,.11);
     grain(light,origin+44,3,.45,.02);
     grain(shade,origin+59,14,.69,-.05);
   }
   rippleElement.setAttribute('d',light.join(' '));
   shadowElement.setAttribute('d',shade.join(' '));
 }
 function legShape(leg,phase,bob){
   const p=(phase+leg.offset)%1;
   const swing=Math.max(0,(p-stance)/(1-stance)), lift=Math.sin(Math.PI*swing)**2;
   // While planted, the sole travels at exactly the same horizontal speed as its patch of sand.
   const travel=groundTravel*(stance/2-p+(3-2*swing)*swing*swing);
   const x=leg.foot+travel, y=ground(x,phase)-3-bob-20*lift;
   const [a,ay,b,by]=leg.root;
   const mid=(a+b)/2;
   const knee=mid+(x-mid)*.48+(leg.back?-13:1)+(leg.back?7:15)*lift;
   const ky=ay+(y-ay)*.44-7*lift;
   const ankle=x-(leg.back?9:6)-8*lift, hy=y-21-5*lift;
   const rear=leg.back?7:5;
   return [
    'M',a,ay,'C',a-2,ay+16,knee-8,ky-12,knee-rear,ky,
    'S',ankle-5,hy-6,ankle-3,hy,'Q',ankle-2,hy+5,x-6,y-8,
    'Q',x-9,y-1,x-3,y,'Q',x+9,y+1,x+15,y-2,
    'Q',x+17,y-6,x+8,y-10,'Q',ankle+3,hy+4,ankle+5,hy,
    'L',knee+7,ky+5,'Q',knee+10,ky,knee+9,ky-7,
    'C',knee+9,ky-16,b-4,by+16,b,by
   ].join(' ');
 }
 function paint(t){
   const phase=(t%period)/period;
   nod(phase);
   drift(phase);
   rollSand(phase);
   const bob=1.9*Math.sin(tau*2*phase)-1;
   animal.setAttribute('transform','translate(0 '+bob+')');
   for (const leg of legs) leg.element.setAttribute('d',legShape(leg,phase,bob));
 }
 // ===== MOBILE-SPLASH-20261121: التحكم بالمشهد =====
 // المراحل: عرض الشعار يمشي ثانية واحدة، ثم ينكمش ويهبط فوق شعار ترويسة الرئيسية بينما تظهر الرئيسية.
 const HOLD = 1000, FLY = 720;
 const root = document.documentElement;
 const splash = document.getElementById('splash');
 const veil = splash.querySelector('.sp-veil');
 const svg = splash.querySelector('.sp-emblem');
 const walking = document.getElementById('walking');
 const still = document.getElementById('still');
 const target = document.querySelector('.brand-lockup img');
 const app = document.querySelector('.app');
 // حدود الرسم الفعلية: في وحدات الـSVG (viewBox ‏44 44 460 436) وككسور من صورة الشعار 256px في الترويسة.
 const SVG_BOX = {x0:49.5, y0:47.9, x1:497.4, y1:472.8, vx:44, vy:44, vw:460};
 const IMG_BOX = {x0:23/256, y0:22/256, x1:232/256, y1:221/256};
 let request = 0, running = false, t0 = 0, flown = false;
 function frame(t) { if (!running) return; paint(t - t0); request = requestAnimationFrame(frame); }
 function finish() {
   root.classList.remove('sp-active');
   app.getAnimations().forEach(a => a.cancel());
   splash.remove();
 }
 function fly() {
   if (flown) return; flown = true;
   running = false; cancelAnimationFrame(request);
   splash.classList.add('fly');
   splash.style.pointerEvents = 'none';
   const reduced = motion.matches;
   const fade = {fill: 'forwards'};
   app.animate([{opacity: 0}, {opacity: 1}], {duration: reduced ? 200 : FLY * .7, delay: reduced ? 0 : FLY * .2, easing: 'ease-out', ...fade});
   if (!reduced) app.querySelector('.content')?.animate([{transform: 'translateY(14px)'}, {transform: 'none'}], {duration: FLY, delay: FLY * .15, easing: 'cubic-bezier(.2,.7,.2,1)'});
   splash.querySelector('.sp-status').animate([{opacity: 1}, {opacity: 0}], {duration: reduced ? 200 : 220, ...fade});
   veil.animate([{opacity: 1}, {opacity: 0}], {duration: reduced ? 200 : FLY * .6, delay: reduced ? 0 : FLY * .1, easing: 'ease', ...fade});
   if (reduced) { svg.animate([{opacity: 1}, {opacity: 0}], {duration: 200, ...fade}).finished.then(finish); return; }
   // الانتقال: من الوضع الكبير في الوسط إلى مربع الشعار في الترويسة.
   const e = svg.getBoundingClientRect(), r = target.getBoundingClientRect();
   const k = e.width / SVG_BOX.vw;
   const cl = (SVG_BOX.x0 - SVG_BOX.vx) * k, ct = (SVG_BOX.y0 - SVG_BOX.vy) * k;
   const cw = (SVG_BOX.x1 - SVG_BOX.x0) * k, ch = (SVG_BOX.y1 - SVG_BOX.y0) * k;
   const tl = r.left + IMG_BOX.x0 * r.width, tt = r.top + IMG_BOX.y0 * r.height;
   const tw = (IMG_BOX.x1 - IMG_BOX.x0) * r.width, th = (IMG_BOX.y1 - IMG_BOX.y0) * r.height;
   const s = Math.sqrt((tw / cw) * (th / ch));
   const dx = tl - e.left - s * cl, dy = tt - e.top - s * ct;
   // نمشي بالشعار إلى وضعية الوقوف أثناء الانكماش ليطابق شعار الترويسة.
   walking.animate([{opacity: 1}, {opacity: 0}], {duration: FLY * .45, easing: 'ease-in', ...fade});
   still.animate([{opacity: 0}, {opacity: 1}], {duration: FLY * .45, easing: 'ease-out', ...fade});
   svg.animate([{transform: 'none'}, {transform: `translate(${dx}px,${dy}px) scale(${s})`}], {duration: FLY, easing: 'cubic-bezier(.55,0,.15,1)', ...fade}).finished.then(() => {
     target.style.visibility = 'visible';
     svg.animate([{opacity: 1}, {opacity: 0}], {duration: 140, ...fade}).finished.then(finish);
   });
 }
 function begin() {
   if (!motion.matches) {
     t0 = performance.now(); paint(0);
     splash.classList.add('animated');
     running = true; request = requestAnimationFrame(frame);
   }
   setTimeout(fly, HOLD);
 }
 // تغيّر تفضيل الحركة أثناء العرض لا يعيد التشغيل؛ يكفي عند البدء.
 root.classList.add('sp-active');
 const ready = Promise.race([document.fonts.ready, new Promise(r => setTimeout(r, 500))]);
 const loaded = document.readyState === 'complete' ? Promise.resolve() : new Promise(r => addEventListener('load', r, {once: true}));
 Promise.all([ready, loaded]).then(() => requestAnimationFrame(begin));
})();
