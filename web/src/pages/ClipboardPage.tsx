import { useState } from 'react'
import { Chip } from '../components/Chip'
import { StatusBar } from '../components/StatusBar'
import { AsciiDivider } from '../components/AsciiDivider'
import { type ClipboardItem } from '../lib/mockData'
import { useEngine } from '../hooks/useEngine'

const KIND_GLYPH: Record<ClipboardItem['kind'], string> = {
  link: '🔗',
  code: '⌘',
  text: '¶',
}

const KIND_TONE: Record<ClipboardItem['kind'], 'sky' | 'flame' | 'outline'> = {
  link: 'sky',
  code: 'flame',
  text: 'outline',
}

function ClipboardCell({ item, onCopy }: { item: ClipboardItem; onCopy: (body: string) => void }) {
  const isCode = item.kind === 'code'
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
        <span style={{ color: item.who === '我' ? 'var(--flame)' : 'var(--sky)' }}>
          {item.who === '我' ? '↑ 我' : `↓ ${item.who}`}
        </span>
        <span>{item.ago}</span>
      </div>

      <div
        style={{
          padding: 12,
          borderRadius: 10,
          background: 'var(--bg)',
          border: '1px solid var(--border)',
          fontSize: 13,
          lineHeight: 1.55,
          color: 'var(--text)',
          fontFamily: isCode ? '"Geist Mono", monospace' : 'inherit',
          whiteSpace: 'pre-wrap',
          wordBreak: 'break-word',
          maxHeight: 160,
          overflowY: 'auto',
        }}
      >
        {item.body}
      </div>

      <div className="flex items-center justify-between" style={{ marginTop: 'auto' }}>
        <Chip tone={KIND_TONE[item.kind]} mono>
          {KIND_GLYPH[item.kind]} {item.kind.toUpperCase()}
          {item.lang ? ` · ${item.lang}` : ''}
        </Chip>
        <button
          onClick={() => onCopy(item.body)}
          style={{
            border: '1px solid var(--border)',
            borderRadius: 8,
            padding: '3px 9px',
            background: 'transparent',
            color: 'var(--text-mute)',
            fontFamily: '"Geist Mono", monospace',
            fontSize: 10,
            fontWeight: 700,
            letterSpacing: '0.08em',
            cursor: 'pointer',
          }}
        >
          ⌘C COPY
        </button>
      </div>
    </div>
  )
}

export function ClipboardPage() {
  const devices = useEngine((s) => s.devices)
  const me = useEngine((s) => s.me)
  const inbox = useEngine((s) => s.clipboardInbox)
  const selectedPeerId = useEngine((s) => s.selectedPeerId)
  const pushClipboard = useEngine((s) => s.pushClipboard)
  const peerCount = devices.filter((d) => d.online).length

  const online = devices.filter((d) => d.online)
  const [target, setTarget] = useState<string>(selectedPeerId ?? online[0]?.id ?? '')
  const [draft, setDraft] = useState('')
  const [busy, setBusy] = useState(false)

  const readSystemClipboard = async () => {
    try {
      const text = await navigator.clipboard?.readText()
      if (text) setDraft(text)
    } catch {
      // 浏览器拒绝读取（无权限 / 非安全上下文）—— 用户可手动粘贴到下方文本框
    }
  }

  const copyToClipboard = (body: string) => {
    try { navigator.clipboard?.writeText(body) } catch { /* ignore */ }
  }

  const doPush = async () => {
    const content = draft.trim()
    if (!content || !target || busy) return
    setBusy(true)
    try {
      await pushClipboard(target, content)
      setDraft('')
    } finally {
      setBusy(false)
    }
  }

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
              剪贴板 · CLIPBOARD
            </div>
            <h1 className="font-display" style={{ fontSize: 30, fontWeight: 700, letterSpacing: '-0.025em', lineHeight: 1 }}>
              推送一段文字到附近设备
            </h1>
            <p style={{ marginTop: 8, color: 'var(--text-mute)', fontSize: 13.5, maxWidth: 600 }}>
              显式推送 —— 由你点一下才发送，不是后台静默同步。链接 / 代码 / 普通文本会自动归类。
            </p>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Chip tone="ink" mono>● 仅本会话</Chip>
            <Chip tone="outline" mono>{inbox.length} 条</Chip>
          </div>
        </header>

        {/* 推送编辑器 */}
        <section
          style={{
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            borderRadius: 14,
            padding: 16,
            display: 'flex',
            flexDirection: 'column',
            gap: 12,
          }}
        >
          <div className="flex items-center gap-2 flex-wrap">
            <span
              style={{
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                color: 'var(--text-faint)',
                letterSpacing: '0.12em',
                textTransform: 'uppercase',
              }}
            >
              推送到
            </span>
            <select
              value={target}
              onChange={(e) => setTarget(e.target.value)}
              style={{
                background: 'var(--bg)',
                border: '1px solid var(--border)',
                borderRadius: 8,
                padding: '5px 10px',
                color: 'var(--text)',
                fontSize: 12.5,
              }}
            >
              {online.length === 0 && <option value="">无在线设备</option>}
              {online.map((d) => (
                <option key={d.id} value={d.id}>{d.who} · {d.name}</option>
              ))}
            </select>
            <button
              onClick={readSystemClipboard}
              style={{
                marginLeft: 'auto',
                border: '1px solid var(--border)',
                borderRadius: 8,
                padding: '5px 11px',
                background: 'transparent',
                color: 'var(--text-mute)',
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                fontWeight: 700,
                letterSpacing: '0.08em',
                cursor: 'pointer',
              }}
            >
              ⎘ 读取系统剪贴板
            </button>
          </div>

          <textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="粘贴或输入要推送的内容…"
            rows={4}
            style={{
              width: '100%',
              resize: 'vertical',
              background: 'var(--bg)',
              border: '1px solid var(--border)',
              borderRadius: 10,
              padding: 12,
              color: 'var(--text)',
              fontSize: 13,
              lineHeight: 1.55,
              fontFamily: 'inherit',
            }}
          />

          <div className="flex items-center justify-end">
            <button
              onClick={doPush}
              disabled={!draft.trim() || !target || busy}
              style={{
                border: 'none',
                borderRadius: 999,
                padding: '8px 18px',
                background: !draft.trim() || !target || busy ? 'var(--ink-06)' : 'var(--ink)',
                color: !draft.trim() || !target || busy ? 'var(--text-faint)' : 'var(--paper)',
                fontFamily: '"Geist Mono", monospace',
                fontSize: 11,
                fontWeight: 700,
                letterSpacing: '0.08em',
                textTransform: 'uppercase',
                cursor: !draft.trim() || !target || busy ? 'default' : 'pointer',
              }}
            >
              {busy ? '推送中…' : '↑ 推送 · PUSH'}
            </button>
          </div>
        </section>

        {/* 收件 */}
        <section style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <AsciiDivider label="—— 收到的剪贴板 · INBOX ——" />
          {inbox.length === 0 ? (
            <div style={{
              padding: '40px 20px', textAlign: 'center', color: 'var(--text-faint)',
              fontFamily: '"Geist Mono", monospace', fontSize: 12, letterSpacing: '0.12em', textTransform: 'uppercase',
            }}>
              还没有收到剪贴板 · NOTHING YET
            </div>
          ) : (
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
                gap: 12,
              }}
            >
              {inbox.map((item) => (
                <ClipboardCell key={item.id} item={item} onCopy={copyToClipboard} />
              ))}
            </div>
          )}
        </section>
      </div>

      <StatusBar peerCount={peerCount} hostIp={me.hostIp} />
    </div>
  )
}
