import { useEffect, useState, type ReactNode } from 'react'
import { SplashScreen } from './SplashScreen'

const IS_TEST = import.meta.env.MODE === 'test'

/** أقل مدة عرض، مثل مدة الثبات في شاشة بداية الجوال (1000ms)، كي لا تومض الشاشة. */
export const SPLASH_MIN_MS = IS_TEST ? 0 : 1000
/** مدة التلاشي؛ تطابق الانتقال في splash.css. */
export const SPLASH_FADE_MS = IS_TEST ? 0 : 240

/**
 * يعرض شاشة التحميل عند فتح اللوحة حتى يصبح `ready`، ثم يرسم المحتوى تحتها
 * ويُخفيها تدريجيًا. لا تعود الشاشة بعد ذلك ما دام المكوّن قائمًا.
 */
export function SplashGate({ ready, children }: { ready: boolean; children: ReactNode }) {
  const [start] = useState(() => performance.now())
  const [phase, setPhase] = useState<'show' | 'leave' | 'done'>('show')

  useEffect(() => {
    if (!ready || phase !== 'show') return
    const wait = Math.max(0, SPLASH_MIN_MS - (performance.now() - start))
    const timer = setTimeout(() => setPhase(SPLASH_FADE_MS > 0 ? 'leave' : 'done'), wait)
    return () => clearTimeout(timer)
  }, [ready, phase, start])

  useEffect(() => {
    if (phase !== 'leave') return
    const timer = setTimeout(() => setPhase('done'), SPLASH_FADE_MS)
    return () => clearTimeout(timer)
  }, [phase])

  // في الاختبارات (مدتان صفريتان) تختفي الشاشة في نفس العرض الذي يجهز فيه المحتوى.
  const instant = SPLASH_MIN_MS === 0 && SPLASH_FADE_MS === 0 && ready
  return (
    <>
      {ready && children}
      {phase !== 'done' && !instant && <SplashScreen leaving={phase === 'leave'} />}
    </>
  )
}
