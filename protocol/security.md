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
| Android | SharedPreferences | EncryptedSharedPreferences（AndroidKeyStore 派生密钥） |
| Windows | DPAPI (`ProtectedData.Protect`)，文件落 LocalAppData | 同当前 |
| Linux   | 文件存储 | libsecret（`org.freedesktop.secrets`）+ 文件回退 |

设备 `id`（UUID）和 Ed25519 密钥一起生成，跨重启稳定；用户在设置中可以"重置
身份"重新生成（会导致所有对端把本机视为新设备需重新配对）。

## 配对（pairing）

首次连接采用 **TOFU + 显式确认**（类似 SSH known_hosts，但增加接收端 UI 确认）：

1. 发送方点击目标设备 → 建立 TCP → 发 HELLO。
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

**指纹显示规则**：所有 UI 上的指纹用 4 字符分组、空格分隔、全大写、共 8 组 32
字符（来自 32 hex 的 `fp` 完整长度），便于人工口头核对。

## 加密（v1.0 强制；v0.1 骨架可选）

v0.1 骨架阶段允许 **明文 TCP**，仅在同局域网内试运行；v1.0 起 **强制 TLS 1.3**：

### 证书

每台设备用自己的 Ed25519 密钥对生成 **自签名 X.509 证书**：
- CN: 设备 `id`
- SAN DNS: `meshdrop-<id>.local`
- 有效期：10 年
- 签名算法：Ed25519

证书在首次生成密钥时一并生成并落盘。

### TLS 配置

- 协议：TLS 1.3 ONLY；不允许 1.2 及以下。
- 密码套件：仅 `TLS_AES_256_GCM_SHA384` / `TLS_CHACHA20_POLY1305_SHA256`。
- ALPN：协议字符串 `"meshdrop/1"`，握手不匹配立即关闭。
- 客户端证书：**双向认证**（mTLS）。客户端与服务端都出示自己的证书。
- 证书校验：**不走 CA 链**；从证书提取 Ed25519 公钥，计算 `fp` 并与
  mDNS TXT 中声明的 `fp` 比对，一致才放行。等价于公钥钉死。

### 与 HELLO 的关系

TLS 完成 → 应用层握手（HELLO）依然进行，但 `fp` 字段必须等于证书公钥导出的
`fp`；否则关闭连接。这层冗余是为了：
- 抵御中间人（mDNS 可被同网段攻击者伪造 TXT；TLS 公钥钉死能拒绝）。
- 让没有 TLS 的早期骨架代码与已加密代码共用同一握手逻辑。

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
