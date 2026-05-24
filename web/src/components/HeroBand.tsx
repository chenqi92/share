import { Chip } from './Chip'
import { MeshDropLockup } from './MeshDropLogo'

interface Props {
  peerCount: number
}

export function HeroBand({ peerCount }: Props) {
  return (
    <section
      className="hero-grad"
      style={{
        padding: '28px 36px 30px',
        borderRadius: 18,
        border: '1px solid var(--border)',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <div className="flex items-start justify-between gap-6">
        <MeshDropLockup size={30} />
        <div className="flex items-center gap-2 flex-wrap justify-end">
          <Chip tone="lime" mono>● {peerCount} 在线 · {peerCount} ONLINE</Chip>
          <Chip tone="outline" mono>无需安装 · NO INSTALL</Chip>
          <Chip tone="outline" mono>访客模式 · GUEST</Chip>
        </div>
      </div>

      <h1
        className="font-display"
        style={{
          marginTop: 22,
          fontSize: 'clamp(34px, 4.2vw, 50px)',
          lineHeight: 1.02,
          fontWeight: 700,
          letterSpacing: '-0.03em',
          color: 'var(--text)',
        }}
      >
        你的浏览器,
        <br />
        <span
          style={{
            backgroundImage: 'linear-gradient(95deg, var(--flame) 8%, var(--lime) 90%)',
            WebkitBackgroundClip: 'text',
            backgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
          }}
        >
          已经是一个 MeshDrop 设备.
        </span>
      </h1>

      <p
        style={{
          marginTop: 14,
          maxWidth: 780,
          fontSize: 14.5,
          lineHeight: 1.55,
          color: 'var(--text-mute)',
        }}
      >
        Linux / Chromebook / 临时同事的笔记本 —— 任何浏览器进 <span style={{ fontFamily: '"Geist Mono", monospace', color: 'var(--text)' }}>192.168.1.42</span>,
        直接收发文件。会话密钥用 <span style={{ fontFamily: '"Geist Mono", monospace', color: 'var(--text)' }}>WebCrypto · X25519</span>,
        关页就销毁。
      </p>

      <div
        style={{
          marginTop: 18,
          display: 'flex',
          gap: 18,
          color: 'var(--text-faint)',
          fontFamily: '"Geist Mono", monospace',
          fontSize: 10.5,
          textTransform: 'uppercase',
          letterSpacing: '0.18em',
        }}
      >
        <span>⤓ DRAG-TO-SEND</span>
        <span>● E2E ENCRYPTED</span>
        <span>● LAN ONLY · 零云</span>
        <span>● PASTE-TO-SHARE</span>
      </div>
    </section>
  )
}
