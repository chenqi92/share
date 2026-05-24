import type { ReactNode } from 'react'

interface Props {
  children: ReactNode
  accent?: boolean
  size?: number
  title?: string
  onClick?: () => void
}

export function IconBtn({ children, accent, size = 32, title, onClick }: Props) {
  return (
    <button
      title={title}
      aria-label={title}
      onClick={onClick}
      style={{
        width: size,
        height: size,
        borderRadius: 10,
        background: accent ? 'var(--lime)' : 'transparent',
        color: accent ? 'var(--ink)' : 'var(--text)',
        border: `1px solid ${accent ? 'var(--lime)' : 'var(--border)'}`,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        transition: 'transform 160ms ease',
      }}
    >
      {children}
    </button>
  )
}
