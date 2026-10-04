import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import ts from 'typescript'

const source = ts.transpileModule(readFileSync(new URL('../src/lib/engine.ts', import.meta.url), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText

function fixture(fetchOverride) {
  const timers = new Map()
  const storage = new Map([['meshdrop.session', 'session']])
  const sockets = []
  const requests = []
  let nextTimer = 0
  class Socket {
    static CONNECTING = 0
    static OPEN = 1
    readyState = 0
    handlers = new Map()
    constructor(url) { this.url = url; sockets.push(this) }
    addEventListener(type, callback) { this.handlers.set(type, callback) }
    emit(type, event = {}) {
      if (type === 'open') this.readyState = 1
      if (type === 'close') this.readyState = 3
      this.handlers.get(type)?.(event)
    }
    close() { this.emit('close') }
  }
  const exports = {}
  const clock = {
    setTimeout(callback, delay) { const id = ++nextTimer; timers.set(id, { callback, delay }); return id },
    clearTimeout(id) { timers.delete(id) },
  }
  vm.runInNewContext(source, {
    exports, require: () => ({ default: { t: (key) => key } }),
    ...clock, window: clock, WebSocket: Socket, AbortController,
    localStorage: { getItem: (key) => storage.get(key) ?? null, setItem: (k, v) => storage.set(k, v), removeItem: (k) => storage.delete(k) },
    fetch: fetchOverride ?? (async (url, options) => { requests.push({ url, options }); return { ok: true, json: async () => ({ token: 'fresh' }) } }),
  })
  const client = new exports.GatewayClient('https://host:7384')
  const states = []
  client.subscribe({ onConn: (state) => states.push(state) })
  return { client, states, storage, sockets, requests, timers, fire(delay) {
    for (const [id, timer] of timers) if (timer.delay === delay) { timers.delete(id); timer.callback(); return }
    assert.fail(`Missing ${delay}ms timer`)
  } }
}

test('pairing accepts the displayed code format and uses the new session once', async () => {
  const f = fixture()
  assert.equal(await f.client.pair('abc · d-ef'), true)
  assert.equal(JSON.parse(f.requests[0].options.body).code, 'ABCDEF')
  await f.client.connect()
  await f.client.connect()
  assert.equal(f.sockets.length, 1)
  assert.match(f.sockets[0].url, /token=fresh$/)
  let snapshot
  f.client.subscribe({ onState: (state) => { snapshot = state } })
  f.sockets[0].emit('open')
  f.sockets[0].emit('message', { data: JSON.stringify({ type: 'state_snapshot', payload: { devices: [], history: [] } }) })
  assert.equal(f.states.at(-1), 'open')
  assert.equal(snapshot.history.length, 0)
  assert.equal(f.timers.size, 0)
})

test('a stalled handshake returns to pairing instead of spinning forever', async () => {
  const f = fixture()
  await f.client.connect()
  f.fire(10_000)
  assert.equal(f.states.at(-1), 'unpaired')
  assert.equal(f.client.hasSession(), false)
  assert.equal(f.sockets[0].readyState, 3)
  assert.equal(f.timers.size, 0)
})

test('a rejected or expired session prompts pairing without a retry loop', async () => {
  const f = fixture()
  await f.client.connect()
  f.sockets[0].emit('close')
  assert.equal(f.states.at(-1), 'unpaired')
  assert.equal(f.storage.has('meshdrop.session'), false)
  assert.equal(f.timers.size, 0)
})

test('unexpected disconnection reconnects, but explicit disconnect ignores late events', async () => {
  const f = fixture()
  await f.client.connect()
  f.sockets[0].emit('open')
  f.sockets[0].emit('close')
  f.fire(2500)
  assert.equal(f.sockets.length, 2)
  f.client.disconnect()
  f.sockets[1].emit('open')
  f.sockets[1].emit('close')
  assert.equal(f.states.at(-1), 'closed')
  assert.equal(f.timers.size, 0)
})

test('pair requests have a deadline and release the pending request', async () => {
  const f = fixture((_url, { signal }) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(new Error('aborted')))
  }))
  const result = f.client.pair('ABCDEF')
  f.fire(10_000)
  await assert.rejects(result, /aborted/)
  assert.equal(f.timers.size, 0)
})
