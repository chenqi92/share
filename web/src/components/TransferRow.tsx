import type { TransferRow as Row } from '../lib/mockData'
import { FileCard } from './FileCard'
import { ProgressBar } from './ProgressBar'

interface Props {
  row: Row
  /** 传入后且 state 是 sending / receiving 时，渲染取消按钮。 */
  onCancel?: () => void
}

function stateLabel(state: Row['state']): { label: string; symbol: string; color: string } {
  switch (state) {
    case 'sending':
      return { label: '发送中 · SENDING', symbol: '↑', color: 'var(--flame)' }
    case 'receiving':
      return { label: '接收中 · RECEIVING', symbol: '↓', color: 'var(--sky)' }
    case 'done':
      return { label: '已完成 · DONE', symbol: '✓', color: 'var(--lime-deep)' }
    case 'failed':
      return { label: '失败 · FAILED', symbol: '×', color: 'var(--error)' }
    case 'queued':
    default:
      return { label: '排队中 · QUEUED', symbol: '·', color: 'var(--text-faint)' }
  }
}

export function TransferRow({ row, onCancel }: Props) {
  const s = stateLabel(row.state)
  const isActive = row.state === 'sending' || row.state === 'receiving'
  return (
    <div
      style={{
        padding: '14px 16px',
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 14,
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      <div className="flex items-start gap-4">
        <FileCard ext={row.ext} name={row.name} size={row.size} meta={`${row.from} → ${row.to}`} />
        <div
          style={{
            color: s.color,
            fontFamily: '"Geist Mono", monospace',
            fontSize: 10.5,
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: '0.16em',
            whiteSpace: 'nowrap',
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <span style={{ fontSize: 14 }}>{s.symbol}</span> {s.label}
        </div>
        {isActive && onCancel && (
          <button
            type="button"
            onClick={onCancel}
            title="取消传输 · Cancel"
            aria-label="取消传输"
            style={{
              marginLeft: 'auto',
              background: 'transparent',
              border: '1px solid var(--border)',
              borderRadius: 8,
              padding: '4px 8px',
              color: 'var(--flame)',
              fontFamily: '"Geist Mono", monospace',
              fontSize: 11,
              fontWeight: 700,
              letterSpacing: '0.08em',
              cursor: 'pointer',
            }}
          >
            × CANCEL
          </button>
        )}
      </div>

      <ProgressBar value={row.progress} state={row.state} />

      <div
        className="flex items-center justify-between"
        style={{
          fontFamily: '"Geist Mono", monospace',
          fontSize: 10.5,
          color: 'var(--text-faint)',
          letterSpacing: '0.06em',
        }}
      >
        <span style={{ color: 'var(--text-mute)' }}>{row.progress}%</span>
        <span>
          {row.speed ? `${row.speed} · ` : ''}
          {row.eta ? `ETA ${row.eta}` : row.state === 'queued' ? '等待发送' : ''}
        </span>
      </div>
    </div>
  )
}
