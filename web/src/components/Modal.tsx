import type { ReactNode } from 'react'

interface Props {
  open: boolean
  title?: string
  onClose: () => void
  children: ReactNode
  maxWidth?: number
}

export function Modal({ open, title, onClose, children, maxWidth = 520 }: Props) {
  if (!open) return null
  return (
    <div
      role="dialog"
      aria-modal="true"
      onClick={onClose}
      style={{
        position: 'absolute',
        inset: 0,
        background: 'rgba(8,6,4,0.78)',
        backdropFilter: 'blur(6px)',
        WebkitBackdropFilter: 'blur(6px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 50,
        padding: 24,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth,
          background: 'var(--surface)',
          border: '1px solid var(--border)',
          borderRadius: 16,
          boxShadow: 'var(--shadow-card)',
          padding: 22,
          color: 'var(--text)',
        }}
      >
        {title && (
          <div
            className="font-display"
            style={{
              fontSize: 18,
              fontWeight: 700,
              letterSpacing: '-0.015em',
              marginBottom: 12,
            }}
          >
            {title}
          </div>
        )}
        {children}
      </div>
    </div>
  )
}
