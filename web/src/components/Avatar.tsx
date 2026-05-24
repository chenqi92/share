interface Props {
  initials: string
  color: string
  size?: number
  ring?: 'lime' | 'flame' | 'sky' | 'none'
}

export function Avatar({ initials, color, size = 32, ring = 'none' }: Props) {
  const ringColor =
    ring === 'lime' ? 'var(--lime)' :
    ring === 'flame' ? 'var(--flame)' :
    ring === 'sky' ? 'var(--sky)' : 'transparent'

  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: color,
        color: '#0a0a0a',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: '"Space Grotesk", system-ui, sans-serif',
        fontWeight: 700,
        fontSize: Math.round(size * 0.42),
        letterSpacing: '-0.02em',
        boxShadow: ring !== 'none' ? `0 0 0 2px ${ringColor}, 0 0 0 4px var(--bg)` : 'none',
        flexShrink: 0,
        userSelect: 'none',
      }}
    >
      {initials}
    </div>
  )
}
