import { useState } from 'react'
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
  const peerCount = devices.filter((d) => d.online).length
  const source = mode === 'live' ? transfers : MESHDROP_TRANSFERS

  const rows = source.filter((t) => {
    if (filter === '发送 · SEND') return t.state === 'sending' || t.state === 'queued'
    if (filter === '接收 · RECV') return t.state === 'receiving'
    if (filter === '完成 · DONE') return t.state === 'done'
    if (filter === '失败 · FAIL') return t.state === 'failed'
    return true
  })

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
              5 个任务在路上 · <span style={{ color: 'var(--lime-deep)' }}>2 已完成</span>
            </h1>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Chip tone="lime" mono>↑ 8.4 MB/s</Chip>
            <Chip tone="sky" mono>↓ 11.7 MB/s</Chip>
            <Chip tone="outline" mono>队列 · 1 件</Chip>
            <Chip tone="outline" mono>SESSION 6m 12s</Chip>
          </div>
        </header>

        <SpeedChart upBars={MESHDROP_UPLOAD_BARS} downBars={MESHDROP_DOWNLOAD_BARS} />

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
            />
          ))}
        </div>
      </div>

      <StatusBar peerCount={peerCount} hostIp={MESHDROP_ME.hostIp} />
    </div>
  )
}
