import { useState } from 'react'
import { Chip } from '../components/Chip'
import { StatusBar } from '../components/StatusBar'
import {
  MESHDROP_DEVICES,
  MESHDROP_HISTORY_BY_DAY,
  type MeshDevice,
} from '../lib/mockData'
import { useEngine } from '../hooks/useEngine'

export function ChatPage() {
  const liveDevices = useEngine((s) => s.devices)
  const me = useEngine((s) => s.me)
  const liveHistory = useEngine((s) => s.history)
  const selectedPeerId = useEngine((s) => s.selectedPeerId)
  const selectPeer = useEngine((s) => s.selectPeer)
  const sendText = useEngine((s) => s.sendText)
  const mode = useEngine((s) => s.mode)

  const devices = mode === 'live' ? liveDevices : MESHDROP_DEVICES
  const days = mode === 'live' ? liveHistory : MESHDROP_HISTORY_BY_DAY
  const selected: MeshDevice | undefined =
    devices.find((d) => d.id === selectedPeerId) ?? devices[0]

  const [draft, setDraft] = useState('')
  const [busy, setBusy] = useState(false)

  const messages = days
    .flatMap((d) => d.items)
    .filter((e) => e.kind === 'text' && selected != null && e.peer === selected.who)
    .reverse() // history 最新在前，对话区按旧→新

  const peerCount = devices.filter((d) => d.online).length

  const send = async () => {
    const content = draft.trim()
    if (!content || !selected || busy) return
    setBusy(true)
    try {
      await sendText(selected.id, content)
      setDraft('')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      <div style={{ flex: 1, display: 'flex', minHeight: 0 }}>
        {/* 左：设备列表 */}
        <div
          className="scroll-thin"
          style={{
            width: 200,
            flexShrink: 0,
            borderRight: '1px solid var(--border)',
            overflowY: 'auto',
            padding: 12,
            display: 'flex',
            flexDirection: 'column',
            gap: 6,
          }}
        >
          <div
            style={{
              fontFamily: '"Geist Mono", monospace',
              fontSize: 10,
              color: 'var(--text-faint)',
              letterSpacing: '0.18em',
              textTransform: 'uppercase',
              padding: '4px 6px 8px',
            }}
          >
            设备 · PEERS
          </div>
          {devices.length === 0 && (
            <div style={{ padding: 8, color: 'var(--text-faint)', fontSize: 12 }}>无在线设备</div>
          )}
          {devices.map((d) => {
            const active = selected?.id === d.id
            return (
              <button
                key={d.id}
                onClick={() => selectPeer(d.id)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '8px 10px',
                  borderRadius: 10,
                  border: '1px solid',
                  borderColor: active ? 'var(--ink)' : 'transparent',
                  background: active ? 'var(--surface)' : 'transparent',
                  textAlign: 'left',
                  cursor: 'pointer',
                }}
              >
                <span
                  style={{
                    width: 26,
                    height: 26,
                    borderRadius: '50%',
                    background: d.color,
                    color: 'var(--ink)',
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 11,
                    fontWeight: 700,
                    flexShrink: 0,
                  }}
                >
                  {d.initials}
                </span>
                <span style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {d.who}
                  </div>
                  <div style={{ fontFamily: '"Geist Mono", monospace', fontSize: 9.5, color: d.online ? 'var(--lime-deep, #8AB400)' : 'var(--text-faint)' }}>
                    {d.online ? '● 在线' : '○ 离线'}
                  </div>
                </span>
              </button>
            )
          })}
        </div>

        {/* 右：对话 */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <header
            className="flex items-center justify-between"
            style={{ padding: '14px 20px', borderBottom: '1px solid var(--border)' }}
          >
            <div>
              <div style={{ fontSize: 16, fontWeight: 700, color: 'var(--text)' }}>
                {selected ? selected.who : '选择设备开始对话'}
              </div>
              {selected && (
                <div style={{ fontFamily: '"Geist Mono", monospace', fontSize: 10.5, color: 'var(--text-faint)' }}>
                  {selected.name}
                </div>
              )}
            </div>
            <Chip tone="ink" mono>● 仅本会话</Chip>
          </header>

          <div
            className="scroll-thin"
            style={{ flex: 1, overflowY: 'auto', padding: 20, display: 'flex', flexDirection: 'column', gap: 10 }}
          >
            {messages.length === 0 ? (
              <div style={{
                margin: 'auto', textAlign: 'center', color: 'var(--text-faint)',
                fontFamily: '"Geist Mono", monospace', fontSize: 12, letterSpacing: '0.1em', textTransform: 'uppercase',
              }}>
                还没有文字消息 · NO MESSAGES YET
              </div>
            ) : (
              messages.map((m) => {
                const mine = m.dir === 'outgoing'
                return (
                  <div key={m.id} style={{ display: 'flex', justifyContent: mine ? 'flex-end' : 'flex-start' }}>
                    <div
                      style={{
                        maxWidth: '70%',
                        padding: '9px 13px',
                        borderRadius: 14,
                        borderBottomRightRadius: mine ? 4 : 14,
                        borderBottomLeftRadius: mine ? 14 : 4,
                        background: mine ? 'var(--ink)' : 'var(--surface)',
                        color: mine ? 'var(--paper)' : 'var(--text)',
                        border: mine ? 'none' : '1px solid var(--border)',
                        fontSize: 13.5,
                        lineHeight: 1.5,
                        whiteSpace: 'pre-wrap',
                        wordBreak: 'break-word',
                      }}
                    >
                      {m.content}
                      <div style={{ marginTop: 4, fontFamily: '"Geist Mono", monospace', fontSize: 9, opacity: 0.55, textAlign: 'right' }}>
                        {m.time}
                      </div>
                    </div>
                  </div>
                )
              })
            )}
          </div>

          {/* 输入框 */}
          <div style={{ padding: 14, borderTop: '1px solid var(--border)', display: 'flex', gap: 8 }}>
            <input
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send() } }}
              placeholder={selected ? '写一条消息… · Enter 发送' : '先选一个设备'}
              disabled={!selected}
              style={{
                flex: 1,
                background: 'var(--surface)',
                border: '1px solid var(--border)',
                borderRadius: 10,
                padding: '10px 12px',
                color: 'var(--text)',
                fontSize: 13.5,
              }}
            />
            <button
              onClick={send}
              disabled={!draft.trim() || !selected || busy}
              style={{
                border: 'none',
                borderRadius: 10,
                padding: '0 18px',
                background: !draft.trim() || !selected || busy ? 'var(--ink-06)' : 'var(--ink)',
                color: !draft.trim() || !selected || busy ? 'var(--text-faint)' : 'var(--paper)',
                fontFamily: '"Geist Mono", monospace',
                fontSize: 11,
                fontWeight: 700,
                letterSpacing: '0.08em',
                textTransform: 'uppercase',
                cursor: !draft.trim() || !selected || busy ? 'default' : 'pointer',
              }}
            >
              {busy ? '…' : '发送'}
            </button>
          </div>
        </div>
      </div>

      <StatusBar peerCount={peerCount} hostIp={me.hostIp} />
    </div>
  )
}
