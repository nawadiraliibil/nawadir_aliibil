import 'dart:typed_data';

/// النوع الفعلي للصورة من أول بايتاتها، لا من اسم الملف. الخادم يعيد الفحص
/// ولا يثق بما يعلنه العميل؛ هذا لرفض مبكر قبل الرفع.
abstract final class ImageSniff {
  static const jpeg = 'image/jpeg';
  static const png = 'image/png';

  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  /// `image/jpeg` أو `image/png`، أو `null` لغيرهما (HEIC وWebP وGIF وPDF…).
  static String? mimeOf(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return jpeg;
    }
    if (b.length >= 8) {
      var isPng = true;
      for (var i = 0; i < 8; i++) {
        if (b[i] != _pngSignature[i]) {
          isPng = false;
          break;
        }
      }
      if (isPng) return png;
    }
    return null;
  }
}

/// النوع الفعلي للفيديو: حاوية ISO BMFF (صندوق ثم `ftyp`) كما يفحصها الخادم.
abstract final class VideoSniff {
  static const mp4 = 'video/mp4';

  static String? mimeOf(Uint8List b) {
    if (b.length >= 12 &&
        b[4] == 0x66 &&
        b[5] == 0x74 &&
        b[6] == 0x79 &&
        b[7] == 0x70) {
      return mp4;
    }
    return null;
  }
}
