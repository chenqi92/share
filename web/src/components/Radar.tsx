import type { MeshDevice } from '../lib/mockData'

interface Props {
  devices: MeshDevice[]
  size?: number
  selectedId?: string
  meIp?: string
}

export function Radar({ devices, size = 320, selectedId, meIp = '' }: Props) {
  const c = size / 2
  const maxR = c - 14

  return (
    <div
      style={{
        position: 'relative',
        width: size,
        height: size,
        margin: '0 auto',
      }}
    >
      <svg
        viewBox={`0 0 ${size} ${size}`}
        width={size}
        height={size}
        style={{ position: 'absolute', inset: 0 }}
      >
        {/* concentric rings */}
        {[1 / 3, 2 / 3, 1].map((r, i) => (
          <circle
            key={i}
            cx={c}
            cy={c}
            r={maxR * r}
            fill="none"
            stroke="var(--border)"
            strokeWidth="1"
            strokeDasharray={i === 2 ? '0' : '2 4'}
          />
        ))}
        {/* crosshair */}
        <line x1={c} y1={c - maxR} x2={c} y2={c + maxR} stroke="var(--border)" strokeWidth="1" />
        <line x1={c - maxR} y1={c} x2={c + maxR} y2={c} stroke="var(--border)" strokeWidth="1" />

        {/* selected dashed lead-line */}
        {selectedId && (() => {
          const peer = devices.find((d) => d.id === selectedId)
          if (!peer) return null
          const a = ((peer.angle - 90) * Math.PI) / 180
          const x = c + Math.cos(a) * maxR * peer.dist
          const y = c + Math.sin(a) * maxR * peer.dist
          return (
            <line
              x1={c}
              y1={c}
              x2={x}
              y2={y}
              stroke="var(--flame)"
              strokeWidth="1.4"
              strokeDasharray="3 4"
            />
          )
        })()}
      </svg>

      {/* sweep arm */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          animation: 'radarSweep 4.5s linear infinite',
          transformOrigin: 'center',
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: c - 1,
            top: 14,
            width: 2,
            height: c - 14,
            background:
              'linear-gradient(to bottom, rgba(221,249,75,0.85), rgba(221,249,75,0))',
            transformOrigin: 'bottom center',
            borderRadius: 2,
          }}
        />
      </div>

      {/* compass letters */}
      {['N', 'E', 'S', 'W'].map((l, i) => {
        const pos = [
          { left: c - 6, top: 0 },
          { left: size - 14, top: c - 7 },
          { left: c - 5, top: size - 14 },
          { left: 2, top: c - 7 },
        ][i]
        return (
          <span
            key={l}
            style={{
              position: 'absolute',
              ...pos,
              fontFamily: '"Geist Mono", monospace',
              fontWeight: 700,
              fontSize: 10,
              color: 'var(--text-faint)',
              letterSpacing: '0.15em',
            }}
          >
            {l}
          </span>
        )
      })}

      {/* center YOU bubble */}
      <div
        style={{
          position: 'absolute',
          left: c - 30,
          top: c - 30,
          width: 60,
          height: 60,
          background: 'var(--ink)',
          color: 'var(--paper)',
          borderRadius: '50%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 1,
          boxShadow: '0 0 0 4px var(--bg)',
        }}
      >
        <span
          style={{
            fontFamily: '"Space Grotesk", sans-serif',
            fontWeight: 700,
            fontSize: 14,
            letterSpacing: '-0.02em',
          }}
        >
          YOU
        </span>
        <span
          style={{
            fontFamily: '"Geist Mono", monospace',
            fontSize: 8.5,
            opacity: 0.7,
          }}
        >
          {meIp}
        </span>
      </div>

      {/* device dots */}
      {devices.map((d, i) => {
        const a = ((d.angle - 90) * Math.PI) / 180
        const x = c + Math.cos(a) * maxR * d.dist
        const y = c + Math.sin(a) * maxR * d.dist
        const isSel = d.id === selectedId
        return (
          <div
            key={d.id}
            style={{
              position: 'absolute',
              left: x - 18,
              top: y - 18,
              width: 36,
              height: 36,
            }}
          >
            {d.online && (
              <span
                style={{
                  position: 'absolute',
                  inset: -8,
                  borderRadius: '50%',
                  background: isSel ? 'rgba(255,90,44,0.30)' : 'rgba(221,249,75,0.28)',
                  animation: 'pulseHalo 2.6s ease-out infinite',
                  animationDelay: `${i * 0.3}s`,
                }}
              />
            )}
            <div
              style={{
                position: 'absolute',
                inset: 0,
                borderRadius: '50%',
                background: d.color,
                color: '#0a0a0a',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontFamily: '"Space Grotesk", sans-serif',
                fontWeight: 700,
                fontSize: 13,
                boxShadow: isSel
                  ? '0 0 0 2.5px var(--flame), 0 0 0 5px var(--bg)'
                  : '0 0 0 2.5px var(--bg)',
              }}
            >
              {d.initials}
            </div>
            <div
              style={{
                position: 'absolute',
                top: 40,
                left: -20,
                width: 80,
                textAlign: 'center',
                color: 'var(--text-mute)',
                fontFamily: '"Geist Mono", monospace',
                fontSize: 9.5,
                letterSpacing: '0.02em',
                lineHeight: 1.25,
              }}
            >
              <div style={{ color: 'var(--text)', fontWeight: 700 }}>{d.who}</div>
              <div>{d.rtt} ms · {d.os.split(' ')[0]}</div>
            </div>
          </div>
        )
      })}
    </div>
  )
}
