import { useEffect, useRef, useState } from 'react'
import { HeroBand } from '../components/HeroBand'
import { DropZone } from '../components/DropZone'
import { PeerRow } from '../components/PeerRow'
import { StatusBar } from '../components/StatusBar'
import { Chip } from '../components/Chip'
import { AsciiDivider } from '../components/AsciiDivider'
import { FileCard } from '../components/FileCard'
import { Modal } from '../components/Modal'
import { useEngine } from '../hooks/useEngine'
import { formatBytes } from '../lib/format'

export function MainPage() {
  const devices = useEngine((s) => s.devices)
  const me = useEngine((s) => s.me)
  const selectedPeerId = useEngine((s) => s.selectedPeerId)
  const selectPeer = useEngine((s) => s.selectPeer)
  const transfers = useEngine((s) => s.transfers)
  const sendText = useEngine((s) => s.sendText)
  const sendFiles = useEngine((s) => s.sendFiles)
  const mode = useEngine((s) => s.mode)
  const conn = useEngine((s) => s.conn)

  const [dragOverPeer, setDragOverPeer] = useState<string | undefined>()
  const [pasteOpen, setPasteOpen] = useState(false)
  const [pasteText, setPasteText] = useState('')
  const [toast, setToast] = useState<string | undefined>()
  const shareHandled = useRef(false)

  const selected = devices.find((d) => d.id === selectedPeerId)
  const peerCount = devices.filter((d) => d.online).length
  const session = transfers.filter((t) => t.state === 'sending' || t.state === 'queued').slice(0, 3)

  // 会话总量实算：求和 session 行的原始 totalBytes（host 上报时才有）；
  // 没有任何字节信息时只显示件数，不再写死 62.8 MB。
  const sessionBytes = session.reduce((sum, t) => sum + (t.totalBytes ?? 0), 0)
  const sessionLabel = sessionBytes > 0
    ? `${session.length} 件 · ${formatBytes(sessionBytes)}`
    : `${session.length} 件`

  const fireToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(undefined), 2400)
  }

  // Web Share Target 入口：URL 上带 ?share_title / ?share_text / ?share_url 时
  // 自动填入粘贴对话框，等用户选 peer 后再发。
  useEffect(() => {
    if (shareHandled.current) return
    const q = new URLSearchParams(window.location.search)
    const t = [q.get('share_title'), q.get('share_text'), q.get('share_url')].filter(Boolean).join('\n')
    if (t) {
      shareHandled.current = true
      setPasteText(t)
      setPasteOpen(true)
    }
  }, [])

  const handleDropFiles = async (peerId: string, files: File[]) => {
    if (!files.length) return
    try {
      await sendFiles(peerId, files)
      fireToast(`已发送 ${files.length} 个文件给 ${devices.find((d) => d.id === peerId)?.who ?? peerId}`)
    } catch (e) {
      fireToast(`发送失败：${(e as Error).message}`)
    }
  }

  const handleSendText = async () => {
    const text = pasteText.trim()
    if (!text) { setPasteOpen(false); return }
    const peerId = selectedPeerId ?? devices[0]?.id
    if (!peerId) { fireToast('没有可发送的设备'); setPasteOpen(false); return }
    setPasteOpen(false)
    setPasteText('')
    try {
      await sendText(peerId, text)
      fireToast(`已发送文字给 ${devices.find((d) => d.id === peerId)?.who ?? peerId}`)
    } catch (e) {
      fireToast(`发送失败：${(e as Error).message}`)
    }
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
                  onDrop={(e) => {
                    setDragOverPeer(undefined)
                    const files = Array.from(e.dataTransfer?.files ?? [])
                    if (files.length) {
                      void handleDropFiles(d.id, files)
                    } else {
                      fireToast(`已选中 ${d.who}，拖文件或粘贴文字发送`)
                    }
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
                {me.visibility}
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
                {me.name}
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
                {me.os}
                <br />
                {me.ip}
                <br />
                匿名访客 · 关浏览器即下线
              </div>
            </div>
          </aside>

          {/* Drop zone */}
          <DropZone
            selectedPeerName={selected?.who}
            onFiles={(files) => {
              const peerId = selectedPeerId ?? devices[0]?.id
              if (!peerId) { fireToast('请先选择一台设备'); return }
              void handleDropFiles(peerId, files)
            }}
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
              <Chip tone="outline" mono>{sessionLabel}</Chip>
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

      <StatusBar
        peerCount={peerCount}
        hostIp={me.hostIp}
        connected={mode === 'live' ? conn === 'open' : true}
        modeLabel={mode === 'live' ? `LIVE · ${conn.toUpperCase()}` : 'OFFLINE PREVIEW'}
      />

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
            onClick={() => { void handleSendText() }}
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
