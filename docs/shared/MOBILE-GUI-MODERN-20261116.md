# نوادر الإبل — إعادة تصميم الجوال بأسلوب عصري

- المهمة: MOBILE-GUI-MODERN-20261116؛ الجانب والمالك: MOBILE / Codex.
- بدأ العمل في 2026-11-16؛ التسليم والتحديث في 2026-11-17 — Asia/Riyadh.
- الحالة: حزمة التصميم والمعرض مكتملان؛ انتهى التحقق من حفظ الشاشات الـ74 في Stitch بتاريخ 2026-11-17، 10:51 — Asia/Riyadh.
- [مشروع Stitch الجديد](https://stitch.withgoogle.com/projects/6310763871032341644) · [المعاينة الفاتحة والداكنة](./stitch-modern-20261116/index.html).
- [المتطلبات](../../Nawader_AlIbil_SRS_Ads_AR.md) · [التقدم](./PROGRESS.md) · [القرارات](./DECISIONS.md) · [التكامل](./INTEGRATION.md).

## ما تغير

أعيد تشكيل تعريفات الشاشات الـ74 السابقة في نسخة مستقلة: نص أساسي 14px، حقول وأزرار 14px، تسميات 12px، معلومات ثانوية 11–12px، عناوين رئيسية 20–22px وشريط علوي 16px. بقيت أزرار الإجراء والحقول عادة بارتفاع 44px، حتى لا يتحول تصغير الخط إلى أهداف لمس صغيرة. بعض عناصر الاختيار والأيقونات الثانوية أصغر؛ لم ينفذ تدقيق شامل لكل هدف لمس.

الرئيسية شبكة صور من عمودين مع السعر أو موعد المزاد والعنوان والمدينة فقط. أزرار الإجراء بنية هادئة في الفاتح وذهبية في الداكن، والذهبي للتأكيدات الصغيرة. أزيلت الفقرات التسويقية والمربعات الإرشادية المتكررة، ونقلت المعلومات الثانوية إلى أقسام قابلة للفتح. لم تلغ الحقول المطلوبة أو الموافقات أو حالات الإعلان الأساسية.

استُخدم IBM Plex Sans Arabic واتجاه RTL، مع أرقام الجوال والرمز في LTR. احتفظ بالهوية الأساسية والشعار الكامل والأيقونة الأصلية، دون إعادة رسمهما. أضيف لون ثانوي أغمق #76695C للنص الصغير، مع توثيق قيمة الدليل #817568. القواعد والقيم في [DESIGN.md](./stitch-modern-20261116/DESIGN.md).

## المخرجات

- 74 تعريف شاشة وحالة، و148 ملف HTML ومعاينة PNG بالمظهرين في المعرض المحلي.
- 74 شاشة فاتحة جاهزة ظاهرة في Stitch، مرتبة في ثماني مجموعات. أعيد إنشاء خمس شاشات حساب لم يحفظها التوليد الأول بصورة سليمة؛ بقيت مسوداتها الخمس مخفية، دون حذفها. العدد الخام 79 سجل تصميم، إضافة إلى مستند الهوية، ولا تمثل المسودات شاشات إضافية في التغطية.
- المظهر الداكن نسخة محلية تكيّف نفس التصميم؛ لا تعني 148 إطارًا مستقلًا في Stitch.
- ملفات HTML ذات CSS وJavaScript مضمنين، مع مصادر مشتركة قابلة للتعديل في [ui.css](./stitch-modern-20261116/ui.css) و[ui.js](./stitch-modern-20261116/ui.js).
- [build_previews.py](./stitch-modern-20261116/build_previews.py) يعيد بناء HTML بالمكتبة القياسية لـPython من نفس المجلد، دون اعتماد على ملفات Temp أو حزمة التصميم القديمة. تجديد PNG يحتاج متصفحًا وأداة التقاط؛ الصور المرفقة موجودة بالفعل.
- المعرض يدعم البحث بالمعرف أو الاسم، تبديل المظهر، عرض جميع الصور وأحجام 360/390/430px.

## التغطية

| المجموعة | المعرفات | العدد | المتطلبات |
|---|---|---:|---|
| A — البداية والدخول | A01–A05 | 5 | AD-FR-001–004 |
| B — الاستكشاف والبحث | B01–B09 | 9 | AD-FR-011–013, 022, 025, 028 |
| C — الإعلان والمعلن | C01–C09 | 9 | AD-FR-013–015, 023–025, 029, 032 |
| D — نشر إعلان | D01–D12 | 12 | AD-FR-005–010, 014, 025, 028 |
| E — إدارة الإعلانات | E01–E09 | 9 | AD-FR-005, 008–010, 030 |
| F — التواصل والتقييم والبلاغ | F01–F10 | 10 | AD-FR-015, 029, 031–033 |
| G — الحساب والمتابعة والتنبيهات | G01–G10 | 10 | AD-FR-003–004, 016, 026–027, 033 |
| H — التوثيق والحالات العامة | H01–H10 | 10 | AD-FR-034, AD-NFR-001, 005, 009 |

كل تعريف قد يجمع حالات فرعية مرتبطة. ليس لكل تباين في البيانات إطار مستقل. بيانات الإعلانات والتواريخ والخرائط أمثلة تصميم ثابتة، وليست بيانات أو مواعيد حية.

## الفحوص المنفذة

- 148 عرضًا عند 390px بالمظهرين: لا تجاوز أفقي، ولا صور مفقودة، ولا موافقات محددة مسبقًا، ولا أزرار ظاهرة بلا تسمية في الفحص البرمجي. الحجم الأساسي المقاس 14px.
- 44 حالة عرض إضافية عند 360 و430px، لـ11 تعريفًا بالمظهرين: لا تجاوز أفقي أو صور مفقودة.
- 11 فحص تفاعل نجحت: موافقات الملف الشخصي، حفظ فرع المزاد عبر الموقع والمعاينة، عدم إتاحة التواصل دون قناة وموافقة، التقييم بعد الدرجة والإقرار، تغيير المظهر وتبديل صورة المعرض. المعرض يعرض 74 اختيارًا في الفاتح.
- فحص JavaScript بصيغة node --check نجح، وتشغيل مولد HTML المحمول نجح وأنتج 148 ملفًا.
- مراجعة بصرية فعلية للرئيسية والتفاصيل والمحادثة الداكنة والإعدادات المحفوظة في Stitch؛ لا ادعاء مراجعة تفصيلية لكل الشاشات أو اختبار مع المستخدمين.
- نجاح تحديث HTML وPNG لجميع الشاشات الـ74، وقراءة المشروع بعد ترتيبه: 74 إطارًا ظاهرًا وثماني مجموعات وخمس مسودات مخفية. قراءة HTML لثماني شاشات من Stitch طابقت النسخ المحلية، بما فيها شاشتا حساب أعيد إنشاؤهما؛ وقرئت صورة الإعدادات من Stitch بأبعاد 390×844.

الأدلة: [render-checks.json](./stitch-modern-20261116/render-checks.json) و[qa-checks.json](./stitch-modern-20261116/qa-checks.json) و[سجل الرفع](./stitch-modern-20261116/upload-ledger.json).

جرد الإطارات المعتمدة في [screen-inventory.json](./stitch-modern-20261116/screen-inventory.json)، وترتيب اللوحة في [canvas-layout.json](./stitch-modern-20261116/canvas-layout.json)، ونتيجة القراءة من الخدمة في [stitch-readback-checks.json](./stitch-modern-20261116/stitch-readback-checks.json). قرار التنفيذ TEAM-DEC-005؛ المشروع السابق وحزمته محفوظان دون تعديل.

أجريت أيضًا قراءة شاملة لـHTML الشاشات الـ74 من Stitch ومقارنة طول المحتوى وبصمته بعد توحيد نهايات الأسطر: 74/74 مطابقة للملفات المحلية. عولجت النسخ القديمة والروابط غير المتاحة بإعادة رفع الملفات المتأثرة ثم إعادة قراءتها. النتيجة النهائية في [full-html-readback-checks.json](./stitch-modern-20261116/full-html-readback-checks.json). تحقق وجود ملفات HTML والصور الـ148 وروابط التقرير المحلية دون ملفات مفقودة؛ نجح git diff --check للسجلات المشتركة.

## حدود التصميم والربط

هذه حزمة تصميم ومعاينة، وليست تطبيق Flutter أو خدمات منشورة. الأزرار التفاعلية توضح التنقل وبعض شروط الواجهة؛ لا ترسل OTP أو رسالة أو مستندًا، ولا تنشر إعلانًا أو توثق حسابًا أو تنفذ إغلاقًا فعليًا. التحقق النهائي والصلاحيات والأهلية والتكرار في الخدمة عند التنفيذ. تبقى احتياجات [INT-002](./INTEGRATION.md) مفتوحة؛ لم يتغير عقد API أو ملف خلفية أو واجهة ADMIN أو شيفرة الجوال.

التوثيق اختياري ولا يفترض مزودًا معينًا، ولا يساوي تأكيد الهاتف. المزاد حضوري دون مزايدة أو دفع داخل التطبيق. النص القانوني موضع مخصص ينتظر الاعتماد. بعض الخطوط وصور الإبل تحتاج الإنترنت في HTML التفاعلي؛ PNG المحلية للمعاينة محفوظة.

لم ينفذ اختبار Flutter أو iOS/Android، أو خدمات SMS/FCM/الخرائط/التوثيق، أو تكبير النص 200% وقارئ الشاشة واختبار الاستخدام مع الفئة المستهدفة. لا اعتماد WCAG شامل من الفحوص الحالية.

## قائمة الشاشات

| المعرف | الشاشة | المعاينة |
|---|---|---|
| A01 | مرحبًا بك | [فاتح](./stitch-modern-20261116/index.html#A01-light) · [داكن](./stitch-modern-20261116/index.html#A01-dark) |
| A02 | رقم الجوال | [فاتح](./stitch-modern-20261116/index.html#A02-light) · [داكن](./stitch-modern-20261116/index.html#A02-dark) |
| A03 | رمز التحقق | [فاتح](./stitch-modern-20261116/index.html#A03-light) · [داكن](./stitch-modern-20261116/index.html#A03-dark) |
| A04 | إكمال الحساب | [فاتح](./stitch-modern-20261116/index.html#A04-light) · [داكن](./stitch-modern-20261116/index.html#A04-dark) |
| A05 | تعذر التحقق | [فاتح](./stitch-modern-20261116/index.html#A05-light) · [داكن](./stitch-modern-20261116/index.html#A05-dark) |
| B01 | الرئيسية | [فاتح](./stitch-modern-20261116/index.html#B01-light) · [داكن](./stitch-modern-20261116/index.html#B01-dark) |
| B02 | نتائج البحث | [فاتح](./stitch-modern-20261116/index.html#B02-light) · [داكن](./stitch-modern-20261116/index.html#B02-dark) |
| B03 | تصفية الإعلانات | [فاتح](./stitch-modern-20261116/index.html#B03-light) · [داكن](./stitch-modern-20261116/index.html#B03-dark) |
| B04 | ترتيب النتائج | [فاتح](./stitch-modern-20261116/index.html#B04-light) · [داكن](./stitch-modern-20261116/index.html#B04-dark) |
| B05 | اختيار المنطقة والمدينة | [فاتح](./stitch-modern-20261116/index.html#B05-light) · [داكن](./stitch-modern-20261116/index.html#B05-dark) |
| B06 | الخريطة والقريب | [فاتح](./stitch-modern-20261116/index.html#B06-light) · [داكن](./stitch-modern-20261116/index.html#B06-dark) |
| B07 | تحديد مركز البحث | [فاتح](./stitch-modern-20261116/index.html#B07-light) · [داكن](./stitch-modern-20261116/index.html#B07-dark) |
| B08 | لا توجد نتائج | [فاتح](./stitch-modern-20261116/index.html#B08-light) · [داكن](./stitch-modern-20261116/index.html#B08-dark) |
| B09 | المفضلة | [فاتح](./stitch-modern-20261116/index.html#B09-light) · [داكن](./stitch-modern-20261116/index.html#B09-dark) |
| C01 | تفاصيل إعلان بسعر محدد | [فاتح](./stitch-modern-20261116/index.html#C01-light) · [داكن](./stitch-modern-20261116/index.html#C01-dark) |
| C02 | تفاصيل مزاد حضوري | [فاتح](./stitch-modern-20261116/index.html#C02-light) · [داكن](./stitch-modern-20261116/index.html#C02-dark) |
| C03 | مضى موعد المزاد | [فاتح](./stitch-modern-20261116/index.html#C03-light) · [داكن](./stitch-modern-20261116/index.html#C03-dark) |
| C04 | صور وفيديو الإعلان | [فاتح](./stitch-modern-20261116/index.html#C04-light) · [داكن](./stitch-modern-20261116/index.html#C04-dark) |
| C05 | خيارات التواصل والمشاركة | [فاتح](./stitch-modern-20261116/index.html#C05-light) · [داكن](./stitch-modern-20261116/index.html#C05-dark) |
| C06 | ملف المعلن | [فاتح](./stitch-modern-20261116/index.html#C06-light) · [داكن](./stitch-modern-20261116/index.html#C06-dark) |
| C07 | أسئلة الإعلان | [فاتح](./stitch-modern-20261116/index.html#C07-light) · [داكن](./stitch-modern-20261116/index.html#C07-dark) |
| C08 | إضافة سؤال أو تعديله | [فاتح](./stitch-modern-20261116/index.html#C08-light) · [داكن](./stitch-modern-20261116/index.html#C08-dark) |
| C09 | الإعلان غير متاح | [فاتح](./stitch-modern-20261116/index.html#C09-light) · [داكن](./stitch-modern-20261116/index.html#C09-dark) |
| D01 | أضف إعلان — نوع العرض | [فاتح](./stitch-modern-20261116/index.html#D01-light) · [داكن](./stitch-modern-20261116/index.html#D01-dark) |
| D02 | بيانات الإبل | [فاتح](./stitch-modern-20261116/index.html#D02-light) · [داكن](./stitch-modern-20261116/index.html#D02-dark) |
| D03 | الوصف والحالة الصحية | [فاتح](./stitch-modern-20261116/index.html#D03-light) · [داكن](./stitch-modern-20261116/index.html#D03-dark) |
| D04 | موقع الإعلان | [فاتح](./stitch-modern-20261116/index.html#D04-light) · [داكن](./stitch-modern-20261116/index.html#D04-dark) |
| D05 | السعر المطلوب | [فاتح](./stitch-modern-20261116/index.html#D05-light) · [داكن](./stitch-modern-20261116/index.html#D05-dark) |
| D06 | موعد ومكان المزاد | [فاتح](./stitch-modern-20261116/index.html#D06-light) · [داكن](./stitch-modern-20261116/index.html#D06-dark) |
| D07 | صور الإعلان والفيديو | [فاتح](./stitch-modern-20261116/index.html#D07-light) · [داكن](./stitch-modern-20261116/index.html#D07-dark) |
| D08 | رقم التواصل والموافقة | [فاتح](./stitch-modern-20261116/index.html#D08-light) · [داكن](./stitch-modern-20261116/index.html#D08-dark) |
| D09 | معاينة إعلان بسعر محدد | [فاتح](./stitch-modern-20261116/index.html#D09-light) · [داكن](./stitch-modern-20261116/index.html#D09-dark) |
| D10 | معاينة إعلان مزاد حضوري | [فاتح](./stitch-modern-20261116/index.html#D10-light) · [داكن](./stitch-modern-20261116/index.html#D10-dark) |
| D11 | تم إرسال الإعلان للمراجعة | [فاتح](./stitch-modern-20261116/index.html#D11-light) · [داكن](./stitch-modern-20261116/index.html#D11-dark) |
| D12 | مغادرة وحفظ المسودة | [فاتح](./stitch-modern-20261116/index.html#D12-light) · [داكن](./stitch-modern-20261116/index.html#D12-dark) |
| E01 | إعلاناتي | [فاتح](./stitch-modern-20261116/index.html#E01-light) · [داكن](./stitch-modern-20261116/index.html#E01-dark) |
| E02 | مسودة محفوظة | [فاتح](./stitch-modern-20261116/index.html#E02-light) · [داكن](./stitch-modern-20261116/index.html#E02-dark) |
| E03 | إعلان قيد المراجعة | [فاتح](./stitch-modern-20261116/index.html#E03-light) · [داكن](./stitch-modern-20261116/index.html#E03-dark) |
| E04 | إعلان مرفوض | [فاتح](./stitch-modern-20261116/index.html#E04-light) · [داكن](./stitch-modern-20261116/index.html#E04-dark) |
| E05 | إعلان منشور | [فاتح](./stitch-modern-20261116/index.html#E05-light) · [داكن](./stitch-modern-20261116/index.html#E05-dark) |
| E06 | تجديد الظهور غير متاح بعد | [فاتح](./stitch-modern-20261116/index.html#E06-light) · [داكن](./stitch-modern-20261116/index.html#E06-dark) |
| E07 | تعديل إعلان منشور | [فاتح](./stitch-modern-20261116/index.html#E07-light) · [داكن](./stitch-modern-20261116/index.html#E07-dark) |
| E08 | إيقاف الإعلان وأرشفته | [فاتح](./stitch-modern-20261116/index.html#E08-light) · [داكن](./stitch-modern-20261116/index.html#E08-dark) |
| E09 | مؤرشف أو مخفي إداريًا | [فاتح](./stitch-modern-20261116/index.html#E09-light) · [داكن](./stitch-modern-20261116/index.html#E09-dark) |
| F01 | الرسائل | [فاتح](./stitch-modern-20261116/index.html#F01-light) · [داكن](./stitch-modern-20261116/index.html#F01-dark) |
| F02 | المحادثة | [فاتح](./stitch-modern-20261116/index.html#F02-light) · [داكن](./stitch-modern-20261116/index.html#F02-dark) |
| F03 | محادثة للقراءة فقط | [فاتح](./stitch-modern-20261116/index.html#F03-light) · [داكن](./stitch-modern-20261116/index.html#F03-dark) |
| F04 | حظر المستخدم | [فاتح](./stitch-modern-20261116/index.html#F04-light) · [داكن](./stitch-modern-20261116/index.html#F04-dark) |
| F05 | تقييمات المعلن | [فاتح](./stitch-modern-20261116/index.html#F05-light) · [داكن](./stitch-modern-20261116/index.html#F05-dark) |
| F06 | إضافة أو تعديل تقييم | [فاتح](./stitch-modern-20261116/index.html#F06-light) · [داكن](./stitch-modern-20261116/index.html#F06-dark) |
| F07 | التقييم غير متاح الآن | [فاتح](./stitch-modern-20261116/index.html#F07-light) · [داكن](./stitch-modern-20261116/index.html#F07-dark) |
| F08 | رد المعلن واعتراض على تقييم | [فاتح](./stitch-modern-20261116/index.html#F08-light) · [داكن](./stitch-modern-20261116/index.html#F08-dark) |
| F09 | الإبلاغ عن محتوى | [فاتح](./stitch-modern-20261116/index.html#F09-light) · [داكن](./stitch-modern-20261116/index.html#F09-dark) |
| F10 | بلاغاتي وتفاصيل البلاغ | [فاتح](./stitch-modern-20261116/index.html#F10-light) · [داكن](./stitch-modern-20261116/index.html#F10-dark) |
| G01 | حسابي | [فاتح](./stitch-modern-20261116/index.html#G01-light) · [داكن](./stitch-modern-20261116/index.html#G01-dark) |
| G02 | تعديل الملف الشخصي | [فاتح](./stitch-modern-20261116/index.html#G02-light) · [داكن](./stitch-modern-20261116/index.html#G02-dark) |
| G03 | المتابعات والبحث المحفوظ | [فاتح](./stitch-modern-20261116/index.html#G03-light) · [داكن](./stitch-modern-20261116/index.html#G03-dark) |
| G04 | الإشعارات | [فاتح](./stitch-modern-20261116/index.html#G04-light) · [داكن](./stitch-modern-20261116/index.html#G04-dark) |
| G05 | إعدادات الإشعارات | [فاتح](./stitch-modern-20261116/index.html#G05-light) · [داكن](./stitch-modern-20261116/index.html#G05-dark) |
| G06 | الإعدادات والمظهر | [فاتح](./stitch-modern-20261116/index.html#G06-light) · [داكن](./stitch-modern-20261116/index.html#G06-dark) |
| G07 | إدارة أرقام وموافقات التواصل | [فاتح](./stitch-modern-20261116/index.html#G07-light) · [داكن](./stitch-modern-20261116/index.html#G07-dark) |
| G08 | المستخدمون المحظورون | [فاتح](./stitch-modern-20261116/index.html#G08-light) · [داكن](./stitch-modern-20261116/index.html#G08-dark) |
| G09 | الشروط والخصوصية والمساعدة | [فاتح](./stitch-modern-20261116/index.html#G09-light) · [داكن](./stitch-modern-20261116/index.html#G09-dark) |
| G10 | تسجيل الخروج وإغلاق الحساب | [فاتح](./stitch-modern-20261116/index.html#G10-light) · [داكن](./stitch-modern-20261116/index.html#G10-dark) |
| H01 | توثيق الحساب | [فاتح](./stitch-modern-20261116/index.html#H01-light) · [داكن](./stitch-modern-20261116/index.html#H01-dark) |
| H02 | توثيق الهوية | [فاتح](./stitch-modern-20261116/index.html#H02-light) · [داكن](./stitch-modern-20261116/index.html#H02-dark) |
| H03 | توثيق النشاط | [فاتح](./stitch-modern-20261116/index.html#H03-light) · [داكن](./stitch-modern-20261116/index.html#H03-dark) |
| H04 | حالة طلب التوثيق | [فاتح](./stitch-modern-20261116/index.html#H04-light) · [داكن](./stitch-modern-20261116/index.html#H04-dark) |
| H05 | التحميل وإعادة المحاولة | [فاتح](./stitch-modern-20261116/index.html#H05-light) · [داكن](./stitch-modern-20261116/index.html#H05-dark) |
| H06 | أنت غير متصل | [فاتح](./stitch-modern-20261116/index.html#H06-light) · [داكن](./stitch-modern-20261116/index.html#H06-dark) |
| H07 | قائمة فارغة | [فاتح](./stitch-modern-20261116/index.html#H07-light) · [داكن](./stitch-modern-20261116/index.html#H07-dark) |
| H08 | الحساب موقوف | [فاتح](./stitch-modern-20261116/index.html#H08-light) · [داكن](./stitch-modern-20261116/index.html#H08-dark) |
| H09 | صلاحيات الصور والموقع والتنبيهات | [فاتح](./stitch-modern-20261116/index.html#H09-light) · [داكن](./stitch-modern-20261116/index.html#H09-dark) |
| H10 | تأكيد النجاح أو فشل الحفظ | [فاتح](./stitch-modern-20261116/index.html#H10-light) · [داكن](./stitch-modern-20261116/index.html#H10-dark) |
