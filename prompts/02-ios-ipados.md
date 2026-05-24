# MeshDrop · iOS + iPadOS Universal 端 UI Prompt

## 端特定任务

重做 iOS / iPadOS app 的全部 UI（**单一 universal target**，按
`horizontalSizeClass` 分支：phone 用 TabView，iPad 横屏用 NavigationSplitView）。
保留 MeshDropKit 协议层（与 macOS 共享 SPM package）。本轮**只做 UI，用 mock 数据
驱动**，不接 backend。

iOS 26 必须启用 **Liquid Glass**（`.glassEffect()`），iOS 17~25 回退
`.ultraThinMaterial`。

## 技术栈

- iOS 17.0+，iPadOS 17.0+
- Swift 5.10 / Swift 6
- SwiftUI（关键：`@Environment(\.horizontalSizeClass)` 分支）
- iOS 26 Liquid Glass：`#if compiler(>=6.2)` + `if #available(iOS 26, *)`
- 文件选择：`fileImporter` + `PhotosPicker`
- Share Extension：独立 target，拦截系统 share sheet

## 文件组织

```
apple/
├── Sources/MeshDropKit/                # 共享，参见 macOS prompt
└── MeshDropApple/                      # rename from ShareiOS, target 名 MeshDrop
    ├── project.yml                 # iOS 17+，TARGETED_DEVICE_FAMILY "1,2"
    │                               # bundle id com.welape.meshdrop，CFBundleDisplayName "MeshDrop"
    ├── Resources/
    │   ├── Info.plist              # NSLocalNetworkUsageDescription / NSBonjourServices _meshdrop._tcp
    │   ├── Assets.xcassets/AppIcon.appiconset/   # 1024 + iOS 18+ tinted 变体
    │   └── Fonts/                  # Space Grotesk + Geist TTF
    ├── Sources/
    │   ├── MeshDropApp.swift           # @main
    │   ├── RootView.swift          # 按 hSizeClass 分发 PhoneRoot / PadRoot
    │   ├── PhoneRoot.swift         # TabView 4 tab
    │   ├── PadRoot.swift           # NavigationSplitView 横屏
    │   ├── tabs/
    │   │   ├── DiscoverTab.swift   # 大字号 hero + Radar + 设备 list
    │   │   ├── ChatTab.swift       # 对话列表 → push ChatDetail
    │   │   ├── ChatDetail.swift    # MsgBubble + composer + 快捷操作 strip
    │   │   ├── TransferTab.swift   # summary card + 进行中 + 已完成
    │   │   └── MeTab.swift         # 本机卡片 + Settings 入口
    │   ├── sheets/
    │   │   ├── SendSheet.swift     # detents [.medium, .large] 文本/文件 segment
    │   │   ├── PairingSheet.swift  # 大字号 QX·8K7·L2M 代码
    │   │   ├── FileOfferSheet.swift # incoming + 可选"文字便签"显示
    │   │   ├── OnboardingSheet.swift # 3 步
    │   │   └── SettingsScreen.swift
    │   ├── components/
    │   │   ├── MeshDropLogo.swift / Avatar.swift / Chip.swift / KindGlyph.swift
    │   │   ├── MsgBubble.swift / FileChip.swift / TransferRow.swift
    │   │   ├── DeviceCard.swift / Radar.swift / Photo.swift
    │   │   ├── AsciiDivider.swift
    │   │   └── LiquidGlass.swift   # iOS 26 .glassEffect 修饰符 + fallback
    │   ├── mock/MockData.swift     # COMMON §9 Swift 化
    │   └── theme/MeshDropColor.swift / MeshDropFont.swift
    └── MeshDropExt/                    # ★ Share Extension target
        ├── ShareViewController.swift
        └── Info.plist
```

## 必做页面（共 14 张 × (light + dark) = 28 张）

基线 10 张（COMMON §8）+ iOS 特有：

11. **底部 TabBar**（iPhone）：附近 / 聊天 / 传输 / 我（4 tab，Liquid Glass）
12. **横屏 NavigationSplitView**（iPad）：左 Discover/Devices，右 ChatDetail
13. **Share Extension**：系统 share sheet 拦截显示"通过 MESHDROP 发送 · LAN" +
    横向滚动设备 card grid + extras（文字便签 / E2E / 过期）
14. **Live Activity + Dynamic Island compact**：传输中显示 "传输中 · 84% ·
    剩 1s"

iPad 必须做 5 张（split / chat / transfer / history / settings），iPhone 必须做
9 张基线 + share ext + live activity。

> 共：iPhone 9 × 2 (亮暗) + iPad 5 × 2 + Share Ext × 2 + Live Activity × 2 = **32 张**

## 关键页面布局

### iPhone Discover Tab（IOSRadarScreen 还原）

```
┌─ iPhone 14 Pro mockup ────────────┐
│   meshdrop.  [● LIVE][⋯]              │  ← nav
│                                    │
│   附近 5 台                        │  ← hero 大字（display 32）
│   Nearby devices.    ← flame 色   │
│   scanning · 192.168.1.0/24 · LAN  │  ← mono 11
│                                    │
│   ┌─────────────────────────────┐  │
│   │      Radar 310×310 sweep    │  │
│   │     • YOU •     halo pulse  │  │
│   └─────────────────────────────┘  │
│                                    │
│   [Avatar 李莉] LL · macOS 18ms   │  ← 3 个 row
│   [Avatar 坤  ] K  · Pixel 32ms   │
│   [Avatar 嘉伟] JW · iPad  14ms   │
│                                    │
│  附近 | 消息(2) | 传输 | 我       │  ← TabBar Liquid Glass
└────────────────────────────────────┘
```

### iPad 横屏 SplitView (IPadSplitScreen)

```
┌────────────────────────────────────────────────────────────┐
│ 14:08 · ACME-LAN · 92%                          (statusbar)│
├──────────────────────┬─────────────────────────────────────┤
│ meshdrop.       ● LIVE 5 │ [Avatar 孟茜] 孟茜              [⋯]│
│                      │ iOS · ●ONLINE · 14ms · E2E         │
│   Radar 360×360      ├─────────────────────────────────────┤
│                      │ Today · 14:08                       │
│ ────────────────     │ [out] 嘉伟说图改完了，我转给你看下 │
│ [DeviceCard × 5]     │ [out file] 规划文档_v0.3.pages    │
│ DeviceCard selected: │ [in] 收到，下午开会前给反馈～     │
│ "孟茜"               │ [in image grid] [Photo×3]          │
│                      │ [in] 这几张供参考                  │
│                      │ ▸▸▸ 孟茜 正在输入…                │
│                      ├─────────────────────────────────────┤
│                      │ [📎][🖼] iMessage 想说点什么…  [↑]│
└──────────────────────┴─────────────────────────────────────┘
```

### Share Sheet 拦截 (IOSShareSheet)

```
（系统 Photos 选了 3 张照片 → 调系统 share → 选 MeshDrop）

┌─ 选了 3 张照片 (12.4 MB) ─┐
│ [📷][📷][📷]               │
├───────────────────────────┤
│ 通过 MESHDROP 发送 · LAN       │
│ ─── horizontal scroll ───  │
│ [李莉•][坤  ][嘉伟][孟茜] │  ← 设备卡片，第一个选中 lime 描边
├───────────────────────────┤
│ 🏷 加文字便签   随手记一句  │
│ 🔒 端对端加密   默认开启   │
│ ⏱ 过期时间    24 小时     │
├───────────────────────────┤
│ → 发送给 李莉              │  ← 大 lime 按钮
└───────────────────────────┘
```

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| 点设备 row | push ChatDetail（mock 该 device 的对话） |
| 长按设备 row | contextMenu：发送…/查看资料/静音/取消信任 |
| Composer 📎 / 🖼 | 弹 PHPicker / fileImporter，选完弹"已选 N 个文件（mock）" |
| 收 file offer（mock 触发） | 弹 FileOfferSheet（detent .medium） |
| 拖照片到 ChatDetail（iPad Stage Manager） | lime drop overlay |
| 系统 Share Sheet → MeshDrop | 跳 ShareExtension |
| Live Activity（mock 计时器） | 锁屏显示进度条 |

## 编译

```bash
cd apple/MeshDropApple
xcodegen generate

# Sim
xcodebuild -project MeshDropApple.xcodeproj -scheme MeshDrop \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build

# 真机（需 Xcode 已登录 Apple ID）
xcodebuild ... -destination 'platform=iOS,id=<UDID>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> <APP_PATH>
```

## 截图清单（PR 必须附 32 张）

```
screenshots/ios-phone-{discovery|chat|transfers|history|settings|trust|pairing|onboarding|receive}-{light|dark}.png  (18)
screenshots/ios-pad-{split|chat|transfers|history|settings}-{light|dark}.png   (10)
screenshots/ios-share-ext-{light|dark}.png  (2)
screenshots/ios-live-activity-{lock|island}.png  (2)
```

## 验收 checklist

- [ ] Sim 与真机都 build 通过
- [ ] iPad 横屏 split 正确，竖屏自动 collapse 到 TabBar
- [ ] iOS 26 设备上 `.glassEffect` 真的看得出（TabBar / SelfCard）
- [ ] iOS 17 上自动退化到 `.ultraThinMaterial`
- [ ] Share Extension 在 Photos / Safari share sheet 中显示 MeshDrop
- [ ] Lock Screen Live Activity 显示传输进度
- [ ] Dynamic Island compact 显示 "传输中 · 84%"
- [ ] outgoing 气泡 dark 模式用 lime 底
- [ ] 32 张截图全部附 PR

## 不能做（端特有）

- 不要用蓝色（iMessage 蓝是 Apple 的）作为任何 accent
- 不要把 TabBar 写在 Sheet 里
- iPad 不要用 `NavigationStack` 顶替 SplitView（split 是 iPad 用法）
- 不要让 Share Extension 直接调 ShareKit（独立进程，本轮 mock 即可）
