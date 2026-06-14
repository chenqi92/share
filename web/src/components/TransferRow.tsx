import { useTranslation } from 'react-i18next'
import type { TFunction } from 'i18next'
import type { TransferRow as Row } from '../lib/mockData'
import { FileCard } from './FileCard'
import { ProgressBar } from './ProgressBar'

interface Props {
  row: Row
  /** 传入后且 state 是 sending / receiving 时，渲染取消按钮。 */
  onCancel?: () => void
  /** 传入后且 state 是 failed 时，渲染重试按钮。调用方需自行限制只给 outgoing 项传入。 */
  onRetry?: () => void
}

// 文案走 i18n（transfer.state.*），这里只保留符号 / 配色等视觉常量。
function stateVisual(state: Row['state'], t: TFunction): { label: string; symbol: string; color: string } {
  switch (state) {
    case 'sending':
      return { label: t('transfer.state.sending'), symbol: '↑', color: 'var(--flame)' }
    case 'receiving':
      return { label: t('transfer.state.receiving'), symbol: '↓', color: 'var(--sky)' }
    case 'done':
      return { label: t('transfer.state.done'), symbol: '✓', color: 'var(--lime-deep)' }
    case 'failed':
      return { label: t('transfer.state.failed'), symbol: '×', color: 'var(--error)' }
    case 'queued':
    default:
      return { label: t('transfer.state.queued'), symbol: '·', color: 'var(--text-faint)' }
  }
}

export function TransferRow({ row, onCancel, onRetry }: Props) {
  const { t } = useTranslation()
  const s = stateVisual(row.state, t)
  const isActive = row.state === 'sending' || row.state === 'receiving'
  const isFailed = row.state === 'failed'
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
            title={t('transfer.cancel')}
            aria-label={t('transfer.cancel')}
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
        {isFailed && onRetry && (
          <button
            type="button"
            onClick={onRetry}
            title={t('transfer.retry')}
            aria-label={t('transfer.retry')}
            style={{
              marginLeft: 'auto',
              background: 'transparent',
              border: '1px solid var(--flame)',
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
            ↻ RETRY
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
          {row.eta ? `ETA ${row.eta}` : row.state === 'queued' ? t('transfer.waitingToSend') : ''}
        </span>
      </div>
    </div>
  )
}
