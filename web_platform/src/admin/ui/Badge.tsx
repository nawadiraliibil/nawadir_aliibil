import type { ReactNode } from 'react'

export type Tone = 'neutral' | 'success' | 'warning' | 'danger' | 'info' | 'gold'

export function Badge({ tone = 'neutral', children, title }: { tone?: Tone; children: ReactNode; title?: string }) {
  return (
    <span className={`badge badge-${tone}`} title={title}>
      {children}
    </span>
  )
}

const LISTING_TONES: Record<string, Tone> = {
  PUBLISHED: 'success',
  HIDDEN: 'danger',
  ARCHIVED: 'neutral',
  DRAFT: 'info',
  REJECTED: 'warning',
  UNDER_REVIEW: 'warning',
}

export function listingStatusTone(status: string | null | undefined): Tone {
  return (status && LISTING_TONES[status]) || 'neutral'
}

export function accountStatusTone(status: string | null | undefined): Tone {
  return status === 'SUSPENDED' ? 'danger' : status === 'ACTIVE' ? 'success' : 'neutral'
}

export function reportStatusTone(status: string | null | undefined): Tone {
  return status === 'OPEN' ? 'warning' : status === 'IN_REVIEW' ? 'info' : status === 'CLOSED' ? 'neutral' : 'neutral'
}
