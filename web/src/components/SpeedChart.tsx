interface Props {
  upBars: number[]
  downBars: number[]
  height?: number
}

export function SpeedChart({ upBars, downBars, height = 96 }: Props) {
  const max = Math.max(...upBars, ...downBars, 14)

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 14,
        padding: '16px 18px',
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 14,
      }}
    >
      <div className="flex items-center justify-between">
        <div
          className="font-display"
          style={{ fontSize: 13, fontWeight: 700, letterSpacing: '-0.005em' }}
        >
          实时吞吐 · LIVE THROUGHPUT
        </div>
        <div
          className="flex items-center gap-4"
          style={{
            fontFamily: '"Geist Mono", monospace',
            fontSize: 10.5,
            color: 'var(--text-mute)',
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
          }}
        >
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 8, height: 8, background: 'var(--flame)', borderRadius: 2 }} /> ↑ 上行
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 8, height: 8, background: 'var(--sky)', borderRadius: 2 }} /> ↓ 下行
          </span>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height }}>
        {upBars.map((u, i) => {
          const d = downBars[i] ?? 0
          return (
            <div
              key={i}
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'flex-end',
                height: '100%',
                gap: 2,
              }}
            >
              <div
                style={{
                  height: `${(u / max) * 60}%`,
                  background: 'var(--flame)',
                  borderRadius: '3px 3px 0 0',
                  opacity: 0.92,
                }}
              />
              <div
                style={{
                  height: `${(d / max) * 60}%`,
                  background: 'var(--sky)',
                  borderRadius: '0 0 3px 3px',
                  opacity: 0.92,
                }}
              />
            </div>
          )
        })}
      </div>

      <div
        className="flex items-center justify-between"
        style={{
          fontFamily: '"Geist Mono", monospace',
          fontSize: 10.5,
          color: 'var(--text-faint)',
          letterSpacing: '0.06em',
          textTransform: 'uppercase',
        }}
      >
        <span>peak ↑ 12.6 MB/s</span>
        <span>peak ↓ 11.7 MB/s</span>
        <span>session 6m 12s</span>
      </div>
    </div>
  )
}
