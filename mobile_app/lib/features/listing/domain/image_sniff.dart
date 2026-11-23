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
