import { AsciiDivider } from '../components/AsciiDivider'
import { Chip } from '../components/Chip'
import { FileCard } from '../components/FileCard'
import { StatusBar } from '../components/StatusBar'
import {
  MESHDROP_HISTORY_BY_DAY,
  MESHDROP_ME,
  type HistoryEntry,
} from '../lib/mockData'
import { useEngine } from '../hooks/useEngine'

function statusChip(item: HistoryEntry) {
  if (item.status === 'transferring') return <Chip tone="flame" mono>↑ {item.progress}% · 进行中</Chip>
  if (item.status === 'queued') return <Chip tone="outline" mono>· 排队中</Chip>
  if (item.status === 'failed') return <Chip tone="outline" mono>✕ 失败</Chip>
  return <Chip tone="lime" mono>✓ 已完成</Chip>
}

function HistoryCell({ item }: { item: HistoryEntry }) {
  const isImage = item.kind === 'image'
  const isText = item.kind === 'text'

  return (
    <div
      style={{
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 14,
        padding: 14,
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
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
        <span style={{ color: item.dir === 'incoming' ? 'var(--sky)' : 'var(--flame)' }}>
          {item.dir === 'incoming' ? '↓ FROM' : '↑ TO'} {item.peer}
        </span>
        <span>{item.time}</span>
      </div>

      {isImage && (
        <div
          style={{
            height: 130,
            borderRadius: 10,
            position: 'relative',
            overflow: 'hidden',
            background:
              'linear-gradient(165deg, #C7B8FF 0%, #FFD970 55%, #FFB4A1 100%)',
          }}
        >
          {/* fake horizon + sun */}
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: '60%',
              height: 1,
              background: 'rgba(0,0,0,0.18)',
            }}
          />
          <div
            style={{
              position: 'absolute',
              left: '24%',
              top: '36%',
              width: 38,
              height: 38,
              borderRadius: '50%',
              background: 'rgba(255,255,255,0.65)',
              boxShadow: '0 0 20px rgba(255,255,255,0.5)',
            }}
          />
          <svg
            viewBox="0 0 200 70"
            style={{ position: 'absolute', left: 0, right: 0, bottom: 0, width: '100%', height: 70 }}
          >
            <path d="M0,70 L40,30 L70,52 L120,18 L160,42 L200,28 L200,70 Z" fill="rgba(10,10,10,0.4)" />
          </svg>
          <div
            style={{
              position: 'absolute',
              right: 10,
              top: 10,
              fontFamily: '"Geist Mono", monospace',
              fontSize: 10,
              color: 'rgba(0,0,0,0.7)',
              background: 'rgba(255,255,255,0.6)',
              padding: '2px 8px',
              borderRadius: 999,
              letterSpacing: '0.06em',
              fontWeight: 700,
            }}
          >
            {item.count} 张 · HEIC
          </div>
        </div>
      )}

      {isText && (
        <div
          style={{
            padding: 12,
            borderRadius: 10,
            background: 'var(--bg)',
            border: '1px solid var(--border)',
            fontSize: 13,
            lineHeight: 1.55,
            color: 'var(--text)',
          }}
        >
          "{item.content}"
        </div>
      )}

      {!isImage && !isText && item.name && (
        <FileCard
          ext={item.ext ?? 'file'}
          name={item.name}
          size={item.size}
          progress={item.status === 'transferring' ? item.progress : undefined}
        />
      )}

      <div className="flex items-center justify-between" style={{ marginTop: 'auto' }}>
        {statusChip(item)}
        <span
          style={{
            fontFamily: '"Geist Mono", monospace',
            fontSize: 10,
            color: 'var(--text-faint)',
            letterSpacing: '0.12em',
            textTransform: 'uppercase',
          }}
        >
          {item.dir === 'incoming' ? 'INCOMING · 收到' : 'OUTGOING · 发出'}
        </span>
      </div>
    </div>
  )
}

export function HistoryPage() {
  const devices = useEngine((s) => s.devices)
  const liveHistory = useEngine((s) => s.history)
  const mode = useEngine((s) => s.mode)
  const peerCount = devices.filter((d) => d.online).length
  const history = mode === 'live' ? liveHistory : MESHDROP_HISTORY_BY_DAY

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      <div
        className="scroll-thin"
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '22px 26px 24px',
          display: 'flex',
          flexDirection: 'column',
          gap: 20,
        }}
      >
        <header className="flex items-end justify-between flex-wrap gap-3">
          <div>
            <div
              style={{
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                color: 'var(--text-faint)',
                letterSpacing: '0.22em',
                textTransform: 'uppercase',
                marginBottom: 6,
              }}
            >
              历史 · HISTORY
            </div>
            <h1 className="font-display" style={{ fontSize: 30, fontWeight: 700, letterSpacing: '-0.025em', lineHeight: 1 }}>
              这台浏览器上发生过的 13 件事
            </h1>
            <p style={{ marginTop: 8, color: 'var(--text-mute)', fontSize: 13.5, maxWidth: 600 }}>
              访客身份下，历史只保留在内存里 — 关掉浏览器即清空。永久记录请在 native 端开启。
            </p>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Chip tone="ink" mono>● 仅本会话</Chip>
            <Chip tone="outline" mono>4 收 / 9 发</Chip>
            <Chip tone="outline" mono>2 失败</Chip>
          </div>
        </header>

        {history.length === 0 && (
          <div style={{
            padding: '40px 20px', textAlign: 'center', color: 'var(--text-faint)',
            fontFamily: '"Geist Mono", monospace', fontSize: 12, letterSpacing: '0.12em', textTransform: 'uppercase',
          }}>
            还没有任何收发 · NO HISTORY YET
          </div>
        )}
        {history.map((day) => (
          <section key={day.label} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <AsciiDivider label={`—— ${day.label} ——`} />
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
                gap: 12,
              }}
            >
              {day.items.map((item) => (
                <HistoryCell key={item.id} item={item} />
              ))}
            </div>
          </section>
        ))}
      </div>

      <StatusBar peerCount={peerCount} hostIp={MESHDROP_ME.hostIp} />
    </div>
  )
}
