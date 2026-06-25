import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useEngineConnection } from './hooks/useEngine'
import { BrowserChrome } from './components/BrowserChrome'
import { MainPage } from './pages/MainPage'
import { ChatPage } from './pages/ChatPage'
import { ReceivePage } from './pages/ReceivePage'
import { TransferPage } from './pages/TransferPage'
import { ClipboardPage } from './pages/ClipboardPage'
import { HistoryPage } from './pages/HistoryPage'
import { PairingPage } from './pages/PairingPage'
import { SettingsPage } from './pages/SettingsPage'
import { useTheme, type ThemeMode } from './hooks/useTheme'
import { MeshDropMark } from './components/MeshDropLogo'

// label 的可见文案由 i18n 提供（app.nav.<id>），这里只保留稳定的页面 id。
const PAGES = [
  { id: 'main' },
  { id: 'chat' },
  { id: 'receive' },
  { id: 'transfer' },
  { id: 'clipboard' },
  { id: 'history' },
  { id: 'pairing' },
  { id: 'settings' },
] as const

type PageId = (typeof PAGES)[number]['id']

function initialPage(): PageId {
  if (typeof window === 'undefined') return 'main'
  const q = new URLSearchParams(window.location.search).get('page')
  return (PAGES.find((p) => p.id === q)?.id as PageId) ?? 'main'
}

export function App() {
  useEngineConnection()
  const { t, i18n } = useTranslation()
  const { mode, setMode } = useTheme()
  const [page, setPage] = useState<PageId>(() => initialPage())
  // URL 里房间名保持原文（属可演示数据），但 hint 里的可读部分走 i18n。
  const room = t('app.roomLiving')

  const url =
    page === 'main' ? 'https://meshdrop.local/room' :
    page === 'chat' ? 'https://meshdrop.local/chat' :
    page === 'receive' ? 'https://meshdrop.local/incoming' :
    page === 'transfer' ? 'https://meshdrop.local/transfers' :
    page === 'clipboard' ? 'https://meshdrop.local/clipboard' :
    page === 'history' ? 'https://meshdrop.local/history' :
    page === 'pairing' ? 'https://meshdrop.local/pair' :
    'https://meshdrop.local/settings'

  const pageNode =
    page === 'main' ? <MainPage /> :
    page === 'chat' ? <ChatPage /> :
    page === 'receive' ? <ReceivePage /> :
    page === 'transfer' ? <TransferPage /> :
    page === 'clipboard' ? <ClipboardPage /> :
    page === 'history' ? <HistoryPage /> :
    page === 'pairing' ? <PairingPage /> :
    <SettingsPage />

  return (
    <div
      style={{
        minHeight: '100vh',
        background: 'var(--bg2)',
        display: 'flex',
        flexDirection: 'column',
        color: 'var(--text)',
      }}
    >
      {/* outer "host" frame – page switcher + theme toggle */}
      <header
        style={{
          height: 50,
          flexShrink: 0,
          padding: '0 18px',
          display: 'flex',
          alignItems: 'center',
          gap: 14,
          borderBottom: '1px solid var(--border)',
          background: 'var(--bg)',
        }}
      >
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <MeshDropMark size={20} />
          <span
            style={{
              fontFamily: '"Geist Mono", monospace',
              fontSize: 10.5,
              textTransform: 'uppercase',
              letterSpacing: '0.22em',
              color: 'var(--text-faint)',
            }}
          >
            {t('app.previewBanner')}
          </span>
        </span>
        <nav
          style={{
            marginLeft: 16,
            display: 'flex',
            gap: 4,
            background: 'var(--bg2)',
            border: '1px solid var(--border)',
            borderRadius: 999,
            padding: 4,
          }}
        >
          {PAGES.map((p) => (
            <button
              key={p.id}
              onClick={() => setPage(p.id)}
              style={{
                padding: '6px 12px',
                borderRadius: 999,
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                fontWeight: 600,
                letterSpacing: '0.06em',
                textTransform: 'uppercase',
                background: page === p.id ? 'var(--ink)' : 'transparent',
                color: page === p.id ? 'var(--paper)' : 'var(--text-mute)',
              }}
            >
              {t(`app.nav.${p.id}`)}
            </button>
          ))}
        </nav>
        {/* 语言切换：zh-CN ↔ en，写回 localStorage（见 i18n/index.ts）。 */}
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 4, background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 999, padding: 4 }}>
          {(['zh-CN', 'en'] as const).map((lng) => (
            <button
              key={lng}
              onClick={() => { void i18n.changeLanguage(lng) }}
              style={{
                padding: '6px 11px',
                borderRadius: 999,
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                fontWeight: 600,
                letterSpacing: '0.06em',
                textTransform: 'uppercase',
                background: i18n.language === lng ? 'var(--ink)' : 'transparent',
                color: i18n.language === lng ? 'var(--paper)' : 'var(--text-mute)',
              }}
            >
              {lng === 'zh-CN' ? '中' : 'EN'}
            </button>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 4, background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 999, padding: 4 }}>
          {(['light', 'dark', 'system'] as ThemeMode[]).map((m) => (
            <button
              key={m}
              onClick={() => setMode(m)}
              style={{
                padding: '6px 11px',
                borderRadius: 999,
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                fontWeight: 600,
                letterSpacing: '0.06em',
                textTransform: 'uppercase',
                background: mode === m ? 'var(--lime)' : 'transparent',
                color: mode === m ? 'var(--ink)' : 'var(--text-mute)',
              }}
            >
              {t(`app.theme.${m}`)}
            </button>
          ))}
        </div>
      </header>

      <main style={{ flex: 1, padding: 18, display: 'flex' }}>
        <BrowserChrome url={url} hint={`${page.toUpperCase()} · ${t('browserChrome.roomHint', { room })}`}>
          {pageNode}
        </BrowserChrome>
      </main>
    </div>
  )
}
