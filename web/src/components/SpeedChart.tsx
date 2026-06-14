import { useTranslation } from 'react-i18next'

interface Props {
  upBars: number[]
  downBars: number[]
  height?: number
}

export function SpeedChart({ upBars, downBars, height = 96 }: Props) {
  const { t } = useTranslation()
  const count = Math.max(upBars.length, downBars.length, 1)
  const bars = Array.from({ length: count }, (_, i) => ({
    up: upBars[i] ?? 0,
    down: downBars[i] ?? 0,
  }))
  const peakUp = Math.max(...bars.map((b) => b.up), 0)
  const peakDown = Math.max(...bars.map((b) => b.down), 0)
  const max = Math.max(peakUp, peakDown, 1)

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
          {t('speedChart.title')}
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
            <span style={{ width: 8, height: 8, background: 'var(--flame)', borderRadius: 2 }} /> {t('speedChart.up')}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 8, height: 8, background: 'var(--sky)', borderRadius: 2 }} /> {t('speedChart.down')}
          </span>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height }}>
        {bars.map(({ up, down }, i) => {
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
                  minWidth: 0,
                }}
              >
                <div
                  style={{
                  height: `${(up / max) * 60}%`,
                  background: 'var(--flame)',
                  borderRadius: '3px 3px 0 0',
                  opacity: 0.92,
                }}
              />
                <div
                  style={{
                  height: `${(down / max) * 60}%`,
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
        <span>{t('speedChart.peakUp', { value: formatBps(peakUp) })}</span>
        <span>{t('speedChart.peakDown', { value: formatBps(peakDown) })}</span>
        <span>{bars.some((b) => b.up > 0 || b.down > 0) ? t('speedChart.liveSamples') : t('speedChart.waitingSamples')}</span>
      </div>
    </div>
  )
}

function formatBps(bps: number): string {
  if (!bps || bps <= 1) return '—'
  if (bps < 1024) return `${Math.round(bps)} B/s`
  if (bps < 1024 * 1024) return `${(bps / 1024).toFixed(1)} KB/s`
  return `${(bps / 1024 / 1024).toFixed(1)} MB/s`
}
