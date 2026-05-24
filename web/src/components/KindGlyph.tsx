import type { DeviceKind } from '../lib/mockData'

interface Props {
  kind: DeviceKind
  size?: number
}

export function KindGlyph({ kind, size = 11 }: Props) {
  const s = size
  const stroke = 'currentColor'
  const sw = 1.4
  switch (kind) {
    case 'mac':
      return (
        <svg width={s * 1.3} height={s} viewBox="0 0 14 10" fill="none" aria-hidden>
          <rect x="0.7" y="0.7" width="12.6" height="7.6" rx="0.8" stroke={stroke} strokeWidth={sw} />
          <line x1="3.5" y1="9.3" x2="10.5" y2="9.3" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />
        </svg>
      )
    case 'win':
      return (
        <svg width={s} height={s} viewBox="0 0 10 10" fill="none" aria-hidden>
          <rect x="0.7" y="0.7" width="3.6" height="3.6" stroke={stroke} strokeWidth={sw} />
          <rect x="5.7" y="0.7" width="3.6" height="3.6" stroke={stroke} strokeWidth={sw} />
          <rect x="0.7" y="5.7" width="3.6" height="3.6" stroke={stroke} strokeWidth={sw} />
          <rect x="5.7" y="5.7" width="3.6" height="3.6" stroke={stroke} strokeWidth={sw} />
        </svg>
      )
    case 'ipad':
      return (
        <svg width={s} height={s * 1.3} viewBox="0 0 10 13" fill="none" aria-hidden>
          <rect x="0.7" y="0.7" width="8.6" height="11.6" rx="1.2" stroke={stroke} strokeWidth={sw} />
          <circle cx="5" cy="10.6" r="0.5" fill={stroke} />
        </svg>
      )
    case 'ios':
      return (
        <svg width={s * 0.7} height={s * 1.3} viewBox="0 0 7 13" fill="none" aria-hidden>
          <rect x="0.7" y="0.7" width="5.6" height="11.6" rx="1.2" stroke={stroke} strokeWidth={sw} />
          <line x1="2.4" y1="10.6" x2="4.6" y2="10.6" stroke={stroke} strokeWidth={sw} strokeLinecap="round" />
        </svg>
      )
    case 'android':
      return (
        <svg width={s * 0.8} height={s * 1.3} viewBox="0 0 8 13" fill="none" aria-hidden>
          <rect x="0.7" y="0.7" width="6.6" height="11.6" rx="1.2" stroke={stroke} strokeWidth={sw} />
          <circle cx="4" cy="10.6" r="0.5" stroke={stroke} strokeWidth={sw} />
        </svg>
      )
    case 'linux':
      return (
        <svg width={s} height={s} viewBox="0 0 10 10" fill="none" aria-hidden>
          <circle cx="5" cy="5" r="3.6" stroke={stroke} strokeWidth={sw} />
          <line x1="2" y1="5" x2="8" y2="5" stroke={stroke} strokeWidth={sw} />
        </svg>
      )
    case 'web':
    default:
      return (
        <svg width={s} height={s} viewBox="0 0 10 10" fill="none" aria-hidden>
          <circle cx="5" cy="5" r="3.6" stroke={stroke} strokeWidth={sw} />
          <ellipse cx="5" cy="5" rx="1.6" ry="3.6" stroke={stroke} strokeWidth={sw} />
          <line x1="1.4" y1="5" x2="8.6" y2="5" stroke={stroke} strokeWidth={sw} />
        </svg>
      )
  }
}
