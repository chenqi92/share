import { useState } from 'react'
import { HeroBand } from '../components/HeroBand'
import { DropZone } from '../components/DropZone'
import { PeerRow } from '../components/PeerRow'
import { StatusBar } from '../components/StatusBar'
import { Chip } from '../components/Chip'
import { AsciiDivider } from '../components/AsciiDivider'
import { FileCard } from '../components/FileCard'
import { Modal } from '../components/Modal'
import { useMockEngine } from '../hooks/useMockEngine'
import { MESHDROP_ME } from '../lib/mockData'

export function MainPage() {
  const { devices, selectedPeerId, selectPeer, transfers } = useMockEngine()
  const [dragOverPeer, setDragOverPeer] = useState<string | undefined>()
  const [pasteOpen, setPasteOpen] = useState(false)
  const [pasteText, setPasteText] = useState('')
  const [toast, setToast] = useState<string | undefined>()

  const selected = devices.find((d) => d.id === selectedPeerId)
  const peerCount = devices.filter((d) => d.online).length
  const session = transfers.filter((t) => t.state === 'sending' || t.state === 'queued').slice(0, 3)

  const fireToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(undefined), 2400)
  }

  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: 'var(--bg)',
      }}
    >
      <div
        className="scroll-thin"
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '20px 26px 24px',
          display: 'flex',
          flexDirection: 'column',
          gap: 18,
        }}
      >
        <HeroBand peerCount={peerCount} />

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '280px 1fr',
            gap: 18,
            alignItems: 'stretch',
            minHeight: 420,
          }}
        >
          {/* Nearby rail */}
          <aside
            style={{
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              borderRadius: 16,
              padding: '14px 14px 16px',
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
            }}
          >
            <div className="flex items-center justify-between" style={{ marginBottom: 4 }}>
              <div
                className="font-display"
                style={{ fontSize: 13, fontWeight: 700, letterSpacing: '-0.005em' }}
              >
                附近 · NEARBY
              </div>
              <Chip tone="outline" mono>{peerCount}</Chip>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {devices.map((d) => (
                <PeerRow
                  key={d.id}
                  device={d}
                  selected={selectedPeerId === d.id}
                  dragOver={dragOverPeer === d.id}
                  onSelect={() => selectPeer(d.id)}
                  onDragOver={(over) => setDragOverPeer(over ? d.id : undefined)}
                  onDrop={() => {
                    setDragOverPeer(undefined)
                    fireToast(`已发送给 ${d.who}（mock）`)
                  }}
                />
              ))}
            </div>

            <div style={{ marginTop: 6 }}>
              <AsciiDivider label="—— 你是谁 · WHO ARE YOU" />
            </div>

            <div
              style={{
                marginTop: 8,
                padding: '12px 12px',
                borderRadius: 12,
                background: 'var(--bg2)',
                border: '1px solid var(--border)',
              }}
            >
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 10.5,
                  letterSpacing: '0.12em',
                  textTransform: 'uppercase',
                  color: 'var(--lime-deep)',
                }}
              >
                <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--lime-deep)' }} />
                {MESHDROP_ME.visibility}
              </div>
              <div
                className="font-display"
                style={{
                  marginTop: 6,
                  fontSize: 14,
                  fontWeight: 700,
                  letterSpacing: '-0.005em',
                  color: 'var(--text)',
                }}
              >
                {MESHDROP_ME.name}
              </div>
              <div
                style={{
                  marginTop: 4,
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 10.5,
                  color: 'var(--text-faint)',
                  letterSpacing: '0.01em',
                  lineHeight: 1.45,
                }}
              >
                {MESHDROP_ME.os}
                <br />
                {MESHDROP_ME.ip}
                <br />
                匿名访客 · 关浏览器即下线
              </div>
            </div>
          </aside>

          {/* Drop zone */}
          <DropZone
            selectedPeerName={selected?.who}
            onFiles={() => fireToast('已添加文件（mock）')}
            onPasteText={() => setPasteOpen(true)}
            forceHighlight={!!dragOverPeer}
          />
        </div>

        {/* Session strip */}
        <div
          style={{
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            borderRadius: 14,
            padding: '14px 18px 16px',
          }}
        >
          <div className="flex items-center justify-between" style={{ marginBottom: 12 }}>
            <div className="flex items-center gap-3">
              <div className="font-display" style={{ fontSize: 13, fontWeight: 700, letterSpacing: '-0.005em' }}>
                本次会话 · SESSION
              </div>
              <Chip tone="outline" mono>{session.length} 件 · 62.8 MB</Chip>
            </div>
            <div
              style={{
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                color: 'var(--text-faint)',
                letterSpacing: '0.08em',
                textTransform: 'uppercase',
              }}
            >
              session #4f2a · open
            </div>
          </div>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
              gap: 12,
            }}
          >
            {session.map((s) => (
              <div
                key={s.id}
                style={{
                  background: 'var(--bg)',
                  border: '1px solid var(--border)',
                  borderRadius: 12,
                  padding: 12,
                }}
              >
                <FileCard
                  ext={s.ext}
                  name={s.name}
                  size={s.size}
                  meta={`→ ${s.to}`}
                  progress={s.state === 'sending' ? s.progress : undefined}
                />
              </div>
            ))}
          </div>
        </div>
      </div>

      <StatusBar peerCount={peerCount} hostIp={MESHDROP_ME.hostIp} />

      <Modal
        open={pasteOpen}
        title="贴文字 / 链接 · Paste"
        onClose={() => setPasteOpen(false)}
      >
        <textarea
          value={pasteText}
          onChange={(e) => setPasteText(e.target.value)}
          placeholder="粘贴文字、链接、代码片段，发给当前选中的设备…"
          style={{
            width: '100%',
            minHeight: 140,
            padding: 12,
            background: 'var(--bg)',
            border: '1px solid var(--border)',
            borderRadius: 10,
            color: 'var(--text)',
            fontFamily: '"Geist Mono", monospace',
            fontSize: 12.5,
            resize: 'vertical',
          }}
        />
        <div className="flex justify-end gap-2" style={{ marginTop: 12 }}>
          <button
            onClick={() => setPasteOpen(false)}
            style={{
              padding: '8px 14px',
              borderRadius: 10,
              border: '1px solid var(--border)',
              color: 'var(--text)',
              fontWeight: 600,
              fontSize: 12.5,
            }}
          >
            取消
          </button>
          <button
            onClick={() => {
              setPasteOpen(false)
              setPasteText('')
              fireToast(`已发送文字给 ${selected?.who ?? '所有人'}（mock）`)
            }}
            style={{
              padding: '8px 14px',
              borderRadius: 10,
              background: 'var(--ink)',
              color: 'var(--paper)',
              fontWeight: 600,
              fontSize: 12.5,
            }}
          >
            发送 →
          </button>
        </div>
      </Modal>

      {toast && (
        <div
          style={{
            position: 'absolute',
            bottom: 56,
            left: '50%',
            transform: 'translateX(-50%)',
            background: 'var(--ink)',
            color: 'var(--paper)',
            padding: '10px 18px',
            borderRadius: 999,
            fontFamily: '"Geist Mono", monospace',
            fontSize: 11,
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            zIndex: 60,
            boxShadow: '0 8px 24px rgba(0,0,0,0.35)',
          }}
        >
          ✓ {toast}
        </div>
      )}
    </div>
  )
}
