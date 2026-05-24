# MeshDrop · Web Backend 接入 Prompt（连 native client gateway）

## 端特定任务

Web 端 **不直连 LAN**，通过 WebSocket 连 macOS / Windows / Linux GUI 上的 native gateway。
gateway 由 **B01 / B04 / B05** 三个 prompt 在各 native client 里实装。本 prompt 只做 web 侧。

## 工作范围

- ✅ `web/src/`（除 lib/mockData.ts 仍可用作 storybook）
- ✅ `web/package.json`（加新依赖时**先问**）
- ❌ 其他端、protocol/ 核心

## 必做

### 1. WebSocket 客户端

新增：

```
web/src/lib/
├── gateway.ts            # WebSocket 连接 + 命令 / 事件 / 回执
├── pairing.ts            # 6 字符码鉴权流程 + session cookie
└── upload.ts             # multipart upload helper
```

`gateway.ts` 暴露的 hook：

```typescript
export function useGateway(host: string): {
  status: 'connecting' | 'auth-needed' | 'online' | 'offline'
  devices: Device[]
  history: HistoryItem[]
  pendingOffers: Offer[]
  sendText: (peerId: string, text: string) => Promise<void>
  sendFile: (peerId: string, file: File) => Promise<void>
  acceptOffer: (offerId: string) => Promise<void>
  rejectOffer: (offerId: string) => Promise<void>
  submitPairingCode: (code: string) => Promise<void>
}
```

内部实装（按 `protocol/companion-bridges.md §4.3`）：

1. **首次访问**：浏览器 fetch `GET /` 看到 native client 的 placeholder，**提示用户输入 6 字符码**
2. **鉴权**：`POST /api/v1/pair` body `{code: "LR4K7M"}` → 返回 session cookie
3. **WebSocket**：`WS /api/v1/control`（携 cookie）→ 双向通道
4. **upload**：`POST /api/v1/upload` (multipart) → 返回 `{uploadToken}` → 用作 `send_file_ref.fileRef`

### 2. UI 切换

`web/src/hooks/useMockEngine.ts` rename → `useEngine.ts`，内部从 mock 改为 `useGateway(window.location.host)`。

UI 所有调用点改成 hook 返回值。

`MainPage.tsx` 顶部加：
- `status === 'connecting'` → 顶部 banner "连接中…"
- `status === 'auth-needed'` → 弹 modal 输入 6 字符码
- `status === 'offline'` → 顶部红 banner "网关失联 · 检查 native client 是否运行"

### 3. 上传流程

DropZone 拿到 File → 先 `POST /api/v1/upload` → 得 token → 再 `gateway.sendFile(peerId, token)` 命令。

或者：直接传 File 给 `gateway.sendFile`，hook 内部封装 upload + 命令两步。后者 API 更清爽，推荐。

### 4. 自签证书首次接受流程

如果 native client 用了自签 TLS，浏览器会拒绝。处理：

- 检测到 `fetch` 报 SSL 错 → 弹 modal 告诉用户：
  > "首次访问需在浏览器接受自签证书。请点击 `https://meshdrop.local:7384/` 在新标签页里点'继续访问'然后回来。"
- 提供一个"测试连接"按钮重试

### 5. 真实 WebCrypto

把 `web/src/lib/crypto.ts` 的 mock 替换成真实 `crypto.subtle.{generateKey,encrypt,decrypt}` 调用：
- 算法：X25519 ECDH（key agreement）+ AES-GCM (256bit) for symmetric
- 注意：浏览器 `crypto.subtle.generateKey({name: 'X25519'})` 只在 Chrome 124+ 支持。如不支持降级到 P-256 ECDH。
- 本轮 web 端的密钥**会话内有效**，关页销毁（设计承诺）

## 验证

```bash
cd web
npm install
npm run dev          # http://localhost:5173
npm run build
```

互通测试：
1. 在 mac 上跑 MeshDrop.app（gateway 启动）
2. 浏览器进 `https://<mac-ip>:7384/`（用 native client 的 placeholder）
3. 接受自签证书
4. 看到 mac native UI 上的 6 字符码 → 输入网页
5. 出现 web UI，能看到 LAN 上其他设备
6. 拖一个文件 → 选 peer → 发送 → 对方 mac 收到

## 依赖

**前置：** B01 / B04 / B05 中至少 1 个 gateway 实装好。

如果都还没合，本轮 web prompt 可以：
- 实装 client 端逻辑
- 用 mock WebSocket server（写一个简单的 node.js 占位）
- 真实互通验证留到 gateway 端合了再做

## PR 标题

`backend(web): 实装 WebSocket gateway client + 真实 WebCrypto`

## 互通证据

- 1 段 ≥ 15s mp4：浏览器接受证书 → 输 6 字符码 → 看到 mac LAN 设备 → 发文件 → mac 端收到
- 1 段截图：浏览器 devtools network 面板，看到 WSS 帧

## 不能做

- 不引入大型 UI 库（Ant / MUI / Chakra） — 沿用上一轮 Tailwind + 自写
- 不删 `mockData.ts`（storybook 用）
- 不在浏览器尝试 mDNS / TCP（用 gateway）
- 不去掉假浏览器 chrome 装饰
- 不持久化访客身份（关页就清是设计承诺）
- 不在 PR 描述里附 mock 数据截图当互通证据
