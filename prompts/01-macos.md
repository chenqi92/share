# MeshDrop · macOS 端 UI Prompt

## 端特定任务

重做 macOS 桌面 app 的全部 UI。底层（mDNS / 握手 / 文件传输）已经存在于
`apple/Sources/ShareKit/`，**这一轮不动 backend，只重做 UI 层 + 改品牌字符串**。

UI 用 mock 数据（COMMON §9）驱动，让所有页面都能渲染。

## 技术栈

- Swift 5.10 / Swift 6 兼容
- SwiftUI（除 MenuBarExtra / NSOpenPanel 必需的 AppKit 互操作外，不混用）
- macOS 14+；macOS 26 Tahoe 的 `.glassEffect()` 用 `#if compiler(>=6.2)` +
  `if #available(macOS 26, *)` 守卫
- Xcode 26+ SDK
- **XcodeGen** 生成工程（写 `project.yml`，不手写 .xcodeproj）
- 已有依赖：无第三方包（CryptoKit / Network framework 是 system framework）

## 文件组织

```
apple/
├── Sources/MeshDropKit/                    # rename from ShareKit
│   └── ... (保留协议层；本轮只改 service type _meshdrop._tcp + logger subsystem)
└── MeshDropMac/                            # rename from ShareMac
    ├── project.yml                     # bundle id com.welape.meshdrop，PRODUCT_NAME MeshDrop
    ├── Resources/
    │   ├── Info.plist                  # CFBundleDisplayName "MeshDrop"
    │   ├── Assets.xcassets/
    │   │   ├── AppIcon.appiconset/     # 多 size icon（16-1024）
    │   │   └── AccentColor.colorset/   # lime #DDF94B
    │   └── Fonts/                      # 嵌入 OFL Space Grotesk + Geist
    ├── MeshDrop.entitlements
    ├── Sources/
    │   ├── MeshDropMacApp.swift            # @main + Settings scene + MenuBarExtra
    │   ├── shell/
    │   │   ├── AppShell.swift          # 主窗口：sidebar + content + traffic lights 让位
    │   │   ├── Sidebar.swift           # 搜索 ⌘K + Nearby + 剪贴板同步卡片 + "本机"
    │   │   └── StatusBar.swift         # 底部 mono 状态条
    │   ├── pages/
    │   │   ├── DiscoveryPage.swift     # 雷达主屏
    │   │   ├── ChatPage.swift          # 消息流（含 drag overlay + receive popover）
    │   │   ├── TransfersPage.swift     # 速度图 + 任务列表
    │   │   ├── HistoryPage.swift       # 按日分组 grid
    │   │   ├── ClipboardPage.swift     # 剪贴板同步收件箱
    │   │   ├── TrustPage.swift         # 已配对设备表格
    │   │   └── SettingsPage.swift      # 6 组设置
    │   ├── modals/
    │   │   ├── OnboardingWindow.swift  # 4 步首启
    │   │   ├── PairingWindow.swift     # QR + 6 字符代码
    │   │   └── ReceiveCard.swift       # incoming file 浮窗
    │   ├── menubar/
    │   │   └── MenuBarDropdown.swift   # 常驻菜单栏 dropdown，含 drop target
    │   ├── components/
    │   │   ├── MeshDropLogo.swift          # MeshDropMark + MeshDropWordmark + MeshDropLockup
    │   │   ├── Avatar.swift
    │   │   ├── Chip.swift              # 5 tone
    │   │   ├── KindGlyph.swift
    │   │   ├── DeviceCard.swift
    │   │   ├── MsgBubble.swift
    │   │   ├── FileChip.swift
    │   │   ├── TransferRow.swift
    │   │   ├── Radar.swift             # ★ Canvas-based，sweep + pulse + grid 三变体
    │   │   ├── SpeedChart.swift
    │   │   ├── Photo.swift             # 渐变占位
    │   │   ├── IconBtn.swift
    │   │   └── AsciiDivider.swift
    │   ├── mock/
    │   │   └── MockData.swift          # ★ 把 COMMON §9 的 mock 数据全部 Swift 化
    │   └── theme/
    │       ├── MeshDropColor.swift         # COMMON §5 token 全部
    │       └── MeshDropFont.swift          # 字号阶梯 + family
```

## 必做页面（共 12 张，每张 light + dark）

基线 10 张（COMMON §8）+ macOS 特有：

11. **MenuBarExtra dropdown** — 常驻菜单栏，含 drop target ("⤓ DROP HERE")
    + Nearby 列表 + 6 项底部操作（快速发送 ⌥⇧S / 剪贴板历史 ⌥⇧V / 配对新设备
    ⌥⇧P / 打开 MeshDrop ⌥⇧O / 设置 ⌘, / 退出 ⌘Q）

12. **拖文件 drop overlay** — Chat 页里拖入文件时整个内容区变 lime 半透明 +
    黑色虚线边框 + 大字 "放手即发 · Drop to send · 3 个文件 · 78.2 MB → 孟茜"

> 12 张 × (light + dark) = **24 张截图**

## 关键页面布局速描

### Discovery 主屏

```
┌─ MeshDrop (traffic lights 让位) ─────────────────────────────────┐
│  搜索 ⌘K                                                     │
│                                                              │
│  ● 附近 · Nearby                            5                │
│  ─────────────────────                                       │
│  [DeviceCard × 5]   ← sidebar 列表                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  附近 5 台设备 · Nearby            [E2E·X25519][LAN]│   │
│  │  扫描中 · scanning LAN · 192.168.1.0/24 · mDNS+uTP  │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  ┌─ ONLINE · 5  │                           │  │   │
│  │  │  ┌─ BUSY · 0    │   ╭───── RADAR ─────╮     │  │   │
│  │  │  ┌─ OFFLINE · 2 │   │      sweep arm  │     │  │   │
│  │  │                  │   │  •  YOU       • │     │  │   │
│  │  │                  │   ╰─────────────────╯     │  │   │
│  │  │                  │  ⤓ 拖任何文件到设备头像即可发送 │
│  │  │                  └──────────────────────────────┘  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  剪贴板已同步 [⌘V]                       ← sidebar 下方       │
│  "https://internal.acme.io/specs/sa..."                      │
│  from 嘉伟 · iPad · 8s ago                                   │
│                                                              │
│  [我 Avatar] This MacBook · 我          ← sidebar 最下       │
│              可见 · Visible · LAN                            │
└──────────────────────────────────────────────────────────────┘
```

### Chat 页

```
┌─ Sidebar 同上 ─┬─ Chat header ─────────────────────────────┐
│                │ [Avatar] 孟茜 · Meng Xi · iPhone           │
│                │ iOS · ●ONLINE · 14ms · E2E · 192.168.1.78 │
│                │                       [已配对 · Paired][⋯]│
│                ├───────────────────────────────────────────┤
│                │  Today · 14:08                            │
│                │  [in bubble] 下午发的那版改完了吗？       │
│                │  [out bubble] 改完了，整理一下发你 👇    │
│                │  [out file bubble] 设计稿_v3.fig 14.2MB  │
│                │  [in bubble] 收到，我看看~                │
│                │  [in image bubble] [Photo][Photo]         │
│                │                                            │
│                │  ┌─ incoming file confirm (浮窗) ──────┐ │
│                │  │ ↓ 来自 孟茜 的传输                    │ │
│                │  │ [FileChip iOS-mocks-final.zip 48.6MB]│ │
│                │  │ [拒绝 Reject][接收 Accept · ⏎]      │ │
│                │  └─────────────────────────────────────┘ │
│                ├───────────────────────────────────────────┤
│                │ [📎][🖼] 那我去过一遍标注… [▶ send]      │
└─────────────────────────────────────────────────────────────┘
```

### Transfers 页

```
传输 · Transfers              [全部][进行中 · 2][已完成][失败]
6 个任务 · 2 进行中 · 1 排队 · 3 已完成 · 上行 11.5 MB/s · 下行 11.7 MB/s
────────────────────────────────────────────────────────────────
[SpeedChart 上行 ↑ flame] [SpeedChart 下行 ↓ sky]     2.41 GB
                                                       本会话总计
────────────────────────────────────────────────────────────────
[TransferRow × 6]   ← 含进度条、speed、ETA、状态色
```

更多页面布局参考 COMMON 中提到的 `__DESIGN_MESHDROP_PATH__screens-mac.jsx`（用户本地有源稿，
你看不到也没关系——按本 prompt 的描述实装即可）。

## 关键交互

| 触发 | 行为（mock 即可） |
| --- | --- |
| 点 sidebar device row | 主区域切换到 ChatPage（mock 显示该 device 的对话） |
| 拖文件到 Chat 内容区 | 整页 lime 半透明 + 虚线边框 + 大字提示；放下 alert "已发送（mock）" |
| Settings 改 displayName | 即时反映到 sidebar 底部"我"卡片 |
| Trust 表格点"撤销" | 弹 NSAlert 确认（mock 行为，不真改 store） |
| ⌥⇧S | 唤起 MenuBarExtra dropdown |
| ⌘K | sidebar 搜索框聚焦 |
| ⌘, | 打开 Settings |
| 右键 history 项 | contextMenu: 复制 / 在 Finder 中显示 / 删除 / 转发（mock） |

## 编译

```bash
cd apple/MeshDropMac
xcodegen generate
xcodebuild -project MeshDropMac.xcodeproj -scheme MeshDropMac -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

## 截图清单（PR 必须附 24 张）

文件名规范：`screenshots/macos-<page>-<theme>.png`

| page (12) | light | dark |
| --- | --- | --- |
| discovery | ✅ | ✅ |
| chat | ✅ | ✅ |
| transfers | ✅ | ✅ |
| history | ✅ | ✅ |
| clipboard | ✅ | ✅ |
| trust | ✅ | ✅ |
| settings | ✅ | ✅ |
| pairing | ✅ | ✅ |
| onboarding | ✅ | ✅ |
| receive | ✅ | ✅ |
| menubar | ✅ | ✅ |
| dragdrop | ✅ | ✅ |

## 验收 checklist

- [ ] `xcodebuild build` 一次过（0 error，warning ≤ 5）
- [ ] dock 显示 MeshDrop logo（lime dot 可见）
- [ ] 全 grep 仓库无 "MeshDrop / 至汝 / drop.mesh / __FREQ_MESHDROPE__" 残留
- [ ] 字体真的是 Space Grotesk（在 Settings → 关于 看出）
- [ ] outgoing 气泡 dark 模式用 **lime** 黄绿底（不是黑）
- [ ] Radar sweep arm 在转（实测 4.5s 一圈）
- [ ] ASCII Divider 在分节处出现
- [ ] 24 张截图全部附 PR

## 不能做（端特有补充）

- 不要用 `NavigationSplitView` — macOS 用自定义 sidebar + content（让位 traffic lights）
- 不要用 `NSWindow` 写主窗口 — SwiftUI Scene only（MenuBarExtra 除外）
- 主窗口拖文件 overlay 必须**整内容区**变 lime drop zone，不是单个 row
- 不要接 MeshDropEngine.shared.sendText / sendFile（本轮 mock 即可）
