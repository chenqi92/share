/**
 * i18next 初始化 —— 默认 zh-CN（简体中文），en（English）为备选语言。
 *
 * why 这样选语言：
 *   1) URL ?lang= 覆盖（便于截图 / 调试）
 *   2) localStorage 记住用户上次选择
 *   3) 浏览器 navigator.language 检测（zh* → zh-CN，其余 → en）
 *   4) 兜底 zh-CN
 * 选择会写回 localStorage，跨刷新保留。
 */

import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import zhCN from './zh-CN.json'
import en from './en.json'

export const SUPPORTED_LANGS = ['zh-CN', 'en'] as const
export type Lang = (typeof SUPPORTED_LANGS)[number]

const STORAGE_KEY = 'meshdrop.lang'

function detectLang(): Lang {
  if (typeof window === 'undefined') return 'zh-CN'
  // 1) URL 覆盖
  try {
    const q = new URLSearchParams(window.location.search).get('lang')
    if (q === 'zh-CN' || q === 'zh' || q?.startsWith('zh')) return 'zh-CN'
    if (q === 'en' || q?.startsWith('en')) return 'en'
  } catch {
    /* ignore */
  }
  // 2) localStorage 记忆
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved === 'zh-CN' || saved === 'en') return saved
  } catch {
    /* ignore */
  }
  // 3) 浏览器语言检测
  const nav = navigator.language || (navigator.languages && navigator.languages[0]) || ''
  if (nav.toLowerCase().startsWith('zh')) return 'zh-CN'
  if (nav.toLowerCase().startsWith('en')) return 'en'
  // 4) 兜底
  return 'zh-CN'
}

const initial = detectLang()

void i18n.use(initReactI18next).init({
  resources: {
    'zh-CN': { translation: zhCN },
    en: { translation: en },
  },
  lng: initial,
  fallbackLng: 'zh-CN',
  interpolation: { escapeValue: false }, // React 已做 XSS 转义
  returnNull: false,
})

// 切语言时同步 <html lang> 并记住选择。
i18n.on('languageChanged', (lng) => {
  try {
    localStorage.setItem(STORAGE_KEY, lng)
  } catch {
    /* ignore */
  }
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('lang', lng)
  }
})

if (typeof document !== 'undefined') {
  document.documentElement.setAttribute('lang', initial)
}

export default i18n
