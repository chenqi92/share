import { MESHDROP_PENDING_OFFER, MESHDROP_DEVICES, MESHDROP_ME } from '../lib/mockData'
import { Avatar } from '../components/Avatar'
import { Chip } from '../components/Chip'
import { FileCard } from '../components/FileCard'
import { KindGlyph } from '../components/KindGlyph'
import { StatusBar } from '../components/StatusBar'
import { AsciiDivider } from '../components/AsciiDivider'

export function ReceivePage() {
  const offer = MESHDROP_PENDING_OFFER
  const peer = MESHDROP_DEVICES.find((d) => d.who === offer.peer) ?? MESHDROP_DEVICES[2]
  const peerCount = MESHDROP_DEVICES.filter((d) => d.online).length

  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: 'rgba(8,6,4,0.92)',
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
          background:
            'radial-gradient(120% 80% at 50% 0%, rgba(221,249,75,0.10), transparent 60%), rgba(8,6,4,0.85)',
          backdropFilter: 'blur(8px)',
          WebkitBackdropFilter: 'blur(8px)',
        }}
      >
        <div
          style={{
            width: 'min(560px, 100%)',
            background: 'var(--surface)',
            borderRadius: 20,
            border: '2px solid var(--lime)',
            padding: '24px 26px 22px',
            boxShadow: '0 30px 80px -16px rgba(0,0,0,0.6), 0 0 0 6px rgba(221,249,75,0.10)',
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
            INCOMING · 嘉伟想发给你
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
                {peer.os} · {peer.rtt} ms · 已配对 · ● 已验证
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
              meta={`${offer.pages ?? '—'} 页 · 端到端加密`}
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
                🏷 文字便签 · NOTE
              </div>
              "{offer.note}"
            </div>
          )}

          <div style={{ marginTop: 18 }}>
            <AsciiDivider label="—— 你确认接收吗？ · ACCEPT?" />
          </div>

          <div className="flex items-center gap-2 flex-wrap" style={{ marginTop: 14 }}>
            <Chip tone="lime" mono>● E2E ENCRYPTED</Chip>
            <Chip tone="outline" mono>SHA-256 校验</Chip>
            <Chip tone="outline" mono>LAN ONLY</Chip>
            <Chip tone="outline" mono>3.4 MB · 预计 0.4s</Chip>
          </div>

          <div className="flex gap-3" style={{ marginTop: 18 }}>
            <button
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
              ✕ 不接收
            </button>
            <button
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
              ✓ 接收并打开
            </button>
          </div>
        </div>
      </div>

      <StatusBar peerCount={peerCount} hostIp={MESHDROP_ME.hostIp} />
    </div>
  )
}
