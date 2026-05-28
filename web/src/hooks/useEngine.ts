/**
 * 真实 engine hook —— 替代 useMockEngine。
 *
 * 行为：
 *   - gateway 已配置且配对成功：从 WS 拉真实 state，所有 send/* 走 GatewayClient
 *   - gateway 未配置 / 未配对 / 连接失败：回退到 mock 数据，所有写入仅本地状态
 *
 * 上面两种模式对组件透明 —— store 的 shape 一致。
 */

import { useEffect } from 'react'
import { create } from 'zustand'
import {
  MESHDROP_DEVICES,
  MESHDROP_HISTORY_BY_DAY,
  MESHDROP_TRANSFERS,
  MESHDROP_PENDING_OFFER,
  MESHDROP_PENDING_PAIRING,
  type HistoryDay,
  type HistoryEntry,
  type MeshDevice,
  type PendingOffer,
  type PendingPairing,
  type TransferRow,
} from '../lib/mockData'
import {
  GatewayClient,
  adaptDevice,
  adaptHistory,
  adaptOffer,
  adaptPairing,
  adaptTransfer,
  getClient,
  isGatewayConfigured,
  type EngineConnState,
} from '../lib/engine'

export interface EngineState {
  mode: 'live' | 'mock'
  conn: EngineConnState

  devices: MeshDevice[]
  transfers: TransferRow[]
  history: HistoryDay[]
  pendingOffer?: PendingOffer
  pendingPairing?: PendingPairing
  selectedPeerId?: string

  selectPeer: (id?: string) => void
  setPendingOffer: (o?: PendingOffer) => void
  setPendingPairing: (p?: PendingPairing) => void

  // actions —— mock 模式下只改本地 state，live 模式下走 gateway
  sendText: (peerId: string, text: string) => Promise<void>
  sendFiles: (peerId: string, files: File[], opts?: { noteText?: string }) => Promise<void>
  acceptOffer: () => Promise<void>
  rejectOffer: () => Promise<void>
  acceptPairing: (trust?: boolean) => Promise<void>
  rejectPairing: () => Promise<void>
  pair: (code: string) => Promise<boolean>
  forgetSession: () => void
  cancelTransfer: (transferId: string) => Promise<void>
  retryTransfer: (transferId: string) => Promise<void>
}

function isMock(): boolean {
  if (typeof window === 'undefined') return true
  const q = new URLSearchParams(window.location.search).get('mock')
  if (q === '1' || q === 'true') return true
  return !isGatewayConfigured()
}

function buildHistoryDays(items: HistoryEntry[]): HistoryDay[] {
  if (!items.length) return []
  return [{ label: `TODAY · 今天 · ${items.length} 件`, items }]
}

export const useEngine = create<EngineState>((set, get) => ({
  mode: isMock() ? 'mock' : 'live',
  conn: 'idle',

  devices: isMock() ? MESHDROP_DEVICES : [],
  transfers: isMock() ? MESHDROP_TRANSFERS : [],
  history: isMock() ? MESHDROP_HISTORY_BY_DAY : [],
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
      onOfferPending: (o) => useEngine.setState({ pendingOffer: adaptOffer(o) }),
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
      },
    })
    c.connect()
    return () => { unsub() }
  }, [])
}

/** dev 调试用：在 console 注入待审项，验证 UI 流程 */
export function devSeedPending() {
  useEngine.setState({
    pendingOffer: MESHDROP_PENDING_OFFER,
    pendingPairing: MESHDROP_PENDING_PAIRING,
  })
}
