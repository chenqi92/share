import type { DragEvent } from 'react'
import type { MeshDevice } from '../lib/mockData'
import { Avatar } from './Avatar'
import { KindGlyph } from './KindGlyph'

interface Props {
  device: MeshDevice
  selected?: boolean
  dragOver?: boolean
  onSelect?: () => void
  onDrop?: (e: DragEvent<HTMLButtonElement>) => void
  onDragOver?: (over: boolean) => void
}

export function PeerRow({ device, selected, dragOver, onSelect, onDrop, onDragOver }: Props) {
  // 拖拽悬停优先于选中态展示，且两态要可区分：
  //   selected   → lime-fill 实底 + 1px lime 实线描边（统一选中态基准）
  //   dragOver   → 更强 lime 高亮 + 2px lime 虚线描边（“放手即发”的临时态）
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
        onDrop?.(e)
      }}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        width: '100%',
        padding: '8px 10px',
        borderRadius: 12,
        // dragOver 用更高不透明度的 lime 实底拉开与 selected 的差异
        background: dragOver
          ? 'rgba(221, 249, 75, 0.5)'
          : selected
            ? 'var(--lime-fill)'
            : 'transparent',
        // dragOver=2px lime 虚线；selected=1px lime 实线；其余无描边
        border: dragOver
          ? '2px dashed var(--lime)'
          : selected
            ? '1px solid var(--lime)'
            : '1px solid transparent',
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
