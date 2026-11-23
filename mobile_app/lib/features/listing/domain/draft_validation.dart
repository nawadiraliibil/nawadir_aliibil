import '../../../core/format/digits.dart';
import '../../../core/settings/published_settings.dart';
import '../../auth/domain/saudi_phone.dart';
import '../data/draft_form.dart';

/// أخطاء حقول خطوة: مفتاح الحقل (كما في الرقعة) ورسالة عربية. خريطة فارغة
/// تعني أن الخطوة صالحة. تطابق قواعد `submit_listing` في الخادم، والخادم هو
/// المرجع النهائي.
typedef FieldErrors = Map<String, String>;

abstract final class DraftValidation {
  static const ageMax = 600;
  static const breedNoteMax = 80;
  static const colorMax = 60;
  static const healthNotesMax = 2000;
  static const venueMax = 300;

  /// الصيغة التي يقبلها الخادم لسعر موجب بمنزلتين عشريتين كحد أقصى.
  static final _priceFormat = RegExp(r'^[0-9]{1,10}(\.[0-9]{1,2})?$');

  static FieldErrors data(DraftForm f, PublishedSettings s) {
    final e = <String, String>{};
    final title = f.title?.trim() ?? '';
    final l = s.listing;
    if (title.length < l.titleMin || title.length > l.titleMax) {
      e['title'] = 'عنوان الإعلان من ${l.titleMin} إلى ${l.titleMax} حرفًا.';
    }
    final breed = s.lookups.breed(f.breedId);
    if (breed == null) {
      e['breed_id'] = 'اختر السلالة.';
    } else if (breed.requiresNote) {
      final note = f.breedNote?.trim() ?? '';
      if (note.isEmpty) {
        e['breed_note'] = 'اكتب اسم السلالة.';
      } else if (note.length > breedNoteMax) {
        e['breed_note'] = 'لا يزيد على $breedNoteMax حرفًا.';
      }
    }
    if (f.sex == null) e['sex'] = 'اختر الجنس.';
    final age = f.ageMonths;
    if (age == null || age < 1 || age > ageMax) {
      e['age_months'] = 'العمر بالأشهر من 1 إلى $ageMax.';
    }
    if ((f.color?.length ?? 0) > colorMax) {
      e['color'] = 'لا يزيد على $colorMax حرفًا.';
    }
    return e;
  }

  static FieldErrors description(DraftForm f, PublishedSettings s) {
    final e = <String, String>{};
    final l = s.listing;
    final d = f.description?.trim() ?? '';
    if (d.length < l.descriptionMin || d.length > l.descriptionMax) {
      e['description'] =
          'الوصف من ${l.descriptionMin} إلى ${l.descriptionMax} حرفًا.';
    }
    final h = f.healthNotes?.trim() ?? '';
    if (h.isEmpty) {
      e['health_notes'] = 'اكتب الحالة الصحية أو «لا توجد عيوب معروفة».';
    } else if (h.length > healthNotesMax) {
      e['health_notes'] = 'لا يزيد على $healthNotesMax حرف.';
    }
    return e;
  }

  static FieldErrors location(DraftForm f, PublishedSettings s) =>
      _place(f.regionId, f.cityId, s, 'region_id', 'city_id');

  static FieldErrors price(DraftForm f) {
    final p = f.price;
    if (p == null || p <= 0 || !_priceFormat.hasMatch(_plain(p))) {
      return {'price': 'أدخل مبلغًا موجبًا بمنزلتين عشريتين كحد أقصى.'};
    }
    return {};
  }

  static FieldErrors auction(DraftForm f, PublishedSettings s, DateTime now) {
    final e = _place(
      f.auctionRegionId,
      f.auctionCityId,
      s,
      'auction_region_id',
      'auction_city_id',
    );
    final venue = f.auctionVenue?.trim() ?? '';
    if (venue.isEmpty) {
      e['auction_venue'] = 'اكتب اسم المكان أو العنوان.';
    } else if (venue.length > venueMax) {
      e['auction_venue'] = 'لا يزيد على $venueMax حرف.';
    }
    final at = f.auctionStartsAt;
    if (at == null || !at.isAfter(now)) {
      e['auction_starts_at'] = 'اختر تاريخًا ووقتًا قادمين.';
    }
    return e;
  }

  static FieldErrors contact(DraftForm f) {
    final e = <String, String>{};
    if (SaudiPhone.tryParse(f.contactPhone ?? '') == null) {
      e['contact_phone'] = 'أدخل رقم جوال سعوديًا يبدأ بـ5 ويتكون من 9 أرقام.';
    }
    if (!f.callEnabled && !f.whatsappEnabled) {
      e['contact_channels'] = 'اختر قناة تواصل واحدة على الأقل.';
    }
    return e;
  }

  static FieldErrors _place(
    int? regionId,
    int? cityId,
    PublishedSettings s,
    String regionKey,
    String cityKey,
  ) {
    final e = <String, String>{};
    if (s.lookups.region(regionId) == null) e[regionKey] = 'اختر المنطقة.';
    final city = s.lookups.city(cityId);
    if (city == null || city.regionId != regionId) {
      e[cityKey] = 'اختر المدينة.';
    }
    return e;
  }

  /// تحويل إدخال المستخدم إلى عدد صحيح، أو `null`.
  static int? parseInt(String raw) =>
      int.tryParse(toWesternDigits(raw).replaceAll(RegExp(r'[\s,٬]'), ''));

  /// تحويل إدخال السعر إلى عدد، أو `null`. يقبل فاصل الآلاف والفاصلة العربية.
  static num? parsePrice(String raw) {
    final t = toWesternDigits(
      raw,
    ).replaceAll(RegExp(r'[\s,٬]'), '').replaceAll('٫', '.');
    if (!_priceFormat.hasMatch(t)) return null;
    return num.parse(t);
  }

  /// نص عددي بلا أس علمي (25000 لا 2.5e4).
  static String _plain(num n) => n == n.truncate()
      ? n.truncate().toString()
      : n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  /// موعد المزاد من تاريخ ووقت يختارهما المستخدم، بتوقيت السعودية (UTC+3).
  static DateTime auctionMoment(DateTime date, int hour, int minute) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      ).subtract(const Duration(hours: 3));
}
