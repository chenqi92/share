import { Chip } from './Chip'

interface Props {
  peerCount: number
  connected?: boolean
  guestMode?: boolean
  hostIp?: string
  modeLabel?: string
}

export function StatusBar({ peerCount, connected = true, guestMode = true, hostIp = '192.168.1.42', modeLabel }: Props) {
  return (
    <div
      style={{
        height: 32,
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        padding: '0 16px',
        background: 'var(--bg2)',
        borderTop: '1px solid var(--border)',
        color: 'var(--text-mute)',
        fontFamily: '"Geist Mono", monospace',
        fontSize: 10.5,
        letterSpacing: '0.06em',
        textTransform: 'uppercase',
      }}
    >
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
        <span
          aria-hidden
          style={{
            width: 7,
            height: 7,
            borderRadius: '50%',
            background: connected ? 'var(--lime-deep)' : 'var(--error)',
            boxShadow: connected ? '0 0 0 3px rgba(168,200,0,0.15)' : 'none',
          }}
        />
        {connected ? 'CONNECTED' : 'OFFLINE'}
      </span>
      <span style={{ opacity: 0.4 }}>·</span>
      <span>GATEWAY · WSS</span>
      <span style={{ opacity: 0.4 }}>·</span>
      <span>{peerCount} peers</span>
      <span style={{ opacity: 0.4 }}>·</span>
      <span style={{ textTransform: 'none', letterSpacing: '0.02em' }}>{hostIp}</span>
      <span style={{ marginLeft: 'auto', display: 'inline-flex', gap: 6 }}>
        {modeLabel && <Chip tone="outline" mono>{modeLabel}</Chip>}
        {guestMode && <Chip tone="outline" mono>访客身份 · GUEST</Chip>}
        <Chip tone="outline" mono>关页即销毁</Chip>
      </span>
    </div>
  )
}
