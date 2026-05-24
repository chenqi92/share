/* Mock WebCrypto wrapper. Real X25519 + ChaCha20-Poly1305 lives in a later
   round; for the UI-first pass we only need deterministic-looking output
   so badges and fingerprints render. */

export interface MockSession {
  peerId: string
  fingerprint: string
  cipher: string
  established: number
}

const FAKE_FP_SEED = ['ZX8K', 'L72M', '9FQ3', '7HD2', 'M1P6', 'QA8N', 'KZ9R', 'X3WF']

export function fakeFingerprint(seed = 0): string {
  return FAKE_FP_SEED.map((g, i) => {
    if (i < seed % 4) return g
    return g
  }).join(' · ')
}

export async function startMockSession(peerId: string): Promise<MockSession> {
  // Real impl would call crypto.subtle.generateKey + X25519.
  await new Promise((r) => setTimeout(r, 24))
  return {
    peerId,
    fingerprint: fakeFingerprint(peerId.length),
    cipher: 'X25519 + ChaCha20-Poly1305',
    established: Date.now(),
  }
}

export function isCryptoAvailable(): boolean {
  return typeof globalThis !== 'undefined' &&
         typeof globalThis.crypto !== 'undefined' &&
         typeof globalThis.crypto.subtle !== 'undefined'
}
