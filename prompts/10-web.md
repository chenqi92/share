# MeshDrop · Web 端 UI Prompt（浏览器 fallback）

## 端特定任务

实现 MeshDrop 的 **Web 端 fallback**：用户即使没装 native app，浏览器进
`http://<LAN-host-ip>:port` 也能直接收发文件。场景：

- Linux / Chromebook 没有 native client
- 临时同事的笔记本（不想装东西）
- 老电脑跑不动 native app

本轮**只重做前端 UI**，用 mock 数据驱动；服务端的 HTTP/WebSocket gateway 后续
轮接入（mDNS 节点附带的 web server 由 native client 中的一台启动，类似 mac
上 MeshDrop.app 兼任 web gateway）。

## 风格关键

Web 端是 MeshDrop "**无门槛**" 的承诺。设计点：

1. **像一个原生 app，不像一个网页**——大字体 hero + 玻璃面板 + 浏览器 chrome
   保留（这反而强化了"在浏览器里"的认知）
2. **dark by default**——LAN 工具场景多在 dev / 协作场景，浅色显得"轻浮"
3. **大 drop zone**——核心交互是"拖文件进来"，drop zone 占主视区 60%+
4. **明确的"访客身份"提示**——访客身份 · 关页即销毁，给安全感
5. **WebCrypto / WebRTC** 标志要露出来（mono 字段 status bar）

## 技术栈

- TypeScript 5.5+
- React 18+
- Vite 5+
- 单页 SPA（react-router-dom 6+ 或不要 router，单页足够）
- 状态：Zustand 4+ 或 useReducer（不上 Redux）
- 样式：Tailwind CSS 3.4+ + 自定义 token CSS variables（COMMON §5）
- 字体：通过 CSS `@font-face` 引入 OFL Space Grotesk + Geist + Geist Mono
- 拖拽：原生 HTML5 DnD（`dragenter`/`dragover`/`drop`），不上 react-dnd
- WebCrypto：浏览器原生（`crypto.subtle`），本轮 mock 即可
- WebRTC：浏览器原生（`RTCPeerConnection`），本轮 mock 即可
- Vite Plugin PWA（可选）：装在桌面像 native app

## 文件组织

```
web/
├── package.json                # name "meshdrop-web"
├── vite.config.ts
├── tsconfig.json
├── tailwind.config.ts
├── postcss.config.js
├── index.html                  # title "MeshDrop · LAN sharing"
├── public/
│   ├── favicon.svg             # meshdrop mark
│   ├── og-image.png            # 1200×630 social card
│   └── fonts/                  # SpaceGrotesk-*.woff2, Geist-*.woff2
└── src/
    ├── main.tsx
    ├── App.tsx                 # 入口 + provider
    ├── theme/
    │   ├── tokens.css          # ★ COMMON §5 全部 CSS variable (light + dark)
    │   ├── fonts.css           # @font-face Space Grotesk / Geist
    │   └── reset.css
    ├── lib/
    │   ├── mockData.ts         # ★ COMMON §9 TS 化
    │   ├── format.ts           # bytes / ETA / time
    │   └── crypto.ts           # WebCrypto wrapper（mock 实装）
    ├── pages/
    │   ├── MainPage.tsx        # ★ hero band + nearby rail + drop zone + activity
    │   ├── ReceivePage.tsx     # incoming file 弹窗
    │   ├── TransferPage.tsx    # 进行中传输大图（mini chart）
    │   ├── HistoryPage.tsx     # 收发历史
    │   ├── PairingPage.tsx     # 6 字符代码 + QR
    │   └── SettingsPage.tsx    # 显示名 / 自动接受
    ├── components/
    │   ├── BrowserChrome.tsx   # 假浏览器 chrome（演示用，本轮始终显示）
    │   ├── MeshDropLogo.tsx
    │   ├── Avatar.tsx
    │   ├── Chip.tsx
    │   ├── KindGlyph.tsx
    │   ├── FileCard.tsx
    │   ├── DropZone.tsx        # 巨型拖拽区（lime dashed border + drop highlight）
    │   ├── PeerRow.tsx
    │   ├── ProgressBar.tsx
    │   ├── StatusBar.tsx       # 底部 mono "● CONNECTED · WebRTC + WebCrypto · 5 peers · 访客身份"
    │   ├── HeroBand.tsx        # 顶部大字 hero（你的浏览器, 已经是一个 MeshDrop 设备.）
    │   └── AsciiDivider.tsx
    └── hooks/
        ├── useDragDrop.ts
        └── useMockEngine.ts    # mock engine 内存状态
```

## 必做页面（共 6 张 × (light + dark) = 12 张）

1. **MainPage** — hero band + 左侧 280 px nearby rail + 主区 drop zone + 底部
   recent activity 卡片 + 底部 status bar
2. **ReceivePage** — incoming file 全屏覆层（dark overlay + 中央 lime 框 card）
3. **TransferPage** — 进行中传输（mini bar chart 上下行 + transfer rows）
4. **HistoryPage** — 按日分组 grid（参考 macOS HistoryPage 的卡片密度）
5. **PairingPage** — 大字号 6 字符代码 + QR + 完整指纹
6. **SettingsPage** — 显示名 / 默认保存路径 / 自动接受信任 / 网络

## 关键页面布局

### Main Page

```
┌── browser chrome (假) ──────────────────────────────────────────────┐
│ ● ● ● │ 🔒 192.168.1.42 / room / 客厅          │            SAFARI │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ ┌── HERO BAND (lime/flame faint gradient bg) ─────────────────────┐ │
│ │ MeshDrop logo                       [●5 在线][无需安装·No install]│ │
│ │                                                                  │ │
│ │ 你的浏览器,    ← display 44                                      │ │
│ │ 已经是一个 MeshDrop 设备.   ← flame→lime 渐变                       │ │
│ │                                                                  │ │
│ │ Linux / Chromebook / 临时同事的笔记本——任何浏览器进              │ │
│ │ 192.168.1.42,直接收发文件。会话密钥用 WebCrypto · X25519,         │ │
│ │ 关页就销毁。                                                      │ │
│ └──────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│ ┌─ NEARBY 280 ─┐  ┌─ DROP ZONE flex ─────────────────────────────┐ │
│ │ 附近·NEARBY  │  │                                              │ │
│ │ [李莉 row]   │  │   把任何东西                                  │ │
│ │ [坤 lime hl] │  │   拖到这里                                    │ │
│ │ [嘉伟  row]  │  │                                              │ │
│ │ [孟茜  row]  │  │   ⤓ 文件夹也行 · 单文件最大 4 GB             │ │
│ │ [DEV01 row]  │  │                                              │ │
│ │              │  │   [选择文件…][贴文字 / 链接]                  │ │
│ │ ─────        │  │                                              │ │
│ │ ●你叫什么    │  └──────────────────────────────────────────────┘ │
│ │ Visitor·Safari│ ┌─ SESSION ──── 2 件 · 14.6 MB ─────────────────┐│
│ │ 匿名访客.    │  │ [设计稿_v3.fig] [iOS-mocks.zip 67% sending]    ││
│ │ 关浏览器即下线│ └────────────────────────────────────────────────┘│
│ └──────────────┘                                                    │
│                                                                      │
├── status bar 26 ────────────────────────────────────────────────────┤
│ ● CONNECTED · WebRTC + WebCrypto  5 peers     访客身份 · 不保存记录│
└──────────────────────────────────────────────────────────────────────┘
```

### Receive Overlay

```
[底层 main page 被 dark overlay 80% 盖住]
                ┌── lime tint center card 520×420 ──┐
                │ INCOMING · 嘉伟想发给你         │
                │                                  │
                │ [Avatar] 嘉伟                    │
                │ iPad · 9 ms · 已配对 · ● 已验证 │
                │                                  │
                │ ┌── FileCard ──────────────┐     │
                │ │ [PDF] 规划文档_v0.3.pdf  │     │
                │ │ 3.4 MB · 12 页           │     │
                │ └──────────────────────────┘     │
                │ 🏷 "帮我看第 3 节，特别是 §2.3"  │
                │                                  │
                │ [不接收]  [接收 ✓]             │
                └──────────────────────────────────┘
```

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| 拖文件到主窗口 | DropZone 整个高亮 lime + dashed → drop 释放 alert "已添加（mock）" |
| 拖文件到具体 PeerRow | 该 row 高亮 lime → drop 释放 alert "已发送给 [name]（mock）" |
| 点 "选择文件…" | 触发 `<input type="file" />` 文件选择 |
| 点 "贴文字 / 链接" | 弹 modal 含 textarea |
| 收到 incoming（mock 触发） | 弹 ReceivePage overlay |
| 点 PeerRow | 高亮选中 + 主区 drop zone 提示 "拖文件给 [name]" |
| 点 "退出访客" | 清 session + 关 WebSocket（mock） |
| `Ctrl/⌘ + V` | 直接粘贴剪贴板 → 自动发给 selected peer |
| 主题切换 | localStorage `meshdrop-theme = light | dark | system` |

## 编译

```bash
cd web
npm install          # 或 pnpm install
npm run dev          # vite dev server, http://localhost:5173
npm run build        # 输出 web/dist/
npm run preview      # 预览 build 后的产物
```

## 截图清单（PR 必须附 12 张）

```
screenshots/web-{main|receive|transfer|history|pairing|settings}-{light|dark}.png  (12)
```

## 验收 checklist

- [ ] `npm run build` 一次过（0 warning if strict, ≤ 5 if lenient）
- [ ] dev server 启动后浏览器进 http://localhost:5173 可见 MainPage
- [ ] 6 张页面 light + dark 都可切换（localStorage 持久化）
- [ ] DropZone 拖入文件有 lime 高亮反馈
- [ ] 字体真的是 Space Grotesk（Devtools 检查 computed font-family）
- [ ] outgoing 强调用 lime，incoming 用 sky
- [ ] 假浏览器 chrome 保留（不要去掉，是设计的一部分）
- [ ] status bar 底部 mono "● CONNECTED · WebRTC + WebCrypto"
- [ ] 文件 grep 无 "Shar / FreqShare / 至汝 / drop.mesh" 残留（这些是旧名）
- [ ] 12 张截图全附

## 不能做（端特有）

- 不要引大型 UI 库（Ant / MUI / Chakra）— Tailwind + 自写组件够了
- 不要用 default Tailwind 蓝 / 灰 — 全部走 COMMON §5 CSS variables
- 不要用 `prompt()` / `alert()` 弹原生对话框 — 用自己的 modal 组件
- 不要去掉假浏览器 chrome — 它强化"在浏览器里"的认知
- 不要接真实 WebRTC backend（本轮 mock）
- 不要让访客身份持久化（关页就清，是设计的核心承诺）
