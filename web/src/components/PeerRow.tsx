import type { MeshDevice } from '../lib/mockData'
import { Avatar } from './Avatar'
import { KindGlyph } from './KindGlyph'

interface Props {
  device: MeshDevice
  selected?: boolean
  dragOver?: boolean
  onSelect?: () => void
  onDrop?: () => void
  onDragOver?: (over: boolean) => void
}

export function PeerRow({ device, selected, dragOver, onSelect, onDrop, onDragOver }: Props) {
  const accent = dragOver ? 'var(--lime)' : selected ? 'var(--lime)' : 'transparent'
  return (
    <button
      onClick={onSelect}
      onDragEnter={(e) => {
        e.preventDefault()
        onDragOver?.(true)
      }}
      onDragOver={(e) => {
        e.preventDefault()
        e.dataTransfer.dropEffect = 'copy'
      }}
      onDragLeave={() => onDragOver?.(false)}
      onDrop={(e) => {
        e.preventDefault()
        onDragOver?.(false)
        onDrop?.()
      }}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        width: '100%',
        padding: '8px 10px',
        borderRadius: 12,
        background: dragOver ? 'var(--lime-fill)' : selected ? 'var(--lime-fill)' : 'transparent',
        border: `1px solid ${accent === 'transparent' ? 'transparent' : accent}`,
        textAlign: 'left',
        transition: 'background 160ms ease, border-color 160ms ease',
        cursor: 'pointer',
      }}
    >
      <Avatar
        initials={device.initials}
        color={device.color}
        size={32}
        ring={selected ? 'lime' : 'none'}
      />
      <div className="min-w-0 flex-1">
        <div
          className="truncate font-display"
          style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--text)', letterSpacing: '-0.005em' }}
        >
          {device.name}
        </div>
        <div
          className="flex items-center gap-1.5"
          style={{
            marginTop: 2,
            color: 'var(--text-faint)',
            fontSize: 10.5,
            fontFamily: '"Geist Mono", monospace',
            letterSpacing: '0.02em',
          }}
        >
          <KindGlyph kind={device.kind} size={9} />
          <span>{device.os}</span>
          <span>·</span>
          <span>{device.rtt} ms</span>
        </div>
      </div>
      <span
        aria-hidden
        style={{
          width: 8,
          height: 8,
          borderRadius: '50%',
          background: device.online ? 'var(--lime-deep)' : 'var(--text-faint)',
          boxShadow: device.online ? '0 0 0 2px var(--lime-fill)' : 'none',
          flexShrink: 0,
        }}
      />
    </button>
  )
}
