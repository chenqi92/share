import type { ReactNode } from 'react'

interface Props {
  url: string
  hint?: string
  children: ReactNode
  browser?: 'Safari' | 'Chrome' | 'Firefox'
}

export function BrowserChrome({ url, hint, children, browser = 'Safari' }: Props) {
  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        background: 'var(--bg)',
        borderRadius: 14,
        overflow: 'hidden',
        border: '1px solid var(--border)',
        boxShadow: 'var(--shadow-card)',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* chrome top bar */}
      <div
        style={{
          height: 40,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '0 14px',
          background: 'var(--bg2)',
          borderBottom: '1px solid var(--border)',
          flexShrink: 0,
        }}
      >
        <div style={{ display: 'flex', gap: 7, flexShrink: 0 }}>
          {[
            ['#FF5F57', '#E0443E'],
            ['#FEBC2E', '#DEA123'],
            ['#28C840', '#1AAB29'],
          ].map(([c, b]) => (
            <span
              key={c}
              style={{
                width: 12,
                height: 12,
                borderRadius: '50%',
                background: c,
                boxShadow: `inset 0 0 0 1px ${b}`,
              }}
            />
          ))}
        </div>

        <div
          style={{
            marginLeft: 14,
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            color: 'var(--text-faint)',
            fontSize: 11,
          }}
        >
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" aria-hidden>
            <path d="M5 12V8a7 7 0 0 1 14 0v4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            <rect x="3" y="12" width="18" height="10" rx="2" stroke="currentColor" strokeWidth="2" />
          </svg>
        </div>

        <div
          style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: 'var(--bg)',
            border: '1px solid var(--border)',
            borderRadius: 8,
            height: 24,
            padding: '0 10px',
            color: 'var(--text-mute)',
            fontFamily: '"Geist Mono", monospace',
            fontSize: 11,
            letterSpacing: '0.01em',
            maxWidth: 720,
            margin: '0 auto',
          }}
        >
          <span style={{ color: 'var(--lime-deep)', marginRight: 6 }}>●</span>
          <span style={{ color: 'var(--text)' }}>{url}</span>
          {hint && (
            <span
              style={{
                marginLeft: 12,
                color: 'var(--text-faint)',
                fontSize: 10,
                textTransform: 'uppercase',
                letterSpacing: '0.16em',
              }}
            >
              · {hint}
            </span>
          )}
        </div>

        <div
          style={{
            color: 'var(--text-faint)',
            fontFamily: '"Geist Mono", monospace',
            fontSize: 10,
            textTransform: 'uppercase',
            letterSpacing: '0.18em',
            flexShrink: 0,
          }}
        >
          {browser}
        </div>
      </div>
      {/* viewport */}
      <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>{children}</div>
    </div>
  )
}
