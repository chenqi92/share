package com.welape.meshdrop.transport

import android.content.Context
import android.net.Uri
import android.os.Build
import android.util.Log
import com.welape.meshdrop.data.ClipboardEntry
import com.welape.meshdrop.data.Device
import com.welape.meshdrop.data.DeviceOS
import com.welape.meshdrop.data.HistoryItem
import com.welape.meshdrop.data.HistoryKind
import com.welape.meshdrop.data.TransferMetrics
import com.welape.meshdrop.data.Identity
import com.welape.meshdrop.data.IdentityStore
import com.welape.meshdrop.data.PairingDecision
import com.welape.meshdrop.data.PendingFileOffer
import com.welape.meshdrop.data.PendingPairing
import com.welape.meshdrop.data.SessionThroughput
import com.welape.meshdrop.data.TransferDirection
import com.welape.meshdrop.data.TransferStatus
import com.welape.meshdrop.data.TrustRecord
import com.welape.meshdrop.data.TrustStore
import com.welape.meshdrop.discovery.MdnsDiscovery
import com.welape.meshdrop.protocol.FileAcceptMessage
import com.welape.meshdrop.protocol.FileCancelMessage
import com.welape.meshdrop.protocol.FileChunkHeader
import com.welape.meshdrop.protocol.FileCompleteMessage
import com.welape.meshdrop.protocol.FileMeta
import com.welape.meshdrop.protocol.FileOfferMessage
import com.welape.meshdrop.protocol.FileRejectMessage
import com.welape.meshdrop.protocol.ClipboardMessage
import com.welape.meshdrop.protocol.HelloAckMessage
import com.welape.meshdrop.protocol.HelloMessage
import com.welape.meshdrop.protocol.MessageCodec
import com.welape.meshdrop.protocol.MessageType
import com.welape.meshdrop.protocol.TextMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.OutputStream
import java.net.ServerSocket
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

private const val TAG = "ShareEngine"
private const val CHUNK_SIZE = 256 * 1024

/** 接收 chunk 时每写满这么多字节就把进度刷一次 ResumeStore。4 MiB ≈ 16 个 256 KiB chunk。 */
private const val RESUME_PERSIST_INTERVAL: Long = 4L * 1024 * 1024

/**
 * 顶层引擎：单例化通过 [com.welape.meshdrop.ShareApplication.engine] 暴露。
 *
 * 完整链路：
 * - sendText / sendFile：建出方 Connection → HELLO/ACK → TEXT 或 FILE_OFFER →
 *   流式 chunk → 等 COMPLETE → 关
 * - 入方：accept → HELLO → 信任校验 / 配对 → ACK → 业务消息分发
 */
class ShareEngine(private val context: Context) {
    val identity: Identity = IdentityStore.loadOrCreate(context)
    val displayName: String = Build.MODEL ?: "Android"
    private val model: String = "${Build.MANUFACTURER} ${Build.MODEL}"

    private val trustStore = TrustStore(context)
    private val resumeStore = ResumeStore.forContext(context)
    private val discovery = MdnsDiscovery(context, identity, displayName, model)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _devices = MutableStateFlow<List<Device>>(emptyList())
    val devices: StateFlow<List<Device>> = _devices.asStateFlow()

    private val _history = MutableStateFlow<List<HistoryItem>>(emptyList())
    val history: StateFlow<List<HistoryItem>> = _history.asStateFlow()

    private val _pendingPairings = MutableStateFlow<List<PendingPairing>>(emptyList())
    val pendingPairings: StateFlow<List<PendingPairing>> = _pendingPairings.asStateFlow()

    private val _pendingFileOffers = MutableStateFlow<List<PendingFileOffer>>(emptyList())
    val pendingFileOffers: StateFlow<List<PendingFileOffer>> = _pendingFileOffers.asStateFlow()

    private val _trusted = MutableStateFlow<List<TrustRecord>>(emptyList())
    val trusted: StateFlow<List<TrustRecord>> = _trusted.asStateFlow()

    private val _isStarting = MutableStateFlow(false)
    val isStarting: StateFlow<Boolean> = _isStarting.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    /** 进行中传输的实时速率 + ETA。key = history.id。terminal 时被 updateHistoryStatus 移除。 */
    private val _transferMetrics = MutableStateFlow<Map<UUID, TransferMetrics>>(emptyMap())
    val transferMetrics: StateFlow<Map<UUID, TransferMetrics>> = _transferMetrics.asStateFlow()

    /** 收到的剪贴板推送（最新在前，上限 50）。见 protocol/messages.md §0x11。 */
    private val _clipboardInbox = MutableStateFlow<List<ClipboardEntry>>(emptyList())
    val clipboardInbox: StateFlow<List<ClipboardEntry>> = _clipboardInbox.asStateFlow()

    /** 会话级吞吐时间序列（每秒采样，最新在后），供传输页速度柱状图绘制真实数据。 */
    private val _sessionThroughput = MutableStateFlow(SessionThroughput())
    val sessionThroughput: StateFlow<SessionThroughput> = _sessionThroughput.asStateFlow()

    /** 每个对端未读入站文本条数（key = peer.id）。收到入站文本 +1；打开会话时 markRead 清零。 */
    private val _unreadByPeer = MutableStateFlow<Map<String, Int>>(emptyMap())
    val unreadByPeer: StateFlow<Map<String, Int>> = _unreadByPeer.asStateFlow()

    /** 打开某对端会话时清掉其未读计数。 */
    fun markRead(peerId: String) {
        if (_unreadByPeer.value.containsKey(peerId)) {
            _unreadByPeer.value = _unreadByPeer.value - peerId
        }
    }

    private val contexts = ConcurrentHashMap<UUID, ConnectionContext>()
    private var listener: ServerSocket? = null
    private var acceptJob: Job? = null
    private var devicesJob: Job? = null
    private var throughputJob: Job? = null

    // MARK: - 生命周期

    fun start() {
        if (listener != null) return
        _isStarting.value = true
        _lastError.value = null
        scope.launch {
            try {
                val sock = ServerSocket(0)
                listener = sock
                val port = sock.localPort
                Log.i(TAG, "listening on port $port")

                discovery.start(port)
                devicesJob = launch { discovery.devices.collect { _devices.value = it } }
                _trusted.value = trustStore.snapshot()

                acceptJob = launch {
                    while (!sock.isClosed) {
                        try {
                            val client = sock.accept()
                            launch { acceptIncoming(Connection.forIncoming(client)) }
                        } catch (e: Exception) {
                            if (!sock.isClosed) Log.e(TAG, "accept failed", e)
                            break
                        }
                    }
                }
                // 每秒采样会话吞吐，喂给传输页速度柱状图
                throughputJob = launch {
                    while (true) {
                        delay(1000)
                        sampleThroughput()
                    }
                }
                _isStarting.value = false
            } catch (e: Exception) {
                Log.e(TAG, "start failed", e)
                _lastError.value = e.message ?: "启动失败"
                _isStarting.value = false
            }
        }
    }

    fun stop() {
        listener?.close()
        listener = null
        discovery.stop()
        devicesJob?.cancel()
        acceptJob?.cancel()
        throughputJob?.cancel()
        _sessionThroughput.value = SessionThroughput()
        val active = contexts.values.toList()
        contexts.clear()
        for (ctx in active) ctx.connection.close()
        _devices.value = emptyList()
        _isStarting.value = false
    }

    /** UI 调用：消费最近一条错误（关 snack 时用）。 */
    fun clearLastError() { _lastError.value = null }

    private fun reportError(message: String) {
        _lastError.value = message
    }

    // MARK: - 历史管理

    fun removeHistoryItem(id: UUID) {
        _history.value = _history.value.filter { it.id != id }
    }

    fun clearHistory() { _history.value = emptyList() }

    // MARK: - 出方：文本

    fun sendText(device: Device, content: String) {
        val item = HistoryItem(
            peer = device,
            direction = TransferDirection.OUTGOING,
            kind = HistoryKind.Text(content),
            status = TransferStatus.Pending,
        )
        insertHistory(item)

        val ctx = ConnectionContext(
            connection = newOutgoingConnection(device) ?: return failHistory(item.id, "无可用 IP"),
            role = ConnectionContext.Role.Client(device, ConnectionContext.Payload.Text(content)),
            state = ConnectionContext.State.AwaitingHelloAck,
        ).apply { historyId = item.id }
        contexts[ctx.id] = ctx
        startConnection(ctx)
    }

    // MARK: - 出方：剪贴板

    /**
     * 显式剪贴板推送（用户主动触发，非后台静默同步）。复用与 TEXT 相同的连接
     * 生命周期：建出方连接 → HELLO/ACK → CLIPBOARD → 关。不写入文件历史。
     * kind ∈ {text|link|code}，由调用方按内容判定。
     */
    fun pushClipboard(device: Device, content: String, kind: String) {
        if (content.isEmpty()) return
        val ctx = ConnectionContext(
            connection = newOutgoingConnection(device) ?: return,
            role = ConnectionContext.Role.Client(device, ConnectionContext.Payload.Clipboard(content, kind)),
            state = ConnectionContext.State.AwaitingHelloAck,
        )
        contexts[ctx.id] = ctx
        startConnection(ctx)
    }

    // MARK: - 出方：文件

    /** 批量发送：每个 file spec 独立 offer + 独立 history 条目，按顺序触发 sendFile。
     *  当前每文件新建一条连接；后续可改协议层批量。 */
    data class FileSpec(val sourceUri: Uri, val fileName: String, val fileSize: Long)

    fun sendFiles(device: Device, files: List<FileSpec>) {
        for (f in files) sendFile(device, f.sourceUri, f.fileName, f.fileSize)
    }

    fun sendFile(device: Device, sourceUri: Uri, fileName: String, fileSize: Long) {
        val item = HistoryItem(
            peer = device,
            direction = TransferDirection.OUTGOING,
            kind = HistoryKind.File(fileName, fileSize, sourceUri),
            status = TransferStatus.Pending,
        )
        insertHistory(item)
        val historyId = item.id

        scope.launch {
            val sha = try {
                computeSha256(sourceUri)
            } catch (e: Exception) {
                failHistory(historyId, "无法读取文件: ${e.message}"); return@launch
            }
            val conn = newOutgoingConnection(device)
                ?: return@launch failHistory(historyId, "无可用 IP")
            val ctx = ConnectionContext(
                connection = conn,
                role = ConnectionContext.Role.Client(device, ConnectionContext.Payload.File(sourceUri, fileSize, sha, fileName)),
                state = ConnectionContext.State.AwaitingHelloAck,
            ).apply {
                this.historyId = historyId
                this.transferId = UUID.randomUUID()
                this.fileSize = fileSize
            }
            contexts[ctx.id] = ctx
            updateHistoryStatus(historyId, TransferStatus.WaitingApproval)
            startConnection(ctx)
        }
    }

    private fun newOutgoingConnection(device: Device): Connection? {
        val host = device.host ?: return null
        return Connection.forOutgoing(host, device.port)
    }

    // MARK: - 决定

    fun respondToPairing(requestId: UUID, decision: PairingDecision) {
        val req = _pendingPairings.value.firstOrNull { it.id == requestId } ?: return
        _pendingPairings.value = _pendingPairings.value.filter { it.id != requestId }

        val entry = contexts.entries.firstOrNull { (_, c) ->
            val s = c.state
            s is ConnectionContext.State.AwaitingPairApproval && s.request.id == requestId
        } ?: return
        val ctx = entry.value
        scope.launch {
            when (decision) {
                PairingDecision.REJECT -> closeContext(ctx.id, null)
                PairingDecision.ALLOW_ONCE -> sendAckAndReady(ctx, req.peer)
                PairingDecision.TRUST -> {
                    trustStore.trust(req.peer.fingerprint, req.peer.name)
                    _trusted.value = trustStore.snapshot()
                    sendAckAndReady(ctx, req.peer)
                }
            }
        }
    }

    fun respondToFileOffer(offerId: UUID, accept: Boolean) {
        val offer = _pendingFileOffers.value.firstOrNull { it.id == offerId } ?: return
        _pendingFileOffers.value = _pendingFileOffers.value.filter { it.id != offerId }

        val ctx = contexts.values.firstOrNull { it.pendingOfferId == offerId } ?: return
        scope.launch {
            if (!accept) {
                try {
                    val body = MessageCodec.encode(FileRejectMessage(offerId.toString(), 0, "user_declined"))
                    ctx.connection.send(MessageType.FILE_REJECT, body)
                } catch (_: Exception) {}
                closeContext(ctx.id, null)
                return@launch
            }
            // 接受：开 file handle + 发 ACCEPT + 进入 receiving
            val saveFile = uniqueFile(defaultSaveDir(offer.peer), offer.fileName)
            try {
                val output = FileOutputStream(saveFile)
                ctx.output = output
                ctx.savedFile = saveFile
                ctx.fileSize = offer.fileSize
                ctx.expectedSha256 = offer.sha256
                ctx.transferId = offer.id
                ctx.pendingOfferId = null
                ctx.state = ConnectionContext.State.ReceivingFile

                val item = HistoryItem(
                    peer = offer.peer,
                    direction = TransferDirection.INCOMING,
                    kind = HistoryKind.File(offer.fileName, offer.fileSize, Uri.fromFile(saveFile)),
                    status = TransferStatus.Transferring(0, offer.fileSize),
                )
                insertHistory(item)
                ctx.historyId = item.id

                val body = MessageCodec.encode(FileAcceptMessage(offer.id.toString(), 0, 0))
                ctx.connection.send(MessageType.FILE_ACCEPT, body)
            } catch (e: Exception) {
                Log.e(TAG, "accept file failed", e)
                closeContext(ctx.id, e)
            }
        }
    }

    fun revokeTrust(fingerprint: String) {
        trustStore.revoke(fingerprint)
        _trusted.value = trustStore.snapshot()
    }

    /**
     * 主动取消进行中的传输（发送方 / 接收方均可）。
     * 查到对应 ctx 后：接收态先关 fileHandle 删半成品 + 清 ResumeStore；
     * 发送/接收都发 FILE_CANCEL（whole transfer, index=null, reason=user_canceled）；
     * 关 ctx 并标 history Canceled。
     */
    /**
     * 重发失败 / 取消的发送项。查 outgoing 失败项，sourceUri 仍可读时调
     * sendFile 走完整流程（新建独立 history 条目，旧失败条目不动）。
     * 返回 true 表示触发了重发；false 表示找不到 / 不是文件 / 源失效。
     */
    fun retryTransfer(historyId: UUID): Boolean {
        val item = _history.value.firstOrNull { it.id == historyId } ?: return false
        if (item.direction != TransferDirection.OUTGOING) return false
        val file = item.kind as? HistoryKind.File ?: return false
        val uri = file.uri ?: return false
        // 尝试打开 input stream 验证可读
        val canOpen = try {
            context.contentResolver.openInputStream(uri)?.use { true } ?: false
        } catch (_: Exception) { false }
        if (!canOpen) return false
        sendFile(item.peer, uri, file.name, file.size)
        return true
    }

    fun cancelTransfer(historyId: UUID) {
        val ctx = contexts.values.firstOrNull { it.historyId == historyId } ?: return
        val transferId = ctx.transferId ?: historyId
        scope.launch {
            if (ctx.state is ConnectionContext.State.ReceivingFile) {
                try { ctx.output?.close() } catch (_: Exception) {}
                ctx.output = null
                ctx.savedFile?.delete()
                val peer = ctx.peer
                val expected = ctx.expectedSha256
                if (peer != null && expected != null) {
                    resumeStore.clear(peer.fingerprint, expected)
                }
            }
            try {
                val body = MessageCodec.encode(
                    FileCancelMessage(
                        transfer_id = transferId.toString(),
                        index = null,
                        reason = "user_canceled",
                    )
                )
                ctx.connection.send(MessageType.FILE_CANCEL, body)
            } catch (_: Exception) {}
            updateHistoryStatus(historyId, TransferStatus.Canceled)
            closeContext(ctx.id, null)
        }
    }

    // MARK: - 入站 + 连接启动

    private suspend fun acceptIncoming(conn: Connection) {
        val ctx = ConnectionContext(
            connection = conn,
            role = ConnectionContext.Role.Server,
            state = ConnectionContext.State.AwaitingHello,
        )
        contexts[ctx.id] = ctx
        val ctxId = ctx.id
        conn.start(
            onReady = { },
            onMessage = { type, body -> handleMessage(ctxId, type, body) },
            onClose = { err -> closeContext(ctxId, err) },
        )
    }

    private fun startConnection(ctx: ConnectionContext) {
        val ctxId = ctx.id
        ctx.connection.start(
            onReady = { sendInitialHello(ctxId) },
            onMessage = { type, body -> handleMessage(ctxId, type, body) },
            onClose = { err -> closeContext(ctxId, err) },
        )
    }

    // MARK: - 路由

    private suspend fun handleMessage(ctxId: UUID, type: Byte, body: ByteArray) {
        val ctx = contexts[ctxId] ?: return
        val state = ctx.state
        when {
            state is ConnectionContext.State.AwaitingHello && type == MessageType.HELLO ->
                serverReceivedHello(ctx, body)

            state is ConnectionContext.State.AwaitingHelloAck && type == MessageType.HELLO_ACK ->
                clientReceivedAck(ctx, body)

            state is ConnectionContext.State.AwaitingFileAccept && type == MessageType.FILE_ACCEPT ->
                clientStartSending(ctx, body)

            state is ConnectionContext.State.AwaitingFileAccept && type == MessageType.FILE_REJECT -> {
                val reason = runCatching { MessageCodec.decode<FileRejectMessage>(body).reason }.getOrDefault("rejected")
                ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed("对方拒收: $reason")) }
                closeContext(ctxId, null)
            }

            state is ConnectionContext.State.SendingFile && type == MessageType.FILE_COMPLETE -> {
                ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Completed) }
                closeContext(ctxId, null)
            }

            state is ConnectionContext.State.Ready && type == MessageType.TEXT ->
                handleReceivedText(ctx, body)

            state is ConnectionContext.State.Ready && type == MessageType.CLIPBOARD ->
                handleReceivedClipboard(ctx, body)

            state is ConnectionContext.State.Ready && type == MessageType.FILE_OFFER ->
                handleReceivedFileOffer(ctx, body)

            state is ConnectionContext.State.ReceivingFile && type == MessageType.FILE_CHUNK ->
                handleReceivedChunk(ctx, body)

            type == MessageType.FILE_CANCEL -> {
                // 对端取消：接收态需删半成品 + 清 ResumeStore，避免之后被误判为可续传。
                if (ctx.state is ConnectionContext.State.ReceivingFile) {
                    try { ctx.output?.close() } catch (_: Exception) {}
                    ctx.output = null
                    ctx.savedFile?.delete()
                    val peer = ctx.peer
                    val expected = ctx.expectedSha256
                    if (peer != null && expected != null) {
                        resumeStore.clear(peer.fingerprint, expected)
                    }
                }
                ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Canceled) }
                closeContext(ctxId, null)
            }

            type == MessageType.PING ->
                try { ctx.connection.send(MessageType.PONG, "{}".toByteArray(Charsets.UTF_8)) } catch (_: Exception) {}

            type == MessageType.PONG -> { /* no-op */ }

            else -> {
                Log.i(TAG, "drop type=$type in state=$state")
                closeContext(ctxId, null)
            }
        }
    }

    // MARK: - HELLO 握手

    private suspend fun sendInitialHello(ctxId: UUID) {
        val ctx = contexts[ctxId] ?: return
        val hello = HelloMessage(
            id = identity.id,
            name = displayName,
            os = DeviceOS.current.raw,
            model = model,
            fp = identity.fingerprint,
            protocol_versions = listOf(1),
        )
        try {
            ctx.connection.send(MessageType.HELLO, MessageCodec.encode(hello))
        } catch (e: Exception) {
            closeContext(ctxId, e)
        }
    }

    private suspend fun serverReceivedHello(ctx: ConnectionContext, body: ByteArray) {
        val hello = runCatching { MessageCodec.decode<HelloMessage>(body) }.getOrNull()
        if (hello == null) { closeContext(ctx.id, null); return }
        if (!hello.protocol_versions.contains(1)) { closeContext(ctx.id, null); return }
        val os = DeviceOS.parse(hello.os) ?: DeviceOS.LINUX
        val peer = Device(
            id = hello.id, name = hello.name, os = os,
            model = hello.model, fingerprint = hello.fp,
            port = 0, protocolVersion = 1,
        )
        ctx.peer = peer

        if (trustStore.isTrusted(hello.fp)) {
            trustStore.touch(hello.fp)
            _trusted.value = trustStore.snapshot()
            sendAckAndReady(ctx, peer)
        } else {
            val req = PendingPairing(peer = peer)
            ctx.state = ConnectionContext.State.AwaitingPairApproval(req)
            _pendingPairings.value = _pendingPairings.value + req
        }
    }

    private suspend fun sendAckAndReady(ctx: ConnectionContext, peer: Device) {
        val ack = HelloAckMessage(
            id = identity.id,
            name = displayName,
            os = DeviceOS.current.raw,
            model = model,
            fp = identity.fingerprint,
            protocol_versions = listOf(1),
            selected_version = 1,
        )
        try {
            ctx.connection.send(MessageType.HELLO_ACK, MessageCodec.encode(ack))
            ctx.state = ConnectionContext.State.Ready
            ctx.peer = peer
        } catch (e: Exception) {
            closeContext(ctx.id, e)
        }
    }

    private suspend fun clientReceivedAck(ctx: ConnectionContext, body: ByteArray) {
        val ack = runCatching { MessageCodec.decode<HelloAckMessage>(body) }.getOrNull()
            ?: return closeContext(ctx.id, null)
        val role = ctx.role as? ConnectionContext.Role.Client ?: return closeContext(ctx.id, null)
        if (ack.fp != role.target.fingerprint) {
            Log.i(TAG, "server fp mismatch"); closeContext(ctx.id, null); return
        }
        ctx.peer = role.target

        when (val payload = role.payload) {
            is ConnectionContext.Payload.Text -> {
                val msg = TextMessage(
                    id = UUID.randomUUID().toString(),
                    content = payload.content,
                    ts = System.currentTimeMillis() / 1000,
                )
                try {
                    ctx.connection.send(MessageType.TEXT, MessageCodec.encode(msg))
                    ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Completed) }
                    delay(200)
                    closeContext(ctx.id, null)
                } catch (e: Exception) {
                    ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed(e.message ?: "error")) }
                    closeContext(ctx.id, e)
                }
            }
            is ConnectionContext.Payload.Clipboard -> {
                val msg = ClipboardMessage(
                    id = UUID.randomUUID().toString(),
                    content = payload.content,
                    kind = payload.kind,
                    ts = System.currentTimeMillis() / 1000,
                )
                try {
                    ctx.connection.send(MessageType.CLIPBOARD, MessageCodec.encode(msg))
                    delay(200)
                    closeContext(ctx.id, null)
                } catch (e: Exception) {
                    closeContext(ctx.id, e)
                }
            }
            is ConnectionContext.Payload.File -> {
                val tid = ctx.transferId ?: UUID.randomUUID().also { ctx.transferId = it }
                val offer = FileOfferMessage(
                    transfer_id = tid.toString(),
                    files = listOf(FileMeta(0, payload.fileName, payload.fileSize, payload.sha256)),
                )
                try {
                    ctx.connection.send(MessageType.FILE_OFFER, MessageCodec.encode(offer))
                    ctx.state = ConnectionContext.State.AwaitingFileAccept
                } catch (e: Exception) {
                    ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed(e.message ?: "error")) }
                    closeContext(ctx.id, e)
                }
            }
        }
    }

    // MARK: - 文件发送

    private suspend fun clientStartSending(ctx: ConnectionContext, acceptBody: ByteArray) {
        val role = ctx.role as? ConnectionContext.Role.Client ?: return
        val payload = role.payload as? ConnectionContext.Payload.File ?: return

        // 解析 FILE_ACCEPT.resume_offset；接收端若有半成品文件会要求从该 offset 起发。
        val resumeOffset: Long = runCatching {
            MessageCodec.decode<FileAcceptMessage>(acceptBody).resume_offset
        }.getOrDefault(0L).coerceIn(0L, payload.fileSize)

        try {
            val input = context.contentResolver.openInputStream(payload.sourceUri)
                ?: throw java.io.IOException("cannot open input")
            if (resumeOffset > 0) {
                // InputStream.skip 不保证一次跳完，循环到位
                var remaining = resumeOffset
                while (remaining > 0) {
                    val skipped = input.skip(remaining)
                    if (skipped <= 0) throw java.io.IOException("skip to $resumeOffset failed")
                    remaining -= skipped
                }
                Log.i(TAG, "resume send from offset=$resumeOffset/${payload.fileSize}")
            }
            ctx.input = input
            ctx.sentBytes = resumeOffset
            ctx.state = ConnectionContext.State.SendingFile
            ctx.historyId?.let {
                updateHistoryStatus(it, TransferStatus.Transferring(resumeOffset, payload.fileSize))
            }
            scope.launch { streamChunks(ctx) }
        } catch (e: Exception) {
            ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed(e.message ?: "error")) }
            closeContext(ctx.id, e)
        }
    }

    private suspend fun streamChunks(ctx: ConnectionContext) = withContext(Dispatchers.IO) {
        val input = ctx.input ?: return@withContext
        val tid = ctx.transferId ?: return@withContext
        val fileSize = ctx.fileSize
        val buf = ByteArray(CHUNK_SIZE)
        // 起点：续传时 ctx.sentBytes > 0；input 已 skip 到对应位置（见 clientStartSending）。
        var offset = ctx.sentBytes

        while (offset < fileSize && !ctx.connection.isClosed) {
            val toRead = minOf(CHUNK_SIZE.toLong(), fileSize - offset).toInt()
            val n = try { input.read(buf, 0, toRead) } catch (e: Exception) {
                ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed(e.message ?: "error")) }
                closeContext(ctx.id, e); return@withContext
            }
            if (n <= 0) break
            val data = if (n == buf.size) buf else buf.copyOf(n)
            val body = FileChunkHeader.encode(FileChunkHeader(tid, 0, offset), data)
            try {
                ctx.connection.send(MessageType.FILE_CHUNK, body)
            } catch (e: Exception) {
                ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed(e.message ?: "error")) }
                closeContext(ctx.id, e); return@withContext
            }
            offset += n
            ctx.sentBytes = offset
            recordProgress(ctx, offset, fileSize)
            ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Transferring(offset, fileSize)) }
        }
        try { input.close() } catch (_: Exception) {}
        ctx.input = null
        // 等对端 FILE_COMPLETE
    }

    // MARK: - 接收

    private fun handleReceivedText(ctx: ConnectionContext, body: ByteArray) {
        val peer = ctx.peer ?: return
        val text = runCatching { MessageCodec.decode<TextMessage>(body) }.getOrNull() ?: return
        insertHistory(
            HistoryItem(
                peer = peer,
                direction = TransferDirection.INCOMING,
                kind = HistoryKind.Text(text.content),
                status = TransferStatus.Completed,
            )
        )
        _unreadByPeer.value = _unreadByPeer.value +
            (peer.id to ((_unreadByPeer.value[peer.id] ?: 0) + 1))
    }

    private fun handleReceivedClipboard(ctx: ConnectionContext, body: ByteArray) {
        val peer = ctx.peer ?: return
        val msg = runCatching { MessageCodec.decode<ClipboardMessage>(body) }.getOrNull() ?: return
        val entry = ClipboardEntry(
            peerName = peer.name,
            content = msg.content,
            kind = msg.kind,
        )
        _clipboardInbox.value = (listOf(entry) + _clipboardInbox.value).take(50)
    }

    private suspend fun handleReceivedFileOffer(ctx: ConnectionContext, body: ByteArray) {
        val peer = ctx.peer ?: return
        val offer = runCatching { MessageCodec.decode<FileOfferMessage>(body) }.getOrNull() ?: return
        val first = offer.files.firstOrNull() ?: return
        val tid = runCatching { UUID.fromString(offer.transfer_id) }.getOrNull() ?: return

        // 命中 ResumeStore 且半成品仍在 → 自动接受，发 resume_offset > 0；否则走正常审批。
        val resume = resumeStore.find(peer.fingerprint, first.sha256)
        if (resume != null &&
            resume.fileSize == first.size &&
            resume.bytesDone < first.size &&
            File(resume.savedPath).exists()) {
            if (startAutoResumeReceive(ctx, peer, tid, first, resume)) return
            // 自动续传打开失败 → 落到正常审批流程
            resumeStore.clear(peer.fingerprint, first.sha256)
        }

        val pending = PendingFileOffer(
            id = tid, peer = peer,
            fileName = first.name, fileSize = first.size, sha256 = first.sha256,
        )
        ctx.pendingOfferId = pending.id
        _pendingFileOffers.value = _pendingFileOffers.value + pending
    }

    /** 命中 ResumeStore：复用 savedFile，append 模式开 output，发 FILE_ACCEPT 带 resume_offset。返回 true 表示已接管（成功进入续传态，或已 close 上下文）。 */
    private suspend fun startAutoResumeReceive(
        ctx: ConnectionContext,
        peer: Device,
        transferId: UUID,
        meta: FileMeta,
        record: ResumeRecord,
    ): Boolean {
        val saveFile = File(record.savedPath)

        // Stage 1: 只做 IO 准备 — 失败时 ctx 未被任何修改，调用方可走正常审批流程。
        val output: FileOutputStream = try {
            java.io.RandomAccessFile(saveFile, "rw").use { it.setLength(record.bytesDone) }
            FileOutputStream(saveFile, /*append=*/ true)
        } catch (e: Exception) {
            Log.e(TAG, "auto-resume prep failed", e)
            return false
        }

        // Stage 2: 提交到 ctx + 发 FILE_ACCEPT。从这里开始 ctx 已进入 ReceivingFile，
        // send 失败也必须关上下文（不能回到 Ready），否则后续 chunk 会写到错地方。
        ctx.output = output
        ctx.savedFile = saveFile
        ctx.fileSize = meta.size
        ctx.expectedSha256 = meta.sha256
        ctx.transferId = transferId
        ctx.pendingOfferId = null
        ctx.receivedBytes = record.bytesDone
        ctx.lastPersistedBytes = record.bytesDone
        ctx.state = ConnectionContext.State.ReceivingFile

        val item = HistoryItem(
            peer = peer,
            direction = TransferDirection.INCOMING,
            kind = HistoryKind.File(meta.name, meta.size, Uri.fromFile(saveFile)),
            status = TransferStatus.Transferring(record.bytesDone, meta.size),
        )
        insertHistory(item)
        ctx.historyId = item.id

        return try {
            val acceptBody = MessageCodec.encode(FileAcceptMessage(transferId.toString(), 0, record.bytesDone))
            ctx.connection.send(MessageType.FILE_ACCEPT, acceptBody)
            Log.i(TAG, "auto-resume: ${record.fileName} from ${record.bytesDone}/${meta.size}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "auto-resume send accept failed", e)
            closeContext(ctx.id, e)
            true
        }
    }

    private suspend fun handleReceivedChunk(ctx: ConnectionContext, body: ByteArray) {
        val (_, data) = FileChunkHeader.decode(body) ?: return
        val output = ctx.output ?: return
        try {
            output.write(data)
        } catch (e: Exception) {
            ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed(e.message ?: "error")) }
            closeContext(ctx.id, e); return
        }
        ctx.receivedBytes += data.size
        recordProgress(ctx, ctx.receivedBytes, ctx.fileSize)
        ctx.historyId?.let {
            updateHistoryStatus(it, TransferStatus.Transferring(ctx.receivedBytes, ctx.fileSize))
        }

        // 增量持久化：每写满 RESUME_PERSIST_INTERVAL 字节刷一次 ResumeStore。
        if (ctx.receivedBytes - ctx.lastPersistedBytes >= RESUME_PERSIST_INTERVAL &&
            ctx.receivedBytes < ctx.fileSize) {
            val saved = ctx.savedFile
            val expected = ctx.expectedSha256
            val tid = ctx.transferId
            val peer = ctx.peer
            if (saved != null && expected != null && tid != null && peer != null) {
                ctx.lastPersistedBytes = ctx.receivedBytes
                resumeStore.upsert(
                    ResumeRecord(
                        peerFingerprint = peer.fingerprint,
                        transferId = tid.toString(),
                        fileName = saved.name,
                        fileSize = ctx.fileSize,
                        sha256 = expected,
                        savedPath = saved.absolutePath,
                        bytesDone = ctx.receivedBytes,
                        updatedAt = System.currentTimeMillis(),
                    )
                )
            }
        }

        if (ctx.receivedBytes >= ctx.fileSize) {
            try { output.close() } catch (_: Exception) {}
            ctx.output = null
            // 校验
            val saved = ctx.savedFile
            val expected = ctx.expectedSha256
            if (saved != null && expected != null) {
                val actual = try { computeSha256OfFile(saved) } catch (_: Exception) { "" }
                if (actual != expected) {
                    ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed("校验失败")) }
                    saved.delete()
                    ctx.peer?.let { resumeStore.clear(it.fingerprint, expected) }
                    closeContext(ctx.id, null); return
                }
                // 完成 → 清掉 ResumeStore 中对应记录
                ctx.peer?.let { resumeStore.clear(it.fingerprint, expected) }
            }
            try {
                val tid = ctx.transferId
                if (tid != null) {
                    val complete = FileCompleteMessage(tid.toString(), 0)
                    ctx.connection.send(MessageType.FILE_COMPLETE, MessageCodec.encode(complete))
                }
            } catch (_: Exception) {}
            ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Completed) }
            delay(150)
            closeContext(ctx.id, null)
        }
    }

    // MARK: - 关闭与辅助

    private suspend fun closeContext(id: UUID, t: Throwable?) {
        val ctx = contexts.remove(id) ?: return
        val state = ctx.state
        if (state is ConnectionContext.State.AwaitingPairApproval) {
            _pendingPairings.value = _pendingPairings.value.filter { it.id != state.request.id }
        }
        ctx.pendingOfferId?.let { pid ->
            _pendingFileOffers.value = _pendingFileOffers.value.filter { it.id != pid }
        }

        // 接收态被异常关闭（output 仍持有 + 字节未收齐）→ 视为「连接中断」：
        //   1) 最后再刷一次 receivedBytes 到 ResumeStore（增量持久化以来可能又写了几 chunks）
        //   2) history 状态标「连接中断 · 等待续传」
        // ResumeRecord 不在这里删 —— 等下次 FILE_OFFER 按 sha256 命中再用。
        if (state is ConnectionContext.State.ReceivingFile &&
            ctx.output != null &&
            ctx.receivedBytes < ctx.fileSize) {
            val saved = ctx.savedFile
            val expected = ctx.expectedSha256
            val tid = ctx.transferId
            val peer = ctx.peer
            if (saved != null && expected != null && tid != null && peer != null &&
                ctx.receivedBytes > 0 && ctx.receivedBytes > ctx.lastPersistedBytes) {
                resumeStore.upsert(
                    ResumeRecord(
                        peerFingerprint = peer.fingerprint,
                        transferId = tid.toString(),
                        fileName = saved.name,
                        fileSize = ctx.fileSize,
                        sha256 = expected,
                        savedPath = saved.absolutePath,
                        bytesDone = ctx.receivedBytes,
                        updatedAt = System.currentTimeMillis(),
                    )
                )
            }
            ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed("连接中断 · 等待续传")) }
        } else if (state is ConnectionContext.State.SendingFile &&
                   ctx.sentBytes < ctx.fileSize) {
            // 发送态意外断开 — UI 标失败，用户可从历史重发。
            ctx.historyId?.let { updateHistoryStatus(it, TransferStatus.Failed("连接中断")) }
        }

        try { ctx.input?.close() } catch (_: Exception) {}
        try { ctx.output?.close() } catch (_: Exception) {}
        ctx.state = ConnectionContext.State.Closed
        ctx.connection.close()
        if (t != null) Log.d(TAG, "ctx $id closed: ${t.message}")
    }

    private fun insertHistory(item: HistoryItem) {
        _history.value = listOf(item) + _history.value
    }

    private fun updateHistoryStatus(id: UUID, status: TransferStatus) {
        _history.value = _history.value.map {
            if (it.id == id) it.copy(status = status) else it
        }
        // 终态：清掉速率指标，UI 上 speed/ETA 立即消失。
        val terminal = status is TransferStatus.Completed
            || status is TransferStatus.Failed
            || status is TransferStatus.Canceled
        if (terminal && _transferMetrics.value.containsKey(id)) {
            _transferMetrics.value = _transferMetrics.value - id
        }
    }

    /**
     * ctx 累计字节变化时调一下，刷新 EMA 字节/秒 + ETA 到 `_transferMetrics[historyId]`。
     * 节流：相邻样本至少 100ms（chunk 触发频率太快会抖到无意义）；α=0.3 指数平滑。
     */
    private fun recordProgress(ctx: ConnectionContext, currentBytes: Long, totalBytes: Long) {
        val hid = ctx.historyId ?: return
        val nowNs = System.nanoTime()
        val prevNs = ctx.lastSampleNanos
        val prevBytes = ctx.lastSampleBytes
        if (prevNs != 0L) {
            val dtNs = nowNs - prevNs
            if (dtNs < 100_000_000L) return // 100ms 节流
            if (currentBytes >= prevBytes) {
                val inst = (currentBytes - prevBytes).toDouble() / (dtNs.toDouble() / 1_000_000_000.0)
                ctx.emaBytesPerSec = if (ctx.emaBytesPerSec == 0.0) inst
                                    else 0.3 * inst + 0.7 * ctx.emaBytesPerSec
            }
        }
        ctx.lastSampleNanos = nowNs
        ctx.lastSampleBytes = currentBytes

        val bps = ctx.emaBytesPerSec
        val eta = if (bps > 1.0 && totalBytes > currentBytes) {
            (totalBytes - currentBytes).toDouble() / bps
        } else null
        _transferMetrics.value = _transferMetrics.value + (hid to TransferMetrics(bps, eta))
    }

    /** 每秒一次：把进行中传输的瞬时速率按方向汇总成一个时间桶，推入环形序列。 */
    private fun sampleThroughput() {
        val metrics = _transferMetrics.value
        var up = 0.0
        var down = 0.0
        for (h in _history.value) {
            if (h.status !is TransferStatus.Transferring) continue
            val m = metrics[h.id] ?: continue
            if (h.direction == TransferDirection.OUTGOING) up += m.bytesPerSec else down += m.bytesPerSec
        }
        val cur = _sessionThroughput.value
        _sessionThroughput.value = SessionThroughput(
            up = (cur.up + up).takeLast(32),
            down = (cur.down + down).takeLast(32),
        )
    }

    private fun failHistory(id: UUID, reason: String) {
        updateHistoryStatus(id, TransferStatus.Failed(reason))
        reportError(reason)
    }

    // sha256

    private suspend fun computeSha256(uri: Uri): String = withContext(Dispatchers.IO) {
        val digest = MessageDigest.getInstance("SHA-256")
        val input = context.contentResolver.openInputStream(uri)
            ?: throw java.io.IOException("cannot open uri")
        input.use {
            val buf = ByteArray(1024 * 1024)
            while (true) {
                val n = it.read(buf)
                if (n <= 0) break
                digest.update(buf, 0, n)
            }
        }
        digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun computeSha256OfFile(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use {
            val buf = ByteArray(1024 * 1024)
            while (true) {
                val n = it.read(buf)
                if (n <= 0) break
                digest.update(buf, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    // 保存路径
    private fun defaultSaveDir(peer: Device): File {
        val base = context.getExternalFilesDir(null) ?: context.filesDir
        val name = peer.name.ifEmpty { peer.id }
        val dir = File(File(base, "MeshDrop"), name)
        dir.mkdirs()
        return dir
    }

    private fun uniqueFile(dir: File, fileName: String): File {
        var candidate = File(dir, fileName)
        if (!candidate.exists()) return candidate
        val base = fileName.substringBeforeLast('.')
        val ext = fileName.substringAfterLast('.', "")
        var n = 1
        while (true) {
            val name = if (ext.isEmpty()) "$base ($n)" else "$base ($n).$ext"
            candidate = File(dir, name)
            if (!candidate.exists()) return candidate
            n++
        }
    }

    companion object {
        /**
         * 按内容粗判剪贴板 kind（与 Apple 端 clipKind 同口径）：
         * 以 http(s):// 开头且无空白 → link；含换行且出现代码特征字符 → code；否则 text。
         */
        fun clipKind(content: String): String {
            val trimmed = content.trim()
            if ((trimmed.startsWith("http://") || trimmed.startsWith("https://")) &&
                !trimmed.any { it.isWhitespace() }) {
                return "link"
            }
            if (trimmed.contains('\n') && trimmed.any { it in "{};=<>/" }) {
                return "code"
            }
            return "text"
        }
    }
}

// MARK: - ConnectionContext

class ConnectionContext(
    val id: UUID = UUID.randomUUID(),
    val connection: Connection,
    val role: Role,
    @Volatile var state: State,
) {
    sealed interface Role {
        data object Server : Role
        data class Client(val target: Device, val payload: Payload) : Role
    }

    sealed interface Payload {
        data class Text(val content: String) : Payload
        data class Clipboard(val content: String, val kind: String) : Payload
        data class File(
            val sourceUri: Uri,
            val fileSize: Long,
            val sha256: String,
            val fileName: String,
        ) : Payload
    }

    sealed interface State {
        data object AwaitingHello : State
        data class AwaitingPairApproval(val request: PendingPairing) : State
        data object AwaitingHelloAck : State
        data object AwaitingFileAccept : State
        data object SendingFile : State
        data object Ready : State
        data object ReceivingFile : State
        data object Closed : State
    }

    @Volatile var peer: Device? = null
    @Volatile var historyId: UUID? = null
    @Volatile var transferId: UUID? = null
    @Volatile var pendingOfferId: UUID? = null

    @Volatile var input: java.io.InputStream? = null
    @Volatile var output: OutputStream? = null
    @Volatile var fileSize: Long = 0
    @Volatile var sentBytes: Long = 0
    @Volatile var receivedBytes: Long = 0
    @Volatile var savedFile: File? = null
    @Volatile var expectedSha256: String? = null
    /** 接收方：上次写入 ResumeStore 的 bytesDone，用来限制持久化频率。 */
    @Volatile var lastPersistedBytes: Long = 0

    // 速率窗口：上次采样时刻 + 当时累计字节，用来算 Δbytes / Δtime。
    @Volatile var lastSampleNanos: Long = 0
    @Volatile var lastSampleBytes: Long = 0
    /** 指数移动平均字节/秒（α=0.3，足够平滑但不会僵硬滞后）。 */
    @Volatile var emaBytesPerSec: Double = 0.0
}
