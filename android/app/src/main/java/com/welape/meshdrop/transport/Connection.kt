package com.welape.meshdrop.transport

import com.welape.meshdrop.protocol.Frame
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket

/**
 * 包装一个 TCP socket，按帧 (Frame) 读写。
 *
 * 用法：建好后调用 [start]，传入 onReady/onMessage/onClose 回调。读循环在
 * Dispatchers.IO 上启动；任一侧关闭或出错都会触发 onClose（仅一次），之后
 * 不再有回调。
 */
class Connection private constructor(
    private val socket: Socket,
    private val outgoingTarget: String?,    // 用于日志
) {
    companion object {
        fun forIncoming(socket: Socket): Connection =
            Connection(socket, outgoingTarget = null)

        fun forOutgoing(host: String, port: Int): Connection {
            val socket = Socket()
            // 实际连接发生在 start() 内（不阻塞主线程）
            return Connection(socket, outgoingTarget = "$host:$port").apply {
                pendingConnect = InetSocketAddress(host, port)
            }
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val sendMutex = Mutex()
    private var pendingConnect: InetSocketAddress? = null

    @Volatile var isClosed: Boolean = false
        private set

    private var output: OutputStream? = null
    private var input: InputStream? = null

    private var onMessage: (suspend (Byte, ByteArray) -> Unit)? = null
    private var onClose: (suspend (Throwable?) -> Unit)? = null
    private var closeNotified = false

    fun start(
        onReady: suspend () -> Unit,
        onMessage: suspend (Byte, ByteArray) -> Unit,
        onClose: suspend (Throwable?) -> Unit,
    ) {
        this.onMessage = onMessage
        this.onClose = onClose

        scope.launch {
            try {
                pendingConnect?.let { socket.connect(it, 5000) }
                output = socket.getOutputStream()
                input = socket.getInputStream()
                onReady()
                readLoop()
            } catch (t: Throwable) {
                notifyClose(t)
            }
        }
    }

    suspend fun send(type: Byte, body: ByteArray) = withContext(Dispatchers.IO) {
        if (isClosed) throw IOException("connection closed")
        val frame = Frame.encode(type, body)
        sendMutex.withLock {
            val out = output ?: throw IOException("not ready")
            out.write(frame)
            out.flush()
        }
    }

    fun close() {
        if (isClosed) return
        isClosed = true
        try { socket.close() } catch (_: Exception) {}
        scope.cancel()
    }

    // MARK: - 私有

    private suspend fun readLoop() {
        val input = this.input ?: return
        val buf = ByteArray(64 * 1024)
        var pending = ByteArray(0)
        while (!isClosed) {
            val n = try { input.read(buf) } catch (e: IOException) {
                if (isClosed) break else throw e
            }
            if (n <= 0) {
                notifyClose(null)
                return
            }
            // 累积到 pending（一次性 copy 避免反复 alloc）
            val merged = ByteArray(pending.size + n)
            pending.copyInto(merged, 0)
            buf.copyInto(merged, pending.size, 0, n)
            pending = merged

            // 解出所有完整帧
            var offset = 0
            while (true) {
                val r = Frame.decode(pending, offset, pending.size - offset)
                when (r) {
                    Frame.DecodeResult.NeedMore -> break
                    is Frame.DecodeResult.LengthOutOfRange -> {
                        notifyClose(IOException("frame length out of range: ${r.len}"))
                        return
                    }
                    is Frame.DecodeResult.Decoded -> {
                        offset += r.consumed
                        try {
                            onMessage?.invoke(r.type, r.body)
                        } catch (t: Throwable) {
                            notifyClose(t)
                            return
                        }
                    }
                }
            }
            if (offset > 0) pending = pending.copyOfRange(offset, pending.size)
        }
        notifyClose(null)
    }

    private suspend fun notifyClose(t: Throwable?) {
        if (closeNotified) return
        closeNotified = true
        isClosed = true
        try { socket.close() } catch (_: Exception) {}
        try { onClose?.invoke(t) } catch (_: Throwable) {}
    }
}
