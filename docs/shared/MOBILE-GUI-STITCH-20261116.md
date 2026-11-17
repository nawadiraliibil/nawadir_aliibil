# نوادر الإبل — تصميم واجهات الجوال في Google Stitch

- المهمة: MOBILE-GUI-STITCH-20261116؛ الجانب والمالك: MOBILE / Codex.
- التاريخ: 2026-11-16 — Asia/Riyadh.
- الحالة: مكتمل كحزمة تصميم قابلة للمراجعة؛ رفعت النسخ المنقحة إلى Stitch، ولا يعني ذلك اعتماد المنتج أو اكتمال Flutter والخدمات.
- [مشروع Google Stitch الأساسي](https://stitch.withgoogle.com/projects/7529577228117709751).
- [افتح المعرض المحلي في متصفح](./stitch-mobile-20261116/index.html).
- [المتطلبات](../../Nawader_AlIbil_SRS_Ads_AR.md) · [التقدم](./PROGRESS.md) · [التكامل](./INTEGRATION.md).

## المخرجات الفعلية

74 تعريف شاشة وحالة تغطي رحلات الجوال، محفوظة في مشروع Stitch الأساسي على هيئة 79 شاشة أصلية: 74 فاتحة و5 داكنة للبداية والدخول. المعرض المحلي يحتوي 148 ملف HTML ومعاينة PNG، أي 74 لكل مظهر. النسخ الداكنة الـ69 الإضافية مشتقة محليًا من HTML الأصلي وتستخدم ألوان الدليل؛ لا تعد شاشات مستقلة على لوحة Stitch. تدعم ملفات HTML المنقحة متغيرات المظهرين.

نجح تحديث HTML وصور المعاينة لجميع شاشات Stitch الأصلية الـ79، ورتبت اللوحة في ثماني مجموعات حسب الرحلات، مع أبعاد معاينات تتطابق مع المحتوى المنقح. سجل الرفع يحفظ نتائج الاستدعاءات الفعلية.

هذا تسليم تصميم للجوال، وليس تطبيق Flutter أو موقعًا منشورًا أو تكامل خدمات. لم تعدل شيفرة الجوال أو الويب أو الخلفية أو العقود أو ملف Figma السابق.

## الهوية والبساطة

استخدم دليل الألوان PDF والشعارين المرفقين بطلب المستخدم. حفظ [الشعار الكامل الأصلي](./stitch-mobile-20261116/logo-full.png) و[الأيقونة الأصلية](./stitch-mobile-20261116/logo-emblem.png)، مع نسخ WebP مصغرة للعرض دون إعادة رسم الشعار. يظهر الشعار الكامل في الترحيب الفاتح والأيقونة في الرأس والداكن.

خلفية فاتحة #F8F3EA، أسطح #FFFCF8، ذهبي #A77434، ونص #2D241B؛ الداكن #111B1C و#202D2D مع #E4BC7B و#F6EEE0. بقية القيم المصدرية وقواعد الاستخدام في [DESIGN.md](./stitch-mobile-20261116/DESIGN.md). الخط Noto Sans Arabic، واتجاه RTL مع عزل أرقام الهاتف والرمز. أزرار رئيسية كبيرة وتسميات ظاهرة وخطوات نشر قصيرة وبطاقات في عمود واحد. الموافقات غير محددة افتراضيًا.

بُسط الترحيب والرئيسية، ونقحت شاشات الدخول والتوثيق والسياسات وإغلاق الحساب. أزيلت ادعاءات السوق الرسمي، أرقام الدعم المختلقة، عداد المزاد التنافسي، والخلط بين تأكيد الهاتف وتوثيق الهوية. بقي السعر المحدد منفصلًا عن مكان وموعد المزاد الحضوري؛ لا دفع أو مزايدة إلكترونية. التوثيق اختياري ولا يفترض مزودًا حكوميًا أو مدة اعتماد أو نجاحًا قبل نتيجة موثوقة. السياسات تعرض موضعًا للنص المعتمد، لا سياسة قانونية مستحدثة.

## التغطية

| المجموعة | التعريفات | العدد | مرجع المتطلبات |
|---|---|---:|---|
| A — البداية والدخول | A01–A05 | 5 | AD-FR-001–004 |
| B — الاستكشاف والبحث | B01–B09 | 9 | AD-FR-011–013, 022, 025, 028 |
| C — الإعلان والمعلن | C01–C09 | 9 | AD-FR-013–015, 023–025, 029, 032 |
| D — نشر إعلان | D01–D12 | 12 | AD-FR-005–010, 014, 025, 028 |
| E — إدارة الإعلانات | E01–E09 | 9 | AD-FR-005, 008–010, 030 |
| F — التواصل والتقييم والبلاغ | F01–F10 | 10 | AD-FR-015, 029, 031–033 |
| G — الحساب والمتابعة والتنبيهات | G01–G10 | 10 | AD-FR-003–004, 016, 026–027, 033 |
| H — التوثيق والحالات العامة | H01–H10 | 10 | AD-FR-034, AD-NFR-001, 005, 009 |

كل تعريف قد يشرح عدة حالات شرطية؛ العدد لا يعني إنشاء إطار مستقل لكل تباين ممكن في البيانات. الحالات الفرعية مثل أسباب الرفض أو حالات طلب التوثيق موضحة في واجهتها ومواصفة التصميم.

## الفحوص الفعلية وحدودها

- قراءة SRS والسجلات، استخراج PDF صفحة واحدة ومعاينته، فحص ملفات الهوية.
- عرض 148 معاينة بعرض 390px: لا تجاوز أفقي، لا صور مفقودة، لا مربع موافقة محدد مسبقًا؛ جميع الأزرار الظاهرة في الفحص لا تقل عن 48px ارتفاعًا. هذه قراءة DOM وليست تدقيقًا شاملًا لكل هدف لمس أو قارئ شاشة.
- فحص 44 حالة عرض عند 360 و430px: 11 شاشة أساسية × مظهرين × مقاسين؛ لا تجاوز أفقي أو صور مفقودة.
- اختبار المعرض: 74 خيارًا في الفاتح؛ تبديل إلى الداكن والبحث عن H03 وفتح ملفه الصحيح في إطار المعاينة.
- قراءة HTML محفوظ من Stitch لست شاشات بعد الرفع: تحقق الشعار المضمن في الترحيب والرئيسية، وRTL وقواعد الهوية، وإزالة عداد المزايدة ووعود النشر الفوري وافتراض مزود الهوية والفحص البيطري؛ جميع فحوص العينة نجحت. تحقق بنيوي من 79 إطارًا في ثماني مجموعات وعرض 390px على اللوحة.
- معاينة بصرية فعلية للترحيب والرئيسية ولوحة من تسع شاشات بحث وتفاصيل ومعاينة حالة التوثيق الداكنة؛ لم تنفذ مراجعة بصرية تفصيلية لكل شاشة.
- حساب تباين جزئي: النص البني على الخلفية الفاتحة 13.77:1؛ الكريم على الداكن 15.22:1؛ البني على الذهبي الفاتح 3.76:1 لذلك تستخدم عناوين أزرار كبيرة غامقة. لم ينفذ اعتماد WCAG شامل.
- لم ينفذ اختبار كبار السن أو المستخدمين غير المعتادين على التقنية، أو تكبير النص 200%، أو VoiceOver/TalkBack، أو اختبارات iOS/Android/Flutter أو الخدمات.

الأدلة: [render-checks.json](./stitch-mobile-20261116/render-checks.json)، [responsive-checks.json](./stitch-mobile-20261116/responsive-checks.json)، [جرد Stitch](./stitch-mobile-20261116/screen-inventory.json)، [جرد المعرض](./stitch-mobile-20261116/manifest.json)، [سجل الرفع](./stitch-mobile-20261116/stitch-final-updates.jsonl).

دليل القراءة من الخادم: [stitch-readback-checks.json](./stitch-mobile-20261116/stitch-readback-checks.json). تأكدت تغطية المعرفات الـ74 ووجود ملفات المعاينات ورفع كل الشاشات الأصلية وروابط التقرير المحلية؛ فحص المسافات للسجلات المعدلة نجح.

## استخدام المعرض والتسليم للتطوير

افتح المعرض في متصفح، واختر الشاشة والمظهر. يوجد بحث بالاسم أو المعرف، وأحجام 360/390/430، وعرض صور جميع الشاشات. بعض أزرار التنقل الرئيسية والترحيب تفتح المعاينات، وبقية الإجراءات تمثل واجهات تصميم. لا ينشر المعرض إعلانًا أو يرسل رمزًا أو رسالة أو مستندًا أو يغلق حسابًا. الصور والخرائط والبيانات توضيحية؛ تحميل الخطوط وCSS وبعض صور الإبل يحتاج اتصال إنترنت.

لا يوجد عقد API تنفيذي معتمد من هذا التصميم. يبقى [INT-002](./INTEGRATION.md) مرجع ربط الخدمات: الموافقات، حالات الإعلانات والوسائط، تجديد الظهور، أهلية التقييم، نتائج التوثيق والإعدادات. يحتاج التنفيذ إلى مهمة MOBILE مستقلة ومسارات مسندة واختبارات قبول.

## تأخر Stitch أثناء التوليد

انتهت عدة استدعاءات بعد 300 ثانية، بينما استمر الحفظ لاحقًا. لم يعد إرسال الدفعات إلى المشروع الأساسي. أُنشئ مشروع احتياطي خاص للحساب والتوثيق أثناء التحقق من التأخير، لكن الشاشات العشرين وصلت لاحقًا إلى المشروع الأساسي، فأصبح هو مرجع التسليم الواحد. المشروع الاحتياطي ليس مصدرًا معتمدًا ولا تدعي هذه المهمة حدًا ثابتًا لعدد شاشات Stitch.

## قائمة الشاشات

| المعرف | الشاشة | فتح المعاينة |
|---|---|---|
| A01 | مرحبًا بك | [فاتح](./stitch-mobile-20261116/index.html#A01-light) · [داكن](./stitch-mobile-20261116/index.html#A01-dark) |
| A02 | رقم الجوال | [فاتح](./stitch-mobile-20261116/index.html#A02-light) · [داكن](./stitch-mobile-20261116/index.html#A02-dark) |
| A03 | رمز التحقق | [فاتح](./stitch-mobile-20261116/index.html#A03-light) · [داكن](./stitch-mobile-20261116/index.html#A03-dark) |
| A04 | إكمال الحساب | [فاتح](./stitch-mobile-20261116/index.html#A04-light) · [داكن](./stitch-mobile-20261116/index.html#A04-dark) |
| A05 | تعذر التحقق | [فاتح](./stitch-mobile-20261116/index.html#A05-light) · [داكن](./stitch-mobile-20261116/index.html#A05-dark) |
| B01 | الرئيسية | [فاتح](./stitch-mobile-20261116/index.html#B01-light) · [داكن](./stitch-mobile-20261116/index.html#B01-dark) |
| B02 | نتائج البحث | [فاتح](./stitch-mobile-20261116/index.html#B02-light) · [داكن](./stitch-mobile-20261116/index.html#B02-dark) |
| B03 | تصفية الإعلانات | [فاتح](./stitch-mobile-20261116/index.html#B03-light) · [داكن](./stitch-mobile-20261116/index.html#B03-dark) |
| B04 | ترتيب النتائج | [فاتح](./stitch-mobile-20261116/index.html#B04-light) · [داكن](./stitch-mobile-20261116/index.html#B04-dark) |
| B05 | اختيار المنطقة والمدينة | [فاتح](./stitch-mobile-20261116/index.html#B05-light) · [داكن](./stitch-mobile-20261116/index.html#B05-dark) |
| B06 | الخريطة والقريب | [فاتح](./stitch-mobile-20261116/index.html#B06-light) · [داكن](./stitch-mobile-20261116/index.html#B06-dark) |
| B07 | تحديد مركز البحث | [فاتح](./stitch-mobile-20261116/index.html#B07-light) · [داكن](./stitch-mobile-20261116/index.html#B07-dark) |
| B08 | لا توجد نتائج | [فاتح](./stitch-mobile-20261116/index.html#B08-light) · [داكن](./stitch-mobile-20261116/index.html#B08-dark) |
| B09 | المفضلة | [فاتح](./stitch-mobile-20261116/index.html#B09-light) · [داكن](./stitch-mobile-20261116/index.html#B09-dark) |
| C01 | تفاصيل إعلان بسعر محدد | [فاتح](./stitch-mobile-20261116/index.html#C01-light) · [داكن](./stitch-mobile-20261116/index.html#C01-dark) |
| C02 | تفاصيل مزاد حضوري | [فاتح](./stitch-mobile-20261116/index.html#C02-light) · [داكن](./stitch-mobile-20261116/index.html#C02-dark) |
| C03 | مضى موعد المزاد | [فاتح](./stitch-mobile-20261116/index.html#C03-light) · [داكن](./stitch-mobile-20261116/index.html#C03-dark) |
| C04 | صور وفيديو الإعلان | [فاتح](./stitch-mobile-20261116/index.html#C04-light) · [داكن](./stitch-mobile-20261116/index.html#C04-dark) |
| C05 | خيارات التواصل والمشاركة | [فاتح](./stitch-mobile-20261116/index.html#C05-light) · [داكن](./stitch-mobile-20261116/index.html#C05-dark) |
| C06 | ملف المعلن | [فاتح](./stitch-mobile-20261116/index.html#C06-light) · [داكن](./stitch-mobile-20261116/index.html#C06-dark) |
| C07 | أسئلة الإعلان | [فاتح](./stitch-mobile-20261116/index.html#C07-light) · [داكن](./stitch-mobile-20261116/index.html#C07-dark) |
| C08 | إضافة سؤال أو تعديله | [فاتح](./stitch-mobile-20261116/index.html#C08-light) · [داكن](./stitch-mobile-20261116/index.html#C08-dark) |
| C09 | الإعلان غير متاح | [فاتح](./stitch-mobile-20261116/index.html#C09-light) · [داكن](./stitch-mobile-20261116/index.html#C09-dark) |
| D01 | أضف إعلان — نوع العرض | [فاتح](./stitch-mobile-20261116/index.html#D01-light) · [داكن](./stitch-mobile-20261116/index.html#D01-dark) |
| D02 | بيانات الإبل | [فاتح](./stitch-mobile-20261116/index.html#D02-light) · [داكن](./stitch-mobile-20261116/index.html#D02-dark) |
| D03 | الوصف والحالة الصحية | [فاتح](./stitch-mobile-20261116/index.html#D03-light) · [داكن](./stitch-mobile-20261116/index.html#D03-dark) |
| D04 | موقع الإعلان | [فاتح](./stitch-mobile-20261116/index.html#D04-light) · [داكن](./stitch-mobile-20261116/index.html#D04-dark) |
| D05 | السعر المطلوب | [فاتح](./stitch-mobile-20261116/index.html#D05-light) · [داكن](./stitch-mobile-20261116/index.html#D05-dark) |
| D06 | موعد ومكان المزاد | [فاتح](./stitch-mobile-20261116/index.html#D06-light) · [داكن](./stitch-mobile-20261116/index.html#D06-dark) |
| D07 | صور الإعلان والفيديو | [فاتح](./stitch-mobile-20261116/index.html#D07-light) · [داكن](./stitch-mobile-20261116/index.html#D07-dark) |
| D08 | رقم التواصل والموافقة | [فاتح](./stitch-mobile-20261116/index.html#D08-light) · [داكن](./stitch-mobile-20261116/index.html#D08-dark) |
| D09 | معاينة إعلان بسعر محدد | [فاتح](./stitch-mobile-20261116/index.html#D09-light) · [داكن](./stitch-mobile-20261116/index.html#D09-dark) |
| D10 | معاينة إعلان مزاد حضوري | [فاتح](./stitch-mobile-20261116/index.html#D10-light) · [داكن](./stitch-mobile-20261116/index.html#D10-dark) |
| D11 | تم إرسال الإعلان للمراجعة | [فاتح](./stitch-mobile-20261116/index.html#D11-light) · [داكن](./stitch-mobile-20261116/index.html#D11-dark) |
| D12 | مغادرة وحفظ المسودة | [فاتح](./stitch-mobile-20261116/index.html#D12-light) · [داكن](./stitch-mobile-20261116/index.html#D12-dark) |
| E01 | إعلاناتي | [فاتح](./stitch-mobile-20261116/index.html#E01-light) · [داكن](./stitch-mobile-20261116/index.html#E01-dark) |
| E02 | مسودة محفوظة | [فاتح](./stitch-mobile-20261116/index.html#E02-light) · [داكن](./stitch-mobile-20261116/index.html#E02-dark) |
| E03 | إعلان قيد المراجعة | [فاتح](./stitch-mobile-20261116/index.html#E03-light) · [داكن](./stitch-mobile-20261116/index.html#E03-dark) |
| E04 | إعلان مرفوض | [فاتح](./stitch-mobile-20261116/index.html#E04-light) · [داكن](./stitch-mobile-20261116/index.html#E04-dark) |
| E05 | إعلان منشور | [فاتح](./stitch-mobile-20261116/index.html#E05-light) · [داكن](./stitch-mobile-20261116/index.html#E05-dark) |
| E06 | تجديد الظهور غير متاح بعد | [فاتح](./stitch-mobile-20261116/index.html#E06-light) · [داكن](./stitch-mobile-20261116/index.html#E06-dark) |
| E07 | تعديل إعلان منشور | [فاتح](./stitch-mobile-20261116/index.html#E07-light) · [داكن](./stitch-mobile-20261116/index.html#E07-dark) |
| E08 | إيقاف الإعلان وأرشفته | [فاتح](./stitch-mobile-20261116/index.html#E08-light) · [داكن](./stitch-mobile-20261116/index.html#E08-dark) |
| E09 | مؤرشف أو مخفي إداريًا | [فاتح](./stitch-mobile-20261116/index.html#E09-light) · [داكن](./stitch-mobile-20261116/index.html#E09-dark) |
| F01 | الرسائل | [فاتح](./stitch-mobile-20261116/index.html#F01-light) · [داكن](./stitch-mobile-20261116/index.html#F01-dark) |
| F02 | المحادثة | [فاتح](./stitch-mobile-20261116/index.html#F02-light) · [داكن](./stitch-mobile-20261116/index.html#F02-dark) |
| F03 | محادثة للقراءة فقط | [فاتح](./stitch-mobile-20261116/index.html#F03-light) · [داكن](./stitch-mobile-20261116/index.html#F03-dark) |
| F04 | حظر المستخدم | [فاتح](./stitch-mobile-20261116/index.html#F04-light) · [داكن](./stitch-mobile-20261116/index.html#F04-dark) |
| F05 | تقييمات المعلن | [فاتح](./stitch-mobile-20261116/index.html#F05-light) · [داكن](./stitch-mobile-20261116/index.html#F05-dark) |
| F06 | إضافة أو تعديل تقييم | [فاتح](./stitch-mobile-20261116/index.html#F06-light) · [داكن](./stitch-mobile-20261116/index.html#F06-dark) |
| F07 | التقييم غير متاح الآن | [فاتح](./stitch-mobile-20261116/index.html#F07-light) · [داكن](./stitch-mobile-20261116/index.html#F07-dark) |
| F08 | رد المعلن واعتراض على تقييم | [فاتح](./stitch-mobile-20261116/index.html#F08-light) · [داكن](./stitch-mobile-20261116/index.html#F08-dark) |
| F09 | الإبلاغ عن محتوى | [فاتح](./stitch-mobile-20261116/index.html#F09-light) · [داكن](./stitch-mobile-20261116/index.html#F09-dark) |
| F10 | بلاغاتي وتفاصيل البلاغ | [فاتح](./stitch-mobile-20261116/index.html#F10-light) · [داكن](./stitch-mobile-20261116/index.html#F10-dark) |
| G01 | حسابي | [فاتح](./stitch-mobile-20261116/index.html#G01-light) · [داكن](./stitch-mobile-20261116/index.html#G01-dark) |
| G02 | تعديل الملف الشخصي | [فاتح](./stitch-mobile-20261116/index.html#G02-light) · [داكن](./stitch-mobile-20261116/index.html#G02-dark) |
| G03 | المتابعات والبحث المحفوظ | [فاتح](./stitch-mobile-20261116/index.html#G03-light) · [داكن](./stitch-mobile-20261116/index.html#G03-dark) |
| G04 | الإشعارات | [فاتح](./stitch-mobile-20261116/index.html#G04-light) · [داكن](./stitch-mobile-20261116/index.html#G04-dark) |
| G05 | إعدادات الإشعارات | [فاتح](./stitch-mobile-20261116/index.html#G05-light) · [داكن](./stitch-mobile-20261116/index.html#G05-dark) |
| G06 | الإعدادات والمظهر | [فاتح](./stitch-mobile-20261116/index.html#G06-light) · [داكن](./stitch-mobile-20261116/index.html#G06-dark) |
| G07 | إدارة أرقام وموافقات التواصل | [فاتح](./stitch-mobile-20261116/index.html#G07-light) · [داكن](./stitch-mobile-20261116/index.html#G07-dark) |
| G08 | المستخدمون المحظورون | [فاتح](./stitch-mobile-20261116/index.html#G08-light) · [داكن](./stitch-mobile-20261116/index.html#G08-dark) |
| G09 | الشروط والخصوصية والمساعدة | [فاتح](./stitch-mobile-20261116/index.html#G09-light) · [داكن](./stitch-mobile-20261116/index.html#G09-dark) |
| G10 | تسجيل الخروج وإغلاق الحساب | [فاتح](./stitch-mobile-20261116/index.html#G10-light) · [داكن](./stitch-mobile-20261116/index.html#G10-dark) |
| H01 | توثيق الحساب | [فاتح](./stitch-mobile-20261116/index.html#H01-light) · [داكن](./stitch-mobile-20261116/index.html#H01-dark) |
| H02 | توثيق الهوية | [فاتح](./stitch-mobile-20261116/index.html#H02-light) · [داكن](./stitch-mobile-20261116/index.html#H02-dark) |
| H03 | توثيق النشاط | [فاتح](./stitch-mobile-20261116/index.html#H03-light) · [داكن](./stitch-mobile-20261116/index.html#H03-dark) |
| H04 | حالة طلب التوثيق | [فاتح](./stitch-mobile-20261116/index.html#H04-light) · [داكن](./stitch-mobile-20261116/index.html#H04-dark) |
| H05 | التحميل وإعادة المحاولة | [فاتح](./stitch-mobile-20261116/index.html#H05-light) · [داكن](./stitch-mobile-20261116/index.html#H05-dark) |
| H06 | أنت غير متصل | [فاتح](./stitch-mobile-20261116/index.html#H06-light) · [داكن](./stitch-mobile-20261116/index.html#H06-dark) |
| H07 | قائمة فارغة | [فاتح](./stitch-mobile-20261116/index.html#H07-light) · [داكن](./stitch-mobile-20261116/index.html#H07-dark) |
| H08 | الحساب موقوف | [فاتح](./stitch-mobile-20261116/index.html#H08-light) · [داكن](./stitch-mobile-20261116/index.html#H08-dark) |
| H09 | صلاحيات الصور والموقع والتنبيهات | [فاتح](./stitch-mobile-20261116/index.html#H09-light) · [داكن](./stitch-mobile-20261116/index.html#H09-dark) |
| H10 | تأكيد النجاح أو فشل الحفظ | [فاتح](./stitch-mobile-20261116/index.html#H10-light) · [داكن](./stitch-mobile-20261116/index.html#H10-dark) |
