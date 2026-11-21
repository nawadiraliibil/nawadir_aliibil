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
 return f'<article class="ad-card {"small-ad" if small else ""}"><div class="ad-image"><img src="{PHOTOS[photo%len(PHOTOS)]}" alt="صورة إبل توضيحية">{ib("heart","حفظ الإعلان","B09")}{badge("مزاد حضوري","auction") if auction else badge("سعر محدد","fixed")}</div><button type="button" class="ad-copy" data-go="{to}"><strong>{"22 نوفمبر · 4:00 م" if auction else "48,000 <small>ريال</small>"}</strong><span>{"قعود مجهم" if auction else "ناقة وضح أصيلة"}</span><small>{icon("pin")}الرياض · منذ ساعة</small></button></article>'
def grid_ads(n=4):
 return '<div class="ad-grid">'+''.join(summary_ad(i%2==1,i) for i in range(n))+'</div>'
def mapview(height='190px',pin='موقع الإعلان'):
 return f'<div class="map" style="height:{height}" aria-label="خريطة توضيحية"><div class="road r1"></div><div class="road r2"></div><div class="road r3"></div><div class="map-pin">{icon("pin")}<span>{pin}</span></div><small>خريطة توضيحية</small></div>'
def empty(title,desc,action,to,ic='search'):
 return f'<div class="empty"><div class="empty-icon">{icon(ic)}</div><h2>{title}</h2><p>{desc}</p>{btn(action,to)}</div>'
def sheet(title,body,actions):
 return f'<div class="sheet-preview"><div class="sheet-handle"></div><h2>{title}</h2>{body}<div class="stack">{actions}</div></div>'
def progress(n,title='إعلان جديد'):
 return f'<div class="step"><span>{title}</span><span><bdi dir="ltr">{n} / 7</bdi></span></div><div class="progress"><i style="width:{n/7*100}%"></i></div>'
def actions(primary,to,secondary='حفظ مسودة',secondary_to='D12'):
 return '<div class="actions">'+btn(primary,to)+ (btn(secondary,secondary_to,'ghost') if secondary else '')+'</div>'
def avatar(txt='م',size=''):
 return f'<span class="avatar {size}">{txt}</span>'
def stars():
 return '<div class="rating" role="group" aria-label="التقييم من واحد إلى خمسة">'+''.join(f'<button type="button" data-rating="{i}" aria-label="{i} من 5">{icon("star")}</button>' for i in range(1,6))+'<input type="hidden" id="rating-value" required value=""></div>'

# --- ملاحظات واجهات الجوال (MOBILE-GUI-NOTES-20261118) ---
# شاشات حُذفت من المعرض، مع وجهة بديلة لأي زر تنقل كان يشير إليها.
REMOVED={'A01':'B01','B06':'B02','B07':'B02','C03':'C02','C05':'C01','E02':'E01','F03':'F02','F10':'G01','G07':'G06','H01':'G01','H02':'G01','H03':'G01','H04':'G01'}
TITLE_OVERRIDES={'B04':'ترتيب حسب','D08':'رقم التواصل','E07':'تعديل الإعلان','E09':'إعلاناتي — مؤرشف','G06':'الإعدادات','G09':'الشروط والمساعدة','G10':'تسجيل الخروج','H09':'صلاحيات الصور والتنبيهات'}
TERMS_URL='https://example.com/terms';PRIVACY_URL='https://example.com/privacy'
PATHS.update({'external':'M14 4h6v6M20 4l-9 9M18 13v6a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h6','list':'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01'})
STATUS_TABS=['الكل','منشور','قيد المراجعة','مرفوض','مؤرشف','مخفي إداريًا']
def ext(label,url):
 return f'<a class="ext-link" href="{url}" target="_blank" rel="noopener">{label}{icon("external")}</a>'
def ext_row(label,url,ic='file'):
 return f'<a class="list-row" href="{url}" target="_blank" rel="noopener">{icon(ic)}<span class="row-copy"><span>{label}</span><small>يفتح في المتصفح</small></span>{icon("external","muted")}</a>'
def tabs(items):
 head='<div class="tabs" role="tablist">'+''.join(f'<button type="button" role="tab" data-tab="{i}" class="{"active" if i==0 else ""}" aria-selected="{"true" if i==0 else "false"}">{t}</button>' for i,(t,_) in enumerate(items))+'</div>'
 return head+''.join(f'<div class="tab-panel" role="tabpanel" data-panel="{i}" {"" if i==0 else "hidden"}>{b}</div>' for i,(_,b) in enumerate(items))
def view_toggle():
 return '<div class="view-toggle" role="group" aria-label="شكل عرض الإعلانات"><button type="button" data-view="grid" class="active" aria-label="عرض شبكي">'+icon('grid')+'</button><button type="button" data-view="list" aria-label="عرض قائمة">'+icon('list')+'</button></div>'
def consents(*labels):
 return '<div class="consents">'+''.join(f'<label class="check"><input type="checkbox" data-consent required><span>{l}</span></label>' for l in labels)+'</div>'
def owner_ad(i,name,status,kind,sub,to):
 return f'<div class="owner-ad"><img src="{PHOTOS[i%2]}" alt="إعلان توضيحي"><div><strong>{name}</strong>{badge(status,kind)}<small>{sub}</small></div>{ib("chevron","فتح الإعلان",to)}</div>'
def scroll_chips(labels,active=0):
 return chips(labels,active).replace('class="chips"','class="chips scroll"',1)
def detail(code):
 # صفحة تفاصيل الإعلان/المزاد، وتُستخدم نفسها في المعاينة قبل النشر.
 auc=code in ['C02','D10'];preview=code in ['D09','D10'];photo=PHOTOS[1 if auc else 0]
 if preview:top=progress(7)+note('معاينة — هكذا سيظهر إعلانك.')+f'<img class="preview-photo" src="{photo}" alt="صورة المعاينة">'
 else:top=f'<div class="detail-hero"><img src="{photo}" alt="إبل توضيحية">{btn('<bdi dir="ltr">1 / 4</bdi>',"C04","photo-count","image")}</div>'
 head=badge('مزاد حضوري','auction') if auc else badge('سعر محدد','fixed')
 head+='<h1>قعود مجهم</h1>' if auc else '<h1>ناقة وضح أصيلة</h1><div class="price">48,000 <small>ريال</small></div>'
 head+=p(icon('pin')+' الرياض · الرياض · منذ ساعة','location')
 if auc:head+='<div class="info-block">'+facts([('موعد المزاد','22 نوفمبر 2026 · 4:00 م'),('مكان المزاد','سوق الإبل · الرياض')])+p('المزايدة حضورية خارج التطبيق.','meta')+'</div>'
 specs=facts([('السلالة','مجهم' if auc else 'وضح'),('الجنس','ذكر' if auc else 'أنثى'),('العمر','36 شهرًا'),('اللون','مجهم' if auc else 'وضح'),('الحالة الصحية','لا توجد عيوب معروفة حسب المعلن')])
 desc=p('إبل بحالة جيدة، والمعاينة متاحة بعد التواصل مع المعلن.')
 seller='<div class="seller">'+avatar()+'<button data-go="C06" class="seller-copy"><strong>معلن تجريبي</strong><small>الرياض · انضم في 2026</small></button>'+ib('chevron','ملف المعلن','C06')+'</div>'
 if not preview:seller+=row('تقييمات المعلن','F05',meta='4.8 · 12 تقييمًا',ic='star')
 body=top+head+tabs([('التفاصيل',specs),('الوصف',desc),('المعلن',seller)])
 if preview:return body+consents('أقر بصحة البيانات وأحقيتي في العرض')+actions('إرسال للمراجعة','D11','تعديل البيانات','D02')
 return body+row('الأسئلة والردود','C07',meta='3 أسئلة',ic='chat')+btn('مشاركة الإعلان','','outline','share',extra='data-confirm="مشاركة الإعلان"')+btn('الإبلاغ عن الإعلان','F09','text','shield')

def content(code):
 if code=='A02':return p('أدخل جوالك لاستلام رمز التحقق.','meta')+field('رقم الجوال','tel','5X XXX XXXX',True,extra='dir="ltr" inputmode="tel" autocomplete="tel-national"')+p('+966 · السعودية','meta ltr')+actions('إرسال الرمز','A03','إلغاء','B01')
 if code=='A03':return p('أدخل الرمز المكوّن من 6 أرقام المرسل إلى <bdi>05*****321</bdi>','meta')+'<div class="otp" dir="ltr" role="group" aria-label="رمز التحقق">'+''.join(f'<input type="text" inputmode="numeric" maxlength="1" required aria-label="الرقم {i+1} من 6" {"autocomplete=one-time-code" if i==0 else ""}>' for i in range(6))+'</div>'+btn('تأكيد','A04')+'<div class="split">'+btn('تغيير الرقم','A02','text')+btn('إعادة الإرسال','A05','text')+'</div>'
 if code=='A04':return field('الاسم المعروض','text','اسمك في التطبيق',True)+select('المنطقة',['الرياض','القصيم','مكة المكرمة','الشرقية'],True)+consents('أوافق على '+ext('شروط الاستخدام',TERMS_URL),'أوافق على '+ext('سياسة الخصوصية',PRIVACY_URL))+actions('حفظ ومتابعة','B01',secondary='')
 if code=='A05':return empty('تعذر تأكيد الرمز','تحقق من الرمز أو اطلب رمزًا جديدًا.','حاول مجددًا','A03','lock')+row('تغيير رقم الجوال','A02',ic='phone')
 if code=='B01':return '<div class="searchbar">'+icon('search')+'<input type="search" placeholder="ابحث عن الإبل" aria-label="البحث">'+ib('filter','التصفية','B03')+'</div>'+chips(['الكل','سعر محدد','مزاد حضوري'])+section('أحدث الإعلانات',grid_ads(),view_toggle())
 if code=='B02':return '<div class="searchbar">'+icon('search')+'<input value="ناقة وضح" aria-label="البحث">'+ib('close','مسح البحث','B01')+'</div><div class="toolbar compact">'+btn('تصفية · 2','B03','outline','filter')+btn('ترتيب حسب: الأحدث','B04','outline','down')+'</div>'+scroll_chips(['الرياض ×','وضح ×'],-1)+'<div class="split"><small class="muted">12 إعلانًا</small>'+view_toggle()+'</div>'+grid_ads()+btn('متابعة هذا البحث','G03','text','bell')
 if code=='B03':return '<div class="form-grid">'+select('المنطقة',['الرياض','القصيم','مكة'])+select('المدينة',['الرياض','الدرعية','المزاحمية'])+select('السلالة',['وضح','مجهم','صفر','أخرى'])+select('الجنس',['ذكر','أنثى'])+'</div>'+section('نوع العرض',chips(['الكل','سعر محدد','مزاد حضوري']))+section('العمر · بالأشهر','<div class="form-grid">'+field('من','number','0')+field('إلى','number','60')+'</div>')+section('السعر · ريال','<div class="form-grid">'+field('من','number','0')+field('إلى','number','100,000')+'</div>'+p('تحديد السعر يستبعد المزادات.','meta'))+actions('عرض النتائج','B02','مسح الكل','B03')
 if code=='B04':return '<div class="radio-list">'+''.join(f'<label><input type="radio" name="sort" {"checked" if i==0 else ""}><span>{t}</span></label>' for i,t in enumerate(['الأحدث ظهورًا','الأحدث نشرًا','السعر: الأقل أولًا','السعر: الأعلى أولًا','أقرب موعد مزاد']))+'</div>'+btn('تطبيق','B02')
 if code=='B05':return '<div class="searchbar">'+icon('search')+'<input placeholder="ابحث عن منطقة أو مدينة" aria-label="البحث في المواقع"></div>'+section('المنطقة','<div class="radio-list">'+''.join(f'<label><input type="radio" name="region" {"checked" if i==1 else ""}><span>{t}</span></label>' for i,t in enumerate(['كل المناطق','الرياض','مكة المكرمة','القصيم','المنطقة الشرقية']))+'</div>')+section('المدينة · الرياض',chips(['كل المدن','الرياض','الدرعية','المزاحمية','الخرج'],0))+actions('تطبيق','B02','مسح الاختيار','B05')
 if code=='B08':return chips(['الرياض ×','وضح ×'],-1)+empty('لا توجد نتائج','جرّب تقليل المرشحات أو تغيير المنطقة.','تعديل البحث','B03')+btn('مسح المرشحات','B01','text')
 if code=='B09':return section('إعلاناتي المحفوظة',grid_ads(2),view_toggle())
 if code in ['C01','C02','D09','D10']:return detail(code)
 if code=='C04':return f'<div class="media-full"><img id="media-main" src="{PHOTOS[0]}" alt="صورة إبل قابلة للتكبير"><span class="media-count"><bdi dir="ltr">1 / 4</bdi></span></div><div class="photo-strip">'+''.join(f'<button type="button" data-photo="{src}" aria-label="اختيار الصورة {i+1}"><img src="{src}" alt="صورة {i+1}"></button>' for i,src in enumerate(PHOTOS[:3]))+f'<button type="button" class="video-thumb" aria-label="تشغيل الفيديو" data-confirm="تشغيل الفيديو"><img src="{PHOTOS[1]}" alt="فيديو الإعلان">{icon("play")}<small>0:45</small></button></div>'+p('اضغط الصورة للتكبير','meta center')
 if code=='C06':return '<div class="profile-center">'+avatar('م','large')+'<h1>معلن تجريبي</h1><p>الرياض · انضم في 2026</p></div><div class="split">'+btn('متابعة','G03','outline','plus')+btn('4.8 · 12 تقييمًا','F05','text','star')+'</div><div class="toolbar">'+btn('محادثة','F02','','chat')+btn('مشاركة','','outline','share',extra='data-confirm="مشاركة ملف المعلن"')+'</div>'+section('إعلانات المعلن',grid_ads(2))
 if code=='C07':return '<div class="discussion"><div class="discussion-head">'+avatar('س')+'<strong>مستخدم تجريبي</strong><small>منذ ساعة</small>'+ib('more','الإبلاغ عن السؤال','F09')+'</div><p>هل المعاينة متاحة؟</p><div class="reply"><strong>المعلن</strong><p>نعم، تواصل لترتيب الموعد.</p></div><div class="split">'+btn('تعديل سؤالي','C08','text','edit')+btn('حذف','','text danger','trash',extra='data-confirm="حذف سؤالك؟"')+'</div></div>'+btn('إضافة سؤال','C08','outline','plus')
 if code=='C08':return p('سيظهر سؤالك للجميع.','meta')+textarea('سؤالك','اكتب سؤالك عن الإعلان',True)+actions('إرسال السؤال','C07','إلغاء','C07')
 if code=='C09':return empty('الإعلان غير متاح','يمكنك استكشاف إعلانات أخرى.','الرئيسية','B01','image')
 if code=='D01':return progress(1)+'<div class="choice-cards">'+row('سعر محدد','D02','أدخل السعر المطلوب','file').replace('data-go=D02','data-go=D02 data-offer="price"').replace('class="list-row"','class="list-row offer-price"')+row('مزاد حضوري','D02','حدد المكان والموعد','clock').replace('data-go=D02','data-go=D02 data-offer="auction"').replace('class="list-row"','class="list-row offer-auction"')+'</div>'+btn('حفظ مسودة','D12','text')
 if code=='D02':return progress(2)+field('عنوان الإعلان','text','مثال: ناقة وضح أصيلة',True)+select('السلالة',['وضح','مجهم','صفر','أخرى'],True)+'<div class="form-grid">'+select('الجنس',['ذكر','أنثى'],True)+field('العمر · شهر','number','36',True,extra='min="1"')+'</div>'+field('اللون · اختياري','text','وضح')+actions('متابعة','D03')
 if code=='D03':return progress(3)+textarea('الوصف','أهم معلومات الإبل',True)+textarea('الحالة الصحية والعيوب','مثال: لا توجد عيوب معروفة',True)+actions('متابعة','D04')
 if code=='D04':return progress(4)+select('المنطقة',['الرياض','القصيم','مكة المكرمة'],True)+select('المدينة',['الرياض','الدرعية','المزاحمية'],True)+actions('متابعة','D05')
 if code=='D05':return progress(4)+field('السعر المطلوب · ريال','number','48,000',True,extra='min="0.01" step="0.01" dir="ltr"')+p('أدخل مبلغًا موجبًا.','meta')+actions('متابعة','D07')
 if code=='D06':return progress(4)+field('مكان المزاد','text','اسم المكان أو العنوان',True)+'<div class="form-grid">'+field('التاريخ','date',required=True)+field('الوقت','time',required=True)+'</div>'+p('بتوقيت السعودية','meta')+actions('متابعة','D07')
 if code=='D07':return progress(5)+'<div class="upload-grid">'+''.join(f'<div class="upload-photo"><img src="{PHOTOS[i]}" alt="صورة مرفوعة {i+1}">{badge("غلاف") if i==0 else ""}{ib("close","حذف الصورة")}</div>' for i in range(3))+f'<div class="upload-photo video"><img src="{PHOTOS[1]}" alt="فيديو مرفوع">{icon("play")}{ib("close","حذف الفيديو")}</div>'+'<label class="upload-add">'+icon('plus')+'<span>إضافة صور أو فيديو</span><input type="file" accept="image/*,video/*" multiple></label></div>'+p('3–10 صور حتى 10MB للصورة · فيديو واحد حتى 60 ثانية و100MB','meta')+actions('متابعة','D08')
 if code=='D08':return progress(6)+field('رقم الاتصال','tel','5X XXX XXXX',True,extra='dir="ltr" inputmode="tel"')+field('رقم واتساب','tel','5X XXX XXXX',extra='dir="ltr" inputmode="tel"')+p('الرقم الذي تعبئه سيظهر في الإعلان. اترك خانة واتساب فارغة إن لم ترد نشرها.','meta')+actions('معاينة الإعلان','D09')
 if code=='D11':return empty('أُرسل للمراجعة','سيظهر إعلانك بعد اعتماد الإدارة.','إعلاناتي','E01','check')
 if code=='D12':return sheet('حفظ المسودة؟',p('يمكنك إكمال إعلانك لاحقًا.'),btn('حفظ ومغادرة','E01')+btn('متابعة التحرير','D02','outline')+btn('تجاهل التغييرات','B01','text danger'))
 if code=='E01':return scroll_chips(STATUS_TABS)+''.join(owner_ad(i,*a) for i,a in enumerate([('ناقة وضح','منشور','success','48,000 ريال','E05'),('قعود مجهم','قيد المراجعة','pending','أُرسل اليوم','E03'),('قعود مجهم','مرفوض','error','تحتاج الصور للتصحيح','E04'),('ناقة صفراء','مؤرشف','','أوقفته أنت','E09')]))
 if code=='E03':return empty('قيد المراجعة','ستصلك نتيجة المراجعة في التنبيهات.','إعلاناتي','E01','clock')+p('لا يمكن تعديل النسخة قيد المراجعة.','meta center')
 if code=='E04':return badge('مرفوض','error')+'<h1>ناقة وضح أصيلة</h1>'+note('الصور غير واضحة. أضف صورًا أوضح.','error')+actions('تصحيح الإعلان','D07','إعلاناتي','E01')
 if code=='E05':return badge('منشور','success')+'<h1>ناقة وضح أصيلة</h1><div class="price">48,000 <small>ريال</small></div>'+facts([('نُشر','16 نوفمبر 2026 · 10:30 ص'),('آخر تجديد','لم يجدد بعد')])+row('عرض الإعلان','C01',ic='eye')+row('تعديل','E07',ic='edit')+row('تجديد الظهور','E06',meta='بعد مرور 24 ساعة',ic='refresh')+row('أرشفة الإعلان','E08',ic='file')
 if code=='E06':return empty('التجديد غير متاح بعد','متاح غدًا 10:30 ص وفق وقت الخدمة.','إعلاناتي','E01','clock')+p('يتاح التجديد بعد 24 ساعة على الأقل من آخر نشر أو تجديد.','meta center')+btn('تعديل المحتوى','E07','text')
 if code=='E07':return progress(2,'تعديل الإعلان')+note('التعديل يمر بخطوات إضافة الإعلان نفسها، ويُراجع الإعلان مجددًا بعد الإرسال.')+field('عنوان الإعلان','text',required=True,value='ناقة وضح أصيلة')+select('السلالة',['وضح','مجهم','صفر','أخرى'],True)+'<div class="form-grid">'+select('الجنس',['ذكر','أنثى'],True)+field('العمر · شهر','number',required=True,value='36',extra='min="1"')+'</div>'+field('اللون · اختياري','text',value='وضح')+actions('متابعة','D03','إلغاء','E05')
 if code=='E08':return sheet('أرشفة الإعلان؟',p('سيختفي عن الجمهور، ويبقى في إعلاناتك.'),btn('أرشفة الإعلان','E09')+btn('إلغاء','E05','outline'))
 if code=='E09':return scroll_chips(STATUS_TABS,4)+owner_ad(0,'ناقة صفراء','مؤرشف','','أوقفته أنت في 10 نوفمبر 2026','E09')+btn('إعادة الإرسال للمراجعة','D02','outline','refresh')+p('الإعلانات المخفية إداريًا تظهر في تبويب «مخفي إداريًا».','meta center')
 if code=='F01':return '<div class="searchbar">'+icon('search')+'<input placeholder="ابحث في الرسائل" aria-label="البحث في الرسائل"></div>'+''.join(f'<button class="conversation-row" data-go="F02">{avatar(chr(1633+i))}<span><strong>معلن تجريبي {i+1}</strong><small>{t}</small></span><time>{"الآن" if i==0 else "أمس"}</time>{badge("2","fixed") if i==0 else ""}</button>' for i,t in enumerate(['ناقة وضح · هل المعاينة متاحة؟','قعود مجهم · شكرًا لك','ناقة وضح · تم ترتيب الموعد']))
 if code=='F02':return '<div class="chat-context">'+f'<img src="{PHOTOS[0]}" alt="سياق الإعلان">'+'<span>ناقة وضح <small>48,000 ريال</small></span>'+ib('chevron','الإعلان','C01')+'</div><div class="messages"><span class="date-divider">اليوم</span><div class="bubble mine">السلام عليكم، هل المعاينة متاحة؟<small>10:30 · تمت القراءة</small></div><div class="bubble">وعليكم السلام، نعم متاحة.<small>10:32</small></div><div class="bubble mine failed">متى يناسبك؟<small>تعذر الإرسال <button data-retry>إعادة المحاولة</button></small></div></div><div class="composer"><input aria-label="رسالة" placeholder="اكتب رسالة...">'+ib('send','إرسال رسالة')+'</div>'
 if code=='F04':return sheet('حظر المستخدم؟',p('يمنع الرسائل والردود الجديدة بينكما. يبقى السجل والتقييم.'),btn('حظر','F01')+btn('إلغاء','F02','outline'))
 if code=='F05':return '<div class="rating-summary"><strong>4.8</strong><div>'+icon('star')+'<span>12 تقييمًا</span></div></div>'+btn('إضافة تقييم','F06','outline','plus')+'<div class="review"><div class="split"><strong>مستخدم تجريبي</strong><span>5 / 5</span></div><p>تواصل واضح وتعامل جيد.</p><small>تجربة تعامل، لا إثبات شراء.</small>'+row('رد المعلن أو اعتراض','F08')+'</div>'
 if code=='F06':return '<div class="intro"><h1>كيف كانت تجربتك؟</h1></div>'+stars()+textarea('تقييمك','اكتب تجربتك باختصار',True)+consents('أقر أنني تعاملت مع هذا المعلن')+actions('نشر التقييم','F05','الأهلية','F07')
 if code=='F07':return empty('التقييم غير متاح','يتطلب حسابًا فعالًا، هاتفًا مؤكدًا ومحادثة متبادلة.','فتح المحادثة','F02','star')
 if code=='F08':return tabs([('رد المعلن',textarea('نص الرد','اكتب ردك',True)+btn('إرسال الرد','F05')),('اعتراض',select('السبب',['محتوى مسيء','لا يعكس تجربة تعامل','سبب آخر'])+textarea('التوضيح')+btn('تقديم الاعتراض','F05','outline')+p('الاعتراض لا يخفي التقييم تلقائيًا.','meta'))])
 if code=='F09':return select('سبب البلاغ',['معلومات غير صحيحة','محتوى مسيء','احتيال محتمل','سبب آخر'],True)+textarea('التوضيح','صف المشكلة باختصار',True)+p('يُرسل البلاغ إلى إدارة التطبيق للمراجعة، وبياناتك لا تظهر للمبلغ عنه.','meta')+btn('إرسال البلاغ','C01')
 if code=='G01':return '<div class="account-head">'+avatar('م','large')+'<div><h1>مستخدم تجريبي</h1><small>الرياض · <bdi dir="ltr">05*****321</bdi></small></div>'+ib('edit','تعديل الملف','G02')+'</div><div class="grouped-list">'+''.join(row(t,to,ic=ic) for t,to,ic in [('إعلاناتي','E01','file'),('المتابعات والبحث المحفوظ','G03','heart'),('التنبيهات','G04','bell'),('المحظورون','G08','lock'),('الشروط والمساعدة','G09','info'),('الإعدادات','G06','settings')])+'</div>'+btn('تسجيل الخروج','G10','text danger','logout')
 if code=='G02':return field('الاسم المعروض','text',required=True,value='مستخدم تجريبي')+select('المنطقة',['الرياض','القصيم','مكة'],True)+facts([('رقم الدخول','05*****321'),('الجوال','مؤكد · خاص')])+btn('حفظ التغييرات','G01')
 if code=='G03':return chips(['بحوث محفوظة','معلنون'])+row('ناقة وضح · الرياض','B02',meta='سعر محدد · حتى 60 شهرًا',ic='search',last=ib('close','إلغاء المتابعة'))+row('معلن تجريبي','C06',meta='الرياض',ic='user',last=ib('close','إلغاء متابعة المعلن'))
 if code=='G04':return ''.join(row(t,to,meta=meta,ic=ic) for t,to,meta,ic in [('تم اعتماد إعلانك','E05','منذ ساعة','check'),('إعلان جديد يطابق بحثك','C01','منذ ساعتين','search'),('لديك رسالة جديدة','F01','اليوم','chat')])
 if code=='G05':return ''.join(f'<div class="switch-row"><span>{t}</span><button class="switch" role="switch" aria-label="{t}" aria-checked="false"><i></i></button></div>' for t in ['تحديثات إعلاناتي','المتابعات','الرسائل','الردود والتقييمات'])
 if code=='G06':return section('المظهر','<div class="theme-options">'+''.join(f'<button data-theme-choice="{v}" class="theme-choice"><span class="theme-swatch {v}"></span><span>{t}</span></button>' for v,t in [('light','فاتح'),('dark','داكن'),('system','النظام')])+'</div>')+section('التنبيهات','<div class="grouped-list">'+row('إعدادات التنبيهات','G05',ic='bell')+'</div>')
 if code=='G08':return '<div class="grouped-list">'+row('مستخدم تجريبي','',ic='user',last=btn('إلغاء الحظر','','text',extra='data-unblock'))+'</div>'
 if code=='G09':return section('الشروط والخصوصية','<div class="grouped-list">'+ext_row('شروط الاستخدام',TERMS_URL)+ext_row('سياسة الخصوصية',PRIVACY_URL,'lock')+'</div>')+section('مساعدة',''.join(f'<div class="qa"><h3>{q}</h3><p>{a}</p></div>' for q,a in [('متى يظهر إعلاني؟','بعد مراجعة الإدارة واعتماده.'),('هل توجد مزايدة داخل التطبيق؟','لا، المزاد حضوري خارج التطبيق.'),('كيف أتواصل مع المعلن؟','من صفحة الإعلان: اتصال أو واتساب أو محادثة.')]))
 if code=='G10':return sheet('تسجيل الخروج؟',p('ستنتهي جلسة هذا الجهاز، ويمكنك الدخول مجددًا برقم الجوال.'),btn('تسجيل الخروج','B01','','logout')+btn('إلغاء','G01','outline'))
 if code=='H05':return '<div class="skeleton"><i></i><i></i><i></i></div>'+note('تعذر تحميل البيانات.')+btn('إعادة المحاولة','B01','outline','refresh')
 if code=='H06':return empty('أنت غير متصل','أعد الاتصال للمتابعة. لم ترسل التغييرات بعد.','إعادة المحاولة','B01','wifi')
 if code=='H07':return empty('لا يوجد شيء هنا بعد','احفظ إعلانًا ليظهر في المفضلة.','تصفح الإعلانات','B01','heart')
 if code=='H08':return empty('الحساب موقوف','النشر والتعديل غير متاحين حاليًا.','المساعدة','G09','lock')
 if code=='H09':return ''.join(row(t,to,meta=meta,ic=ic) for t,to,meta,ic in [('الصور','D07','تُطلب عند إضافة صور الإعلان','image'),('التنبيهات','G05','تُطلب عند تفعيل أول تنبيه','bell')])+p('يمكنك تغيير الأذونات من إعدادات الجهاز.','meta')
 if code=='H10':return section('تم الحفظ',note('حُفظت التغييرات بعد تأكيد الخدمة.','success'))+section('تعذر الحفظ',note('بقيت بياناتك. أعد المحاولة.','error')+btn('إعادة المحاولة','G02','outline','refresh'))+section('جارٍ الحفظ','<div class="saving"><i></i><span>انتظر...</span></div>')
 raise ValueError(code)

MAIN={'B01':'home','B02':'home','B08':'home','B09':'heart','E01':'plus','E09':'plus','F01':'chat','G01':'user'}
SCREENS=[s for s in SCREENS if s['id'] not in REMOVED]
TITLES={s['id']:TITLE_OVERRIDES.get(s['id'],s['title']) for s in SCREENS}
def nav(code):
 return '<nav class="bottom-nav" aria-label="التنقل الرئيسي">'+''.join(f'<button data-go="{to}" class="{"active" if MAIN.get(code)==ic else ""}" aria-label="{label}">{icon(ic)}<span>{label}</span></button>' for label,to,ic in [('الرئيسية','B01','home'),('المفضلة','B09','heart'),('أضف إعلان','D01','plus'),('الرسائل','F01','chat'),('حسابي','G01','user')])+'</nav>'
def header(code):
 if code=='B01':return f'<header class="app-header brand"><div class="brand-lockup"><img src="{EMBLEM}" alt="نوادر الإبل"><strong>نوادر الإبل</strong></div>{ib("bell","التنبيهات","G04")}</header>'
 title={'C01':'الإعلان','C02':'مزاد حضوري','C09':'الإعلان','D01':'نوع العرض','D09':'معاينة الإعلان','D10':'معاينة المزاد','E06':'تجديد الظهور','E09':'إعلاناتي','F08':'الرد والاعتراض','H09':'الأذونات','H10':'حالة الحفظ'}.get(code,TITLES[code])
 end='<span class="header-spacer"></span>'
 if code in ['C01','C02']:end=ib('heart','حفظ الإعلان','B09')+ib('share','مشاركة الإعلان',extra='data-confirm="مشاركة الإعلان"')
 # خيارات المحادثة كلها في قائمة النقاط الثلاث أعلى الشاشة.
 if code=='F02':end=ib('more','خيارات المحادثة',extra='data-menu="chat-menu" aria-haspopup="true" aria-expanded="false"')
 menu='<div class="menu" id="chat-menu" hidden>'+row('عرض الإعلان','C01',ic='eye')+row('ملف المعلن','C06',ic='user')+row('كتم التنبيهات','G05',ic='bell')+row('حظر المستخدم','F04',ic='lock').replace('class="list-row"','class="list-row danger-text"')+row('إبلاغ','F09',ic='shield').replace('class="list-row"','class="list-row danger-text"')+'</div>' if code=='F02' else ''
 return '<header class="app-header">'+ib('arrow','رجوع','B01')+f'<h1>{title}</h1>'+end+'</header>'+menu

def build():
 css=(ROOT/'ui.css').read_text(encoding='utf8');js=(ROOT/'ui.js').read_text(encoding='utf8')
 (ROOT/'screens').mkdir(exist_ok=True)
 for old in list((ROOT/'screens').glob('*.html'))+list((ROOT/'previews').glob('*.png')):
  if old.name[:3] in REMOVED:old.unlink()
 regone=re.compile(r'data-go="?('+'|'.join(REMOVED)+r')"?')
 manifest=[]
 for s in SCREENS:
  for theme in ['light','dark']:
   code=s['id'];title=TITLES[code];body=content(code)
   # شريط التواصل الثابت في صفحات التفاصيل: تُوزَّع عليه ميزات صفحة «خيارات التواصل» المحذوفة.
   contact='<div class="contact-bar">'+btn('محادثة','F02','', 'chat')+btn('اتصال','','contact-compact call','phone',extra='data-confirm="الاتصال بالمعلن"')+btn('واتساب','','contact-compact wa','chat',extra='data-confirm="فتح واتساب"')+'</div>' if code in ['C01','C02'] else ''
   doc=f'<!doctype html><html lang="ar" dir="rtl" data-theme="{theme}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{code} — {title}</title><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&display=swap" rel="stylesheet"><style>{css}</style></head><body data-screen="{code}"><div class="app {"has-nav" if code in MAIN else ""} {"has-contact" if contact else ""} {"chat-app" if code=="F02" else ""}">{header(code)}<main class="content">{body}</main>{nav(code) if code in MAIN else ""}{contact}</div><dialog id="confirm-dialog"><h2 id="confirm-title">تأكيد الإجراء</h2><p>هذه معاينة تصميم، ولن ينفذ إجراء فعلي.</p><div class="stack"><button class="btn" data-dialog-close>حسنًا</button><button class="btn outline" data-dialog-close>إلغاء</button></div></dialog><script>{js}</script></body></html>'
   doc=regone.sub(lambda m:'data-go='+REMOVED[m.group(1)],doc)
   file=f'{code}-{theme}.html';(ROOT/'screens'/file).write_text(doc,encoding='utf8');manifest.append({'id':code,'title':title,'theme':theme,'file':file})
 (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
 # قائمة الشاشات مضمّنة في المعرض؛ تُحدَّث مع كل بناء.
 index=ROOT/'index.html';page=index.read_text(encoding='utf8')
 page=re.sub(r'const screens=\[.*?\];let current;',lambda m:'const screens='+json.dumps(manifest,ensure_ascii=False)+';let current;',page,count=1,flags=re.S)
 index.write_text(page,encoding='utf8')
 print(json.dumps({'screens':len(SCREENS),'html':len(manifest)}))
if __name__=='__main__':build()
