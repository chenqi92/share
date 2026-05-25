import { useState } from 'react'
import { AsciiDivider } from '../components/AsciiDivider'
import { Chip } from '../components/Chip'
import { StatusBar } from '../components/StatusBar'
import { MESHDROP_ME } from '../lib/mockData'
import { useEngine } from '../hooks/useEngine'

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
  const [autoAccept, setAutoAccept] = useState(false)
  const [showInRadar, setShowInRadar] = useState(true)
  const [keepHistory, setKeepHistory] = useState(false)
  const [defaultPath, setDefaultPath] = useState('浏览器下载')
  const [scope, setScope] = useState('LAN 内全部')
  const devices = useEngine((s) => s.devices)
  const peerCount = devices.filter((d) => d.online).length

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
            hint="关闭即关页清空（推荐）。打开后会写一条非永久 cookie 让自动重连工作。"
            value={false}
            onChange={() => {}}
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
              fingerprint · {MESHDROP_ME.fingerprint}
            </span>
          </div>
          <ToggleRow
            label="未配对设备的文件 offer 自动接收"
            hint="不推荐 · 仅在你完全控制 LAN 时打开。"
            value={autoAccept}
            onChange={setAutoAccept}
          />
        </section>

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
            host · {MESHDROP_ME.hostIp} (Lily's MacBook · macOS 14.5 · gateway)<br />
            session · #4f2a · opened 6m 12s ago<br />
            engine · WebRTC DataChannel + WebCrypto X25519 · MOCK MODE
          </div>
        </section>
      </div>

      <StatusBar peerCount={peerCount} hostIp={MESHDROP_ME.hostIp} />
    </div>
  )
}
