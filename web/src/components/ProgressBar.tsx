import type { TransferState } from '../lib/mockData'

interface Props {
  value: number
  state?: TransferState
  height?: number
}

const stateColor: Record<TransferState, string> = {
  sending: 'var(--flame)',
  receiving: 'var(--sky)',
  done: 'var(--lime-deep)',
  failed: 'var(--error)',
  queued: 'var(--text-faint)',
}

export function ProgressBar({ value, state = 'sending', height = 4 }: Props) {
  return (
    <div
      style={{
        height,
        background: 'var(--ink-06)',
        borderRadius: 999,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: `${Math.max(0, Math.min(100, value))}%`,
          height: '100%',
          background: stateColor[state],
          transition: 'width 240ms cubic-bezier(.32,.72,.21,1)',
        }}
      />
    </div>
  )
}
