interface Props {
  label: string
}

export function AsciiDivider({ label }: Props) {
  return (
    <div
      className="flex items-center gap-3 w-full"
      style={{
        color: 'var(--text-faint)',
        fontFamily: '"Geist Mono", ui-monospace, monospace',
        fontSize: 10.5,
        fontWeight: 700,
        textTransform: 'uppercase',
        letterSpacing: '0.18em',
        opacity: 0.7,
      }}
    >
      <span aria-hidden style={{ flex: 1, height: 1, background: 'var(--border)' }} />
      <span>{label}</span>
      <span aria-hidden style={{ flex: 1, height: 1, background: 'var(--border)' }} />
    </div>
  )
}
