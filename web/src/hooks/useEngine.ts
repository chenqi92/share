/**
 * 真实 engine hook —— 替代 useMockEngine。
 *
 * 行为：
 *   - live：从 native Web Gateway 的 WS 拉真实 state，所有 send/* 走 GatewayClient
 *   - mock：仅在显式 `?mock=1` / `?mock=true` 时启用，所有写入仅本地状态
 *
 * 上面两种模式对组件透明 —— store 的 shape 一致。
 */

import { useEffect } from 'react'
import { create } from 'zustand'
import {
  MESHDROP_DEVICES,
  MESHDROP_HISTORY_BY_DAY,
  MESHDROP_TRANSFERS,
  MESHDROP_CLIPBOARD,
  MESHDROP_ME,
  MESHDROP_PENDING_OFFER,
  MESHDROP_PENDING_PAIRING,
  type ClipboardItem,
  type HistoryDay,
  type HistoryEntry,
  type MeIdentity,
  type MeshDevice,
  type PendingOffer,
  type PendingPairing,
  type TransferRow,
} from '../lib/mockData'
import {
  GatewayClient,
  adaptClipboard,
  adaptDevice,
  adaptHistory,
  adaptMe,
  adaptOffer,
  adaptPairing,
  adaptTransfer,
  getClient,
  type EngineConnState,
} from '../lib/engine'
import { autoAcceptEnabled, notificationsEnabled } from '../lib/settings'

export interface EngineState {
  mode: 'live' | 'mock'
  conn: EngineConnState

  /** 本机身份：mock 模式用常量；live 模式从 host 握手快照 me 字段 + 浏览器 UA 派生。 */
  me: MeIdentity
  devices: MeshDevice[]
  transfers: TransferRow[]
  history: HistoryDay[]
  clipboardInbox: ClipboardItem[]
  /** 速度柱状图实时序列（每秒采样，live 模式才填）。 */
  uploadBars: number[]
  downBars: number[]
  pendingOffer?: PendingOffer
  pendingPairing?: PendingPairing
  selectedPeerId?: string

  selectPeer: (id?: string) => void
  setPendingOffer: (o?: PendingOffer) => void
  setPendingPairing: (p?: PendingPairing) => void

  // actions —— mock 模式下只改本地 state，live 模式下走 gateway
  sendText: (peerId: string, text: string) => Promise<void>
  /** 显式推送剪贴板内容到对端。kind 省略时按内容自动判定 link/code/text。 */
  pushClipboard: (peerId: string, content: string, kind?: ClipboardItem['kind']) => Promise<void>
  sendFiles: (peerId: string, files: File[], opts?: { noteText?: string }) => Promise<void>
  acceptOffer: () => Promise<void>
  rejectOffer: () => Promise<void>
  acceptPairing: (trust?: boolean) => Promise<void>
  rejectPairing: () => Promise<void>
  pair: (code: string) => Promise<boolean>
  forgetSession: () => void
  cancelTransfer: (transferId: string) => Promise<void>
  retryTransfer: (transferId: string) => Promise<void>
  /** 已接收文件的下载 URL；mock 模式返回 undefined（无真实文件）。 */
  downloadURL: (historyId: string) => string | undefined
  /** 每秒采样一次：把进行中传输的瞬时速率按方向汇总成一个时间桶，推入环形序列。 */
  sampleThroughput: () => void
}

function isMock(): boolean {
  if (typeof window === 'undefined') return true
  const q = new URLSearchParams(window.location.search).get('mock')
  if (q === '1' || q === 'true') return true
  return false
}

function buildHistoryDays(items: HistoryEntry[]): HistoryDay[] {
  if (!items.length) return []
  return [{ label: `TODAY · 今天 · ${items.length} 件`, items }]
}

/** 收到对端内容时弹一条浏览器通知（需用户已授权 + 设置里开启通知）。无权限 / 不支持时静默。 */
function notifyIncoming(title: string, body: string) {
  if (typeof window === 'undefined' || !('Notification' in window)) return
  if (!notificationsEnabled()) return
  if (Notification.permission !== 'granted') return
  try { new Notification(title, { body: body.slice(0, 120) }) } catch { /* ignore */ }
}

/** 按内容粗判剪贴板 kind（与 Apple / Android 端同口径）。 */
export function clipKind(content: string): ClipboardItem['kind'] {
  const t = content.trim()
  if ((t.startsWith('http://') || t.startsWith('https://')) && !/\s/.test(t)) return 'link'
  if (t.includes('\n') && /[{};=<>/]/.test(t)) return 'code'
  return 'text'
}

export const useEngine = create<EngineState>((set, get) => ({
  mode: isMock() ? 'mock' : 'live',
  conn: 'idle',

  // mock 用写死常量；live 先放一个浏览器 UA 派生的占位，握手快照到达后由 onState 覆盖。
  me: isMock() ? MESHDROP_ME : adaptMe(undefined),
  devices: isMock() ? MESHDROP_DEVICES : [],
  transfers: isMock() ? MESHDROP_TRANSFERS : [],
  history: isMock() ? MESHDROP_HISTORY_BY_DAY : [],
  clipboardInbox: isMock() ? MESHDROP_CLIPBOARD : [],
  uploadBars: [],
  downBars: [],
  pendingOffer: undefined,
  pendingPairing: undefined,
  selectedPeerId: isMock() ? 'jiawei' : undefined,

  selectPeer: (id) => set({ selectedPeerId: id }),
  setPendingOffer: (o) => set({ pendingOffer: o }),
  setPendingPairing: (p) => set({ pendingPairing: p }),

  sendText: async (peerId, text) => {
    if (get().mode === 'live') {
      await getClient().sendText(peerId, text)
      return
    }
    // mock：在本地 transfers 加一条
    const t: TransferRow = {
      id: `t-${Date.now()}`,
      name: text.length > 32 ? text.slice(0, 32) + '…' : text,
      size: `${new Blob([text]).size} B`, ext: 'txt',
      from: '我', to: get().devices.find((d) => d.id === peerId)?.who ?? peerId,
      progress: 100, state: 'done',
    }
    set({ transfers: [t, ...get().transfers] })
  },

  pushClipboard: async (peerId, content, kind) => {
    const k = kind ?? clipKind(content)
    if (get().mode === 'live') {
      await getClient().sendClipboard(peerId, content, k)
      return
    }
    // mock：在本地 clipboardInbox 顶部加一条（以"我"署名）
    const item: ClipboardItem = {
      id: `cb-${Date.now()}`,
      who: '我',
      kind: k,
      body: content,
      ago: 'just now',
    }
    set({ clipboardInbox: [item, ...get().clipboardInbox].slice(0, 50) })
  },

  sendFiles: async (peerId, files, opts) => {
    if (get().mode === 'live') {
      const c = getClient()
      for (const f of files) await c.sendFile(peerId, f, opts)
      return
    }
    const peerName = get().devices.find((d) => d.id === peerId)?.who ?? peerId
    const rows: TransferRow[] = files.map((f) => ({
      id: `t-${Date.now()}-${f.name}`,
      name: f.name, size: `${(f.size / 1024 / 1024).toFixed(1)} MB`,
      ext: f.name.split('.').pop()?.toLowerCase() ?? '',
      from: '我', to: peerName, progress: 0, state: 'sending', speed: '0 MB/s',
    }))
    set({ transfers: [...rows, ...get().transfers] })
  },

  acceptOffer: async () => {
    const offer = get().pendingOffer
    if (!offer) return
    if (get().mode === 'live') {
      await getClient().acceptOffer(offer.id)
    }
    set({ pendingOffer: undefined })
  },

  rejectOffer: async () => {
    const offer = get().pendingOffer
    if (!offer) return
    if (get().mode === 'live') {
      await getClient().rejectOffer(offer.id)
    }
    set({ pendingOffer: undefined })
  },

  acceptPairing: async (trust = true) => {
    const p = get().pendingPairing
    if (!p) return
    if (get().mode === 'live') {
      await getClient().acceptPairing(p.id, trust)
    }
    set({ pendingPairing: undefined })
  },

  rejectPairing: async () => {
    const p = get().pendingPairing
    if (!p) return
    if (get().mode === 'live') {
      await getClient().rejectPairing(p.id)
    }
    set({ pendingPairing: undefined })
  },

  pair: async (code) => {
    if (get().mode !== 'live') return true
    const ok = await getClient().pair(code)
    if (ok) await getClient().connect()
    return ok
  },

  forgetSession: () => {
    getClient().forgetSession()
    set({ conn: 'unpaired' })
  },

  cancelTransfer: async (transferId) => {
    if (get().mode === 'live') {
      await getClient().cancelTransfer(transferId)
      return
    }
    // mock：把对应 transfer state 标 failed（视觉提示已取消）
    set({
      transfers: get().transfers.map((t) =>
        t.id === transferId ? { ...t, state: 'failed' } : t,
      ),
    })
  },

  retryTransfer: async (transferId) => {
    if (get().mode === 'live') {
      await getClient().retryTransfer(transferId)
      return
    }
    // mock：把对应行从 failed 重置回 sending 0%（视觉模拟重发）
    set({
      transfers: get().transfers.map((t) =>
        t.id === transferId ? { ...t, state: 'sending', progress: 0 } : t,
      ),
    })
  },

  downloadURL: (historyId) => {
    if (get().mode !== 'live') return undefined
    return getClient().downloadURL(historyId)
  },

  sampleThroughput: () => {
    let up = 0
    let down = 0
    for (const t of get().transfers) {
      if (t.state === 'sending') up += t.speedBps ?? 0
      else if (t.state === 'receiving') down += t.speedBps ?? 0
    }
    const cap = 32
    set({
      uploadBars: [...get().uploadBars, up].slice(-cap),
      downBars: [...get().downBars, down].slice(-cap),
    })
  },
}))

/**
 * 装载时打开 WS 连接，订阅事件流。组件树根部调用一次即可。
 * 注意：StrictMode 双调用会建两次连接 —— gateway 端会用第一条；
 * 我们用单例 client 自带的去重保护。
 */
export function useEngineConnection() {
  useEffect(() => {
    if (useEngine.getState().mode !== 'live') return
    const c = getClient()
    const unsub = c.subscribe({
      onConn: (conn) => useEngine.setState({ conn }),
      onState: (snap) => {
        const devices = snap.devices.map(adaptDevice)
        const history = buildHistoryDays(snap.history.map(adaptHistory))
        const transfers = snap.transfers.map((t) => adaptTransfer(t))
        useEngine.setState({
          me: adaptMe(snap.me),
          devices, history, transfers,
          pendingOffer: snap.pendingOffers[0] ? adaptOffer(snap.pendingOffers[0]) : undefined,
          pendingPairing: snap.pendingPairings[0] ? adaptPairing(snap.pendingPairings[0]) : undefined,
        })
      },
      onDevicesSnapshot: (list) => useEngine.setState({ devices: list.map(adaptDevice) }),
      onDeviceAdded: (d) => {
        const next = useEngine.getState().devices.filter((x) => x.id !== d.id)
        next.push(adaptDevice(d))
        useEngine.setState({ devices: next })
      },
      onDeviceUpdated: (d) => {
        const next = useEngine.getState().devices.map((x) => x.id === d.id ? adaptDevice(d) : x)
        useEngine.setState({ devices: next })
      },
      onDeviceRemoved: (id) => {
        useEngine.setState({ devices: useEngine.getState().devices.filter((x) => x.id !== id) })
      },
      onPairingPending: (p) => useEngine.setState({ pendingPairing: adaptPairing(p) }),
      onPairingResolved: () => useEngine.setState({ pendingPairing: undefined }),
      onOfferPending: (o) => {
        useEngine.setState({ pendingOffer: adaptOffer(o) })
        // 设置里开启「自动接收」时，直接接受并清掉待审弹窗。
        if (autoAcceptEnabled()) { useEngine.getState().acceptOffer() }
      },
      onOfferResolved: () => useEngine.setState({ pendingOffer: undefined }),
      onTransferProgress: (t) => {
        const next = useEngine.getState().transfers.map((r) =>
          r.id === t.id ? adaptTransfer(t, r.state) : r
        )
        if (!next.some((r) => r.id === t.id)) next.unshift(adaptTransfer(t))
        useEngine.setState({ transfers: next })
      },
      onTransferDone: (id, ok) => {
        const next = useEngine.getState().transfers.map((r) =>
          r.id === id ? { ...r, state: ok ? ('done' as const) : ('failed' as const), progress: ok ? 100 : r.progress } : r
        )
        useEngine.setState({ transfers: next })
      },
      onHistoryAdded: (h) => {
        const item = adaptHistory(h)
        const day = useEngine.getState().history[0]
        const items = day ? [item, ...day.items] : [item]
        useEngine.setState({ history: buildHistoryDays(items) })
        if (h.direction === 'received') {
          const body = h.kind === 'text' ? (h.text ?? '') : (h.files?.[0]?.name ?? '文件')
          notifyIncoming(`来自 ${h.peerName}`, body)
        }
      },
      onClipboardReceived: (c) => {
        const inbox = useEngine.getState().clipboardInbox
        useEngine.setState({ clipboardInbox: [adaptClipboard(c), ...inbox].slice(0, 50) })
        notifyIncoming(`${c.peerName} 推送了剪贴板`, c.content)
      },
    })
    c.connect()
    // 首次连接时请求通知授权（用户可拒绝；拒绝后 notifyIncoming 自动静默）。
    if (typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission().catch(() => { /* ignore */ })
    }
    // 每秒采样吞吐，喂给传输页速度柱状图。
    const tpTimer = window.setInterval(() => useEngine.getState().sampleThroughput(), 1000)
    return () => { unsub(); window.clearInterval(tpTimer) }
  }, [])
}

/** dev 调试用：在 console 注入待审项，验证 UI 流程 */
export function devSeedPending() {
  useEngine.setState({
    pendingOffer: MESHDROP_PENDING_OFFER,
    pendingPairing: MESHDROP_PENDING_PAIRING,
  })
}
