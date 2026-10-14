# 身份、配对与加密（security）

## 设备身份

每台设备首次启动时生成一对 **Ed25519** 长期密钥：

- 私钥：保存在平台安全存储（见下表）。
- 公钥：每次广告 / 握手时附带。
- 设备指纹 `fp`：`SHA-256(public_key)` 取前 16 字节，32 位小写 hex。`fp` 在
  mDNS TXT 与 HELLO 中都会出现，必须一致；否则握手失败。

| 平台    | 当前实现 | 目标实现 |
| ------- | -------- | -------- |
| iOS / macOS | Keychain（accessible: `afterFirstUnlock`） | 同当前 |
| Android | EncryptedSharedPreferences（AndroidKeyStore 派生主密钥；旧明文库自动迁移并清空） | 同当前 |
| Windows | DPAPI (`ProtectedData.Protect`)，文件落 LocalAppData | 同当前 |
| Linux   | 文件存储（`0o600`，仅当前用户可读，**静置未加密**） | libsecret（`org.freedesktop.secrets`）+ 文件回退 |

设备 `id`（UUID）和 Ed25519 密钥一起生成，跨重启稳定；用户在设置中可以"重置
身份"重新生成（会导致所有对端把本机视为新设备需重新配对）。

## 配对（pairing）

首次连接采用 **TOFU + 显式确认**（类似 SSH known_hosts，但增加接收端 UI 确认）：

1. 发送方点击目标设备 → 建立 TCP 与 TLS 1.3 双向认证 → 发 HELLO。
2. 接收方收到 HELLO，在本地信任库 (`trusted_devices`) 查 `fp`。
3. **未命中**：接收端弹出配对对话框：
   ```
   "陈奇 的 iPhone" 想要连接到本设备
   指纹: AB12 34CD ... EF
   [拒绝]  [允许一次]  [允许并记住]
   ```
   - 拒绝 → 接收端直接断 TCP，不发 HELLO_ACK。
   - 允许一次 → 进入业务消息，但不写入信任库。
   - 允许并记住 → 写入 `trusted_devices`（`fp` + `name` 快照 + 时间戳），下次直
     接放行。
4. **已命中**：直接回 HELLO_ACK 进入业务消息。

Apple 与 Windows 1.1.2 起，已信任且通过连接身份校验的设备默认自动接收文件。
接收设置中关闭「自动接收已信任设备」后，每次文件传输需要确认；文本在连接获准后直接接收。
「允许一次」不会记住信任，也不会启用文件自动接收。撤销信任或指纹变化后需要重新配对。

**指纹显示规则**：所有 UI 上的指纹用 4 字符分组、空格分隔、全大写、共 8 组 32
字符（来自 32 hex 的 `fp` 完整长度），便于人工口头核对。

## 加密（Apple / Windows 1.1）

Apple 与 Windows 原生连接强制 TLS 1.3，不回退到旧版明文 TCP。Windows 使用
Bouncy Castle，在 Windows 10 与 Windows 11 上提供相同的 TLS 1.3 能力。
仓库中的其他平台实现应分别核对进度，不能仅由此文档推断已支持加密互通。

### 证书

长期 Ed25519 身份与短期 TLS 密钥分开：每条新连接生成 P-256 密钥和自签 X.509
证书，CN 为设备指纹，有效期从当前整秒减 300 秒起算 30 天。证书使用
ECDSA-SHA256 签名，含非 CA Basic Constraints、Digital Signature Key Usage 和
Server/Client Authentication EKU。

SAN 只有一个 URI：`urn:meshdrop:identity:` 后接标准 Base64 编码的 96 字节证明：
32 字节 Ed25519 公钥 + 64 字节 Ed25519 签名。签名内容依次拼接为：

- UTF-8 字节 `MeshDrop TLS identity v1` 和一个 NUL 字节；
- 65 字节 P-256 X9.63 未压缩公钥；
- ASCII `|<notBefore Unix 秒>|<notAfter Unix 秒>`。

这样，传输证书续期不改变设备指纹和信任关系，证书公钥或有效期不能被替换。
校验包含 DER 结构、有效期、自签名、允许的扩展、单一 SAN 和 Ed25519 证明。

### TLS 与 HELLO

- TLS 1.3 ONLY；双向证书认证。Windows 原生连接允许
  `TLS_AES_256_GCM_SHA384` / `TLS_CHACHA20_POLY1305_SHA256`。
- ALPN 为 `meshdrop/1`；Windows 在缺失或不匹配时关闭连接。
- 不复用 TLS 会话，不发送应用层早期数据。
- 不依赖公共 CA，也不向系统根证书库安装设备证书。
- 从验证后的证明中取 Ed25519 公钥计算 `fp`；出站连接必须与发现记录中的
  目标 `fp` 一致。HELLO / HELLO_ACK 必须与 TLS 认证得到的 `fp` 一致。
- 身份校验在进入配对和业务消息之前完成。

mDNS 本身没有认证。首次使用仍需用户核对双方设备指纹，不能仅把“与广播中
的指纹相同”当作对陌生设备的信任；记住信任后使用稳定的设备身份识别对端。

浏览器 Web Gateway 使用独立的 HTTPS 自签证书和配对码，不使用原生连接的
设备 mTLS。Windows 的 Web Gateway 也通过 Bouncy Castle 提供 TLS 1.3。

## 重放与时序

- TEXT、FILE_OFFER 都带 `id` / `transfer_id`（UUID v4），接收方做 5 分钟窗口
  去重：以 `(peer_fp, message_id) → 收到时刻` 维护一个 5 分钟 TTL 集合，命中
  即丢弃，避免断连重发 / 恶意重放导致同一消息重复入库或重复弹窗。
- 不允许从一条连接 fork 出多条文件传输用同一 `transfer_id`；接收方记录
  `transfer_id → 连接 id` 的映射，跨连接 ID 必须不同。

  **v0.1 实现状态（TODO）**：上述两项去重 / 映射在 v0.1 各端尚未落地——
  当前接收侧不丢弃重复的 `id` / `transfer_id`，也未维护 `transfer_id → 连接 id`
  全局映射（仅在单连接内校验 `FILE_ACCEPT` 的 `transfer_id` 是否匹配）。本项
  为协议不变量，留待后续按上述规则补齐；在补齐前断连重发可能产生重复消息。

## 隐私

- mDNS TXT 中的 `name` 是用户可见的显示名，会泄露给同网段任何设备；用户应
  被告知"在公共网络（咖啡馆、机场）开启可见性时其他人能看到你的设备名"。
- 提供"仅信任设备可见"模式：只对 `trusted_devices` 中的 `fp` 出现的浏览者
  应答 HELLO，未知 `fp` 直接关连接。具体实现各端 UI 自定。
