import { useEffect, useId, useRef, useState } from 'react'
import { GROUND_PATH, MARK_PATH, RING_PATH, UPPER_CLIP_PATH } from './splashArt'
import { GUSTS, LEGS, paintWalk } from './walk'
import './splash.css'

const REDUCED_MOTION = '(prefers-reduced-motion: reduce)'

function prefersReducedMotion(): boolean {
  return typeof window.matchMedia === 'function' && window.matchMedia(REDUCED_MOTION).matches
}

/**
 * شاشة التحميل (السبلاش) المعتمدة للمنصة: الجمل يمشي على الكثيب ثم «جارٍ التحميل».
 * مع «تقليل الحركة» يظهر الشعار ثابتًا. `leaving` يبدأ التلاشي فوق المحتوى.
 */
export function SplashScreen({ leaving = false }: { leaving?: boolean }) {
  const uid = useId().replace(/[^a-zA-Z0-9_-]/g, '')
  const ids = { gold: `${uid}-gold`, mark: `${uid}-mark`, upper: `${uid}-upper` }
  const [animated, setAnimated] = useState(() => !prefersReducedMotion())
  const animalRef = useRef<SVGGElement>(null)
  const upperRef = useRef<SVGPathElement>(null)
  const gustRefs = useRef<(SVGGElement | null)[]>([])
  const legRefs = useRef<(SVGPathElement | null)[]>([])

  useEffect(() => {
    const motion = typeof window.matchMedia === 'function' ? window.matchMedia(REDUCED_MOTION) : null
    let request = 0
    const nodes = () => {
      const animal = animalRef.current
      const upper = upperRef.current
      const gusts = gustRefs.current.filter((n): n is SVGGElement => n !== null)
      const legs = legRefs.current.filter((n): n is SVGPathElement => n !== null)
      return animal && upper && gusts.length === GUSTS.length && legs.length === LEGS.length ? { animal, upper, gusts, legs } : null
    }
    const frame = (t: number) => {
      const n = nodes()
      if (n) paintWalk(n, t)
      request = requestAnimationFrame(frame)
    }
    const sync = () => {
      cancelAnimationFrame(request)
      const enabled = !(motion?.matches ?? false)
      setAnimated(enabled)
      const n = nodes()
      if (enabled && n) paintWalk(n, performance.now())
      if (enabled && !document.hidden) request = requestAnimationFrame(frame)
    }
    motion?.addEventListener?.('change', sync)
    document.addEventListener('visibilitychange', sync)
    sync()
    return () => {
      cancelAnimationFrame(request)
      motion?.removeEventListener?.('change', sync)
      document.removeEventListener('visibilitychange', sync)
    }
  }, [])

  const className = ['splash', animated ? 'splash-animated' : '', leaving ? 'splash-leaving' : ''].filter(Boolean).join(' ')

  return (
    <div className={className} aria-hidden={leaving || undefined}>
      <section className="splash-brand" aria-label="نوادر الإبل">
        <svg className="splash-emblem" viewBox="44 44 460 436" aria-hidden="true" focusable="false">
          <defs>
            <linearGradient id={ids.gold} x1="0" y1=".1" x2="1" y2=".8" gradientUnits="objectBoundingBox">
              <stop stopColor="#b17a38" />
              <stop offset=".52" stopColor="#a96f30" />
              <stop offset="1" stopColor="#a06a30" />
            </linearGradient>
            <path id={ids.mark} fillRule="evenodd" d={MARK_PATH} />
            <clipPath id={ids.upper}>
              <path d={UPPER_CLIP_PATH} />
            </clipPath>
          </defs>
          <path fill={`url(#${ids.gold})`} fillRule="evenodd" d={RING_PATH} />
          <use className="splash-still" href={`#${ids.mark}`} fill={`url(#${ids.gold})`} />
          <g className="splash-walking">
            <g fill="#b68950" stroke="#b68950" strokeLinecap="round">
              <g ref={(n) => void (gustRefs.current[0] = n)} opacity="0">
                <path fill="none" strokeWidth="2.5" d="M0 1c12 2 20 1 34-3s28-5 43-1" />
                <path fill="none" strokeWidth="1.7" d="M20 8q11 1 20-2" />
                <circle cx="84" cy="-3" r="1.25" />
                <circle cx="-7" cy="1" r=".9" />
              </g>
              <g ref={(n) => void (gustRefs.current[1] = n)} opacity="0">
                <path fill="none" strokeWidth="2.4" d="M0 0c9-4 17-5 27-3s21 3 28 0" />
                <path fill="none" strokeWidth="1.5" d="M25 5q7 2 13 1" />
                <circle cx="61" cy="-4" r="1.25" />
              </g>
              <g ref={(n) => void (gustRefs.current[2] = n)} opacity="0">
                <path fill="none" strokeWidth="1.7" d="M0 1q10 2 22-1" />
                <circle cx="29" cy="-2" r="1.4" />
                <circle cx="36" cy="-4" r="1" />
                <circle cx="40" cy="0" r=".75" />
              </g>
            </g>
            <g ref={animalRef}>
              <g fill="#f8f3ea" stroke="#bc8a50" strokeWidth="6.7" strokeLinecap="round" strokeLinejoin="round">
                <path ref={(n) => void (legRefs.current[0] = n)} />
                <path ref={(n) => void (legRefs.current[1] = n)} />
              </g>
              <g fill="#f8f3ea" stroke="#aa7133" strokeWidth="8.6" strokeLinecap="round" strokeLinejoin="round">
                <path ref={(n) => void (legRefs.current[2] = n)} />
                <path ref={(n) => void (legRefs.current[3] = n)} />
              </g>
              <path ref={upperRef} clipPath={`url(#${ids.upper})`} fill={`url(#${ids.gold})`} fillRule="evenodd" d={MARK_PATH} />
            </g>
            <path d={GROUND_PATH} fill={`url(#${ids.gold})`} />
          </g>
        </svg>
        <p className="splash-status" role="status">
          جارٍ التحميل
        </p>
      </section>
      <svg className="splash-dunes" aria-hidden="true" viewBox="0 0 1440 140" preserveAspectRatio="none" focusable="false">
        <path fill="#f4ecdf" d="M0 58C163 16 355 15 576 68S1060 155 1440 47V140H0Z" />
        <path fill="none" stroke="#e6d8c2" strokeWidth=".9" d="M0 58C163 16 355 15 576 68S1060 155 1440 47" />
        <path fill="#f0e6d6" d="M0 95C282 171 580 132 813 83S1237 26 1440 68V140H0Z" />
        <path fill="none" stroke="#e2d2ba" strokeWidth=".85" d="M0 95C282 171 580 132 813 83S1237 26 1440 68" />
      </svg>
    </div>
  )
}
