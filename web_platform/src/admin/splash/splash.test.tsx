import { render, screen } from '@testing-library/react'
import { afterEach, vi } from 'vitest'
import { SplashGate } from './SplashGate'
import { SplashScreen } from './SplashScreen'
import { LEGS } from './walk'

function mockReducedMotion(reduced: boolean) {
  vi.stubGlobal(
    'matchMedia',
    vi.fn().mockImplementation((query: string) => ({
      matches: reduced && query.includes('reduce'),
      media: query,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  )
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('SplashScreen', () => {
  it('announces loading and draws the walking camel', () => {
    mockReducedMotion(false)
    const { container } = render(<SplashScreen />)
    expect(screen.getByRole('status')).toHaveTextContent('جارٍ التحميل')
    const root = container.querySelector('.splash')!
    expect(root).toHaveClass('splash-animated')
    // أول إطار يرسم الأرجل الأربع فورًا دون انتظار requestAnimationFrame.
    const legs = container.querySelectorAll('.splash-walking g[stroke-linejoin] path')
    expect(legs).toHaveLength(LEGS.length)
    legs.forEach((leg) => expect(leg.getAttribute('d')).toMatch(/^M /))
  })

  it('shows the still emblem with reduced motion', () => {
    mockReducedMotion(true)
    const { container } = render(<SplashScreen />)
    expect(container.querySelector('.splash')).not.toHaveClass('splash-animated')
    expect(container.querySelector('.splash-still')).toBeInTheDocument()
  })

  it('gives each instance its own SVG ids', () => {
    mockReducedMotion(true)
    const { container } = render(
      <>
        <SplashScreen />
        <SplashScreen />
      </>,
    )
    const ids = Array.from(container.querySelectorAll('[id]')).map((n) => n.id)
    expect(new Set(ids).size).toBe(ids.length)
  })
})

describe('SplashGate', () => {
  it('shows only the splash until ready, then the content', () => {
    mockReducedMotion(true)
    const { rerender } = render(
      <SplashGate ready={false}>
        <p>المحتوى</p>
      </SplashGate>,
    )
    expect(screen.getByRole('status')).toHaveTextContent('جارٍ التحميل')
    expect(screen.queryByText('المحتوى')).not.toBeInTheDocument()

    rerender(
      <SplashGate ready>
        <p>المحتوى</p>
      </SplashGate>,
    )
    expect(screen.getByText('المحتوى')).toBeInTheDocument()
    expect(screen.queryByRole('status')).not.toBeInTheDocument()
  })
})
