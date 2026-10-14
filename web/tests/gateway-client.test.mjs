import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import { webcrypto } from 'node:crypto'
import { createServer } from 'node:http'
import ts from 'typescript'

const source = ts.transpileModule(readFileSync(new URL('../src/lib/engine.ts', import.meta.url), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText

const sessionKey = 'meshdrop.session:https://host:7384'

function fixture(fetchOverride, options = {}) {
  const timers = new Map()
  const storage = new Map(options.storage ?? [[sessionKey, 'session']])
  const sockets = []
  const requests = []
  let nextTimer = 0
  class Socket {
    static CONNECTING = 0
    static OPEN = 1
    readyState = 0
    handlers = new Map()
    sent = []
    send(frame) { this.sent.push(JSON.parse(frame)) }
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
    ...clock, window: { ...clock, location: options.location ?? { origin: 'https://host:7384', search: '' } },
    WebSocket: Socket, AbortController, FormData, URL, URLSearchParams, crypto: webcrypto,
    localStorage: { getItem: (key) => storage.get(key) ?? null, setItem: (k, v) => storage.set(k, v), removeItem: (k) => storage.delete(k) },
    fetch: fetchOverride ?? (async (url, options) => { requests.push({ url, options }); return { ok: true, json: async () => ({ token: 'fresh' }) } }),
  })
  const client = new exports.GatewayClient('https://host:7384')
  const states = []
  client.subscribe({ onConn: (state) => states.push(state) })
  return { client, states, storage, sockets, requests, timers, api: exports, fire(delay) {
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
  assert.equal(f.storage.has(sessionKey), false)
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

test('file upload rejection from the gateway is not reported as sent', async () => {
  const f = fixture()
  await f.client.connect()
  f.sockets[0].emit('open')
  const result = f.client.sendFile('phone', new File(['hello'], 'original.txt'))
  await new Promise((resolve) => setImmediate(resolve))
  const command = f.sockets[0].sent[0]
  assert.equal(command.type, 'send_file_ref')
  assert.equal(command.payload.name, 'original.txt')
  assert.equal(command.payload.fileRef, 'fresh')
  f.sockets[0].emit('message', { data: JSON.stringify({ id: command.id, ok: false, error: 'peer_not_found' }) })
  await assert.rejects(result, /peer_not_found/)
  assert.equal(f.timers.size, 0)
})

test('files are not uploaded while disconnected or sent without an upload reference', async () => {
  const f = fixture(async () => ({ ok: true, json: async () => ({}) }))
  const file = new File(['hello'], 'original.txt')
  await assert.rejects(f.client.sendFile('phone', file), /not connected/)
  await f.client.connect()
  f.sockets[0].emit('open')
  await assert.rejects(f.client.sendFile('phone', file), /file reference/)
  assert.equal(f.sockets[0].sent.length, 0)
})

test('waiting, failure before progress, and completion reach history and transfer UI', async () => {
  const f = fixture()
  const item = { id: 'file', peerName: 'iPhone', direction: 'sent', kind: 'file', files: [{ name: 'a.txt', sizeBytes: 50 }], completedAt: 0, ok: false }
  await f.client.connect()
  f.sockets[0].emit('open')
  const updates = []
  f.client.subscribe({ onHistoryUpdated: (h) => updates.push(h) })
  for (const change of [{ status: 'waiting' }, { status: 'failed', error: 'Connection timed out' }, { status: 'done', ok: true }]) {
    f.sockets[0].emit('message', { data: JSON.stringify({ type: 'history_updated', payload: { ...item, ...change } }) })
  }
  const rows = updates.map(f.api.adaptHistoryTransfer)
  assert.equal(rows[0].state, 'queued')
  assert.equal(rows[0].statusDetail, 'transfer.waitingApproval')
  assert.equal(f.api.adaptHistory(updates[0]).status, 'queued')
  assert.equal(rows[1].state, 'failed')
  assert.equal(rows[1].statusDetail, 'Connection timed out')
  assert.equal(rows[2].state, 'done')
  assert.equal(rows[2].progress, 100)
  assert.equal(f.api.adaptHistory(updates[2]).status, 'done')
})

test('a gateway query parameter cannot redirect an existing session', async () => {
  const f = fixture(undefined, { location: { origin: 'https://host:7384', search: '?gw=https%3A%2F%2Fevil.example' } })
  assert.equal(f.api.getGatewayEndpoint(), 'https://host:7384')
  await f.api.getClient().connect()
  assert.equal(f.sockets[0].url, 'wss://host:7384/api/v1/control?token=session')
  await f.api.getClient().pair('ABCDEF')
  assert.equal(f.requests[0].url, 'https://host:7384/api/v1/pair')
})

test('legacy tokens are not sent to a gateway with an unknown origin', async () => {
  const f = fixture(undefined, { storage: [['meshdrop.session', 'legacy']] })
  await f.client.connect()
  assert.equal(f.client.hasSession(), false)
  assert.equal(f.sockets.length, 0)
  assert.equal(f.storage.has('meshdrop.session'), false)
  assert.equal(await f.client.pair('ABCDEF'), true)
  assert.equal(f.storage.get(sessionKey), 'fresh')
})

test('gateway changes isolate tokens and keep listeners on the active client', async () => {
  const f = fixture()
  const client = f.api.getClient()
  const states = []
  client.subscribe({ onConn: (state) => states.push(state) })
  await client.connect()
  f.sockets[0].emit('open')
  f.api.setGatewayEndpoint('https://other:7384/')
  assert.equal(f.api.getClient(), client)
  assert.equal(f.sockets[0].readyState, 3)
  await client.connect()
  assert.equal(client.hasSession(), false)
  assert.equal(f.sockets.length, 1)
  assert.equal(await client.pair('ABCDEF'), true)
  assert.equal(f.requests[0].url, 'https://other:7384/api/v1/pair')
  assert.equal(f.storage.get(sessionKey), 'session')
  assert.equal(f.storage.get('meshdrop.session:https://other:7384'), 'fresh')
  await client.connect()
  f.sockets[1].emit('open')
  assert.equal(states.at(-1), 'open')
  client.forgetSession()
  assert.equal(f.sockets[1].readyState, 3)
  assert.equal(f.storage.has('meshdrop.session:https://other:7384'), false)
  f.api.setGatewayEndpoint('https://host:7384')
  assert.equal(client.hasSession(), true)
})

test('gateway origins reject credentials, paths, query strings and non-HTTP schemes', () => {
  const f = fixture()
  for (const endpoint of ['javascript:alert(1)', 'file:///tmp/a', 'https://user:pass@host/',
    'https://host/api', 'https://host/?redirect=evil', 'https://host/#fragment', '//host', 'not a URL']) {
    assert.throws(() => new f.api.GatewayClient(endpoint))
    assert.throws(() => f.api.setGatewayEndpoint(endpoint))
  }
  assert.equal(f.requests.length, 0)
  assert.equal(f.sockets.length, 0)
})

test('invalid stored gateways fall back safely and unconfigured clients never request a URL', async () => {
  const f = fixture(undefined, {
    storage: [['meshdrop.gateway', 'https://user:pass@evil.example/api']],
    location: { origin: 'http://localhost:5173', search: '?gw=https://evil.example' },
  })
  assert.equal(f.api.isGatewayConfigured(), false)
  const client = f.api.getClient()
  await client.connect()
  await assert.rejects(client.pair('ABCDEF'), /needGateway/)
  assert.equal(f.requests.length, 0)
  assert.equal(f.sockets.length, 0)
})

test('download identifiers cannot change the endpoint or inject a token', () => {
  const f = fixture()
  for (const id of ['.', '..', '../pair', '%2e%2e', 'file?token=other', 'file#fragment', 'a/b', '']) {
    assert.throws(() => f.client.downloadURL(id), /Invalid offer ID/)
  }
  assert.equal(f.client.downloadURL('offer-123'), 'https://host:7384/api/v1/download/offer-123?token=session')
})

test('late pairing and upload responses cannot cross a gateway change', async () => {
  let reply
  const f = fixture(() => new Promise((resolve) => { reply = resolve }))
  const pairing = f.client.pair('ABCDEF')
  f.client.setGateway('https://other:7384')
  reply({ ok: true, json: async () => ({ token: 'old-origin-token' }) })
  assert.equal(await pairing, false)
  assert.equal(f.client.hasSession(), false)
  assert.equal(f.storage.has('meshdrop.session:https://other:7384'), false)

  f.client.setGateway('https://host:7384')
  await f.client.connect()
  f.sockets[0].emit('open')
  const upload = f.client.sendFile('phone', new File(['secret'], 'private.txt'))
  f.client.setGateway('https://other:7384')
  reply({ ok: true, json: async () => ({ token: 'old-file-reference' }) })
  await assert.rejects(upload, /disconnected/)
  assert.equal(f.sockets[0].sent.length, 0)
})

test('HTTP redirects never forward pairing codes or upload credentials', async (t) => {
  let redirectedRequests = 0
  const server = createServer((req, res) => {
    req.resume()
    if (req.url === '/redirected') {
      redirectedRequests++
      res.writeHead(200, { 'content-type': 'application/json' })
      res.end('{"token":"redirected"}')
    } else {
      res.writeHead(307, { location: '/redirected' })
      res.end()
    }
  })
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
  t.after(() => new Promise((resolve) => server.close(resolve)))
  const origin = `http://127.0.0.1:${server.address().port}`
  const f = fixture(fetch, { storage: [[`meshdrop.session:${origin}`, 'secret-token']] })
  const client = new f.api.GatewayClient(origin)
  await assert.rejects(client.pair('ABCDEF'), /fetch failed/)
  await client.connect()
  f.sockets[0].emit('open')
  await assert.rejects(client.sendFile('phone', new File(['secret'], 'private.txt')), /fetch failed/)
  assert.equal(redirectedRequests, 0)
})
