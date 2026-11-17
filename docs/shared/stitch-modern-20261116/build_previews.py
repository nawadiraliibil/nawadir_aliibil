import json,base64,html,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PLAN=json.loads((ROOT/'screen-plan.json').read_text(encoding='utf8'))
SCREENS=[s for g in PLAN for s in g['screens']]
EMBLEM='data:image/webp;base64,'+base64.b64encode((ROOT/'logo-emblem.webp').read_bytes()).decode()
FULL='data:image/webp;base64,'+base64.b64encode((ROOT/'logo-full.webp').read_bytes()).decode()
PHOTOS=json.loads((ROOT/'photo-sources.json').read_text(encoding='utf8'))

PATHS={
'back':'M15 18l-6-6 6-6','arrow':'M5 12h14m-6-6 6 6-6 6','home':'m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z',
'heart':'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z',
'plus':'M12 5v14M5 12h14','chat':'M21 11.5a8.4 8.4 0 0 1-.9 3.8A8.5 8.5 0 0 1 12.5 20a8.4 8.4 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8A8.5 8.5 0 0 1 8.7 3.9a8.4 8.4 0 0 1 3.8-.9h.5a8.5 8.5 0 0 1 8 8z',
'user':'M20 21v-2a7 7 0 0 0-14 0v2M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
'search':'M21 21l-5.2-5.2M18 10.5a7.5 7.5 0 1 1-15 0 7.5 7.5 0 0 1 15 0',
'filter':'M4 7h16M7 12h10M10 17h4','bell':'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4',
'pin':'M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0M15 10a3 3 0 1 1-6 0 3 3 0 0 1 6 0',
'grid':'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z',
'map':'m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3zM9 3v15M15 6v15','chevron':'m14 6-6 6 6 6','down':'m6 9 6 6 6-6',
'check':'m5 12 4 4L19 6','close':'m6 6 12 12M6 18 18 6','clock':'M12 8v5l3 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0',
'image':'M3 3h18v18H3zM3 16l6-6 5 5 3-3 4 4M16 7h.01','camera':'M3 7h4l2-3h6l2 3h4v14H3zM16 13a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
'send':'m22 2-7 20-4-9-9-4zM22 2 11 13','phone':'M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6 19.8 19.8 0 0 1-3.1-8.7A2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.5c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.8 2.1z',
'share':'m15 8 6-5M15 16l6 5M6 12h9M7 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0M23 3a3 3 0 1 1-6 0 3 3 0 0 1 6 0M23 21a3 3 0 1 1-6 0 3 3 0 0 1 6 0',
'shield':'m12 2 9 4v6c0 5-9 10-9 10S3 17 3 12V6zM8 12l3 3 5-6','settings':'M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M5 19l2-2M17 7l2-2',
'file':'M14 2H5v20h14V7zM14 2v5h5M8 12h8M8 16h6','edit':'m16 3 5 5-13 13H3v-5zM14 5l5 5','trash':'M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7',
'star':'m12 2 3.1 6.3L22 9.3l-5 4.9 1.2 6.9L12 17.8l-6.2 3.3 1.2-6.9-5-4.9 6.9-1z','info':'M12 11v6M12 7h.01M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0',
'refresh':'M21 3v6h-6M3 21v-6h6M20 9a8 8 0 0 0-14-4L3 9M4 15a8 8 0 0 0 14 4l3-4',
'eye':'M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0',
'lock':'M5 10h14v12H5zM8 10V6a4 4 0 0 1 8 0v4','wifi':'M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0M12 20h.01','logout':'M9 21H3V3h6M15 8l4 4-4 4M8 12h11','more':'M5 12h.01M12 12h.01M19 12h.01','play':'m8 5 11 7-11 7z'}
def icon(name,cls=''):
 return f'<svg class="icon {cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="{PATHS.get(name,PATHS["info"])}"/></svg>'
def btn(label,to='',kind='',ic=None,extra=''):
 return f'<button class="btn {kind}" type="button" {"data-go="+to if to else ""} {extra}>{icon(ic) if ic else ""}<span>{label}</span></button>'
def ib(name,label,to='',extra=''):
 return f'<button class="icon-btn" type="button" aria-label="{label}" {"data-go="+to if to else ""} {extra}>{icon(name)}</button>'
def badge(label,kind=''):
 return f'<span class="badge {kind}">{label}</span>'
def p(txt,cls=''):
 return f'<p class="{cls}">{txt}</p>'
def field(label,kind='text',placeholder='',required=False,value='',extra=''):
 v=f'value="{html.escape(value,quote=True)}"' if value else ''
 return f'<label class="field"><span>{label}</span><input type="{kind}" placeholder="{placeholder}" {"required" if required else ""} {v} {extra}></label>'
def select(label,options,required=False):
 return '<label class="field"><span>'+label+'</span><select '+('required' if required else '')+'><option value="">اختر</option>'+''.join(f'<option value="{i+1}">{o}</option>' for i,o in enumerate(options))+'</select></label>'
def textarea(label,placeholder='',required=False):
 return f'<label class="field"><span>{label}</span><textarea rows="3" placeholder="{placeholder}" {"required" if required else ""}></textarea></label>'
def consent(label,required=True):
 return f'<label class="check"><input type="checkbox" data-consent {"required" if required else ""}><span>{label}</span></label>'
def row(label,to='',meta='',ic=None,last=None):
 copy=f'{icon(ic) if ic else ""}<span class="row-copy"><span>{label}</span>{f"<small>{meta}</small>" if meta else ""}</span>'
 if last and '<button' in last:return f'<div class="list-row"><button type="button" class="row-main" {"data-go="+to if to else ""}>{copy}</button>{last}</div>'
 return f'<button type="button" class="list-row" {"data-go="+to if to else ""}>{copy}{last or icon("chevron","muted")}</button>'
def facts(items):
 return '<dl class="facts">'+''.join(f'<div><dt>{k}</dt><dd>{v}</dd></div>' for k,v in items)+'</dl>'
def accordion(title,body):
 return f'<details><summary>{title}{icon("down")}</summary><div class="details-body">{body}</div></details>'
def note(text,kind=''):
 return f'<div class="note {kind}">{icon("info")}<span>{text}</span></div>'
def section(title,body,action=''):
 return f'<section class="section"><div class="section-title"><h2>{title}</h2>{action}</div>{body}</section>'
def chips(labels,active=0):
 return '<div class="chips">'+''.join(f'<button type="button" class="chip {"active" if i==active else ""}" data-choice>{t}</button>' for i,t in enumerate(labels))+'</div>'
def summary_ad(auction=False,photo=0,small=False):
 to='C02' if auction else 'C01'
 return f'<article class="ad-card {"small-ad" if small else ""}"><div class="ad-image"><img src="{PHOTOS[photo%len(PHOTOS)]}" alt="صورة إبل توضيحية">{ib("heart","حفظ الإعلان","B09")}{badge("مزاد حضوري" if auction else "سعر محدد")}</div><button type="button" class="ad-copy" data-go="{to}"><strong>{"22 نوفمبر · 4:00 م" if auction else "48,000 <small>ريال</small>"}</strong><span>{"قعود مجهم" if auction else "ناقة وضح أصيلة"}</span><small>{icon("pin")}الرياض · منذ ساعة</small></button></article>'
def grid_ads(n=4):
 return '<div class="ad-grid">'+''.join(summary_ad(i%2==1,i) for i in range(n))+'</div>'
def mapview(height='190px',pin='موقع الإعلان'):
 return f'<div class="map" style="height:{height}" aria-label="خريطة توضيحية"><div class="road r1"></div><div class="road r2"></div><div class="road r3"></div><div class="map-pin">{icon("pin")}<span>{pin}</span></div><small>خريطة توضيحية</small></div>'
def empty(title,desc,action,to,ic='search'):
 return f'<div class="empty"><div class="empty-icon">{icon(ic)}</div><h2>{title}</h2><p>{desc}</p>{btn(action,to)}</div>'
def sheet(title,body,actions):
 return f'<div class="sheet-preview"><div class="sheet-handle"></div><h2>{title}</h2>{body}<div class="stack">{actions}</div></div>'
def progress(n,title='إعلان جديد'):
 return f'<div class="step"><span>{title}</span><span>{n} / 7</span></div><div class="progress"><i style="width:{n/7*100}%"></i></div>'
def actions(primary,to,secondary='حفظ مسودة',secondary_to='D12'):
 return '<div class="actions">'+btn(primary,to)+ (btn(secondary,secondary_to,'ghost') if secondary else '')+'</div>'
def avatar(txt='م',size=''):
 return f'<span class="avatar {size}">{txt}</span>'
def stars():
 return '<div class="rating" role="group" aria-label="التقييم من واحد إلى خمسة">'+''.join(f'<button type="button" data-rating="{i}" aria-label="{i} من 5">{icon("star")}</button>' for i in range(1,6))+'<input type="hidden" id="rating-value" required value=""></div>'

def content(code):
 if code=='A01':return f'<div class="welcome"><img src="{FULL}" alt="شعار نوادر الإبل" class="full-logo"><h1>أهلًا بك</h1><div class="stack">{btn("تصفح الإعلانات","B01")}{btn("دخول برقم الجوال","A02","outline")}</div></div>'
 if code=='A02':return p('أدخل جوالك لاستلام رمز التحقق.','meta')+field('رقم الجوال','tel','5X XXX XXXX',True,extra='dir="ltr" inputmode="tel" autocomplete="tel-national"')+p('+966 · السعودية','meta ltr')+actions('إرسال الرمز','A03','المتابعة كزائر','B01')
 if code=='A03':return p('أرسلناه إلى <bdi>05*****321</bdi>','meta')+field('الرمز','text','أدخل رمز التحقق',True,extra='inputmode="numeric" autocomplete="one-time-code" dir="ltr"')+btn('تأكيد','A04')+'<div class="split">'+btn('تغيير الرقم','A02','text')+btn('إعادة الإرسال','A05','text')+'</div>'
 if code=='A04':return field('الاسم المعروض','text','اسمك في التطبيق',True)+select('المنطقة',['الرياض','القصيم','مكة المكرمة','الشرقية'],True)+consent('أوافق على شروط الاستخدام')+consent('أوافق على سياسة الخصوصية')+actions('حفظ ومتابعة','B01','السياسات','G09')
 if code=='A05':return empty('تعذر تأكيد الرمز','تحقق من الرمز أو اطلب رمزًا جديدًا.','حاول مجددًا','A03','lock')+row('تغيير رقم الجوال','A02')+accordion('طلبت الرمز عدة مرات؟',p('انتظر المدة المحددة من الخدمة ثم أعد المحاولة.'))
 if code=='B01':return '<div class="searchbar">'+icon('search')+'<input type="search" placeholder="ابحث عن الإبل" aria-label="البحث">'+ib('filter','التصفية','B03')+'</div>'+chips(['الكل','سعر محدد','مزاد حضوري'])+section('أحدث الإعلانات',grid_ads(),btn('الخريطة','B06','text','map'))
 if code=='B02':return '<div class="searchbar">'+icon('search')+'<input value="ناقة وضح" aria-label="البحث">'+ib('close','مسح البحث','B01')+'</div><div class="toolbar">'+btn('تصفية · 2','B03','outline','filter')+btn('الأحدث','B04','outline','down')+ib('map','الخريطة','B06')+'</div><div class="split"><small class="muted">12 إعلانًا</small>'+btn('متابعة البحث','G03','text','bell')+'</div>'+grid_ads()
 if code=='B03':return '<div class="form-grid">'+select('المنطقة',['الرياض','القصيم','مكة'])+select('المدينة',['الرياض','الدرعية','المزاحمية'])+select('السلالة',['وضح','مجهم','صفر','أخرى'])+select('الجنس',['ذكر','أنثى'])+'</div>'+section('نوع العرض',chips(['الكل','سعر محدد','مزاد حضوري']))+section('العمر · بالأشهر','<div class="form-grid">'+field('من','number','0')+field('إلى','number','60')+'</div>')+section('السعر · ريال','<div class="form-grid">'+field('من','number','0')+field('إلى','number','100,000')+'</div>'+p('تحديد السعر يستبعد المزادات.','meta'))+actions('عرض النتائج','B02','مسح الكل','B03')
 if code=='B04':return '<div class="radio-list">'+''.join(f'<label><input type="radio" name="sort" {"checked" if i==0 else ""}><span>{t}</span></label>' for i,t in enumerate(['الأحدث ظهورًا','الأحدث نشرًا','السعر: الأقل أولًا','السعر: الأعلى أولًا']))+'</div>'+btn('تطبيق','B02')
 if code=='B05':return '<div class="searchbar">'+icon('search')+'<input placeholder="ابحث عن منطقة أو مدينة" aria-label="البحث في المواقع"></div>'+p('المنطقة','eyebrow')+''.join(row(t,'B05',ic='pin',last=badge('محددة') if i==0 else icon('chevron')) for i,t in enumerate(['الرياض','مكة المكرمة','القصيم','الشرقية']))+accordion('مدن الرياض',''.join(row(c,'B02') for c in ['الرياض','الدرعية','المزاحمية']))+p('تغيير المنطقة يمسح اختيار المدينة.','meta')
 if code=='B06':return '<div class="split">'+btn('مركز البحث','B07','text','pin')+btn('القائمة','B02','text','grid')+'</div>'+chips(['10 كم','25 كم','50 كم','100 كم','200 كم'],2)+mapview('370px','الرياض')+ '<div class="mini-ad">'+f'<img src="{PHOTOS[0]}" alt="إبل توضيحية">'+'<div><strong>ناقة وضح</strong><p>48,000 ريال</p><small>نقطة تقريبية · 12 كم</small></div>'+ib('arrow','التفاصيل','C01')+'</div>'
 if code=='B07':return btn('استخدام موقعي','B06','outline','pin')+p('أو اختر مركزًا يدويًا','meta center')+select('المنطقة',['الرياض','القصيم','مكة'],True)+select('المدينة',['الرياض','الدرعية'],True)+mapview('210px','مركز البحث')+section('المسافة',chips(['10 كم','25 كم','50 كم','100 كم'],2))+actions('اعتماد المركز','B06',secondary='')
 if code=='B08':return chips(['الرياض ×','وضح ×'])+empty('لا توجد نتائج','جرّب تقليل المرشحات أو تغيير المنطقة.','تعديل البحث','B03')+btn('مسح المرشحات','B01','text')
 if code=='B09':return grid_ads(2)+'<div class="unavailable">'+icon('lock')+'<span>إعلان غير متاح</span>'+ib('trash','إزالة من المفضلة')+'</div>'
 if code in ['C01','C02']:
  auc=code=='C02'
  hero=f'<div class="detail-hero"><img src="{PHOTOS[1 if auc else 0]}" alt="إبل توضيحية">{btn("1 / 3","C04","photo-count","image")}</div>'
  main=badge('مزاد حضوري' if auc else 'سعر محدد')+ ('<h1>قعود مجهم</h1>' if auc else '<h1>ناقة وضح أصيلة</h1><div class="price">48,000 <small>ريال</small></div>')
  main+=p(icon('pin')+' الرياض · منذ ساعة','location')+ ('<div class="fact-chips"><span>مجهم</span><span>ذكر</span><span>36 شهرًا</span></div>' if auc else '<div class="fact-chips"><span>وضح</span><span>أنثى</span><span>36 شهرًا</span></div>')+p('الحالة الصحية: لا عيوب معروفة حسب المعلن.','meta')
  if auc:main+=facts([('الموعد','22 نوفمبر 2026 · 4:00 م'),('المكان','سوق الإبل · الرياض')])+p('المزايدة حضورية خارج التطبيق.','meta')+mapview('130px','مكان المزاد')+btn('الاتجاهات','B06','outline','map')
  main+=accordion('وصف الإعلان',p('إبل بحالة جيدة، لا توجد عيوب معروفة حسب المعلن.'))+accordion('بيانات الإبل',facts([('السلالة','وضح'),('الجنس','أنثى'),('العمر','36 شهرًا · تقريبي'),('الحالة الصحية','لا توجد عيوب معروفة')]))
  main+='<div class="seller">'+avatar()+'<button data-go="C06" class="seller-copy"><strong>معلن تجريبي</strong><small>الرياض · هاتف مؤكد</small></button>'+ib('chevron','ملف المعلن','C06')+'</div>'+row('الأسئلة والردود','C07',meta='3 أسئلة',ic='chat')+row('الإبلاغ عن الإعلان','F09',ic='shield')
  return hero+main
 if code=='C03':return note('مضى موعد المزاد.')+ '<div class="mini-ad">'+f'<img src="{PHOTOS[1]}" alt="إبل توضيحية">'+'<div><strong>قعود مجهم</strong><small>الموعد: 15 نوفمبر 2026</small></div></div>'+facts([('المكان','الرياض · سوق الإبل'),('الحالة','الإعلان منشور')])+p('لا يعرض التطبيق نتيجة المزاد أو فائزًا.','meta')+accordion('خيارات المعلن',btn('تعديل الموعد','D06','outline')+btn('أرشفة الإعلان','E08','text'))
 if code=='C04':return f'<div class="media-full"><img id="media-main" src="{PHOTOS[0]}" alt="صورة إبل قابلة للتكبير"></div><div class="photo-strip">'+''.join(f'<button type="button" data-photo="{src}" aria-label="اختيار الصورة {i+1}"><img src="{src}" alt="صورة {i+1}"></button>' for i,src in enumerate(PHOTOS[:3]))+'</div>'+p('اضغط الصورة للتكبير','meta center')+accordion('الفيديو الاختياري','<div class="video-placeholder">'+icon('play')+'<span>معاينة مشغل الفيديو</span></div>')
 if code=='C05':return '<div class="mini-ad">'+f'<img src="{PHOTOS[0]}" alt="إبل توضيحية">'+'<div><strong>ناقة وضح</strong><small>48,000 ريال</small></div></div>'+row('اتصال','C05',meta='+966 5X XXX XXXX',ic='phone')+row('واتساب','C05',ic='chat')+row('محادثة خاصة','F02',ic='send')+row('مشاركة الإعلان','C05',ic='share')+p('يظهر رقم التواصل بموافقة المعلن.','meta')
 if code=='C06':return '<div class="profile-center">'+avatar('م','large')+'<h1>معلن تجريبي</h1><p>الرياض · انضم في 2026</p>'+badge('هوية موثقة')+'</div><div class="split">'+btn('متابعة','G03','outline','plus')+btn('4.8 · 12 تقييمًا','F05','text','star')+'</div>'+section('إعلانات المعلن',grid_ads(2))
 if code=='C07':return '<div class="discussion"><div class="discussion-head">'+avatar('س')+'<strong>مستخدم تجريبي</strong><small>منذ ساعة</small>'+ib('more','الإبلاغ عن السؤال','F09')+'</div><p>هل المعاينة متاحة؟</p><div class="reply"><strong>المعلن</strong><p>نعم، تواصل لترتيب الموعد.</p></div></div>'+btn('إضافة سؤال','C08','outline','plus')+accordion('خيارات سؤالك',btn('تعديل السؤال','C08','text','edit')+btn('حذف السؤال','','text danger','trash',extra='data-confirm="حذف سؤالك؟"'))+accordion('خيارات المعلن',btn('إغلاق الردود الجديدة','C07','text'))
 if code=='C08':return p('سيظهر سؤالك للجميع.','meta')+textarea('سؤالك','اكتب سؤالك عن الإعلان',True)+actions('إرسال السؤال','C07','إلغاء','C07')
 if code=='C09':return empty('الإعلان غير متاح','يمكنك استكشاف إعلانات أخرى.','الرئيسية','B01','image')
 if code=='D01':return progress(1)+p('رأس واحد لكل إعلان','meta')+'<div class="choice-cards">'+row('سعر محدد','D02','أدخل السعر المطلوب','file').replace('data-go=D02','data-go=D02 data-offer="price"')+row('مزاد حضوري','D02','حدد المكان والموعد','pin').replace('data-go=D02','data-go=D02 data-offer="auction"')+'</div>'+btn('حفظ مسودة','D12','text')
 if code=='D02':return progress(2)+field('عنوان الإعلان','text','مثال: ناقة وضح أصيلة',True)+select('السلالة',['وضح','مجهم','صفر','أخرى'],True)+'<div class="form-grid">'+select('الجنس',['ذكر','أنثى'],True)+field('العمر · شهر','number','36',True,extra='min="1"')+'</div>'+consent('العمر تقريبي',False)+field('اللون · اختياري','text','وضح')+actions('متابعة','D03')
 if code=='D03':return progress(3)+textarea('الوصف','أهم معلومات الإبل',True)+textarea('الحالة الصحية والعيوب','مثال: لا توجد عيوب معروفة',True)+actions('متابعة','D04')
 if code=='D04':return progress(4)+select('المنطقة',['الرياض','القصيم','مكة المكرمة'],True)+select('المدينة',['الرياض','الدرعية','المزاحمية'],True)+accordion('نقطة تقريبية · اختياري',mapview('150px','نقطة تقريبية')+consent('أوافق على نشر هذه النقطة',False))+actions('متابعة','D05')
 if code=='D05':return progress(4)+field('السعر المطلوب · ريال','number','48,000',True,extra='min="0.01" step="0.01" dir="ltr"')+p('أدخل مبلغًا موجبًا.','meta')+actions('متابعة','D07')
 if code=='D06':return progress(4)+field('مكان المزاد','text','اسم المكان أو العنوان',True)+'<div class="form-grid">'+field('التاريخ','date',required=True)+field('الوقت','time',required=True)+'</div>'+p('بتوقيت السعودية','meta')+mapview('150px','موقع المزاد')+consent('أوافق على نشر موقع انعقاد المزاد')+actions('متابعة','D07')
 if code=='D07':return progress(5)+'<div class="upload-grid">'+''.join(f'<div class="upload-photo"><img src="{PHOTOS[i]}" alt="صورة مرفوعة {i+1}">{badge("غلاف" if i==0 else str(i+1))}</div>' for i in range(3))+'<label class="upload-add">'+icon('plus')+'<span>إضافة صور</span><input type="file" accept="image/*" multiple></label></div>'+p('3–10 صور · حتى 10MB للصورة','meta')+row('إضافة فيديو · اختياري','','60 ثانية · حتى 100MB','camera')+accordion('ترتيب الصور وإعادة الرفع',p('اختر الغلاف أو انقل الصورة.','meta')+btn('إعادة محاولة رفع صورة','D07','outline','refresh'))+actions('متابعة','D08')
 if code=='D08':return progress(6)+field('رقم التواصل','tel','5X XXX XXXX',True,extra='dir="ltr" inputmode="tel"')+p('مستقل عن رقم الدخول.','meta')+'<div class="form-grid">'+consent('اتصال',False).replace('data-consent','data-channel')+consent('واتساب',False).replace('data-consent','data-channel')+'</div>'+consent('أوافق على نشر رقم التواصل في الإعلان')+actions('معاينة الإعلان','D09')
 if code in ['D09','D10']:
  auc=code=='D10'
  return progress(7)+f'<img class="preview-photo" src="{PHOTOS[1 if auc else 0]}" alt="صورة المعاينة">'+badge('مزاد حضوري' if auc else 'سعر محدد')+'<h1>'+('قعود مجهم' if auc else 'ناقة وضح أصيلة')+'</h1>'+('<div class="price">48,000 <small>ريال</small></div>' if not auc else facts([('الموعد','22 نوفمبر 2026 · 4:00 م'),('المكان','سوق الإبل · الرياض')]))+facts([('المدينة','الرياض'),('العمر','36 شهرًا'),('التواصل','اتصال وواتساب')])+accordion('مراجعة باقي البيانات',facts([('السلالة','مجهم' if auc else 'وضح'),('الجنس','ذكر' if auc else 'أنثى'),('الحالة الصحية','لا توجد عيوب معروفة حسب المعلن')]))+consent('أقر بصحة البيانات وأحقيتي في العرض')+actions('إرسال للمراجعة','D11','تعديل البيانات','D02')
 if code=='D11':return empty('أُرسل للمراجعة','سيظهر إعلانك بعد اعتماد الإدارة.','إعلاناتي','E01','check')
 if code=='D12':return sheet('حفظ المسودة؟',p('يمكنك إكمال إعلانك لاحقًا.'),btn('حفظ ومغادرة','E02')+btn('متابعة التحرير','D02','outline')+btn('تجاهل التغييرات','B01','text danger'))
 if code=='E01':return chips(['الكل','منشور','مراجعة','مسودة'])+''.join(f'<div class="owner-ad"><img src="{PHOTOS[i%2]}" alt="إعلان توضيحي"><div><strong>{name}</strong>{badge(status)}<small>{sub}</small></div>{ib("chevron","فتح الإعلان",to)}</div>' for i,(name,status,sub,to) in enumerate([('ناقة وضح','منشور','48,000 ريال','E05'),('قعود مجهم','قيد المراجعة','أُرسل اليوم','E03'),('ناقة وضح','مسودة','آخر حفظ منذ ساعة','E02'),('قعود مجهم','مرفوض','تحتاج الصور للتصحيح','E04')]))+accordion('حالات أخرى',row('مؤرشف ومخفي','E09'))
 if code=='E02':return note('آخر حفظ: اليوم 10:30')+field('عنوان المسودة','text',value='ناقة وضح أصيلة')+actions('إكمال الإعلان','D02','حذف المسودة','D12')
 if code=='E03':return empty('قيد المراجعة','ستصلك نتيجة المراجعة في التنبيهات.','إعلاناتي','E01','clock')+p('لا يمكن تعديل النسخة قيد المراجعة.','meta center')
 if code=='E04':return badge('مرفوض','error')+'<h1>ناقة وضح أصيلة</h1>'+note('الصور غير واضحة. أضف صورًا أوضح.','error')+actions('تصحيح الإعلان','D07','إعلاناتي','E01')
 if code=='E05':return badge('منشور','success')+'<h1>ناقة وضح أصيلة</h1><div class="price">48,000 <small>ريال</small></div>'+facts([('نُشر','16 نوفمبر 2026 · 10:30 ص'),('آخر تجديد','لم يجدد بعد')])+row('عرض الإعلان','C01',ic='eye')+row('تعديل','E07',ic='edit')+row('تجديد الظهور','E06',meta='بعد مرور 24 ساعة',ic='refresh')+row('أرشفة الإعلان','E08',ic='file')
 if code=='E06':return empty('التجديد غير متاح بعد','متاح غدًا 10:30 ص وفق وقت الخدمة.','إعلاناتي','E01','clock')+btn('تعديل المحتوى','E07','text')+accordion('قاعدة التجديد',p('بعد 24 ساعة على الأقل من آخر نشر أو تجديد مستحق.'))
 if code=='E07':return note('عند إرسال التعديل يختفي الإعلان حتى اعتماده.')+field('العنوان','text',required=True,value='ناقة وضح أصيلة')+field('السعر · ريال','number',required=True,value='48000')+accordion('الصور وباقي البيانات',row('تعديل الصور','D07')+row('بيانات الإبل','D02'))+actions('إرسال التعديل للمراجعة','E03','إلغاء','E05')
 if code=='E08':return sheet('أرشفة الإعلان؟',p('سيختفي عن الجمهور، ويبقى في إعلاناتك.'),btn('أرشفة الإعلان','E09')+btn('إلغاء','E05','outline'))
 if code=='E09':return section('مؤرشف',badge('مؤرشف')+p('أوقفته أنت.')+btn('إعادة الإرسال للمراجعة','D02','outline'))+section('مخفي إداريًا',badge('مخفي','error')+p('تحتاج إعادته إلى مراجعة الإدارة.'))
 if code=='F01':return '<div class="searchbar">'+icon('search')+'<input placeholder="ابحث في الرسائل" aria-label="البحث في الرسائل"></div>'+''.join(f'<button class="conversation-row" data-go="F02">{avatar(chr(1633+i))}<span><strong>معلن تجريبي {i+1}</strong><small>{t}</small></span><time>{"الآن" if i==0 else "أمس"}</time>{badge("2") if i==0 else ""}</button>' for i,t in enumerate(['ناقة وضح · هل المعاينة متاحة؟','قعود مجهم · شكرًا لك','ناقة وضح · تم ترتيب الموعد']))
 if code=='F02':return '<div class="chat-context">'+f'<img src="{PHOTOS[0]}" alt="سياق الإعلان">'+'<span>ناقة وضح <small>48,000 ريال</small></span>'+ib('chevron','الإعلان','C01')+'</div><div class="messages"><span class="date-divider">اليوم</span><div class="bubble mine">السلام عليكم، هل المعاينة متاحة؟<small>10:30 · تمت القراءة</small></div><div class="bubble">وعليكم السلام، نعم متاحة.<small>10:32</small></div><div class="bubble mine failed">متى يناسبك؟<small>تعذر الإرسال <button data-retry>إعادة المحاولة</button></small></div></div><div class="composer"><input aria-label="رسالة" placeholder="اكتب رسالة...">'+ib('send','إرسال رسالة')+'</div>'+accordion('خيارات المحادثة',row('كتم التنبيهات','G05',ic='bell')+row('حظر','F04',ic='lock')+row('إبلاغ','F09',ic='shield'))
 if code=='F03':return note('هذه المحادثة للقراءة فقط.')+'<div class="messages"><div class="bubble">هل المعاينة متاحة؟</div><div class="bubble mine">تم الاتفاق على الموعد.</div></div><div class="composer"><input disabled aria-label="محادثة للقراءة فقط" placeholder="الإرسال غير متاح">'+ib('lock','الإرسال غير متاح',extra='disabled')+'</div>'
 if code=='F04':return sheet('حظر المستخدم؟',p('يمنع الرسائل والردود الجديدة بينكما. يبقى السجل والتقييم.'),btn('حظر','F03')+btn('إلغاء','F02','outline'))
 if code=='F05':return '<div class="rating-summary"><strong>4.8</strong><div>'+icon('star')+'<span>12 تقييمًا</span></div></div>'+btn('إضافة تقييم','F06','outline','plus')+'<div class="review"><div class="split"><strong>مستخدم تجريبي</strong><span>5 / 5</span></div><p>تواصل واضح وتعامل جيد.</p><small>تجربة تعامل، لا إثبات شراء.</small>'+row('رد المعلن أو اعتراض','F08')+'</div>'
 if code=='F06':return '<div class="intro"><h1>كيف كانت تجربتك؟</h1></div>'+stars()+textarea('تقييمك','اكتب تجربتك باختصار',True)+consent('أقر أنني تعاملت مع هذا المعلن')+actions('نشر التقييم','F05','الأهلية','F07')
 if code=='F07':return empty('التقييم غير متاح','يتطلب حسابًا فعالًا، هاتفًا مؤكدًا ومحادثة متبادلة.','فتح المحادثة','F02','star')
 if code=='F08':return chips(['رد المعلن','اعتراض'])+textarea('نص الرد','اكتب ردك',True)+btn('إرسال الرد','F05')+accordion('الاعتراض على التقييم',select('السبب',['محتوى مسيء','لا يعكس تجربة تعامل','سبب آخر'])+textarea('التوضيح')+btn('تقديم الاعتراض','F05','outline')+p('الاعتراض لا يخفي التقييم تلقائيًا.','meta'))
 if code=='F09':return select('سبب البلاغ',['معلومات غير صحيحة','محتوى مسيء','احتيال محتمل','سبب آخر'],True)+textarea('التوضيح','صف المشكلة باختصار',True)+p('بياناتك لا تظهر للمبلغ عنه.','meta')+btn('إرسال البلاغ','F10')
 if code=='F10':return badge('قيد المراجعة')+'<h1>بلاغ #1042</h1>'+facts([('النوع','بلاغ عن إعلان'),('أُرسل','16 نوفمبر 2026')])+'<ol class="timeline"><li class="done">تم الاستلام</li><li class="current">قيد المراجعة</li><li>بانتظار القرار</li></ol>'+accordion('بلاغاتي',row('بلاغ #1021','F10',meta='مغلق'))
 if code=='G01':return '<div class="account-head">'+avatar('م','large')+'<div><h1>مستخدم تجريبي</h1><small>الرياض · هاتف مؤكد</small></div>'+ib('edit','تعديل الملف','G02')+'</div><div class="grouped-list">'+''.join(row(t,to,ic=ic) for t,to,ic in [('إعلاناتي','E01','file'),('المتابعات','G03','heart'),('التنبيهات','G04','bell'),('التوثيق','H01','shield'),('بلاغاتي','F10','info'),('المحظورون','G08','lock'),('الإعدادات','G06','settings'),('الشروط والمساعدة','G09','file'),('الخروج وإغلاق الحساب','G10','logout')])+'</div>'
 if code=='G02':return field('الاسم المعروض','text',required=True,value='مستخدم تجريبي')+select('المنطقة',['الرياض','القصيم','مكة'],True)+facts([('رقم الدخول','05*****321'),('الجوال','مؤكد · خاص')])+btn('حفظ التغييرات','G01')
 if code=='G03':return chips(['بحوث محفوظة','معلنون'])+row('ناقة وضح · الرياض','B02',meta='سعر محدد · حتى 60 شهرًا',ic='search',last=ib('close','إلغاء المتابعة'))+row('معلن تجريبي','C06',meta='الرياض',ic='user',last=ib('close','إلغاء متابعة المعلن'))
 if code=='G04':return ''.join(row(t,to,meta=meta,ic=ic) for t,to,meta,ic in [('تم اعتماد إعلانك','E05','منذ ساعة','check'),('إعلان جديد يطابق بحثك','C01','منذ ساعتين','search'),('لديك رسالة جديدة','F01','اليوم','chat'),('تحديث طلب التوثيق','H04','أمس','shield')])+p('تظل التنبيهات هنا عند إيقاف الدفع.','meta')
 if code=='G05':return ''.join(f'<div class="switch-row"><span>{t}</span><button class="switch" role="switch" aria-label="{t}" aria-checked="false"><i></i></button></div>' for t in ['تحديثات إعلاناتي','المتابعات','الرسائل','الردود والتقييمات','التوثيق'])+accordion('صلاحية تنبيهات الجهاز',p('يمكن تفعيل الإذن من إعدادات الجهاز.')+btn('إعدادات التنبيهات','H09','text'))
 if code=='G06':return section('المظهر','<div class="theme-options">'+''.join(f'<button data-theme-choice="{v}" class="theme-choice"><span class="theme-swatch {v}"></span><span>{t}</span></button>' for v,t in [('light','فاتح'),('dark','داكن'),('system','النظام')])+'</div>')+row('إعدادات التنبيهات','G05',ic='bell')+row('أرقام التواصل','G07',ic='phone')+row('المحظورون','G08',ic='lock')+row('الشروط والخصوصية','G09',ic='file')
 if code=='G07':return '<h2>ناقة وضح أصيلة</h2>'+field('رقم التواصل','tel','5X XXX XXXX',True,extra='dir="ltr"')+'<div class="form-grid">'+consent('اتصال',False)+consent('واتساب',False)+'</div>'+consent('أوافق على نشر رقم التواصل')+note('سحب موافقة آخر قناة يوقف الإعلان.')+actions('حفظ','G01','سحب الموافقة','E08')
 if code=='G08':return '<div class="grouped-list">'+row('مستخدم تجريبي','',ic='user',last=btn('إلغاء الحظر','','text',extra='data-unblock'))+'</div>'
 if code=='G09':return accordion('شروط الاستخدام',p('يوضع هنا النص المعتمد للشروط. هذه معاينة تصميم.'))+accordion('سياسة الخصوصية',p('يوضع هنا النص المعتمد للخصوصية والاحتفاظ بالبيانات.'))+section('مساعدة',accordion('متى يظهر إعلاني؟',p('بعد مراجعة الإدارة واعتماده.'))+accordion('هل توجد مزايدة داخل التطبيق؟',p('لا، المزاد حضوري خارج التطبيق.'))+accordion('هل تأكيد الجوال توثيق هوية؟',p('لا، التوثيق خدمة مستقلة واختيارية.')))
 if code=='G10':return section('تسجيل الخروج',p('إنهاء جلسة هذا الجهاز.')+btn('تسجيل الخروج','A01','outline','logout'))+section('إغلاق الحساب',p('تخفى إعلاناتك وتبطل الجلسات. تعالج البيانات وفق السياسة.')+consent('أفهم أثر إغلاق الحساب')+btn('طلب إغلاق الحساب','','danger',extra='data-confirm="طلب إغلاق الحساب"'))
 if code=='H01':return p('اختياري · يختلف عن تأكيد الجوال','meta')+row('توثيق الهوية','H02','عبر مزود معتمد','user')+row('توثيق النشاط','H03','مستندات خاصة','file')+row('متابعة طلباتي','H04',ic='clock')
 if code=='H02':return '<div class="verification-mark">'+icon('shield')+'</div><h1>توثيق الهوية</h1>'+p('إكمال التحقق عبر مزود معتمد عند توفر الخدمة.')+consent('أوافق على مشاركة البيانات اللازمة للتحقق')+btn('بدء التحقق','H04')+accordion('إذا تعذرت الخدمة',p('حاول لاحقًا. لا تمنح الشارة قبل تأكيد النتيجة.'))
 if code=='H03':return field('اسم النشاط','text','اسم النشاط',True)+'<label class="document-upload">'+icon('file')+'<strong>إضافة مستند</strong><small>المستندات خاصة</small><input type="file" required></label>'+consent('أوافق على إرسال المستندات لمراجعة الطلب')+actions('إرسال الطلب','H04','حفظ مسودة','G01')
 if code=='H04':return badge('قيد التحقق')+'<h1>طلب التوثيق</h1>'+p('#1042 · 16 نوفمبر 2026','meta')+'<ol class="timeline"><li class="done">تم تقديم الطلب</li><li class="current">قيد التحقق</li><li>انتظار النتيجة</li></ol>'+p('ستصلك النتيجة في التنبيهات.')+accordion('حالات الطلب',p('مسودة، مقدم، قيد التحقق، معتمد، مرفوض، منتهي أو ملغى. تظهر الأسباب والإجراء المناسب بحسب الحالة.'))+btn('حسابي','G01','outline')
 if code=='H05':return '<div class="skeleton"><i></i><i></i><i></i></div>'+note('تعذر تحميل البيانات.')+btn('إعادة المحاولة','B01','outline','refresh')
 if code=='H06':return empty('أنت غير متصل','أعد الاتصال للمتابعة. لم ترسل التغييرات بعد.','إعادة المحاولة','B01','wifi')+btn('المسودات','E02','text')
 if code=='H07':return empty('لا يوجد شيء هنا بعد','احفظ إعلانًا ليظهر في المفضلة.','تصفح الإعلانات','B01','heart')
 if code=='H08':return empty('الحساب موقوف','النشر والتعديل غير متاحين حاليًا.','المساعدة','G09','lock')
 if code=='H09':return ''.join(row(t,to,meta=meta,ic=ic) for t,to,meta,ic in [('الموقع','B07','يمكن اختيار مركز يدوي','pin'),('الصور','D07','اختر من المعرض أو الكاميرا','image'),('التنبيهات','G05','مركز التنبيهات يعمل دون الإذن','bell')])+p('يمكنك تغيير الأذونات من إعدادات الجهاز.','meta')
 if code=='H10':return section('تم الحفظ',note('حُفظت التغييرات بعد تأكيد الخدمة.','success'))+section('تعذر الحفظ',note('بقيت بياناتك. أعد المحاولة.','error')+btn('إعادة المحاولة','G02','outline','refresh'))+section('جارٍ الحفظ','<div class="saving"><i></i><span>انتظر...</span></div>')
 raise ValueError(code)

MAIN={'B01':'home','B02':'home','B06':'home','B08':'home','B09':'heart','E01':'plus','F01':'chat','G01':'user'}
TITLES={s['id']:s['title'] for s in SCREENS}
def nav(code):
 return '<nav class="bottom-nav" aria-label="التنقل الرئيسي">'+''.join(f'<button data-go="{to}" class="{"active" if MAIN.get(code)==ic else ""}" aria-label="{label}">{icon(ic)}<span>{label}</span></button>' for label,to,ic in [('الرئيسية','B01','home'),('المفضلة','B09','heart'),('أضف إعلان','D01','plus'),('الرسائل','F01','chat'),('حسابي','G01','user')])+'</nav>'
def header(code):
 if code=='A01':return ''
 if code=='B01':return f'<header class="app-header brand"><div class="brand-lockup"><img src="{EMBLEM}" alt="نوادر الإبل"><strong>نوادر الإبل</strong></div>{ib("bell","التنبيهات","G04")}</header>'
 title={'C01':'الإعلان','C02':'مزاد حضوري','C09':'الإعلان','D01':'نوع العرض','D09':'معاينة الإعلان','D10':'معاينة المزاد','E06':'تجديد الظهور','E09':'حالة الإعلان','F03':'المحادثة','F08':'الرد والاعتراض','F10':'بلاغاتي','G07':'أرقام التواصل','G09':'الشروط والمساعدة','G10':'إدارة الحساب','H09':'الأذونات','H10':'حالة الحفظ'}.get(code,TITLES[code])
 return '<header class="app-header">'+ib('arrow','رجوع','B01')+f'<h1>{title}</h1>'+ (ib('more','خيارات','C05') if code=='F02' else '<span class="header-spacer"></span>')+'</header>'

def build():
 css=(ROOT/'ui.css').read_text(encoding='utf8');js=(ROOT/'ui.js').read_text(encoding='utf8')
 (ROOT/'screens').mkdir(exist_ok=True)
 manifest=[]
 for s in SCREENS:
  for theme in ['light','dark']:
   code=s['id'];body=content(code)
   if code=='A01' and theme=='dark':body=body.replace(FULL,EMBLEM).replace('<h1>أهلًا بك</h1>','<h1>نوادر الإبل</h1>')
   # Minimal sticky contact bar only on the ad-detail pages.
   contact='<div class="contact-bar">'+btn('محادثة','F02','', 'chat')+btn('اتصال','C05','contact-compact','phone')+btn('واتساب','C05','contact-compact','chat')+'</div>' if code in ['C01','C02'] else ''
   doc=f'<!doctype html><html lang="ar" dir="rtl" data-theme="{theme}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{code} — {s["title"]}</title><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&display=swap" rel="stylesheet"><style>{css}</style></head><body data-screen="{code}"><div class="app {"has-nav" if code in MAIN else ""} {"has-contact" if contact else ""} {"chat-app" if code in ["F02","F03"] else ""}">{header(code)}<main class="content">{body}</main>{nav(code) if code in MAIN else ""}{contact}</div><dialog id="confirm-dialog"><h2 id="confirm-title">تأكيد الإجراء</h2><p>هذه معاينة تصميم، ولن ينفذ إجراء فعلي.</p><div class="stack"><button class="btn" data-dialog-close>حسنًا</button><button class="btn outline" data-dialog-close>إلغاء</button></div></dialog><script>{js}</script></body></html>'
   file=f'{code}-{theme}.html';(ROOT/'screens'/file).write_text(doc,encoding='utf8');manifest.append({'id':code,'title':s['title'],'theme':theme,'file':file})
 (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps({'screens':len(SCREENS),'html':len(manifest)}))
if __name__=='__main__':build()
