/**
 * MeshDrop Web Gateway 客户端 —— companion-bridges §4.3
 *
 * 通过 host 端（macOS / Windows / Linux GUI 上的 native client）的 Web Gateway
 * 间接收发，本端不直接挂 LAN。协议：
 *   - WS  /api/v1/control  双向命令 / 事件（companion-bridges §1, §2）
 *   - POST /api/v1/pair    用 6 字符代码换 session cookie
 *   - POST /api/v1/upload  multipart 上传，返回 uploadToken 作为 send_file_ref.fileRef
 *   - GET  /api/v1/download/<offerId> 接受 offer 后下载文件
 */

import type { DeviceKind, HistoryEntry, MeshDevice, PendingOffer, PendingPairing, TransferRow, TransferState } from './mockData'

// ---------- wire types (protocol/companion-bridges.md §3) ----------

export interface WireDevice {
  id: string
  displayName: string
  kind: DeviceKind | 'tv' | 'vision' | 'watch' | 'wear' | 'ipad'
  model?: string
  ip?: string
  rttMs?: number
  online: boolean
  trusted: boolean
  busy?: boolean
}

export interface WirePairing {
  id: string
  peerName: string
  code: string
  fingerprint: string
  createdAt: number
}

export interface WireOffer {
  id: string
  peerId: string
  peerName: string
  kind: 'text' | 'file' | 'files'
  files?: Array<{ name: string; sizeBytes: number; mime?: string }>
  noteText?: string
  createdAt: number
}

export interface WireHistoryItem {
  id: string
  direction: 'sent' | 'received'
  peerName: string
  kind: 'text' | 'file' | 'files'
  text?: string
  files?: Array<{ name: string; sizeBytes: number; mime?: string }>
  bytesTransferred?: number
  ok: boolean
  completedAt: number
}

export interface WireTransferProgress {
  id: string
  peerName?: string
  fileName?: string
  bytesSent: number
  totalBytes: number
  speedBps: number
  /** 剩余时间秒数；host 端无法估算时不发。 */
  etaSeconds?: number
}

export interface StateSnapshot {
  v: 1
  type: 'state_snapshot'
  payload: {
    devices: WireDevice[]
    history: WireHistoryItem[]
    pendingPairings: WirePairing[]
    pendingOffers: WireOffer[]
    transfers: WireTransferProgress[]
    me?: {
      displayName: string
      fingerprint: string
      ip: string
      hostIp: string
    }
  }
}

type WsEvent =
  | StateSnapshot
  | { v: 1; type: 'device_added' | 'device_updated'; payload: WireDevice }
  | { v: 1; type: 'device_removed'; payload: { id: string } }
  | { v: 1; type: 'device_snapshot'; payload: WireDevice[] }
  | { v: 1; type: 'pairing_pending'; payload: WirePairing }
  | { v: 1; type: 'pairing_resolved'; payload: { id: string } }
  | { v: 1; type: 'offer_pending'; payload: WireOffer }
  | { v: 1; type: 'offer_resolved'; payload: { id: string } }
  | { v: 1; type: 'transfer_progress'; payload: WireTransferProgress }
  | { v: 1; type: 'transfer_done'; payload: { id: string; ok: boolean; error?: string } }
  | { v: 1; type: 'history_added'; payload: WireHistoryItem }

type CmdAck = {
  v: 1
  id: string
  ok: boolean
  error?: string | null
  result?: any
}

// ---------- adapters: wire -> UI shape (lib/mockData.ts) ----------

const PALETTE = ['#FFB4A1', '#B7E5C8', '#C7B8FF', '#FFD970', '#9AD0FF', '#F2B5D4', '#A8E8E8']

function colorFor(id: string): string {
  let h = 0
  for (let i = 0; i < id.length; i++) h = ((h << 5) - h + id.charCodeAt(i)) | 0
  return PALETTE[Math.abs(h) % PALETTE.length]
}

function initialsFor(name: string): string {
  const parts = name.split(/[\s·]+/).filter(Boolean)
  if (!parts.length) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[1][0]).toUpperCase()
}

function adaptKind(k: WireDevice['kind']): DeviceKind {
  if (k === 'tv' || k === 'vision' || k === 'watch' || k === 'wear') return 'mac'
  return k as DeviceKind
}

export function adaptDevice(w: WireDevice): MeshDevice {
  const id = w.id
  return {
    id,
    name: w.model ? `${w.displayName} · ${w.model}` : w.displayName,
    who: w.displayName,
    kind: adaptKind(w.kind),
    dist: Math.min(0.92, Math.max(0.25, (w.rttMs ?? 40) / 80)),
    angle: (parseInt(id.replace(/\D/g, '').slice(-3) || '0', 10) * 137) % 360,
    color: colorFor(id),
    initials: initialsFor(w.displayName),
    os: w.model ?? '',
    rtt: w.rttMs ?? 0,
    online: w.online,
    paired: w.trusted,
  }
}

function formatBytes(b?: number): string {
  if (b == null) return ''
  if (b < 1024) return `${b} B`
  if (b < 1024 * 1024) return `${(b / 1024).toFixed(1)} KB`
  if (b < 1024 * 1024 * 1024) return `${(b / 1024 / 1024).toFixed(1)} MB`
  return `${(b / 1024 / 1024 / 1024).toFixed(2)} GB`
}

function extOf(name?: string): string {
  if (!name) return ''
  const dot = name.lastIndexOf('.')
  return dot > 0 ? name.slice(dot + 1).toLowerCase() : ''
}

function timeOf(ts: number): string {
  const d = new Date(ts * 1000)
  return d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false })
}

export function adaptHistory(h: WireHistoryItem): HistoryEntry {
  const first = h.files?.[0]
  const dir = h.direction === 'sent' ? 'outgoing' : 'incoming'
  const status = h.ok ? 'done' : 'failed'
  if (h.kind === 'text') {
    return { id: h.id, dir, peer: h.peerName, time: timeOf(h.completedAt), kind: 'text', content: h.text ?? '', status }
  }
  if (h.kind === 'files' && (h.files?.length ?? 0) > 1) {
    return { id: h.id, dir, peer: h.peerName, time: timeOf(h.completedAt), kind: 'image', count: h.files!.length, status }
  }
  return {
    id: h.id, dir, peer: h.peerName, time: timeOf(h.completedAt),
    kind: 'file',
    name: first?.name, size: formatBytes(first?.sizeBytes), ext: extOf(first?.name),
    status,
  }
}

export function adaptOffer(o: WireOffer): PendingOffer {
  const f = o.files?.[0]
  return {
    id: o.id,
    peer: o.peerName,
    deviceName: o.peerName,
    fileName: f?.name ?? '(文本)',
    fileSize: formatBytes(f?.sizeBytes),
    ext: extOf(f?.name),
    note: o.noteText,
    receivedAt: 'just now',
  }
}

export function adaptPairing(p: WirePairing): PendingPairing {
  return {
    id: p.id,
    peer: p.peerName,
    deviceName: p.peerName,
    fingerprint: p.fingerprint,
    receivedAt: timeOf(p.createdAt),
  }
}

function formatSpeed(bps: number): string {
  if (bps < 1024) return `${Math.round(bps)} B/s`
  if (bps < 1024 * 1024) return `${(bps / 1024).toFixed(1)} KB/s`
  return `${(bps / 1024 / 1024).toFixed(1)} MB/s`
}

function formatEta(secs?: number): string | undefined {
  if (secs == null || !isFinite(secs) || secs < 0) return undefined
  if (secs < 1) return '<1s'
  if (secs >= 3600) return '>1h'
  const s = Math.round(secs)
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}

export function adaptTransfer(t: WireTransferProgress, state: TransferState = 'sending'): TransferRow {
  const pct = t.totalBytes > 0 ? Math.round((t.bytesSent / t.totalBytes) * 100) : 0
  return {
    id: t.id,
    name: t.fileName ?? t.id,
    size: formatBytes(t.totalBytes),
    ext: extOf(t.fileName),
    from: state === 'receiving' ? (t.peerName ?? '') : '我',
    to: state === 'receiving' ? '我' : (t.peerName ?? ''),
    progress: pct,
    state,
    speed: t.speedBps > 0 ? formatSpeed(t.speedBps) : undefined,
    speedBps: t.speedBps > 0 ? t.speedBps : undefined,
    totalBytes: t.totalBytes > 0 ? t.totalBytes : undefined,
    eta: formatEta(t.etaSeconds),
  }
}

// ---------- client ----------

export type EngineConnState = 'idle' | 'connecting' | 'open' | 'closed' | 'unpaired'

export interface EngineListener {
  onState?(snap: StateSnapshot['payload']): void
  onDeviceAdded?(d: WireDevice): void
  onDeviceRemoved?(id: string): void
  onDeviceUpdated?(d: WireDevice): void
  onDevicesSnapshot?(list: WireDevice[]): void
  onPairingPending?(p: WirePairing): void
  onPairingResolved?(id: string): void
  onOfferPending?(o: WireOffer): void
  onOfferResolved?(id: string): void
  onTransferProgress?(t: WireTransferProgress): void
  onTransferDone?(id: string, ok: boolean, error?: string): void
  onHistoryAdded?(h: WireHistoryItem): void
  onConn?(s: EngineConnState): void
}

const CMD_TIMEOUT_MS = 10_000

export class GatewayClient {
  private ws?: WebSocket
  private listeners = new Set<EngineListener>()
  private pending = new Map<string, { resolve: (r: CmdAck) => void; reject: (e: Error) => void; timer: number }>()
  private state: EngineConnState = 'idle'
  private retryTimer?: number
  private gateway: string
  private session?: string

  constructor(gateway: string) {
    this.gateway = gateway.replace(/\/$/, '')
    try {
      this.session = localStorage.getItem('meshdrop.session') ?? undefined
    } catch {
      // ignore
    }
  }

  subscribe(l: EngineListener): () => void {
    this.listeners.add(l)
    l.onConn?.(this.state)
    return () => { this.listeners.delete(l) }
  }

  /** 用 6 字符配对代码换 session cookie。返回 true 表示已配对。 */
  async pair(code: string): Promise<boolean> {
    const r = await fetch(`${this.gateway}/api/v1/pair`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ code }),
      credentials: 'include',
    })
    if (!r.ok) return false
    const body = await r.json().catch(() => null) as { token?: string } | null
    if (body?.token) {
      this.session = body.token
      try { localStorage.setItem('meshdrop.session', body.token) } catch { /* ignore */ }
    }
    return true
  }

  hasSession(): boolean {
    return !!this.session
  }

  /** 已接收文件的下载 URL（GET /api/v1/download/<historyId>，server 带
   *  Content-Disposition: attachment）。带 ?token= 兼容无 cookie 场景。 */
  downloadURL(historyId: string): string {
    const base = `${this.gateway}/api/v1/download/${encodeURIComponent(historyId)}`
    return this.session ? `${base}?token=${encodeURIComponent(this.session)}` : base
  }

  forgetSession(): void {
    this.session = undefined
    try { localStorage.removeItem('meshdrop.session') } catch { /* ignore */ }
  }

  async connect(): Promise<void> {
    if (!this.session) {
      this.setState('unpaired')
      return
    }
    this.setState('connecting')
    const scheme = this.gateway.startsWith('https') ? 'wss' : 'ws'
    const host = this.gateway.replace(/^https?:\/\//, '')
    const url = `${scheme}://${host}/api/v1/control?token=${encodeURIComponent(this.session)}`

    const ws = new WebSocket(url)
    this.ws = ws

    ws.addEventListener('open', () => { this.setState('open') })
    ws.addEventListener('close', () => {
      this.setState('closed')
      this.scheduleRetry()
    })
    ws.addEventListener('error', () => { /* close handler will retry */ })
    ws.addEventListener('message', (e) => this.onMessage(e.data))
  }

  disconnect(): void {
    if (this.retryTimer) { clearTimeout(this.retryTimer); this.retryTimer = undefined }
    this.ws?.close()
    this.ws = undefined
    this.setState('closed')
  }

  // -------- commands --------

  sendText(peerId: string, text: string): Promise<CmdAck> {
    return this.cmd('send_text', { peerId, text })
  }

  async sendFile(peerId: string, file: File, opts?: { noteText?: string }): Promise<CmdAck> {
    const fd = new FormData()
    fd.append('file', file, file.name)
    const r = await fetch(`${this.gateway}/api/v1/upload`, {
      method: 'POST', body: fd, credentials: 'include',
      headers: this.session ? { 'x-meshdrop-token': this.session } : undefined,
    })
    if (!r.ok) throw new Error(`upload failed: HTTP ${r.status}`)
    const { token } = await r.json() as { token: string }
    return this.cmd('send_file_ref', {
      peerId, fileRef: token, name: file.name, sizeBytes: file.size, mime: file.type,
      noteText: opts?.noteText,
    })
  }

  acceptOffer(offerId: string): Promise<CmdAck> { return this.cmd('accept_offer', { offerId }) }
  rejectOffer(offerId: string): Promise<CmdAck> { return this.cmd('reject_offer', { offerId }) }
  acceptPairing(pairingId: string, trust = true): Promise<CmdAck> { return this.cmd('accept_pairing', { pairingId, trust }) }
  rejectPairing(pairingId: string): Promise<CmdAck> { return this.cmd('reject_pairing', { pairingId }) }
  clearHistory(scope: 'all' | 'sent' | 'received' = 'all'): Promise<CmdAck> { return this.cmd('clear_history', { scope }) }
  deleteHistoryItem(itemId: string): Promise<CmdAck> { return this.cmd('delete_history_item', { itemId }) }
  /** 取消进行中的传输（发送 / 接收均可）；server 端解析 itemId 后调 engine.cancelTransfer。 */
  cancelTransfer(itemId: string): Promise<CmdAck> { return this.cmd('cancel_transfer', { itemId }) }
  /** 重发失败 / 取消的发送项；server 端解析 itemId 后调 engine.retryTransfer（源文件不可用时返回 ok:false）。 */
  retryTransfer(itemId: string): Promise<CmdAck> { return this.cmd('retry_transfer', { itemId }) }
  getState(): Promise<CmdAck> { return this.cmd('get_state', {}) }

  // -------- internals --------

  private setState(s: EngineConnState) {
    if (this.state === s) return
    this.state = s
    for (const l of this.listeners) l.onConn?.(s)
  }

  private scheduleRetry() {
    if (this.retryTimer || !this.session) return
    this.retryTimer = window.setTimeout(() => {
      this.retryTimer = undefined
      this.connect()
    }, 2500)
  }

  private cmd(type: string, payload: unknown): Promise<CmdAck> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      return Promise.reject(new Error('gateway not connected'))
    }
    const id = `cmd-${crypto.randomUUID()}`
    const frame = { v: 1, id, type, ts: Math.floor(Date.now() / 1000), payload }
    return new Promise<CmdAck>((resolve, reject) => {
      const timer = window.setTimeout(() => {
        this.pending.delete(id)
        reject(new Error('timeout'))
      }, CMD_TIMEOUT_MS)
      this.pending.set(id, { resolve, reject, timer })
      this.ws!.send(JSON.stringify(frame))
    })
  }

  private onMessage(raw: unknown) {
    if (typeof raw !== 'string') return
    let msg: WsEvent | CmdAck
    try { msg = JSON.parse(raw) as WsEvent | CmdAck } catch { return }

    // cmd ack 有 ok 字段，事件没有
    if ('ok' in msg && 'id' in msg && typeof msg.ok === 'boolean') {
      const p = this.pending.get(msg.id)
      if (p) {
        clearTimeout(p.timer)
        this.pending.delete(msg.id)
        p.resolve(msg as CmdAck)
      }
      return
    }

    const ev = msg as WsEvent
    for (const l of this.listeners) {
      switch (ev.type) {
        case 'state_snapshot': l.onState?.(ev.payload); break
        case 'device_added': l.onDeviceAdded?.(ev.payload); break
        case 'device_updated': l.onDeviceUpdated?.(ev.payload); break
        case 'device_removed': l.onDeviceRemoved?.(ev.payload.id); break
        case 'device_snapshot': l.onDevicesSnapshot?.(ev.payload); break
        case 'pairing_pending': l.onPairingPending?.(ev.payload); break
        case 'pairing_resolved': l.onPairingResolved?.(ev.payload.id); break
        case 'offer_pending': l.onOfferPending?.(ev.payload); break
        case 'offer_resolved': l.onOfferResolved?.(ev.payload.id); break
        case 'transfer_progress': l.onTransferProgress?.(ev.payload); break
        case 'transfer_done': l.onTransferDone?.(ev.payload.id, ev.payload.ok, ev.payload.error); break
        case 'history_added': l.onHistoryAdded?.(ev.payload); break
      }
    }
  }
}

// ---------- single shared instance ----------

function detectGateway(): string {
  // 1) 显式覆盖 (?gw=https://1.2.3.4:7384)
  try {
    const q = new URLSearchParams(window.location.search).get('gw')
    if (q) return q
    const stored = localStorage.getItem('meshdrop.gateway')
    if (stored) return stored
  } catch { /* ignore */ }
  // 2) gateway 把 web fallback 嵌在自己进程里：当前 origin 就是 gateway
  if (typeof window !== 'undefined' && window.location.origin && !window.location.origin.startsWith('http://localhost')) {
    return window.location.origin
  }
  // 3) dev 模式默认占位
  return ''
}

let _client: GatewayClient | undefined
export function getClient(): GatewayClient {
  if (!_client) _client = new GatewayClient(detectGateway() || 'about:blank')
  return _client
}

export function isGatewayConfigured(): boolean {
  return !!detectGateway()
}
