import { ACTION_CTA } from './logic'
import type { ActionType } from './types'

export interface PreviewData {
  title: string
  body: string | null
  advertiser_name: string
  image_src: string | null
  action_type: ActionType
}

/**
 * معاينة تقريبية لبطاقة الدعاية في التطبيق: صورة 16:10 مثل البطاقة الكبيرة، وشارة «إعلان ممول»
 * ظاهرة دائمًا. الشكل النهائي يبنيه MOBILE وفق INT-010.
 */
export function PromotionPreview({ data }: { data: PreviewData }) {
  const cta = ACTION_CTA[data.action_type]
  return (
    <figure className="promo-preview" aria-label="معاينة البطاقة في التطبيق">
      <div className="promo-preview-phone">
        <div className="promo-preview-ghost" aria-hidden="true" />
        <article className="promo-card">
          <div className="promo-card-media">
            {data.image_src ? <img src={data.image_src} alt="" /> : <span className="promo-card-placeholder">صورة 16:10</span>}
            <span className="promo-card-badge">إعلان ممول</span>
          </div>
          <div className="promo-card-body">
            <p className="promo-card-title">{data.title.trim() || 'عنوان الدعاية'}</p>
            {data.body?.trim() && <p className="promo-card-text">{data.body.trim()}</p>}
            <div className="promo-card-foot">
              <span className="promo-card-advertiser">{data.advertiser_name.trim() || 'اسم المعلن'}</span>
              {cta && <span className="promo-card-cta">{cta}</span>}
            </div>
          </div>
        </article>
        <div className="promo-preview-ghost" aria-hidden="true" />
      </div>
      <figcaption className="muted small">تظهر بين إعلانات المستخدمين. المعاينة تقريبية.</figcaption>
    </figure>
  )
}
