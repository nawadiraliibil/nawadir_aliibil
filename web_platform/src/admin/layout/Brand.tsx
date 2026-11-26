import logoEmblem from '../assets/logo-emblem.webp'

/** هوية اللوحة: شعار المنصة (الملف نفسه في تطبيق الجوال) مع الاسم. */
export function Brand({ large = false }: { large?: boolean }) {
  return (
    <div className={large ? 'brand brand-lg' : 'brand'}>
      <span className="brand-mark" aria-hidden="true">
        <img src={logoEmblem} alt="" width={large ? 72 : 44} height={large ? 72 : 44} decoding="async" />
      </span>
      <span>
        <span className="brand-name">نوادر الإبل</span>
        <span className="brand-sub">لوحة الإدارة</span>
      </span>
    </div>
  )
}
