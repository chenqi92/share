/**
 * 本地偏好设置 —— 用 localStorage 持久化，无后端 / 无第三方依赖。
 *
 * 这里只放「之前是空回调 / 纯本地 state、live 模式下没真正生效」的开关，
 * 接成真实状态后跨刷新保留并被 engine 逻辑读取：
 *   - autoAccept   ：未配对设备发来文件时是否自动接受 offer（onOfferPending 读取）
 *   - notifications ：是否弹浏览器通知（notifyIncoming 在弹之前读取）
 *
 * 主题（深 / 浅 / 跟随系统）已由 hooks/useTheme.ts 单独管理，不在此重复。
 */

export interface AppSettings {
  autoAccept: boolean
  notifications: boolean
}

const KEY = 'meshdrop.settings'

const DEFAULTS: AppSettings = {
  autoAccept: false,
  notifications: true,
}

export function loadSettings(): AppSettings {
  if (typeof localStorage === 'undefined') return { ...DEFAULTS }
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return { ...DEFAULTS }
    const parsed = JSON.parse(raw) as Partial<AppSettings>
    return { ...DEFAULTS, ...parsed }
  } catch {
    return { ...DEFAULTS }
  }
}

export function saveSettings(s: AppSettings): void {
  if (typeof localStorage === 'undefined') return
  try {
    localStorage.setItem(KEY, JSON.stringify(s))
  } catch {
    /* ignore quota / 隐私模式 */
  }
}

/** 读取「是否允许弹通知」开关。 */
export function notificationsEnabled(): boolean {
  return loadSettings().notifications
}

/** 读取「自动接收」开关。 */
export function autoAcceptEnabled(): boolean {
  return loadSettings().autoAccept
}
