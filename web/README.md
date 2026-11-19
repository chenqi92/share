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

从本机 `http://localhost:5173` 打开开发或预览页面，在配对页输入局域网网关地址（例如 `https://192.168.1.20:7384`）并保存，再输入主机显示的配对码。
网关地址必须使用 HTTPS。跨源手动配置支持 localhost、回环地址、IPv4 私有地址和 IPv6 ULA。浏览器按网关源分别保存会话。
截图或演示可以显式使用 `?mock=1`。

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

`src/lib/engine.ts` 里 `detectGateway()` 的顺序：

1. 使用通过相同地址校验的已保存配置。
2. 内置页面默认连接当前源。本机 Vite 开发和预览页面等待手动配置。
3. 页面链接中的 `?gw` 参数不参与选择网关。

API 与 gateway 之间走（按 `companion-bridges.md §4.3`）：

| 端点 | 说明 |
| --- | --- |
| `POST /api/v1/pair` | 6 字符配对码 → 24h session token + Set-Cookie |
| `WSS /api/v1/control` | 双向命令 / 事件通道 |
| `POST /api/v1/upload` | multipart 上传 → `{token:"<path>"}` 作为 `send_file_ref.fileRef` |
| `GET /api/v1/download/<historyId>` | 流式下载已接收文件 |

同源使用 Secure、HttpOnly 会话 cookie。手动配置的本机开发页通过 `x-meshdrop-token` 认证上传和下载，WebSocket 握手通过子协议传递会话。

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
