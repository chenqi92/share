interface Props {
  size?: number
  stroke?: string
  showDot?: boolean
}

export function MeshDropMark({ size = 28, stroke }: Props) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      aria-hidden="true"
      style={{ display: 'block' }}
    >
      <circle cx="9" cy="12" r="6.5" fill="none" stroke={stroke ?? 'currentColor'} strokeWidth="2" />
      <circle cx="15" cy="12" r="6.5" fill="none" stroke={stroke ?? 'currentColor'} strokeWidth="2" />
      <circle cx="12" cy="12" r="1.8" fill="var(--lime)" />
    </svg>
  )
}

export function MeshDropWordmark({ size = 22 }: { size?: number }) {
  return (
    <span
      className="font-display inline-flex items-baseline"
      style={{
        fontWeight: 600,
        letterSpacing: '-0.025em',
        fontSize: size,
        lineHeight: 1,
        color: 'var(--text)',
      }}
    >
      meshdrop
      <span
        style={{
          display: 'inline-block',
          width: size * 0.22,
          height: size * 0.22,
          marginLeft: size * 0.06,
          marginBottom: size * 0.04,
          borderRadius: '999px',
          background: 'var(--lime)',
        }}
      />
    </span>
  )
}

export function MeshDropLockup({ size = 28 }: { size?: number }) {
  return (
    <div className="inline-flex items-center gap-2.5" style={{ color: 'var(--text)' }}>
      <MeshDropMark size={size} />
      <MeshDropWordmark size={size * 0.82} />
    </div>
  )
}
