# MeshDrop · tvOS 端 UI Prompt（Apple TV）

## 端特定任务

重做 Apple TV 上的 MeshDrop。客厅的电视作为家庭共享落点——朋友/家人把手机里
的照片、视频、文档"扔"到这块屏上播放或保存。**遥控器优先**（Siri Remote），
键鼠 / 触摸不要假定。本轮只重做 UI 用 mock 数据驱动，不接 backend。

## 风格关键

tvOS 的设计点：**巨大字号 + 巨大焦点态**。遥控器只有上下左右 + 选择 + 菜单，
所以每一个可聚焦元素必须：

1. 视觉上**明确可聚焦**（边框 / 投影 / 缩放）
2. 焦点态变化要**可感知**（`scale(1.05)` + `0 0 0 6px rgba(255,255,255,.18)` ring）
3. 安全区 90 px（左右）/ 50 px（上下）— **绝不**让内容贴边
4. 默认 dark + 大背景（radial-gradient 模拟客厅环境光）

不要用 Fluent / Material / iOS 风格的小按钮 / 小列表 — tvOS 是 3 米外看的屏。

## 技术栈

- Swift 5.10 / Swift 6 兼容
- SwiftUI（**主体**）+ 必要时 UIKit focus 桥接
- tvOS 17+；tvOS 18 焦点 effect 用 `.focusable() + .hoverEffect()`
- Xcode 16+ SDK
- XcodeGen 生成工程（写 `project.yml`）
- 复用 MeshDropKit（apple/Sources/MeshDropKit/）作为 SPM 依赖

## 文件组织

```
apple/MeshDropTV/
├── project.yml                # bundle id com.welape.meshdrop.tv，PRODUCT_NAME MeshDropTV
├── Resources/
│   ├── Info.plist             # CFBundleDisplayName "MeshDrop"
│   ├── Assets.xcassets/
│   │   ├── App Icon & Top Shelf Image.brandassets/  # tvOS 多层 icon
│   │   ├── AccentColor.colorset/    # lime #DDF94B
│   │   └── LaunchImage.imageset/
│   └── Fonts/                 # Space Grotesk + Geist (OFL)
├── Sources/
│   ├── MeshDropTVApp.swift       # @main + Scene
│   ├── shell/
│   │   ├── TVRoot.swift       # TabView (顶部 TV-style)
│   │   └── TVTopBar.swift     # logo + tabs + status line
│   ├── pages/
│   │   ├── ReceivePage.swift  # 大幅照片 + 接收 CTA
│   │   ├── NearbyPage.swift   # 大雷达 + QR 配对码
│   │   ├── GalleryPage.swift  # 已收件 grid
│   │   └── SettingsPage.swift # 显示名 / 自动接受信任 / 保存路径
│   ├── components/
│   │   ├── MeshDropLogo.swift    # 复用 macOS 版即可
│   │   ├── Avatar.swift
│   │   ├── Chip.swift
│   │   ├── Photo.swift
│   │   ├── QRCode.swift       # Vision/CoreImage CIQRCodeGenerator
│   │   ├── Radar.swift        # ★ Canvas-based，sweep 变体，720 pt 巨型
│   │   ├── RemoteHint.swift   # 底部按键提示条
│   │   └── FocusCard.swift    # 标准可聚焦卡（带 scale + ring）
│   ├── mock/
│   │   └── MockData.swift     # ★ COMMON §9 Swift 化
│   └── theme/
│       ├── MeshDropColor.swift
│       └── MeshDropFont.swift     # 巨型字阶（display 56 / 36 / 22）
```

## 必做页面（共 5 张 × dark only = 5 张，tvOS 没有真正 light）

> tvOS 客户端**只有 dark 主题**（电视环境多为夜间客厅）。

1. **NearbyScreen** — 巨型雷达 + 右侧大字 hero "这台电视 / 谁都能 ping" +
   QR 二维码 + 6 字符代码 `LR · 4K7M` + 附近 5 台设备 avatar row
2. **ReceiveScreen** — 全屏照片 hero（1/18 张）+ 缩略图条 + 右侧发送者卡片 +
   超大 lime CTA "接收并播放" + 次要 "仅保存" / "不接收"
3. **GalleryScreen** — 收件箱大字标题 "收件箱 · 124 件 · 14.2 GB" + 5×2 tile grid，
   聚焦 tile 放大 + 白色边框 ring
4. **PairingScreen** — 大字号 6 字符代码 `LR · 4K7M` block 字符 + QR + 完整指纹
5. **SettingsScreen** — 大字 settings：显示名 / 默认保存路径 / 自动接受信任 / 网络

## 关键页面布局

### Nearby Screen

```
┌─ 1920 × 1080 ────────────────────────────────────────────────────────┐
│                    safe area 50                                       │
│ ┌─ MeshDrop logo │ 接收 · 相册 · 设置 · [附近 selected]   ● 客厅·5 台│
│ │                                                                    │
│ │   ╭───────────────╮     READY · 待机                              │
│ │   │   RADAR 720   │     这台电视                                  │
│ │   │   sweep arm   │     谁都能 ping.    ← flame→lime 渐变         │
│ │   │   pulse blip  │     ─────                                    │
│ │   ╰───────────────╯     在你手机上打开 MeshDrop，选 Living Room TV │
│ │                          照片、视频、文档都可以推到这块屏上。      │
│ │                                                                    │
│ │   SCANNING · 客厅 LAN    ┌─────────┐ SCAN 或 输入代码             │
│ │                          │   QR    │ LR · 4K7M ← mono 36 letter   │
│ │                          └─────────┘ 无 App? 浏览器进 192.168.1.42│
│ │                                                                    │
│ │                          附近 5 台 · 客厅可见                      │
│ │                          [AVA][AVA][AVA][AVA][AVA]                │
│ │                                                                    │
│ │                    safe area 50                                    │
│ └────────────────────────────────────────────────────────────────────┘
```

### Receive Screen

```
[接收 selected] · 相册 · 设置 · 附近                          ● 客厅·5 台
─────────────────────────────────────────────────────────────────────────

┌─────────────────── 巨型照片 hero 3:2 ─────────────────┐ │ 来自 · FROM
│                                                       │ │ [Avatar 84]
│                  Photo h="100%"                       │ │ 孟茜
│                                                       │ │ Meng Xi
│                                                       │ │
│        [1 / 18 · HEIC]  ← 左上 corner counter         │ │ ┌─ file ──┐
└───────────────────────────────────────────────────────┘ │ │ [HEIC]  │
                                                          │ │ 团建相册│
[T1][T2 ✓lime ring][T3][T4][T5][T6][T7][T8][+10]          │ │ 18 张   │
                                                          │ │ 128 MB  │
                                                          │ │ ● E2E   │
                                                          │ │ 9ms LAN │
                                                          │ └─────────┘
                                                          │
                                                          │ ┌─ CTA ────────┐
                                                          │ │ [OK] 接收并播│
                                                          │ │      按⏵幻灯片│
                                                          │ └──────────────┘
                                                          │ [仅保存][不接收]

─────────────────────────────────────────────────────────────────────────
   [◀▶ 切换缩略图]  [◉ 接收]  [▶︎ 播放幻灯片]  [TV/⌂ 返回]
   ↑ bottom 浮窗 remote hint
```

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| 遥控器 ↑↓←→ | 在可聚焦元素间移动焦点 |
| ◉ Select | 触发当前焦点动作（接收 / 选缩略图 / 进 settings） |
| ▶︎ Play/Pause | Receive 页：直接进入幻灯片播放 mock |
| TV / 菜单键 | 回上一层（Tab 间不回） |
| Siri Remote 滑动 | 缩略图条快速跳跃 |
| 长按 Select | （Gallery）弹出 "删除 / 信息 / 转发" 上下文菜单 |

## 编译

```bash
cd apple/MeshDropTV
xcodegen generate
xcodebuild -project MeshDropTV.xcodeproj -scheme MeshDropTV -configuration Debug \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

## 截图清单（PR 必须附 5 张）

```
screenshots/tvos-{nearby|receive|gallery|pairing|settings}-dark.png  (5)
```

外加 1 段 10-15s asciinema/mp4 cast 模拟遥控器导航：进 nearby → 切到 receive →
聚焦在大 CTA → 模拟接收完成 → 进 gallery 浏览。

## 验收 checklist

- [ ] `xcodebuild -destination 'platform=tvOS Simulator...' build` 一次过
- [ ] 焦点态明确（scale + ring），3 米外可辨
- [ ] 所有字号 ≥ 18 pt（远距阅读）
- [ ] 安全区严格 90/50（没有内容贴边）
- [ ] 巨型 hero 字号 ≥ 44 pt
- [ ] 没有出现"小按钮 / 紧凑列表"风格
- [ ] outgoing 元素绝对不用（tvOS 只接收，不发送）
- [ ] 文件 grep 无 "Shar / FreqShare / 至汝 / drop.mesh" 残留（这些是旧名）
- [ ] 5 张截图 + 1 段 cast 全附

## 不能做（端特有）

- 不要假定用户能"快速点击"——所有 CTA 都要"可看见焦点"
- 不要做 keyboard / mouse 交互态（tvOS 不该 focus on text input 多于必要）
- tvOS 客户端**不发送**文件，只接收 / 浏览（发送由手机端发起）
- 不要在 Composable 里调真实 MeshDropEngine（本轮 mock）
- 不要用 NavigationStack 多层钻进（tvOS 偏好 Tab + Detail 平铺）
