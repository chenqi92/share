package drop.mesh.transport

import android.content.Context
import android.net.Uri
import android.os.Build
import android.util.Log
import drop.mesh.data.Device
import drop.mesh.data.DeviceOS
import drop.mesh.data.HistoryItem
import drop.mesh.data.HistoryKind
import drop.mesh.data.Identity
import drop.mesh.data.IdentityStore
import drop.mesh.data.PairingDecision
import drop.mesh.data.PendingFileOffer
import drop.mesh.data.PendingPairing
import drop.mesh.data.TransferDirection
import drop.mesh.data.TransferStatus
import drop.mesh.data.TrustRecord
import drop.mesh.data.TrustStore
import drop.mesh.discovery.MdnsDiscovery
import drop.mesh.protocol.FileAcceptMessage
import drop.mesh.protocol.FileChunkHeader
import drop.mesh.protocol.FileCompleteMessage
import drop.mesh.protocol.FileMeta
import drop.mesh.protocol.FileOfferMessage
import drop.mesh.protocol.FileRejectMessage
import drop.mesh.protocol.HelloAckMessage
import drop.mesh.protocol.HelloMessage
import drop.mesh.protocol.MessageCodec
import drop.mesh.protocol.MessageType
import drop.mesh.protocol.TextMessage
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

/**
 * 顶层引擎：单例化通过 [drop.mesh.ShareApplication.engine] 暴露。
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

    private val contexts = ConcurrentHashMap<UUID, ConnectionContext>()
    private var listener: ServerSocket? = null
    private var acceptJob: Job? = null
    private var devicesJob: Job? = null

    // MARK: - 生命周期

    fun start() {
        if (listener != null) return
        scope.launch {
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
        }
    }

    fun stop() {
        listener?.close()
        listener = null
        discovery.stop()
        devicesJob?.cancel()
        acceptJob?.cancel()
        val active = contexts.values.toList()
        contexts.clear()
        for (ctx in active) ctx.connection.close()
        _devices.value = emptyList()
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

    // MARK: - 出方：文件

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
                clientStartSending(ctx)

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

            state is ConnectionContext.State.Ready && type == MessageType.FILE_OFFER ->
                handleReceivedFileOffer(ctx, body)

            state is ConnectionContext.State.ReceivingFile && type == MessageType.FILE_CHUNK ->
                handleReceivedChunk(ctx, body)

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

    private suspend fun clientStartSending(ctx: ConnectionContext) {
        val role = ctx.role as? ConnectionContext.Role.Client ?: return
        val payload = role.payload as? ConnectionContext.Payload.File ?: return
        try {
            val input = context.contentResolver.openInputStream(payload.sourceUri)
                ?: throw java.io.IOException("cannot open input")
            ctx.input = input
            ctx.state = ConnectionContext.State.SendingFile
            ctx.historyId?.let {
                updateHistoryStatus(it, TransferStatus.Transferring(0, payload.fileSize))
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
        var offset = 0L

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
    }

    private fun handleReceivedFileOffer(ctx: ConnectionContext, body: ByteArray) {
        val peer = ctx.peer ?: return
        val offer = runCatching { MessageCodec.decode<FileOfferMessage>(body) }.getOrNull() ?: return
        val first = offer.files.firstOrNull() ?: return
        val tid = runCatching { UUID.fromString(offer.transfer_id) }.getOrNull() ?: return

        val pending = PendingFileOffer(
            id = tid, peer = peer,
            fileName = first.name, fileSize = first.size, sha256 = first.sha256,
        )
        ctx.pendingOfferId = pending.id
        _pendingFileOffers.value = _pendingFileOffers.value + pending
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
        ctx.historyId?.let {
            updateHistoryStatus(it, TransferStatus.Transferring(ctx.receivedBytes, ctx.fileSize))
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
                    closeContext(ctx.id, null); return
                }
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
    }

    private fun failHistory(id: UUID, reason: String) {
        updateHistoryStatus(id, TransferStatus.Failed(reason))
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
}
