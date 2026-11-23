// فحص بايتات الصورة الفعلية وتنظيفها من البيانات الوصفية — MOBILE-BE-110
// دوال خالصة على Uint8Array دون اعتماديات، تعمل في Deno وNode.

export type SniffedMime = "image/jpeg" | "image/png" | "video/mp4";

export interface SanitizedImage {
  bytes: Uint8Array;
  width: number;
  height: number;
  /** هل اختلف الناتج عن الأصل (أزيلت بيانات وصفية). */
  changed: boolean;
}

export class MalformedImageError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MalformedImageError";
  }
}

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/** نوع الملف من بايتاته الأولى، لا من الامتداد أو ترويسة الرفع. */
export function sniffMime(bytes: Uint8Array): SniffedMime | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "image/jpeg";
  }
  if (bytes.length >= 8 && PNG_SIGNATURE.every((b, i) => bytes[i] === b)) {
    return "image/png";
  }
  // ISO BMFF: حجم الصندوق ثم "ftyp".
  if (
    bytes.length >= 12 &&
    bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70
  ) {
    return "video/mp4";
  }
  return null;
}

export function sanitizeImage(bytes: Uint8Array, mime: "image/jpeg" | "image/png"): SanitizedImage {
  return mime === "image/jpeg" ? sanitizeJpeg(bytes) : sanitizePng(bytes);
}

function concat(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    out.set(p, offset);
    offset += p.length;
  }
  return out;
}

function startsWithAscii(bytes: Uint8Array, offset: number, text: string): boolean {
  if (offset + text.length > bytes.length) return false;
  for (let i = 0; i < text.length; i++) {
    if (bytes[offset + i] !== text.charCodeAt(i)) return false;
  }
  return true;
}

/** اتجاه الصورة من EXIF (الوسم 0x0112) إن وجد وكان صالحًا. */
function readExifOrientation(exif: Uint8Array): number | null {
  // exif يبدأ بترويسة TIFF بعد "Exif\0\0".
  if (exif.length < 14) return null;
  const little = exif[0] === 0x49 && exif[1] === 0x49;
  const big = exif[0] === 0x4d && exif[1] === 0x4d;
  if (!little && !big) return null;
  const u16 = (o: number) => (little ? exif[o] | (exif[o + 1] << 8) : (exif[o] << 8) | exif[o + 1]);
  const u32 = (o: number) =>
    little
      ? (exif[o] | (exif[o + 1] << 8) | (exif[o + 2] << 16) | (exif[o + 3] << 24)) >>> 0
      : ((exif[o] << 24) | (exif[o + 1] << 16) | (exif[o + 2] << 8) | exif[o + 3]) >>> 0;
  if (u16(2) !== 42) return null;
  const ifd = u32(4);
  if (ifd + 2 > exif.length) return null;
  const count = u16(ifd);
  for (let i = 0; i < count; i++) {
    const entry = ifd + 2 + i * 12;
    if (entry + 12 > exif.length) return null;
    if (u16(entry) === 0x0112) {
      const value = u16(entry + 8);
      return value >= 1 && value <= 8 ? value : null;
    }
  }
  return null;
}

/** مقطع EXIF أدنى يحمل الاتجاه فقط، ليبقى عرض الصورة صحيحًا بعد حذف بقية EXIF. */
function orientationSegment(orientation: number): Uint8Array {
  const payload = [
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    0x4d, 0x4d, 0x00, 0x2a, 0x00, 0x00, 0x00, 0x08, // TIFF big-endian، IFD0 عند 8
    0x00, 0x01, // وسم واحد
    0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, orientation, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, // لا IFD تالٍ
  ];
  const length = payload.length + 2;
  return new Uint8Array([0xff, 0xe1, (length >> 8) & 0xff, length & 0xff, ...payload]);
}

function isSofMarker(marker: number): boolean {
  return marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
}

/**
 * يحذف من JPEG مقاطع EXIF وXMP (APP1) وIPTC (APP13) والتعليقات (COM)، وفيها
 * إحداثيات الموقع، ويبقي الاتجاه بمقطع EXIF أدنى. بيانات الصورة لا تعاد ضغطها.
 */
function sanitizeJpeg(bytes: Uint8Array): SanitizedImage {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) {
    throw new MalformedImageError("not a JPEG");
  }

  const leading: Uint8Array[] = []; // مقاطع APP0 (JFIF) في أول الملف
  const rest: Uint8Array[] = [];
  let orientation: number | null = null;
  let width = 0;
  let height = 0;
  let removed = false;
  let seenNonApp0 = false;
  let offset = 2;

  while (true) {
    if (offset + 4 > bytes.length) throw new MalformedImageError("truncated JPEG");
    if (bytes[offset] !== 0xff) throw new MalformedImageError("bad JPEG marker");
    // بايتات حشو 0xFF قبل الوسم.
    while (offset < bytes.length && bytes[offset + 1] === 0xff) offset++;
    const marker = bytes[offset + 1];

    if (marker === 0xd9) throw new MalformedImageError("JPEG without image data");
    const length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (length < 2 || offset + 2 + length > bytes.length) {
      throw new MalformedImageError("bad JPEG segment length");
    }
    const segment = bytes.subarray(offset, offset + 2 + length);
    const payload = offset + 4;

    if (marker === 0xda) {
      // بداية المسح: ما بعدها بيانات الصورة حتى نهاية الملف.
      rest.push(bytes.subarray(offset));
      break;
    }

    if (isSofMarker(marker)) {
      if (length < 7) throw new MalformedImageError("bad JPEG frame header");
      height = (bytes[payload + 1] << 8) | bytes[payload + 2];
      width = (bytes[payload + 3] << 8) | bytes[payload + 4];
    }

    if (marker === 0xe1 && startsWithAscii(bytes, payload, "Exif\0\0")) {
      orientation ??= readExifOrientation(bytes.subarray(payload + 6, offset + 2 + length));
      removed = true;
    } else if (marker === 0xe1 || marker === 0xed || marker === 0xfe) {
      removed = true;
    } else if (marker === 0xe0 && !seenNonApp0) {
      leading.push(segment);
    } else {
      seenNonApp0 = true;
      rest.push(segment);
    }

    offset += 2 + length;
  }

  if (width === 0 || height === 0) throw new MalformedImageError("JPEG without frame header");
  if (!removed) return { bytes, width, height, changed: false };

  const parts: Uint8Array[] = [bytes.subarray(0, 2), ...leading];
  if (orientation !== null && orientation !== 1) parts.push(orientationSegment(orientation));
  parts.push(...rest);
  return { bytes: concat(parts), width, height, changed: true };
}

/** يحذف من PNG مقاطع eXIf والنصوص (tEXt وzTXt وiTXt) التي قد تحمل الموقع. */
function sanitizePng(bytes: Uint8Array): SanitizedImage {
  if (bytes.length < 8 || !PNG_SIGNATURE.every((b, i) => bytes[i] === b)) {
    throw new MalformedImageError("not a PNG");
  }
  const dropped = new Set(["eXIf", "tEXt", "zTXt", "iTXt"]);
  const parts: Uint8Array[] = [bytes.subarray(0, 8)];
  let width = 0;
  let height = 0;
  let removed = false;
  let ended = false;
  let first = true;
  let offset = 8;

  while (offset < bytes.length) {
    if (offset + 12 > bytes.length) throw new MalformedImageError("truncated PNG");
    const length =
      ((bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]) >>> 0;
    const type = String.fromCharCode(bytes[offset + 4], bytes[offset + 5], bytes[offset + 6], bytes[offset + 7]);
    const end = offset + 12 + length;
    if (end > bytes.length) throw new MalformedImageError("bad PNG chunk length");

    if (first) {
      if (type !== "IHDR" || length < 8) throw new MalformedImageError("PNG without IHDR");
      const d = offset + 8;
      width = ((bytes[d] << 24) | (bytes[d + 1] << 16) | (bytes[d + 2] << 8) | bytes[d + 3]) >>> 0;
      height = ((bytes[d + 4] << 24) | (bytes[d + 5] << 16) | (bytes[d + 6] << 8) | bytes[d + 7]) >>> 0;
      first = false;
    }

    if (dropped.has(type)) {
      removed = true;
    } else {
      parts.push(bytes.subarray(offset, end));
    }

    offset = end;
    if (type === "IEND") {
      ended = true;
      break;
    }
  }

  if (!ended || width === 0 || height === 0) throw new MalformedImageError("incomplete PNG");
  // بيانات بعد IEND تحذف أيضًا.
  if (offset < bytes.length) removed = true;
  if (!removed) return { bytes, width, height, changed: false };
  return { bytes: concat(parts), width, height, changed: true };
}
