interface Props {
  ext: string
  name: string
  size?: string
  meta?: string
  progress?: number
  width?: number
  height?: number
}

function extPalette(ext: string): { fg: string; bg: string } {
  const e = ext.toLowerCase()
  if (['fig', 'sketch', 'xd', 'ai'].includes(e)) return { fg: '#4DB8FF', bg: 'rgba(77,184,255,0.12)' }
  if (['zip', 'rar', '7z', 'tar', 'gz'].includes(e)) return { fg: '#FF5A2C', bg: 'rgba(255,90,44,0.12)' }
  if (['pdf', 'pages', 'doc', 'docx'].includes(e)) return { fg: '#C4322B', bg: 'rgba(196,50,43,0.12)' }
  if (['mp4', 'mov', 'mkv', 'webm'].includes(e)) return { fg: '#A8C800', bg: 'rgba(168,200,0,0.12)' }
  if (['heic', 'jpg', 'jpeg', 'png', 'gif', 'webp'].includes(e)) return { fg: '#C7B8FF', bg: 'rgba(199,184,255,0.18)' }
  if (['md', 'txt'].includes(e)) return { fg: '#A8C800', bg: 'rgba(168,200,0,0.10)' }
  return { fg: 'var(--text-mute)', bg: 'var(--ink-06)' }
}

export function FileCard({ ext, name, size, meta, progress, width = 38, height = 46 }: Props) {
  const palette = extPalette(ext)
  const fold = Math.min(12, Math.round(width * 0.32))
  return (
    <div className="flex items-center gap-3">
      <div
        style={{
          position: 'relative',
          width,
          height,
          flexShrink: 0,
          background: 'var(--card)',
          border: '1px solid var(--border)',
          borderRadius: 3,
          color: palette.fg,
          fontFamily: '"Geist Mono", ui-monospace, monospace',
          fontWeight: 700,
          fontSize: Math.max(8, Math.round(width * 0.22)),
          textTransform: 'uppercase',
          letterSpacing: '0.05em',
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'center',
          paddingBottom: 4,
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 0,
            right: 0,
            width: fold,
            height: fold,
            background: palette.bg,
            borderLeft: '1px solid var(--border)',
            borderBottom: '1px solid var(--border)',
            clipPath: `polygon(0 0, 100% 100%, 0 100%)`,
          }}
        />
        <span
          style={{
            position: 'absolute',
            top: 0,
            right: 0,
            width: fold,
            height: fold,
            clipPath: `polygon(100% 0, 100% 100%, 0 0)`,
            background: 'var(--bg)',
          }}
        />
        {ext}
      </div>
      <div className="min-w-0 flex-1">
        <div
          className="truncate font-display"
          style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--text)', letterSpacing: '-0.005em' }}
        >
          {name}
        </div>
        <div
          className="truncate"
          style={{
            fontFamily: '"Geist Mono", monospace',
            fontSize: 10.5,
            color: 'var(--text-faint)',
            marginTop: 2,
            letterSpacing: '0.01em',
          }}
        >
          {[size, meta].filter(Boolean).join(' · ')}
        </div>
        {typeof progress === 'number' && (
          <div
            style={{
              marginTop: 6,
              height: 3,
              borderRadius: 999,
              background: 'var(--ink-06)',
              overflow: 'hidden',
            }}
          >
            <div
              style={{
                width: `${progress}%`,
                height: '100%',
                background: 'var(--flame)',
              }}
            />
          </div>
        )}
      </div>
    </div>
  )
}
