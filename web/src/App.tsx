import { useState } from 'react'
import { useEngineConnection } from './hooks/useEngine'
import { BrowserChrome } from './components/BrowserChrome'
import { MainPage } from './pages/MainPage'
import { ReceivePage } from './pages/ReceivePage'
import { TransferPage } from './pages/TransferPage'
import { ClipboardPage } from './pages/ClipboardPage'
import { HistoryPage } from './pages/HistoryPage'
import { PairingPage } from './pages/PairingPage'
import { SettingsPage } from './pages/SettingsPage'
import { useTheme, type ThemeMode } from './hooks/useTheme'
import { MeshDropMark } from './components/MeshDropLogo'

const PAGES = [
  { id: 'main', label: '主页 · MAIN' },
  { id: 'receive', label: '接收 · RECEIVE' },
  { id: 'transfer', label: '传输 · TRANSFER' },
  { id: 'clipboard', label: '剪贴板 · CLIPBOARD' },
  { id: 'history', label: '历史 · HISTORY' },
  { id: 'pairing', label: '配对 · PAIRING' },
  { id: 'settings', label: '设置 · SETTINGS' },
] as const

type PageId = (typeof PAGES)[number]['id']

function initialPage(): PageId {
  if (typeof window === 'undefined') return 'main'
  const q = new URLSearchParams(window.location.search).get('page')
  return (PAGES.find((p) => p.id === q)?.id as PageId) ?? 'main'
}

export function App() {
  useEngineConnection()
  const { mode, setMode } = useTheme()
  const [page, setPage] = useState<PageId>(() => initialPage())

  const url =
    page === 'main' ? 'http://192.168.1.42/room/客厅' :
    page === 'receive' ? 'http://192.168.1.42/incoming/嘉伟' :
    page === 'transfer' ? 'http://192.168.1.42/transfers' :
    page === 'clipboard' ? 'http://192.168.1.42/clipboard' :
    page === 'history' ? 'http://192.168.1.42/history' :
    page === 'pairing' ? 'http://192.168.1.42/pair' :
    'http://192.168.1.42/settings'

  const pageNode =
    page === 'main' ? <MainPage /> :
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
            MESHDROP · WEB FALLBACK PREVIEW
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
              {p.label}
            </button>
          ))}
        </nav>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 4, background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 999, padding: 4 }}>
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
              {m}
            </button>
          ))}
        </div>
      </header>

      <main style={{ flex: 1, padding: 18, display: 'flex' }}>
        <BrowserChrome url={url} hint={`${page.toUpperCase()} · ROOM 客厅`}>
          {pageNode}
        </BrowserChrome>
      </main>
    </div>
  )
}
