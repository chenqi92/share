import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: ['class', '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        ink: 'var(--ink)',
        'ink-80': 'var(--ink-80)',
        'ink-60': 'var(--ink-60)',
        'ink-45': 'var(--ink-45)',
        'ink-30': 'var(--ink-30)',
        'ink-12': 'var(--ink-12)',
        'ink-06': 'var(--ink-06)',
        paper: 'var(--paper)',
        paper2: 'var(--paper2)',
        card: 'var(--card)',
        line: 'var(--line)',
        dink: 'var(--dink)',
        dink2: 'var(--dink2)',
        dink3: 'var(--dink3)',
        dpaper: 'var(--dpaper)',
        dline: 'var(--dline)',
        lime: 'var(--lime)',
        'lime-deep': 'var(--lime-deep)',
        flame: 'var(--flame)',
        'flame-deep': 'var(--flame-deep)',
        sky: 'var(--sky)',
        error: 'var(--error)',

        bg: 'var(--bg)',
        bg2: 'var(--bg2)',
        surface: 'var(--surface)',
        text: 'var(--text)',
        'text-mute': 'var(--text-mute)',
        'text-faint': 'var(--text-faint)',
        border: 'var(--border)',
      },
      fontFamily: {
        display: ['"Space Grotesk"', '"PingFang SC"', '"Noto Sans SC"', 'system-ui', 'sans-serif'],
        body: ['Geist', '"PingFang SC"', '"Noto Sans SC"', '-apple-system', 'system-ui', 'sans-serif'],
        mono: ['"Geist Mono"', '"SF Mono"', 'ui-monospace', 'Menlo', 'monospace'],
      },
      letterSpacing: {
        tightish: '-0.012em',
        tighter1: '-0.025em',
        ascii: '0.18em',
      },
      borderRadius: {
        chip: '999px',
      },
      keyframes: {
        radarSweep: {
          '0%': { transform: 'rotate(0deg)' },
          '100%': { transform: 'rotate(360deg)' },
        },
        pulseHalo: {
          '0%': { transform: 'scale(0.6)', opacity: '0.9' },
          '100%': { transform: 'scale(1.6)', opacity: '0' },
        },
        bubbleIn: {
          '0%': { opacity: '0', transform: 'translateY(6px) scale(0.96)' },
          '100%': { opacity: '1', transform: 'translateY(0) scale(1)' },
        },
      },
      animation: {
        'radar-sweep': 'radarSweep 4.5s linear infinite',
        'pulse-halo': 'pulseHalo 2.4s ease-out infinite',
        'bubble-in': 'bubbleIn .22s cubic-bezier(.32,.72,.21,1)',
      },
    },
  },
  plugins: [],
}

export default config
