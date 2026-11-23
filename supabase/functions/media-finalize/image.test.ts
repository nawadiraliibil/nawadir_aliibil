// اختبارات فحص الصور وتنظيفها — MOBILE-BE-110
// التشغيل: node --test supabase/functions/media-finalize/image.test.ts
import assert from "node:assert/strict";
import { test } from "node:test";

import { MalformedImageError, sanitizeImage, sniffMime } from "./image.ts";

const ascii = (text: string) => [...text].map((c) => c.charCodeAt(0));

function segment(marker: number, payload: number[]): number[] {
  const length = payload.length + 2;
  return [0xff, marker, (length >> 8) & 0xff, length & 0xff, ...payload];
}

/** EXIF بترتيب little-endian فيه الاتجاه ومؤشر GPS وإحداثيات نصية للتحقق من حذفها. */
function exifSegment(orientation: number): number[] {
  const tiff = [
    0x49, 0x49, 0x2a, 0x00, 0x08, 0x00, 0x00, 0x00, // II، IFD0 عند 8
    0x02, 0x00, // وسمان
    0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, orientation, 0x00, 0x00, 0x00, // Orientation
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x26, 0x00, 0x00, 0x00, // GPS IFD pointer
    0x00, 0x00, 0x00, 0x00,
    ...ascii("GPS-24.7136N-46.6753E"),
  ];
  return segment(0xe1, [...ascii("Exif\0\0"), ...tiff]);
}

const JFIF = segment(0xe0, [...ascii("JFIF\0"), 1, 1, 0, 0, 1, 0, 1, 0, 0]);
const DQT = segment(0xdb, [0, ...new Array(64).fill(1)]);
// SOF0: دقة 8، ارتفاع 600، عرض 800، مكون واحد.
const SOF0 = segment(0xc0, [8, 0x02, 0x58, 0x03, 0x20, 1, 1, 0x11, 0]);
const SOS_AND_DATA = [...segment(0xda, [1, 1, 0, 0, 63, 0]), 0x12, 0x34, 0x56, 0xff, 0xd9];

function jpeg(...segments: number[][]): Uint8Array {
  return new Uint8Array([0xff, 0xd8, ...segments.flat(), ...SOS_AND_DATA]);
}

function includesAscii(bytes: Uint8Array, text: string): boolean {
  const needle = ascii(text);
  for (let i = 0; i + needle.length <= bytes.length; i++) {
    if (needle.every((b, j) => bytes[i + j] === b)) return true;
  }
  return false;
}

function pngChunk(type: string, data: number[]): number[] {
  const n = data.length;
  return [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff, ...ascii(type), ...data, 0, 0, 0, 0];
}

const PNG_SIG = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const IHDR = pngChunk("IHDR", [0, 0, 0x03, 0x20, 0, 0, 0x02, 0x58, 8, 2, 0, 0, 0]);
const IDAT = pngChunk("IDAT", [1, 2, 3, 4]);
const IEND = pngChunk("IEND", []);

test("sniffMime يعرف النوع من البايتات", () => {
  assert.equal(sniffMime(jpeg(JFIF, DQT, SOF0)), "image/jpeg");
  assert.equal(sniffMime(new Uint8Array([...PNG_SIG, ...IHDR, ...IDAT, ...IEND])), "image/png");
  assert.equal(sniffMime(new Uint8Array([0, 0, 0, 0x18, ...ascii("ftypmp42"), 0, 0, 0, 0])), "video/mp4");
  assert.equal(sniffMime(new Uint8Array(ascii("GIF89a............"))), null);
  assert.equal(sniffMime(new Uint8Array(ascii("<html><script>alert(1)</script>"))), null);
  assert.equal(sniffMime(new Uint8Array([])), null);
});

test("JPEG: حذف EXIF وبيانات الموقع مع بقاء الاتجاه والأبعاد وبيانات الصورة", () => {
  const original = jpeg(JFIF, exifSegment(6), DQT, SOF0);
  assert.ok(includesAscii(original, "GPS-24.7136N"));

  const result = sanitizeImage(original, "image/jpeg");
  assert.equal(result.changed, true);
  assert.equal(result.width, 800);
  assert.equal(result.height, 600);
  assert.equal(includesAscii(result.bytes, "GPS-24.7136N"), false, "إحداثيات الموقع أزيلت");
  assert.ok(result.bytes.length < original.length);
  // SOI ثم JFIF ثم مقطع الاتجاه الأدنى.
  assert.deepEqual([...result.bytes.subarray(0, 2)], [0xff, 0xd8]);
  assert.deepEqual([...result.bytes.subarray(2, 2 + JFIF.length)], JFIF);
  // بيانات الصورة باقية كما هي حتى نهاية الملف.
  assert.deepEqual([...result.bytes.subarray(result.bytes.length - SOS_AND_DATA.length)], SOS_AND_DATA);

  // إعادة التنظيف تبقي الاتجاه: المقطع الأدنى يقرأ ويعاد كما هو.
  const again = sanitizeImage(result.bytes, "image/jpeg");
  assert.deepEqual([...again.bytes], [...result.bytes]);
  // قيمة الاتجاه 6 موجودة في الناتج بعد وسم 0x0112.
  const marker = [0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x06];
  let found = false;
  for (let i = 0; i + marker.length <= result.bytes.length; i++) {
    if (marker.every((b, j) => result.bytes[i + j] === b)) found = true;
  }
  assert.ok(found, "الاتجاه 6 محفوظ");
});

test("JPEG: اتجاه عادي لا يضيف مقطع EXIF، وXMP وIPTC والتعليقات تحذف", () => {
  const xmp = segment(0xe1, [...ascii("http://ns.adobe.com/xap/1.0/\0"), ...ascii("<x>exif:GPSLatitude=24,42N</x>")]);
  const iptc = segment(0xed, ascii("Photoshop 3.0\0City=Riyadh"));
  const comment = segment(0xfe, ascii("shot at home address"));
  const result = sanitizeImage(jpeg(JFIF, exifSegment(1), xmp, iptc, comment, DQT, SOF0), "image/jpeg");
  assert.equal(result.changed, true);
  for (const text of ["GPSLatitude", "City=Riyadh", "home address", "Exif"]) {
    assert.equal(includesAscii(result.bytes, text), false, text);
  }
});

test("JPEG دون بيانات وصفية يعاد كما هو", () => {
  const original = jpeg(JFIF, DQT, SOF0);
  const result = sanitizeImage(original, "image/jpeg");
  assert.equal(result.changed, false);
  assert.equal(result.bytes, original);
  assert.equal(result.width, 800);
});

test("JPEG معطوب يرفض", () => {
  assert.throws(() => sanitizeImage(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00]), "image/jpeg"), MalformedImageError);
  assert.throws(() => sanitizeImage(new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 0xff, 0xff, 1, 2]), "image/jpeg"), MalformedImageError);
  // دون SOF: لا أبعاد.
  assert.throws(() => sanitizeImage(jpeg(JFIF, DQT), "image/jpeg"), MalformedImageError);
  assert.throws(() => sanitizeImage(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), "image/jpeg"), MalformedImageError);
});

test("PNG: حذف eXIf والنصوص وما بعد IEND مع بقاء الأبعاد", () => {
  const original = new Uint8Array([
    ...PNG_SIG, ...IHDR,
    ...pngChunk("eXIf", ascii("GPS-24.7136N")),
    ...pngChunk("tEXt", ascii("Location\0Riyadh")),
    ...pngChunk("iTXt", ascii("XML:com.adobe.xmp\0GPSLongitude")),
    ...IDAT, ...IEND, ...ascii("trailing-secret"),
  ]);
  const result = sanitizeImage(original, "image/png");
  assert.equal(result.changed, true);
  assert.equal(result.width, 800);
  assert.equal(result.height, 600);
  for (const text of ["GPS-24.7136N", "Riyadh", "GPSLongitude", "trailing-secret"]) {
    assert.equal(includesAscii(result.bytes, text), false, text);
  }
  assert.deepEqual([...result.bytes], [...PNG_SIG, ...IHDR, ...IDAT, ...IEND]);
});

test("PNG نظيف يعاد كما هو، والمعطوب يرفض", () => {
  const clean = new Uint8Array([...PNG_SIG, ...IHDR, ...IDAT, ...IEND]);
  assert.equal(sanitizeImage(clean, "image/png").changed, false);
  assert.throws(() => sanitizeImage(new Uint8Array([...PNG_SIG, ...IHDR, ...IDAT]), "image/png"), MalformedImageError);
  assert.throws(() => sanitizeImage(new Uint8Array([...PNG_SIG, ...IDAT, ...IEND]), "image/png"), MalformedImageError);
  assert.throws(() => sanitizeImage(new Uint8Array([...PNG_SIG, 0, 0, 0xff, 0xff, ...ascii("IHDR")]), "image/png"), MalformedImageError);
});
