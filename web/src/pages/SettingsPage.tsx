import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { AsciiDivider } from '../components/AsciiDivider'
import { Chip } from '../components/Chip'
import { StatusBar } from '../components/StatusBar'
import { useEngine } from '../hooks/useEngine'
import { getGatewayEndpoint } from '../lib/engine'
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

interface SelectOption {
  value: string
  label: string
}

interface SelectRowProps {
  label: string
  hint?: string
  value: string
  // value 是持久化的稳定 key，label 是 i18n 后的可见文案。
  options: SelectOption[]
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
          const active = value === o.value
          return (
            <button
              key={o.value}
              onClick={() => onChange(o.value)}
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
              {o.label}
            </button>
          )
        })}
      </div>
    </div>
  )
}

export function SettingsPage() {
  const { t } = useTranslation()
  // 自动接收 / 通知：持久化到 localStorage，engine 的 onOfferPending / notifyIncoming 会读取，
  // 不再是「关页即丢、且 live 模式不生效」的纯本地 state。
  const [settings, setSettings] = useState<AppSettings>(() => loadSettings())
  const updateSettings = (patch: Partial<AppSettings>) =>
    setSettings((prev) => {
      const next = { ...prev, ...patch }
      saveSettings(next)
      return next
    })
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
      case 'open': return t('settings.session.conn.open')
      case 'connecting': return t('settings.session.conn.connecting')
      case 'closed': return t('settings.session.conn.closed')
      case 'unpaired': return t('settings.session.conn.unpaired')
      case 'idle': return t('settings.session.conn.idle')
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
            {t('settings.eyebrow')}
          </div>
          <h1
            className="font-display"
            style={{ fontSize: 30, fontWeight: 700, letterSpacing: '-0.025em', lineHeight: 1 }}
          >
            {t('settings.titleLead')}<span style={{ color: 'var(--text-mute)' }}>{t('settings.titleTail')}</span>
          </h1>
          <p style={{ marginTop: 8, color: 'var(--text-mute)', fontSize: 13.5, maxWidth: 720 }}>
            {t('settings.subtitle')}
          </p>
        </header>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label={`—— ${t('settings.visibility.section')} ——`} />
          <ToggleRow
            label={t('settings.visibility.showInRadar')}
            hint={t('settings.visibility.showInRadarHint')}
            value={settings.showInRadar}
            onChange={(v) => updateSettings({ showInRadar: v })}
          />
          <SelectRow
            label={t('settings.visibility.scope')}
            hint={t('settings.visibility.scopeHint')}
            value={settings.scope}
            options={[
              { value: 'lanAll', label: t('settings.visibility.scopeOptions.lanAll') },
              { value: 'paired', label: t('settings.visibility.scopeOptions.paired') },
              { value: 'inviteLink', label: t('settings.visibility.scopeOptions.inviteLink') },
            ]}
            onChange={(v) => updateSettings({ scope: v as AppSettings['scope'] })}
          />
          <ToggleRow
            label={t('settings.visibility.rememberBrowser')}
            hint={t('settings.visibility.rememberBrowserHint')}
            value={mode === 'live' && conn !== 'unpaired'}
            onChange={(on) => { if (!on) forgetSession() }}
          />
        </section>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label={`—— ${t('settings.security.section')} ——`} />
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
            <Chip tone={mode === 'live' ? 'lime' : 'outline'} mono>
              {mode === 'live' ? `● ${t('common.lanPlaintext')}` : t('settings.security.mockSession')}
            </Chip>
            <Chip tone="outline" mono>{t('settings.security.fingerprintVerify')}</Chip>
            <Chip tone="outline" mono>{t('settings.security.gatewayWss')}</Chip>
            <span
              style={{
                marginLeft: 'auto',
                fontFamily: '"Geist Mono", monospace',
                fontSize: 11,
                color: 'var(--text-faint)',
                letterSpacing: '0.02em',
              }}
            >
              {t('settings.security.fingerprintLabel', { fingerprint: me.fingerprint })}
            </span>
          </div>
          <ToggleRow
            label={t('settings.security.autoAccept')}
            hint={t('settings.security.autoAcceptHint')}
            value={settings.autoAccept}
            onChange={(v) => updateSettings({ autoAccept: v })}
          />
          <ToggleRow
            label={t('settings.security.notify')}
            hint={t('settings.security.notifyHint')}
            value={settings.notifications}
            onChange={(v) => {
              updateSettings({ notifications: v })
              // 用户主动打开时才请求授权（用户手势触发，符合浏览器最佳实践）。
              if (v && typeof window !== 'undefined' && 'Notification' in window
                  && Notification.permission === 'default') {
                Notification.requestPermission().catch(() => { /* 用户拒绝则 notifyIncoming 静默 */ })
              }
            }}
          />
        </section>

        {mode === 'live' && (
          <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <AsciiDivider label={`—— ${t('settings.session.section')} ——`} />
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
                {t('settings.session.gatewayLabel', { endpoint: getGatewayEndpoint() || window.location.host })}
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
                {t('settings.session.reconnect')}
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
                  {t('settings.session.confirmText')}
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
                  {t('common.cancel')}
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
                  {t('settings.session.confirmDisconnect')}
                </button>
              </div>
            )}
          </section>
        )}

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label={`—— ${t('settings.receiveBehavior.section')} ——`} />
          <SelectRow
            label={t('settings.receiveBehavior.defaultPath')}
            hint={t('settings.receiveBehavior.defaultPathHint')}
            value={settings.defaultPath}
            options={[
              { value: 'browserDownloads', label: t('settings.receiveBehavior.pathOptions.browserDownloads') },
              { value: 'sandbox', label: t('settings.receiveBehavior.pathOptions.sandbox') },
              { value: 'askEveryTime', label: t('settings.receiveBehavior.pathOptions.askEveryTime') },
            ]}
            onChange={(v) => updateSettings({ defaultPath: v as AppSettings['defaultPath'] })}
          />
          <ToggleRow
            label={t('settings.receiveBehavior.keepHistory')}
            hint={t('settings.receiveBehavior.keepHistoryHint')}
            value={settings.keepHistory}
            onChange={(v) => updateSettings({ keepHistory: v })}
          />
        </section>

        <section style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <AsciiDivider label={`—— ${t('settings.about.section')} ——`} />
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
            {t('settings.about.engine', { mode: mode === 'live' ? t('settings.about.modeLive') : t('settings.about.modeMock') })}
          </div>
        </section>
      </div>

      <StatusBar peerCount={peerCount} hostIp={me.hostIp} connected={mode === 'live' ? conn === 'open' : true} />
    </div>
  )
}
