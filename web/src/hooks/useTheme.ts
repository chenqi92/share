import { useEffect, useState } from 'react'

export type ThemeMode = 'light' | 'dark' | 'system'

const STORAGE_KEY = 'meshdrop-theme'

function readInitial(): ThemeMode {
  if (typeof window !== 'undefined') {
    const fromUrl = new URLSearchParams(window.location.search).get('theme')
    if (fromUrl === 'light' || fromUrl === 'dark' || fromUrl === 'system') return fromUrl
  }
  if (typeof localStorage === 'undefined') return 'dark'
  const v = localStorage.getItem(STORAGE_KEY)
  return v === 'light' || v === 'dark' || v === 'system' ? v : 'dark'
}

function resolveSystem(): 'light' | 'dark' {
  if (typeof window === 'undefined') return 'dark'
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

function applyTheme(mode: ThemeMode) {
  if (typeof document === 'undefined') return
  const actual = mode === 'system' ? resolveSystem() : mode
  document.documentElement.setAttribute('data-theme', actual)
}

export function useTheme(): { mode: ThemeMode; setMode: (m: ThemeMode) => void; actual: 'light' | 'dark' } {
  const [mode, setModeState] = useState<ThemeMode>(() => readInitial())

  useEffect(() => {
    applyTheme(mode)
    if (mode === 'system') {
      const mq = window.matchMedia('(prefers-color-scheme: dark)')
      const handler = () => applyTheme('system')
      mq.addEventListener('change', handler)
      return () => mq.removeEventListener('change', handler)
    }
  }, [mode])

  const setMode = (m: ThemeMode) => {
    localStorage.setItem(STORAGE_KEY, m)
    setModeState(m)
  }

  const actual = mode === 'system' ? resolveSystem() : mode
  return { mode, setMode, actual }
}
