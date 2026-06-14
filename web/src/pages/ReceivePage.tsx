import { useEngine } from '../hooks/useEngine'
import { MESHDROP_PENDING_OFFER } from '../lib/mockData'
import { Avatar } from '../components/Avatar'
import { Chip } from '../components/Chip'
import { FileCard } from '../components/FileCard'
import { KindGlyph } from '../components/KindGlyph'
import { StatusBar } from '../components/StatusBar'
import { AsciiDivider } from '../components/AsciiDivider'

export function ReceivePage() {
  const devices = useEngine((s) => s.devices)
  const me = useEngine((s) => s.me)
  const mode = useEngine((s) => s.mode)
  const conn = useEngine((s) => s.conn)
  const live = useEngine((s) => s.pendingOffer)
  const acceptOffer = useEngine((s) => s.acceptOffer)
  const rejectOffer = useEngine((s) => s.rejectOffer)
  // live 模式没待审项时显示空态；preview 模式下用 mock 让 UI 不空
  const offer = live ?? (mode === 'mock' ? MESHDROP_PENDING_OFFER : undefined)
  const peer = offer
    ? devices.find((d) => d.who === offer.peer) ?? devices[2] ?? { initials: '?', color: '#ccc', kind: 'mac' as const, os: '', rtt: 0 }
    : undefined
  const peerCount = devices.filter((d) => d.online).length

  if (!offer || !peer) {
    return (
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{
          flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--text-faint)', fontFamily: '"Geist Mono", monospace',
          fontSize: 13, letterSpacing: '0.1em', textTransform: 'uppercase',
        }}>
          没有待审项 · NO PENDING OFFER
        </div>
        <StatusBar peerCount={peerCount} hostIp={me.hostIp} connected={mode === 'live' ? conn === 'open' : true} />
      </div>
    )
  }

  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: 'var(--ink)',
      }}
    >
      {/* faint ghost backdrop strip */}
      <div
        aria-hidden
        style={{
          flex: '0 0 auto',
          minHeight: 56,
          padding: '14px 26px',
          display: 'flex',
          gap: 18,
          alignItems: 'center',
          borderBottom: '1px solid var(--border)',
          background: 'var(--bg2)',
          opacity: 0.55,
        }}
      >
        <div style={{ height: 16, width: 90, background: 'var(--surface)', borderRadius: 8 }} />
        <div style={{ height: 16, width: 200, background: 'var(--surface)', borderRadius: 8 }} />
        <div style={{ height: 16, width: 120, background: 'var(--surface)', borderRadius: 8 }} />
        <div
          style={{
            marginLeft: 'auto',
            fontFamily: '"Geist Mono", monospace',
            fontSize: 10,
            color: 'var(--text-faint)',
            letterSpacing: '0.2em',
            textTransform: 'uppercase',
          }}
        >
          MainPage 已暂停 · paused
        </div>
      </div>

      <div
        style={{
          flex: 1,
          minHeight: 600,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '32px 24px',
          background: 'var(--ink)',
        }}
      >
        <div
          style={{
            width: 'min(560px, 100%)',
            background: 'var(--surface)',
            borderRadius: 20,
            border: '2px solid var(--lime)',
            padding: '24px 26px 22px',
            color: 'var(--text)',
          }}
        >
          <div
            className="flex items-center gap-2"
            style={{
              color: 'var(--lime-deep)',
              fontFamily: '"Geist Mono", monospace',
              fontSize: 10.5,
              letterSpacing: '0.22em',
              textTransform: 'uppercase',
              fontWeight: 700,
            }}
          >
            <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--lime-deep)' }} />
            INCOMING · {offer.peer} 想发给你
            <span style={{ color: 'var(--text-faint)', marginLeft: 'auto' }}>{offer.receivedAt}</span>
          </div>

          <div className="flex items-center gap-3" style={{ marginTop: 14 }}>
            <Avatar initials={peer.initials} color={peer.color} size={44} ring="lime" />
            <div>
              <div
                className="font-display"
                style={{ fontSize: 18, fontWeight: 700, letterSpacing: '-0.018em' }}
              >
                {offer.peer}
              </div>
              <div
                style={{
                  marginTop: 2,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  color: 'var(--text-faint)',
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 10.5,
                  letterSpacing: '0.02em',
                }}
              >
                <KindGlyph kind={peer.kind} size={9} />
                {peer.os} · {peer.rtt} ms · 已配对
              </div>
            </div>
          </div>

          <div
            style={{
              marginTop: 18,
              padding: 14,
              background: 'var(--bg)',
              border: '1px solid var(--border)',
              borderRadius: 14,
            }}
          >
            <FileCard
              ext={offer.ext ?? 'file'}
              name={offer.fileName}
              size={offer.fileSize}
              meta={`${offer.pages ?? '—'} 页 · LAN · 明文 v0.1`}
            />
          </div>

          {offer.note && (
            <div
              style={{
                marginTop: 12,
                padding: '10px 14px',
                borderLeft: '3px solid var(--flame)',
                background: 'var(--flame-fill)',
                borderRadius: 8,
                fontSize: 13,
                color: 'var(--text)',
                lineHeight: 1.45,
              }}
            >
              <div
                style={{
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 10,
                  color: 'var(--flame)',
                  letterSpacing: '0.16em',
                  textTransform: 'uppercase',
                  marginBottom: 4,
                }}
              >
                ¶ 文字便签 · NOTE
              </div>
              "{offer.note}"
            </div>
          )}

          <div style={{ marginTop: 18 }}>
            <AsciiDivider label="—— 你确认接收吗？ · ACCEPT?" />
          </div>

          <div className="flex items-center gap-2 flex-wrap" style={{ marginTop: 14 }}>
            <Chip tone="outline" mono>● LAN · 明文 v0.1</Chip>
            <Chip tone="outline" mono>SHA-256 校验</Chip>
            <Chip tone="outline" mono>LAN ONLY</Chip>
            <Chip tone="outline" mono>{offer.fileSize}</Chip>
          </div>

          <div className="flex gap-3" style={{ marginTop: 18 }}>
            <button
              onClick={() => { void rejectOffer() }}
              style={{
                flex: 1,
                padding: '12px 18px',
                borderRadius: 12,
                background: 'transparent',
                border: '1px solid var(--border)',
                color: 'var(--text)',
                fontWeight: 600,
                fontSize: 13.5,
              }}
            >
              × 不接收
            </button>
            <button
              onClick={() => { void acceptOffer() }}
              style={{
                flex: 1.5,
                padding: '12px 18px',
                borderRadius: 12,
                background: 'var(--lime)',
                color: 'var(--ink)',
                fontWeight: 700,
                fontSize: 13.5,
              }}
            >
              接收并打开 →
            </button>
          </div>
        </div>
      </div>

      <StatusBar peerCount={peerCount} hostIp={me.hostIp} connected={mode === 'live' ? conn === 'open' : true} />
    </div>
  )
}
