import { Trans, useTranslation } from 'react-i18next'
import { Chip } from './Chip'
import { MeshDropLockup } from './MeshDropLogo'

interface Props {
  peerCount: number
}

export function HeroBand({ peerCount }: Props) {
  const { t } = useTranslation()
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
          <Chip tone="lime" mono>● {t('hero.onlineCount', { n: peerCount })}</Chip>
          <Chip tone="outline" mono>{t('hero.noInstall')}</Chip>
          <Chip tone="outline" mono>{t('hero.guest')}</Chip>
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
        {t('hero.titleLine1')}
        <br />
        <span
          style={{
            backgroundImage: 'linear-gradient(95deg, var(--flame) 8%, var(--lime) 90%)',
            WebkitBackgroundClip: 'text',
            backgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
          }}
        >
          {t('hero.titleLine2')}
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
        {/* host / idScheme 用 mono 高亮，是协议常量按原文显示，不进语言文件。 */}
        <Trans
          i18nKey="hero.body"
          values={{ host: '192.168.1.42', idScheme: 'Ed25519 · SHA-256' }}
          components={{
            mono: <span style={{ fontFamily: '"Geist Mono", monospace', color: 'var(--text)' }} />,
          }}
        />
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
        <span>⤓ {t('hero.dragToSend')}</span>
        <span>● {t('common.lanPlaintext')}</span>
        <span>● {t('hero.lanZeroCloud')}</span>
        <span>● {t('hero.pasteToShare')}</span>
      </div>
    </section>
  )
}
