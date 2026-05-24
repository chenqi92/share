/* COMMON §9 — mock data ported to TS, drives all pages. */

export type DeviceKind = 'mac' | 'ios' | 'ipad' | 'android' | 'win' | 'linux' | 'web'

export interface MeshDevice {
  id: string
  name: string
  who: string
  kind: DeviceKind
  dist: number
  angle: number
  color: string
  initials: string
  os: string
  rtt: number
  online?: boolean
  paired?: boolean
}

export const MESHDROP_DEVICES: MeshDevice[] = [
  { id: 'lily',   name: "Lily's MacBook",   who: '李莉',   kind: 'mac',     dist: 0.55, angle: 35,  color: '#FFB4A1', initials: 'LL', os: 'macOS 14',  rtt: 18, online: true,  paired: true  },
  { id: 'kun',    name: 'Kun · Pixel 8',    who: '坤',     kind: 'android', dist: 0.78, angle: 110, color: '#B7E5C8', initials: 'K',  os: 'Android 15', rtt: 32, online: true,  paired: true  },
  { id: 'jiawei', name: 'Jiawei · iPad',    who: '嘉伟',   kind: 'ipad',    dist: 0.40, angle: 200, color: '#C7B8FF', initials: 'JW', os: 'iPadOS 18', rtt: 14, online: true,  paired: true  },
  { id: 'mengxi', name: 'Meng Xi · iPhone', who: '孟茜',   kind: 'ios',     dist: 0.62, angle: 265, color: '#FFD970', initials: 'MX', os: 'iOS 18',    rtt: 26, online: true,  paired: true  },
  { id: 'dev01',  name: 'DEV-01 · Win 11',  who: '工位机', kind: 'win',     dist: 0.88, angle: 320, color: '#9AD0FF', initials: 'D1', os: 'Win 11',    rtt: 41, online: false, paired: false },
]

export interface HistoryEntry {
  id: string
  dir: 'incoming' | 'outgoing'
  peer: string
  time: string
  kind: 'image' | 'file' | 'text'
  status: 'done' | 'transferring' | 'queued' | 'failed'
  name?: string
  size?: string
  ext?: string
  count?: number
  content?: string
  progress?: number
}

export const MESHDROP_HISTORY: HistoryEntry[] = [
  { id: 'h6', dir: 'incoming', peer: '孟茜',   time: '14:18', kind: 'image', count: 2, status: 'done' },
  { id: 'h5', dir: 'outgoing', peer: '孟茜',   time: '14:10', kind: 'file',  name: '设计稿_v3_final.fig', size: '14.2 MB', ext: 'fig', status: 'done' },
  { id: 'h4', dir: 'outgoing', peer: '李莉',   time: '14:09', kind: 'text',  content: '改完了，整理一下发你 👇', status: 'done' },
  { id: 'h3', dir: 'outgoing', peer: '嘉伟',   time: '14:08', kind: 'file',  name: 'iOS-mocks-final.zip', size: '48.6 MB', ext: 'zip',  progress: 67, status: 'transferring' },
  { id: 'h2', dir: 'incoming', peer: '坤',     time: '13:58', kind: 'file',  name: 'IMG_4821~38.heic',    size: '128 MB',  ext: 'heic', progress: 12, status: 'transferring' },
  { id: 'h1', dir: 'outgoing', peer: '李莉',   time: '13:42', kind: 'file',  name: 'demo-video.mp4',      size: '512 MB',  ext: 'mp4',  status: 'queued' },
]

export interface PendingPairing {
  id: string
  peer: string
  deviceName: string
  fingerprint: string
  receivedAt: string
}

export const MESHDROP_PENDING_PAIRING: PendingPairing = {
  id: 'pp-1',
  peer: '李莉',
  deviceName: "Lily's MacBook",
  fingerprint: 'ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF',
  receivedAt: '8s ago',
}

export interface PendingOffer {
  id: string
  peer: string
  deviceName: string
  fileName: string
  fileSize: string
  ext?: string
  pages?: number
  note?: string
  receivedAt: string
}

export const MESHDROP_PENDING_OFFER: PendingOffer = {
  id: 'po-1',
  peer: '嘉伟',
  deviceName: 'Jiawei · iPad',
  fileName: '规划文档_v0.3.pages',
  fileSize: '3.4 MB',
  ext: 'pages',
  pages: 12,
  note: '改完了帮我看下第二章，特别是 §2.3 那段',
  receivedAt: 'just now',
}

export interface ClipboardItem {
  id: string
  who: string
  kind: 'link' | 'text' | 'code'
  body: string
  ago: string
  lang?: string
}

export const MESHDROP_CLIPBOARD: ClipboardItem[] = [
  { id: 'cb1', who: '嘉伟', kind: 'link', body: 'https://internal.acme.io/specs/auth-v3', ago: '8s' },
  { id: 'cb2', who: '孟茜', kind: 'text', body: '"1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配"', ago: '12m' },
  { id: 'cb3', who: '李莉', kind: 'code', lang: 'sh', body: 'docker run --rm -v $PWD:/app meshdrop/build:latest', ago: '34m' },
  { id: 'cb4', who: '坤',   kind: 'text', body: '"会议室 B 已订到 16:00–17:30"', ago: '1h' },
  { id: 'cb5', who: '我',   kind: 'link', body: 'figma://file/Q8xK2/MeshDrop?node-id=42:108', ago: '2h' },
]

export type TransferState = 'sending' | 'receiving' | 'done' | 'failed' | 'queued'

export interface TransferRow {
  id: string
  name: string
  size: string
  ext: string
  from: string
  to: string
  progress: number
  state: TransferState
  eta?: string
  speed?: string
}

export const MESHDROP_TRANSFERS: TransferRow[] = [
  { id: 't1', name: '设计稿_v3_final.fig',  size: '14.2 MB',         ext: 'fig',  from: '我',  to: '孟茜', progress: 100, state: 'done',       eta: '00:08' },
  { id: 't2', name: 'iOS-mocks-final.zip',  size: '48.6 MB',         ext: 'zip',  from: '我',  to: '孟茜', progress: 67,  state: 'sending',    speed: '8.4 MB/s',  eta: '00:02' },
  { id: 't3', name: 'spec_PRD_2026Q1.pdf',  size: '2.1 MB',          ext: 'pdf',  from: '我',  to: '嘉伟', progress: 34,  state: 'sending',    speed: '3.1 MB/s',  eta: '00:01' },
  { id: 't4', name: 'IMG_4821~IMG_4838.heic', size: '128 MB · 18 张', ext: 'heic', from: '坤',  to: '我',  progress: 12,  state: 'receiving',  speed: '11.7 MB/s', eta: '00:09' },
  { id: 't5', name: 'release-notes.md',     size: '4.8 KB',          ext: 'md',   from: '我',  to: 'DEV-01', progress: 100, state: 'done',     eta: '00:01' },
  { id: 't6', name: 'demo-video.mp4',       size: '512 MB',          ext: 'mp4',  from: '我',  to: '李莉', progress: 0,   state: 'queued' },
]

export const MESHDROP_UPLOAD_BARS = [3, 5, 8, 7, 9, 6, 11, 12, 14, 11, 10, 11, 12, 11]
export const MESHDROP_DOWNLOAD_BARS = [8, 9, 7, 6, 5, 7, 10, 12, 11, 12, 11, 12, 11, 12]
export const MESHDROP_SESSION_BARS = [2, 3, 5, 4, 6, 8, 7, 9, 10, 12, 11, 12, 11, 12, 14]

export const MESHDROP_ME = {
  name: '访客 · Visitor',
  fingerprint: 'ZX8K · L72M · 9FQ3 · 7HD2',
  ip: '192.168.1.207',
  hostIp: '192.168.1.42',
  os: 'Chromium 121 · macOS',
  visibility: '访客可见',
  pairingCode: 'XJ9-LM4',
}

export interface HistoryDay {
  label: string
  items: HistoryEntry[]
}

export const MESHDROP_HISTORY_BY_DAY: HistoryDay[] = [
  {
    label: 'TODAY · 今天 · 6 件',
    items: MESHDROP_HISTORY,
  },
  {
    label: 'YESTERDAY · 昨天 · 4 件',
    items: [
      { id: 'y1', dir: 'incoming', peer: '李莉', time: '昨 22:14', kind: 'file',  name: 'meeting-notes.md', size: '8.2 KB',  ext: 'md',  status: 'done' },
      { id: 'y2', dir: 'outgoing', peer: '坤',   time: '昨 19:31', kind: 'image', count: 3, status: 'done' },
      { id: 'y3', dir: 'incoming', peer: '嘉伟', time: '昨 18:02', kind: 'text',  content: '后端接口我接好了，明早一起跑下', status: 'done' },
      { id: 'y4', dir: 'outgoing', peer: '孟茜', time: '昨 09:48', kind: 'file',  name: 'logo-final.svg', size: '46 KB',  ext: 'svg', status: 'done' },
    ],
  },
  {
    label: 'EARLIER · 早些时候 · 3 件',
    items: [
      { id: 'e1', dir: 'incoming', peer: '孟茜', time: '周三 16:20', kind: 'file', name: '团队合影.heic', size: '4.1 MB',  ext: 'heic', status: 'done' },
      { id: 'e2', dir: 'outgoing', peer: 'DEV-01', time: '周二 14:08', kind: 'file', name: 'build.exe', size: '92 MB',  ext: 'exe', status: 'failed' },
      { id: 'e3', dir: 'outgoing', peer: '李莉',  time: '周二 11:30', kind: 'text', content: '中午一起？三楼那家', status: 'done' },
    ],
  },
]
