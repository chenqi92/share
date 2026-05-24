import { useCallback, useRef, useState, type ReactNode } from 'react'

interface Props {
  selectedPeerName?: string
  onFiles?: (files: File[]) => void
  onPasteText?: () => void
  /** force the drop-overlay highlight (used when dragging over peer rows etc.) */
  forceHighlight?: boolean
  children?: ReactNode
}

export function DropZone({ selectedPeerName, onFiles, onPasteText, forceHighlight, children }: Props) {
  const [active, setActive] = useState(false)
  const counter = useRef(0)
  const inputRef = useRef<HTMLInputElement>(null)

  const onDragEnter = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    counter.current += 1
    setActive(true)
  }, [])

  const onDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    counter.current = Math.max(0, counter.current - 1)
    if (counter.current === 0) setActive(false)
  }, [])

  const onDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'copy'
  }, [])

  const onDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault()
      counter.current = 0
      setActive(false)
      const files = Array.from(e.dataTransfer.files ?? [])
      if (files.length) onFiles?.(files)
    },
    [onFiles],
  )

  const highlight = active || !!forceHighlight

  return (
    <div
      onDragEnter={onDragEnter}
      onDragLeave={onDragLeave}
      onDragOver={onDragOver}
      onDrop={onDrop}
      style={{
        position: 'relative',
        flex: 1,
        minHeight: 360,
        borderRadius: 18,
        border: `2px dashed ${highlight ? 'var(--lime)' : 'var(--border)'}`,
        background: highlight ? 'var(--lime-fill)' : 'var(--surface)',
        transition: 'background 180ms ease, border-color 180ms ease',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 16,
        padding: '36px 28px',
        textAlign: 'center',
      }}
    >
      <input
        ref={inputRef}
        type="file"
        multiple
        hidden
        onChange={(e) => {
          const files = Array.from(e.target.files ?? [])
          if (files.length) onFiles?.(files)
          if (inputRef.current) inputRef.current.value = ''
        }}
      />
      <div
        aria-hidden
        style={{
          color: highlight ? 'var(--ink)' : 'var(--text-faint)',
          fontFamily: '"Geist Mono", monospace',
          fontSize: 11,
          textTransform: 'uppercase',
          letterSpacing: '0.22em',
        }}
      >
        {highlight ? '放手即发 · DROP TO SEND' : 'DRAG ZONE · 拖即发'}
      </div>

      <div
        className="font-display"
        style={{
          fontSize: 'clamp(28px, 3.4vw, 40px)',
          lineHeight: 1.05,
          fontWeight: 700,
          letterSpacing: '-0.025em',
          color: highlight ? 'var(--ink)' : 'var(--text)',
        }}
      >
        {highlight
          ? selectedPeerName
            ? `→ ${selectedPeerName}`
            : '把任何东西拖进来'
          : '把任何东西拖到这里'}
      </div>

      <p
        style={{
          maxWidth: 460,
          fontSize: 13,
          color: 'var(--text-mute)',
          lineHeight: 1.55,
        }}
      >
        {selectedPeerName
          ? `当前目标：${selectedPeerName} · 拖文件 / 文件夹直接发送`
          : '⤓ 文件夹也行 · 单文件最大 4 GB · 文字 / 链接也接受'}
      </p>

      <div className="flex flex-wrap gap-3 justify-center" style={{ marginTop: 6 }}>
        <button
          onClick={() => inputRef.current?.click()}
          style={{
            background: 'var(--ink)',
            color: 'var(--paper)',
            padding: '10px 18px',
            borderRadius: 10,
            fontWeight: 600,
            fontSize: 13,
            letterSpacing: '-0.005em',
          }}
        >
          选择文件… · Choose files
        </button>
        <button
          onClick={onPasteText}
          style={{
            background: 'transparent',
            color: 'var(--text)',
            padding: '10px 18px',
            borderRadius: 10,
            fontWeight: 600,
            fontSize: 13,
            border: '1px solid var(--border)',
          }}
        >
          贴文字 / 链接 · Paste
        </button>
      </div>

      {children}
    </div>
  )
}
