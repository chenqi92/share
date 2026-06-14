import { useState } from 'react'
import { AsciiDivider } from '../components/AsciiDivider'
import { Chip } from '../components/Chip'
import { StatusBar } from '../components/StatusBar'
import { useEngine } from '../hooks/useEngine'
import { getGatewayEndpoint, isGatewayConfigured, setGatewayEndpoint } from '../lib/engine'

function FakeQr({ size = 220 }: { size?: number }) {
  // 21×21 deterministic-looking pattern with the three locator squares.
  const cells = 21
  const m: boolean[][] = []
  for (let y = 0; y < cells; y++) {
    m[y] = []
    for (let x = 0; x < cells; x++) {
      const seed = (x * 37 + y * 71 + x * y * 13) % 100
      m[y][x] = seed % 3 !== 0 && seed % 11 !== 0
    }
  }
  // wipe locator squares (top-left, top-right, bottom-left)
  const locators = [
    [0, 0],
    [0, cells - 7],
    [cells - 7, 0],
  ]
  for (const [oy, ox] of locators) {
    for (let y = 0; y < 7; y++) {
      for (let x = 0; x < 7; x++) {
        m[oy + y][ox + x] = false
      }
    }
  }

  const cell = size / cells
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-label="pairing QR code">
      <rect width={size} height={size} fill="var(--card)" />
      {m.flatMap((row, y) =>
        row.map((on, x) =>
          on ? <rect key={`${x}-${y}`} x={x * cell} y={y * cell} width={cell} height={cell} fill="var(--ink)" /> : null,
        ),
      )}
      {/* locator squares */}
      {locators.map(([oy, ox], i) => (
        <g key={i} transform={`translate(${ox * cell} ${oy * cell})`}>
          <rect x="0" y="0" width={cell * 7} height={cell * 7} fill="var(--ink)" />
          <rect x={cell} y={cell} width={cell * 5} height={cell * 5} fill="var(--card)" />
          <rect x={cell * 2} y={cell * 2} width={cell * 3} height={cell * 3} fill="var(--ink)" />
        </g>
      ))}
      {/* center logo overlay */}
      <g transform={`translate(${size / 2 - 16} ${size / 2 - 16})`}>
        <rect width="32" height="32" rx="6" fill="var(--card)" />
        <circle cx="13" cy="16" r="6.5" fill="none" stroke="var(--ink)" strokeWidth="2" />
        <circle cx="19" cy="16" r="6.5" fill="none" stroke="var(--ink)" strokeWidth="2" />
        <circle cx="16" cy="16" r="2" fill="var(--lime)" />
      </g>
    </svg>
  )
}

export function PairingPage() {
  const devices = useEngine((s) => s.devices)
  const me = useEngine((s) => s.me)
  const mode = useEngine((s) => s.mode)
  const conn = useEngine((s) => s.conn)
  const pair = useEngine((s) => s.pair)
  const forgetSession = useEngine((s) => s.forgetSession)
  const pendingPairing = useEngine((s) => s.pendingPairing)
  const acceptPairing = useEngine((s) => s.acceptPairing)
  const rejectPairing = useEngine((s) => s.rejectPairing)
  const peerCount = devices.filter((d) => d.online).length
  const [code, setCode] = useState('')
  const [pairing, setPairing] = useState(false)
  const [pairErr, setPairErr] = useState<string | undefined>()
  const [gateway, setGateway] = useState(() => getGatewayEndpoint())
  const [gatewayErr, setGatewayErr] = useState<string | undefined>()
  const [gatewayReady, setGatewayReady] = useState(() => isGatewayConfigured())

  const saveGateway = () => {
    setGatewayErr(undefined)
    try {
      setGatewayEndpoint(gateway)
      setGatewayReady(isGatewayConfigured())
    } catch (e) {
      setGatewayErr((e as Error).message)
    }
  }

  const submitCode = async () => {
    setPairErr(undefined)
    if (!gatewayReady) {
      setPairErr('请先设置 native Web Gateway 地址')
      return
    }
    setPairing(true)
    try {
      const ok = await pair(code.trim())
      if (!ok) setPairErr('代码无效或已过期')
      else setCode('')
    } catch (e) {
      setPairErr((e as Error).message)
    } finally {
      setPairing(false)
    }
  }
  const steps: { idx: string; title: string; body: string }[] = [
    { idx: '1', title: '同一局域网', body: '确认两台设备连在同一 Wi-Fi 或交换机下，没有客户端隔离。' },
    { idx: '2', title: '扫一扫 / 输入代码', body: '原生 App 里点 "添加设备"，扫描右侧 QR 或手动输入下方 6 字符代码。' },
    { idx: '3', title: '指纹对一遍', body: '两端会显示同一组 32 位指纹，确认一致后点 "信任并记住"。' },
  ]

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      <div
        className="scroll-thin"
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '24px 28px 28px',
          display: 'flex',
          flexDirection: 'column',
          gap: 22,
        }}
      >
        {mode === 'live' && (
          <section
            style={{
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              borderRadius: 16,
              padding: '16px 18px',
              display: 'flex',
              flexDirection: 'column',
              gap: 12,
            }}
          >
            {!gatewayReady && (
              <div style={{
                padding: 12,
                borderRadius: 10,
                background: 'var(--flame-fill)',
                borderLeft: '3px solid var(--flame)',
                fontSize: 12.5,
                color: 'var(--text)',
                lineHeight: 1.5,
              }}>
                当前未配置 native Web Gateway。输入运行 MeshDrop native 端的地址后再配对。
              </div>
            )}
            <div className="flex items-center gap-3" style={{ flexWrap: 'wrap' }}>
              <input
                value={gateway}
                onChange={(e) => {
                  setGateway(e.target.value)
                  setGatewayReady(false)
                }}
                onKeyDown={(e) => { if (e.key === 'Enter') saveGateway() }}
                placeholder="https://192.168.1.12:7384"
                spellCheck={false}
                style={{
                  flex: '1 1 260px',
                  minWidth: 240,
                  padding: '9px 12px',
                  borderRadius: 10,
                  background: 'var(--bg)',
                  border: '1px solid var(--border)',
                  color: 'var(--text)',
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 12.5,
                }}
              />
              <button
                onClick={saveGateway}
                style={{
                  padding: '9px 14px',
                  borderRadius: 10,
                  background: 'var(--lime)',
                  color: 'var(--ink)',
                  fontWeight: 700,
                  fontSize: 12.5,
                  cursor: 'pointer',
                }}
              >
                保存 gateway
              </button>
              <div style={{
                flex: '1 1 100%',
                color: gatewayErr ? 'var(--error)' : 'var(--text-faint)',
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                letterSpacing: '0.04em',
              }}>
                {gatewayErr ?? (gatewayReady ? `gateway · ${getGatewayEndpoint()}` : '例: https://192.168.1.12:7384 或 http://127.0.0.1:7384')}
              </div>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Chip tone={conn === 'open' ? 'lime' : 'outline'} mono>
                  {conn === 'open' ? '● ONLINE · 已连接 gateway'
                    : conn === 'unpaired' ? '○ 未配对 · UNPAIRED'
                    : conn === 'connecting' ? '◌ 连接中 · CONNECTING'
                    : `● ${conn.toUpperCase()}`}
                </Chip>
                <span style={{
                  fontFamily: '"Geist Mono", monospace', fontSize: 10.5,
                  color: 'var(--text-mute)', letterSpacing: '0.08em', textTransform: 'uppercase',
                }}>WEB GATEWAY · /api/v1/control</span>
              </div>
              {conn === 'open' && (
                <button
                  onClick={() => forgetSession()}
                  style={{
                    padding: '6px 12px', borderRadius: 8, border: '1px solid var(--border)',
                    background: 'transparent', color: 'var(--text-mute)', fontSize: 11,
                    fontFamily: '"Geist Mono", monospace', letterSpacing: '0.08em', textTransform: 'uppercase',
                  }}
                >
                  解配 · UNPAIR
                </button>
              )}
            </div>
            {(conn === 'unpaired' || conn === 'closed' || conn === 'idle') && (
              <div className="flex items-center gap-3" style={{ flexWrap: 'wrap' }}>
                <input
                  value={code}
                  onChange={(e) => setCode(e.target.value.toUpperCase().replace(/[^A-Z0-9·-]/g, ''))}
                  onKeyDown={(e) => { if (e.key === 'Enter') void submitCode() }}
                  placeholder="LR · 4K7M"
                  spellCheck={false}
                  style={{
                    flex: '1 1 220px', minWidth: 200,
                    padding: '10px 14px', borderRadius: 10,
                    background: 'var(--bg)', border: '1px solid var(--border)',
                    color: 'var(--text)', fontFamily: '"Geist Mono", monospace',
                    fontSize: 18, letterSpacing: '0.2em', textTransform: 'uppercase',
                  }}
                />
                <button
                  onClick={() => { void submitCode() }}
                  disabled={pairing || !code.trim()}
                  style={{
                    padding: '10px 18px', borderRadius: 10,
                    background: pairing || !code.trim() ? 'var(--border)' : 'var(--lime)',
                    color: 'var(--ink)', fontWeight: 700, fontSize: 13.5,
                    cursor: pairing || !code.trim() ? 'not-allowed' : 'pointer',
                  }}
                >
                  {pairing ? '配对中…' : '配对 →'}
                </button>
                <div style={{
                  flex: '1 1 100%', color: pairErr ? 'var(--error)' : 'var(--text-faint)',
                  fontFamily: '"Geist Mono", monospace', fontSize: 11, letterSpacing: '0.04em',
                }}>
                  {pairErr ?? '在 native app 顶部找到 6 字符代码，输入这里'}
                </div>
              </div>
            )}
            {pendingPairing && (
              <div style={{
                marginTop: 4, padding: 12, borderRadius: 10,
                background: 'var(--flame-fill)', borderLeft: '3px solid var(--flame)',
              }}>
                <div style={{
                  fontFamily: '"Geist Mono", monospace', fontSize: 10.5,
                  color: 'var(--flame)', letterSpacing: '0.18em', textTransform: 'uppercase',
                }}>
                  待审配对 · {pendingPairing.peer}
                </div>
                <div style={{ marginTop: 6, fontSize: 12.5, color: 'var(--text)', fontFamily: '"Geist Mono", monospace', lineHeight: 1.5 }}>
                  {pendingPairing.fingerprint}
                </div>
                <div className="flex gap-2" style={{ marginTop: 10 }}>
                  <button onClick={() => { void rejectPairing() }}
                    style={{ padding: '6px 12px', borderRadius: 8, border: '1px solid var(--border)', background: 'transparent', color: 'var(--text)', fontSize: 12 }}>
                    拒绝
                  </button>
                  <button onClick={() => { void acceptPairing(true) }}
                    style={{ padding: '6px 12px', borderRadius: 8, background: 'var(--lime)', color: 'var(--ink)', fontSize: 12, fontWeight: 700 }}>
                    信任并记住
                  </button>
                </div>
              </div>
            )}
          </section>
        )}

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
            配对 · PAIRING
          </div>
          <h1
            className="font-display"
            style={{
              fontSize: 'clamp(28px, 3.4vw, 38px)',
              fontWeight: 700,
              letterSpacing: '-0.028em',
              lineHeight: 1.04,
            }}
          >
            把这台浏览器,
            <br />
            <span style={{ color: 'var(--lime-deep)' }}>加入你的 MeshDrop 网</span>
          </h1>
          <p style={{ marginTop: 10, color: 'var(--text-mute)', fontSize: 14, maxWidth: 720 }}>
            访客匿名收发不需要配对；只有当你希望这台浏览器变成"长期信任"——下次进来不再弹接收确认——
            才需要把它配对到你的 MeshDrop 设备上。
          </p>
        </header>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'minmax(0, 1fr) 280px',
            gap: 22,
            alignItems: 'stretch',
          }}
        >
          <section
            style={{
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              borderRadius: 18,
              padding: '24px 28px',
              display: 'flex',
              flexDirection: 'column',
              gap: 22,
            }}
          >
            <div className="flex items-center gap-2">
              <Chip tone="lime" mono>● 6 字符代码 · 30s</Chip>
              <Chip tone="outline" mono>限本会话</Chip>
            </div>

            <div
              className="font-display"
              style={{
                fontSize: 'clamp(56px, 7vw, 92px)',
                fontWeight: 700,
                letterSpacing: '0.04em',
                lineHeight: 1,
                fontFamily: '"Geist Mono", monospace',
                color: 'var(--text)',
                display: 'flex',
                gap: 'clamp(8px, 1.4vw, 18px)',
              }}
            >
              {me.pairingCode.split('').map((ch, i) => (
                <span
                  key={i}
                  style={{
                    minWidth: '0.9em',
                    textAlign: 'center',
                    background: ch === '-' ? 'transparent' : 'var(--bg)',
                    border: ch === '-' ? 'none' : '1px solid var(--border)',
                    borderRadius: 10,
                    padding: ch === '-' ? '0' : '4px 10px',
                    color: ch === '-' ? 'var(--text-faint)' : 'var(--text)',
                  }}
                >
                  {ch}
                </span>
              ))}
            </div>

            <AsciiDivider label="—— 指纹 · FINGERPRINT · 完整 32 位 ——" />

            <div
              style={{
                fontFamily: '"Geist Mono", monospace',
                fontSize: 13.5,
                fontWeight: 600,
                letterSpacing: '0.04em',
                color: 'var(--text)',
                background: 'var(--bg)',
                border: '1px solid var(--border)',
                borderRadius: 12,
                padding: '14px 16px',
                lineHeight: 1.7,
              }}
            >
              A3F1 · 9C2D · 7B40 · E58A
              <br />
              1D6C · F092 · 4AB3 · C7E5
            </div>

            <div className="flex items-center gap-2 flex-wrap">
              <Chip tone="outline" mono>对方应看到同样 8 组</Chip>
              <Chip tone="outline" mono>ED25519 PUBLIC KEY</Chip>
              <Chip tone="outline" mono>SHA-256 FINGERPRINT</Chip>
            </div>
          </section>

          <aside
            style={{
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              borderRadius: 18,
              padding: '24px 22px',
              display: 'flex',
              flexDirection: 'column',
              gap: 14,
              alignItems: 'center',
              textAlign: 'center',
            }}
          >
            <FakeQr size={210} />
            <div
              style={{
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                color: 'var(--text-mute)',
                letterSpacing: '0.12em',
                textTransform: 'uppercase',
              }}
            >
              meshdrop://pair?code=XJ9-LM4
            </div>
            <Chip tone="lime" mono>用 native app 扫码</Chip>
          </aside>
        </div>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <AsciiDivider label="—— 三步说明 · 3-STEP GUIDE ——" />
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 14,
            }}
          >
            {steps.map((s) => (
              <div
                key={s.idx}
                style={{
                  background: 'var(--surface)',
                  border: '1px solid var(--border)',
                  borderRadius: 14,
                  padding: '16px 16px 18px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 8,
                }}
              >
                <div
                  className="font-display"
                  style={{
                    fontSize: 11,
                    fontWeight: 700,
                    letterSpacing: '0.2em',
                    color: 'var(--lime-deep)',
                    fontFamily: '"Geist Mono", monospace',
                  }}
                >
                  STEP {s.idx} / 3
                </div>
                <div
                  className="font-display"
                  style={{ fontSize: 16, fontWeight: 700, letterSpacing: '-0.015em' }}
                >
                  {s.title}
                </div>
                <div style={{ fontSize: 13, color: 'var(--text-mute)', lineHeight: 1.55 }}>
                  {s.body}
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>

      <StatusBar peerCount={peerCount} hostIp={me.hostIp} connected={mode === 'live' ? conn === 'open' : true} />
    </div>
  )
}
