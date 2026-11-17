(() => {
  const screen = document.body.dataset.screen;
  const urlOffer=new URLSearchParams(location.search).get('offer');
  let offer=['price','auction'].includes(urlOffer)?urlOffer:(screen==='D10'?'auction':'price');
  const go = id => {
    if(screen==='D04'&&id==='D05'&&offer==='auction')id='D06';
    if(screen==='D08'&&id==='D09'&&offer==='auction')id='D10';
    if(id)parent.postMessage({nawaderScreen:id,nawaderOffer:offer},'*');
  };
  document.querySelectorAll('[data-go]').forEach(el => el.addEventListener('click', () => {
    if(el.dataset.offer)offer=el.dataset.offer;
    go(el.dataset.go);
  }));
  document.querySelectorAll('[data-choice]').forEach(el => el.addEventListener('click', () => {
    el.parentElement.querySelectorAll('[data-choice]').forEach(s => s.classList.remove('active'));
    el.classList.add('active');
  }));
  document.querySelectorAll('.switch').forEach(el => el.addEventListener('click', () => el.setAttribute('aria-checked',String(el.getAttribute('aria-checked')!=='true'))));
  document.querySelectorAll('[data-theme-choice]').forEach(el => el.addEventListener('click', () => {
    const value=el.dataset.themeChoice, theme=value==='system'?(matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light'):value;
    document.documentElement.dataset.theme=theme;
    parent.postMessage({nawaderThemeChoice:theme},'*');
  }));
  addEventListener('message', e => {
    if(e.source!==parent)return;
    if(['light','dark'].includes(e.data?.nawaderTheme))document.documentElement.dataset.theme=e.data.nawaderTheme;
    if(['price','auction'].includes(e.data?.nawaderOffer))offer=e.data.nawaderOffer;
  });
  document.querySelectorAll('[data-photo]').forEach(el => el.addEventListener('click', () => {document.querySelector('#media-main').src=el.dataset.photo;}));
  document.querySelector('#media-main')?.addEventListener('click', e=>e.target.classList.toggle('zoomed'));
  const dialog=document.querySelector('#confirm-dialog');
  document.querySelectorAll('[data-confirm]').forEach(el=>el.addEventListener('click',()=>{document.querySelector('#confirm-title').textContent=el.dataset.confirm;dialog.showModal();}));
  document.querySelectorAll('[data-dialog-close]').forEach(el=>el.addEventListener('click',()=>dialog.close()));
  document.querySelector('[data-unblock]')?.addEventListener('click',e=>{e.currentTarget.textContent='تم إلغاء الحظر';e.currentTarget.disabled=true;});
  document.querySelectorAll('[data-retry]').forEach(el=>el.addEventListener('click',()=>{el.textContent='إعادة المحاولة';}));
  document.querySelectorAll('[data-rating]').forEach(el=>el.addEventListener('click',()=>{
    document.querySelector('#rating-value').value=el.dataset.rating;
    document.querySelectorAll('[data-rating]').forEach(star=>star.classList.toggle('selected',Number(star.dataset.rating)<=Number(el.dataset.rating)));
    validate();
  }));
  const required=[...document.querySelectorAll('input[required],select[required],textarea[required]')];
  const channels=[...document.querySelectorAll('[data-channel]')];
  const primary=[...document.querySelectorAll('.actions>.btn:first-child,.content>.btn:not(.outline):not(.text):not(.ghost),.section>.btn.danger')].filter(el=>el.dataset.go||el.dataset.confirm);
  function validate(){
    const valid=required.every(el=>el.type==='checkbox'?el.checked:el.type==='file'?el.files.length>0:el.value.trim()!=='')&&(!channels.length||channels.some(el=>el.checked));
    primary.forEach(el=>{el.disabled=!valid;el.setAttribute('aria-disabled',String(!valid));});
  }
  [...required,...channels].forEach(el=>{el.addEventListener('input',validate);el.addEventListener('change',validate);});validate();
  document.querySelectorAll('form').forEach(form=>form.addEventListener('submit',e=>e.preventDefault()));
})();
