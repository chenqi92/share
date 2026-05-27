# MeshDrop · Web

浏览器端 MeshDrop UI。通过 `protocol/companion-bridges.md §4.3` 描述的 Web Gateway
桥接到一台 native client（macOS / Windows / Linux GUI 上的 MeshDrop app），由
native client 代为接入 LAN。本端不直接挂 LAN。

## 开发

```bash
cd web
npm install
npm run dev               # vite dev server，默认 http://localhost:5173
```

dev 模式需要手工指定 gateway URL：

```
http://localhost:5173?gw=https://<lan-ip>:7384
```

或在浏览器 console 里：

```js
localStorage.setItem('meshdrop.gateway', 'https://<lan-ip>:7384')
```

之后再刷新页面即可。token 会自动持久化在 localStorage。

## 构建

```bash
npm run build             # 输出到 dist/
npm run preview           # 起 vite preview 看构建后的产物
```

`dist/` 会被各 native client 嵌进自己的 `web-fallback` 资源里（macOS 的
`apple/MeshDropMac/Resources/web-fallback/`、Windows 的
`windows/MeshDrop/Assets/web-fallback/`、Linux 的
`linux/crates/meshdrop-core/data/web-fallback/`），作为 gateway 的静态根。
直接访问 `https://<gateway-ip>:7384/` 就能拿到这份 UI。

## Gateway 连接

`src/lib/engine.ts` 里 `detectGateway()` 三层 fallback：

1. URL `?gw=<url>` 显式覆盖
2. `localStorage['meshdrop.gateway']` 上次配置
3. 当前 `window.location.origin`（gateway 把 web 嵌在自己 host 上时这一步直接命中）
4. 否则 `about:blank` 占位（dev 模式无 gateway 时）

API 与 gateway 之间走（按 `companion-bridges.md §4.3`）：

| 端点 | 说明 |
| --- | --- |
| `POST /api/v1/pair` | 6 字符配对码 → 24h session token + Set-Cookie |
| `WS /api/v1/control?token=<sid>` | 双向命令 / 事件通道 |
| `POST /api/v1/upload` | multipart 上传 → `{token:"<path>"}` 作为 `send_file_ref.fileRef` |
| `GET /api/v1/download/<historyId>` | 流式下载已接收文件（仅 macOS gateway 当前实装） |

`Cookie meshdrop_session`、`?token=`、`x-meshdrop-token` header 任一都能鉴权（与 Apple / Linux / Windows gateway 三端约定一致）。

## 调试 TLS 自签证书

native gateway 用 CN=`meshdrop.local` 的自签 cert。首次访问浏览器会显示证书警告：
- Safari → "显示详细信息" → "访问此网站" → 信任后写 keychain
- Chrome → "高级" → "继续前往"（LAN IP 上可点）
- Firefox → "高级…" → "接受风险并继续"

之后该 host 的 trust override 写入用户 keychain，wss 会自动可用。

## 与 native UI 的关系

Web UI 视觉与 native 端是 *一致语言* 但不严格 1:1 复刻。视觉风格在 `tailwind.config.ts` 与 `src/components/` 里。

## 11 条不能做（继承自 prompts/B-COMMON.md）

参考 [prompts/B-COMMON.md](../prompts/B-COMMON.md)。重点：
- 不直接连 LAN（必须走 gateway）
- 不绕过 token 鉴权
- 不引入第二个 WebSocket 库
