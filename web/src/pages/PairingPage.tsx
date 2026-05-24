import { AsciiDivider } from '../components/AsciiDivider'
import { Chip } from '../components/Chip'
import { StatusBar } from '../components/StatusBar'
import { MESHDROP_DEVICES, MESHDROP_ME } from '../lib/mockData'

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
  const peerCount = MESHDROP_DEVICES.filter((d) => d.online).length
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
              {MESHDROP_ME.pairingCode.split('').map((ch, i) => (
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
              ZX8K · L72M · 9FQ3 · 7HD2
              <br />
              M1P6 · QA8N · KZ9R · X3WF
            </div>

            <div className="flex items-center gap-2 flex-wrap">
              <Chip tone="outline" mono>对方应看到同样 8 组</Chip>
              <Chip tone="outline" mono>X25519 PUBLIC KEY</Chip>
              <Chip tone="outline" mono>HMAC-SHA-256</Chip>
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

      <StatusBar peerCount={peerCount} hostIp={MESHDROP_ME.hostIp} />
    </div>
  )
}
