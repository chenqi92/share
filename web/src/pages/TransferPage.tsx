import { useEffect, useRef, useState } from 'react'
import { Chip } from '../components/Chip'
import { SpeedChart } from '../components/SpeedChart'
import { StatusBar } from '../components/StatusBar'
import { TransferRow } from '../components/TransferRow'
import { AsciiDivider } from '../components/AsciiDivider'
import {
  MESHDROP_DOWNLOAD_BARS,
  MESHDROP_ME,
  MESHDROP_TRANSFERS,
  MESHDROP_UPLOAD_BARS,
} from '../lib/mockData'
import { useEngine } from '../hooks/useEngine'

const FILTERS = ['全部 · ALL', '发送 · SEND', '接收 · RECV', '完成 · DONE', '失败 · FAIL'] as const

export function TransferPage() {
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('全部 · ALL')
  const devices = useEngine((s) => s.devices)
  const transfers = useEngine((s) => s.transfers)
  const mode = useEngine((s) => s.mode)
  const cancelTransfer = useEngine((s) => s.cancelTransfer)
  const retryTransfer = useEngine((s) => s.retryTransfer)
  const uploadBars = useEngine((s) => s.uploadBars)
  const downBars = useEngine((s) => s.downBars)
  const peerCount = devices.filter((d) => d.online).length
  const source = mode === 'live' ? transfers : MESHDROP_TRANSFERS
  // live 且已有采样 → 真实序列；否则用 mock 装饰柱。
  const chartUp = mode === 'live' && uploadBars.length ? uploadBars : MESHDROP_UPLOAD_BARS
  const chartDown = mode === 'live' && downBars.length ? downBars : MESHDROP_DOWNLOAD_BARS

  const rows = source.filter((t) => {
    if (filter === '发送 · SEND') return t.state === 'sending' || t.state === 'queued'
    if (filter === '接收 · RECV') return t.state === 'receiving'
    if (filter === '完成 · DONE') return t.state === 'done'
    if (filter === '失败 · FAIL') return t.state === 'failed'
    return true
  })

  // 顶部 chip 实数据：source 是当前 mode 下的全集，分别汇总。
  const inProgressCount = source.filter((t) => t.state === 'sending' || t.state === 'receiving').length
  const doneCount = source.filter((t) => t.state === 'done').length
  const queuedCount = source.filter((t) => t.state === 'queued').length
  const totalCount = source.length
  const uploadBps = source.reduce((s, t) => (t.state === 'sending' && t.from === '我') ? s + (t.speedBps ?? 0) : s, 0)
  const downloadBps = source.reduce((s, t) => (t.state === 'receiving' && t.to === '我') ? s + (t.speedBps ?? 0) : s, 0)
  const sessionTotalBytes = source.reduce((s, t) => s + (t.totalBytes ?? 0), 0)

  // SESSION 时长：组件挂载到现在；mode 切换不重置。
  const sessionStart = useRef(Date.now())
  const [sessionDuration, setSessionDuration] = useState('0s')
  useEffect(() => {
    const tick = () => setSessionDuration(formatDuration(Date.now() - sessionStart.current))
    tick()
    const id = window.setInterval(tick, 1000)
    return () => window.clearInterval(id)
  }, [])

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      <div
        className="scroll-thin"
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '22px 26px 24px',
          display: 'flex',
          flexDirection: 'column',
          gap: 18,
        }}
      >
        <header className="flex items-end justify-between flex-wrap gap-3">
          <div>
            <div
              style={{
                fontFamily: '"Geist Mono", monospace',
                fontSize: 10.5,
                color: 'var(--text-faint)',
                letterSpacing: '0.22em',
                textTransform: 'uppercase',
                marginBottom: 6,
              }}
            >
              传输 · TRANSFERS
            </div>
            <h1
              className="font-display"
              style={{ fontSize: 30, fontWeight: 700, letterSpacing: '-0.025em', lineHeight: 1 }}
            >
              {totalCount} 个任务{inProgressCount > 0 && '在路上'} · <span style={{ color: 'var(--lime-deep)' }}>{doneCount} 已完成</span>
            </h1>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Chip tone="lime" mono>↑ {formatBps(uploadBps)}</Chip>
            <Chip tone="sky" mono>↓ {formatBps(downloadBps)}</Chip>
            <Chip tone="outline" mono>队列 · {queuedCount} 件</Chip>
            <Chip tone="outline" mono>SESSION {sessionDuration}</Chip>
            <Chip tone="outline" mono>{formatTotal(sessionTotalBytes)}</Chip>
          </div>
        </header>

        <SpeedChart upBars={chartUp} downBars={chartDown} />

        <div
          className="flex items-center gap-2 flex-wrap"
          style={{ padding: '0 2px' }}
        >
          {FILTERS.map((f) => {
            const active = filter === f
            return (
              <button
                key={f}
                onClick={() => setFilter(f)}
                style={{
                  padding: '6px 12px',
                  borderRadius: 999,
                  border: `1px solid ${active ? 'var(--ink)' : 'var(--border)'}`,
                  background: active ? 'var(--ink)' : 'transparent',
                  color: active ? 'var(--paper)' : 'var(--text-mute)',
                  fontFamily: '"Geist Mono", monospace',
                  fontSize: 10.5,
                  fontWeight: 600,
                  letterSpacing: '0.08em',
                  textTransform: 'uppercase',
                }}
              >
                {f}
              </button>
            )
          })}
        </div>

        <AsciiDivider label={`—— ACTIVE · 进行中 · ${rows.length} 件 ——`} />

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {rows.map((r) => (
            <TransferRow
              key={r.id}
              row={r}
              onCancel={() => { void cancelTransfer(r.id) }}
              onRetry={r.from === '我' ? () => { void retryTransfer(r.id) } : undefined}
            />
          ))}
        </div>
      </div>

      <StatusBar peerCount={peerCount} hostIp={MESHDROP_ME.hostIp} />
    </div>
  )
}

function formatBps(bps: number): string {
  if (!bps || bps <= 1) return '—'
  if (bps < 1024) return `${Math.round(bps)} B/s`
  if (bps < 1024 * 1024) return `${(bps / 1024).toFixed(1)} KB/s`
  return `${(bps / 1024 / 1024).toFixed(1)} MB/s`
}

function formatTotal(bytes: number): string {
  if (!bytes || bytes <= 0) return '0 B'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}

function formatDuration(ms: number): string {
  const s = Math.floor(ms / 1000)
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  const ss = s % 60
  if (m < 60) return `${m}m ${ss.toString().padStart(2, '0')}s`
  const h = Math.floor(m / 60)
  const mm = m % 60
  return `${h}h ${mm.toString().padStart(2, '0')}m`
}
