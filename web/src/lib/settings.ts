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

/** 可见性接入范围（持久化为稳定 key，显示文案由 i18n 给）。 */
export type ScopeKey = 'lanAll' | 'paired' | 'inviteLink'
/** 默认保存位置（持久化为稳定 key，显示文案由 i18n 给）。 */
export type DefaultPathKey = 'browserDownloads' | 'sandbox' | 'askEveryTime'

export interface AppSettings {
  autoAccept: boolean
  notifications: boolean
  /** 以下为「仅本端偏好」：浏览器无法直接改 native 端的雷达/可见性/落盘路径，
   *  这里只跨刷新记住选择，真正的可见性/接入控制需在 native 端配置。 */
  showInRadar: boolean
  scope: ScopeKey
  defaultPath: DefaultPathKey
  keepHistory: boolean
}

const KEY = 'meshdrop.settings'

const DEFAULTS: AppSettings = {
  autoAccept: false,
  notifications: true,
  showInRadar: true,
  scope: 'lanAll',
  defaultPath: 'browserDownloads',
  keepHistory: false,
}

/** 兼容旧版本里存的中文枚举值，迁移到稳定 key。 */
const LEGACY_SCOPE: Record<string, ScopeKey> = {
  'LAN 内全部': 'lanAll',
  '已配对设备': 'paired',
  '邀请链接': 'inviteLink',
}
const LEGACY_PATH: Record<string, DefaultPathKey> = {
  '浏览器下载': 'browserDownloads',
  '当前域名 sandbox': 'sandbox',
  '弹窗每次询问': 'askEveryTime',
}

export function loadSettings(): AppSettings {
  if (typeof localStorage === 'undefined') return { ...DEFAULTS }
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return { ...DEFAULTS }
    const parsed = JSON.parse(raw) as Partial<AppSettings>
    const merged = { ...DEFAULTS, ...parsed }
    // 把旧版本存的中文枚举迁移成稳定 key，避免下拉项对不上。
    merged.scope = LEGACY_SCOPE[merged.scope as string] ?? merged.scope
    merged.defaultPath = LEGACY_PATH[merged.defaultPath as string] ?? merged.defaultPath
    return merged
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
