import type { ReactNode } from 'react'

export type ChipTone = 'mute' | 'lime' | 'ink' | 'outline' | 'flame' | 'sky'

interface Props {
  tone?: ChipTone
  mono?: boolean
  children: ReactNode
}

const toneStyles: Record<ChipTone, { bg: string; fg: string; border?: string }> = {
  mute: { bg: 'var(--ink-06)', fg: 'var(--text-mute)' },
  lime: { bg: 'var(--lime)', fg: 'var(--ink)' },
  ink: { bg: 'var(--ink)', fg: 'var(--paper)' },
  outline: { bg: 'transparent', fg: 'var(--text-mute)', border: 'var(--border)' },
  flame: { bg: 'var(--flame)', fg: '#fff' },
  sky: { bg: 'var(--sky)', fg: '#082338' },
}

export function Chip({ tone = 'mute', mono = false, children }: Props) {
  const s = toneStyles[tone]
  return (
    <span
      style={{
        height: 20,
        display: 'inline-flex',
        alignItems: 'center',
        padding: '0 8px',
        borderRadius: '999px',
        background: s.bg,
        color: s.fg,
        border: s.border ? `1px solid ${s.border}` : 'none',
        fontFamily: mono ? '"Geist Mono", ui-monospace, Menlo, monospace' : 'Geist, system-ui, sans-serif',
        fontWeight: 600,
        fontSize: 10.5,
        letterSpacing: mono ? '0.08em' : '-0.005em',
        textTransform: mono ? 'uppercase' : 'none',
        whiteSpace: 'nowrap',
        lineHeight: 1,
      }}
    >
      {children}
    </span>
  )
}
