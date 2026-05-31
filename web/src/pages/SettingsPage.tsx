import { useState } from 'react'
import { AsciiDivider } from '../components/AsciiDivider'
import { Chip } from '../components/Chip'
import { StatusBar } from '../components/StatusBar'
import { useEngine } from '../hooks/useEngine'
import { loadSettings, saveSettings, type AppSettings } from '../lib/settings'

interface ToggleRowProps {
  label: string
  hint?: string
  value: boolean
  onChange: (v: boolean) => void
}

function ToggleRow({ label, hint, value, onChange }: ToggleRowProps) {
  return (
    <div
      style={{
        padding: '14px 16px',
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 12,
        display: 'flex',
        alignItems: 'center',
        gap: 14,
      }}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="font-display" style={{ fontSize: 13.5, fontWeight: 600, letterSpacing: '-0.005em' }}>
          {label}
        </div>
        {hint && (
          <div style={{ marginTop: 2, color: 'var(--text-mute)', fontSize: 12.5, lineHeight: 1.45 }}>{hint}</div>
        )}
      </div>
      <button
        onClick={() => onChange(!value)}
        aria-pressed={value}
        style={{
          width: 44,
          height: 24,
          borderRadius: 999,
          background: value ? 'var(--lime)' : 'var(--bg2)',
          border: `1px solid ${value ? 'var(--lime)' : 'var(--border)'}`,
          padding: 2,
          position: 'relative',
          flexShrink: 0,
          transition: 'background 160ms ease',
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 2,
            left: value ? 22 : 2,
            width: 18,
            height: 18,
            borderRadius: '50%',
            background: value ? 'var(--ink)' : 'var(--text-faint)',
            transition: 'left 200ms cubic-bezier(.32,.72,.21,1)',
          }}
        />
      </button>
    </div>
  )
}

interface SelectRowProps {
  label: string
  hint?: string
  value: string
  options: string[]
  onChange: (v: string) => void
}

function SelectRow({ label, hint, value, options, onChange }: SelectRowProps) {
  return (
    <div
      style={{
        padding: '14px 16px',
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 12,
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      <div>
        <div className="font-display" style={{ fontSize: 13.5, fontWeight: 600, letterSpacing: '-0.005em' }}>
          {label}
        </div>
        {hint && <div style={{ marginTop: 2, color: 'var(--text-mute)', fontSize: 12.5 }}>{hint}</div>}
      </div>
      <div className="flex flex-wrap gap-2">
        {options.map((o) => {
          const active = value === o
          return (
            <button
              key={o}
              onClick={() => onChange(o)}
              style={{
                padding: '6px 12px',
                borderRadius: 999,
                background: active ? 'var(--ink)' : 'transparent',
                color: active ? 'var(--paper)' : 'var(--text-mute)',
                border: `1px solid ${active ? 'var(--ink)' : 'var(--border)'}`,
                fontSize: 12,
                fontWeight: 600,
              }}
            >
              {o}
            </button>
          )
        })}
      </div>
    </div>
  )
}

export function SettingsPage() {
  // 自动接收 / 通知：持久化到 localStorage，engine 的 onOfferPending / notifyIncoming 会读取，
  // 不再是「关页即丢、且 live 模式不生效」的纯本地 state。
  const [settings, setSettings] = useState<AppSettings>(() => loadSettings())
  const updateSettings = (patch: Partial<AppSettings>) =>
    setSettings((prev) => {
      const next = { ...prev, ...patch }
      saveSettings(next)
      return next
    })
  const [showInRadar, setShowInRadar] = useState(true)
  const [keepHistory, setKeepHistory] = useState(false)
  const [defaultPath, setDefaultPath] = useState('浏览器下载')
  const [scope, setScope] = useState('LAN 内全部')
  const [confirmingForget, setConfirmingForget] = useState(false)
  const devices = useEngine((s) => s.devices)
  const me = useEngine((s) => s.me)
  const mode = useEngine((s) => s.mode)
  const conn = useEngine((s) => s.conn)
  const forgetSession = useEngine((s) => s.forgetSession)
  const peerCount = devices.filter((d) => d.online).length

  const handleForget = () => {
    forgetSession()
    setConfirmingForget(false)
    // 跳到配对页 + 刷新让 hook 重新走 isMock 判定
    window.location.href = '?page=pairing'
  }

  const connLabel = (() => {
    switch (conn) {
      case 'open': return '已连接'
      case 'connecting': return '连接中…'
      case 'closed': return '已断开'
      case 'unpaired': return '未配对'
      case 'idle': return '空闲'
    }
  })()
  const connTone: 'lime' | 'flame' | 'outline' = conn === 'open' ? 'lime' : conn === 'connecting' ? 'outline' : 'flame'

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
          gap: 22,
        }}
      >
        <header>
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
            设置 · SETTINGS
          </div>
          <h1
            className="font-display"
            style={{ fontSize: 30, fontWeight: 700, letterSpacing: '-0.025em', lineHeight: 1 }}
          >
            浏览器即用,<span style={{ color: 'var(--text-mute)' }}> 但仍然可以调.</span>
          </h1>
          <p style={{ marginTop: 8, color: 'var(--text-mute)', fontSize: 13.5, maxWidth: 720 }}>
            访客身份下的偏好只对当前标签页生效；想跨设备同步的偏好请在 native 端配置。
          </p>
        </header>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label="—— 可见性 · VISIBILITY ——" />
          <ToggleRow
            label="在他人雷达里露脸"
            hint="关闭后你的设备不出现在 mDNS 广播里，但可以主动连他人。"
            value={showInRadar}
            onChange={setShowInRadar}
          />
          <SelectRow
            label="可被谁连接"
            hint="决定谁能向你发送文件 / 文字便签。"
            value={scope}
            options={['LAN 内全部', '已配对设备', '邀请链接']}
            onChange={setScope}
          />
          <ToggleRow
            label="访客身份记住浏览器"
            hint="关闭即关页清空（推荐）。打开后保留 session token 让自动重连工作；关闭会立即清掉。"
            value={mode === 'live' && conn !== 'unpaired'}
            onChange={(on) => { if (!on) forgetSession() }}
          />
        </section>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label="—— 安全 · ENCRYPTION ——" />
          <div
            style={{
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              borderRadius: 12,
              padding: '14px 16px',
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              flexWrap: 'wrap',
            }}
          >
            <Chip tone="lime" mono>● X25519 · CHACHA20</Chip>
            <Chip tone="outline" mono>SHA-256 校验</Chip>
            <Chip tone="outline" mono>WebCrypto subtle</Chip>
            <span
              style={{
                marginLeft: 'auto',
                fontFamily: '"Geist Mono", monospace',
                fontSize: 11,
                color: 'var(--text-faint)',
                letterSpacing: '0.02em',
              }}
            >
              fingerprint · {me.fingerprint}
            </span>
          </div>
          <ToggleRow
            label="未配对设备的文件 offer 自动接收"
            hint="不推荐 · 仅在你完全控制 LAN 时打开。"
            value={settings.autoAccept}
            onChange={(v) => updateSettings({ autoAccept: v })}
          />
          <ToggleRow
            label="收到文件 / 剪贴板时弹通知"
            hint="需要浏览器通知权限；关闭后即使有权限也不弹。"
            value={settings.notifications}
            onChange={(v) => updateSettings({ notifications: v })}
          />
        </section>

        {mode === 'live' && (
          <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <AsciiDivider label="—— 会话 · SESSION ——" />
            <div
              style={{
                background: 'var(--surface)',
                border: '1px solid var(--border)',
                borderRadius: 12,
                padding: '14px 16px',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                flexWrap: 'wrap',
              }}
            >
              <Chip tone={connTone} mono>● {connLabel}</Chip>
              <span
                style={{
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 11,
                  color: 'var(--text-faint)',
                  letterSpacing: '0.02em',
                }}
              >
                gateway · {window.location.host}
              </span>
              <button
                onClick={() => setConfirmingForget(true)}
                style={{
                  marginLeft: 'auto',
                  padding: '6px 14px',
                  background: 'transparent',
                  border: '1px solid var(--flame, #FF5A2C)',
                  borderRadius: 8,
                  color: 'var(--flame, #FF5A2C)',
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 11.5,
                  fontWeight: 600,
                  letterSpacing: '0.02em',
                  cursor: 'pointer',
                }}
              >
                断开 / 重新配对
              </button>
            </div>
            {confirmingForget && (
              <div
                style={{
                  background: 'var(--surface)',
                  border: '1px solid var(--flame, #FF5A2C)',
                  borderRadius: 12,
                  padding: '14px 16px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  flexWrap: 'wrap',
                }}
              >
                <span style={{ fontSize: 12.5, color: 'var(--text-mute)', flex: 1, minWidth: 240 }}>
                  断开会清掉本地 session token；下次访问需要重新输入 6 字符配对码。继续？
                </span>
                <button
                  onClick={() => setConfirmingForget(false)}
                  style={{
                    padding: '6px 14px',
                    background: 'transparent',
                    border: '1px solid var(--border)',
                    borderRadius: 8,
                    fontFamily: '"Geist Mono", monospace',
                    fontSize: 11.5,
                    cursor: 'pointer',
                  }}
                >
                  取消
                </button>
                <button
                  onClick={handleForget}
                  style={{
                    padding: '6px 14px',
                    background: 'var(--flame, #FF5A2C)',
                    border: '1px solid var(--flame, #FF5A2C)',
                    borderRadius: 8,
                    color: '#fff',
                    fontFamily: '"Geist Mono", monospace',
                    fontSize: 11.5,
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  确认断开
                </button>
              </div>
            )}
          </section>
        )}

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label="—— 接收行为 · RECEIVE BEHAVIOR ——" />
          <SelectRow
            label="默认保存到"
            hint="浏览器只能写到下载文件夹；要其他路径请走 native。"
            value={defaultPath}
            options={['浏览器下载', '当前域名 sandbox', '弹窗每次询问']}
            onChange={setDefaultPath}
          />
          <ToggleRow
            label="本会话历史保留到关页"
            hint="打开后历史在内存里多保留一阵，便于你查刚才发过什么。永远不会写盘。"
            value={keepHistory}
            onChange={setKeepHistory}
          />
        </section>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label="—— 关于 · ABOUT ——" />
          <div
            style={{
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              borderRadius: 12,
              padding: '14px 16px',
              fontFamily: '"Geist Mono", monospace',
              fontSize: 11.5,
              color: 'var(--text-mute)',
              letterSpacing: '0.02em',
              lineHeight: 1.7,
            }}
          >
            meshdrop-web · v0.1.0-ui<br />
            host · {me.hostIp}<br />
            session · {mode === 'live' ? conn.toUpperCase() : '—'}<br />
            engine · WebRTC DataChannel + WebCrypto X25519 · {mode === 'live' ? 'LIVE MODE' : 'MOCK MODE'}
          </div>
        </section>
      </div>

      <StatusBar peerCount={peerCount} hostIp={me.hostIp} />
    </div>
  )
}
