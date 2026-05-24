# MeshDrop · 手表端 UI Prompt（Apple Watch + Wear OS）

## 端特定任务

重做手表端 MeshDrop：**Apple Watch（方形屏 49mm）+ Wear OS（圆屏 Pixel Watch）**
两个子端共享一套设计语言但布局适配各自屏形。手表上 MeshDrop 的核心场景是
"**手腕一抬，确认接收**"+"**快速选人快速发**"——不是完整对话或文件管理。
本轮只重做 UI 用 mock 数据驱动，不接 backend。

## 风格关键

手表 3 大约束：

1. **屏幕极小**——所有字 ≥ 12 pt（mono 可到 10），关键 CTA ≥ 16
2. **离手机最近**——大多数操作其实是 "在手表上点一下，行为发生在手机里"
3. **表冠 / 旋钮**是主导航——上下滑都是上下选择，不是 swipe page

色彩复用 COMMON §5（lime / flame / sky / ink），但**底色一律黑**（OLED 省电）。

## 技术栈

### Apple Watch
- Swift 5.10 / Swift 6 兼容
- SwiftUI（watchOS 10+ API）
- watchOS 10+；haptics 用 `WKInterfaceDevice.current().play(.success)`
- 复用 MeshDropKit SPM 模块（apple/Sources/MeshDropKit/）
- 配对模型：作为 iPhone companion app（不能独立装）
- XcodeGen 生成工程

### Wear OS
- Kotlin 2.1+
- Jetpack Compose for Wear OS 1.4+
- `androidx.wear.compose:compose-material3:1.4+`
- minSdk 30, targetSdk 35
- Wear OS 4+
- 蓝牙桥接 phone app（companion）
- Hilt / coroutines

## 文件组织

### Apple Watch

```
apple/MeshDropWatch/
├── project.yml                # bundle id com.welape.meshdrop.watch
├── Resources/
│   ├── Info.plist             # WKWatchKitApp = true
│   ├── Assets.xcassets/       # AppIcon (watch sizes) + AccentColor
│   └── Fonts/                 # Space Grotesk + Geist (OFL)
├── Sources/
│   ├── MeshDropWatchApp.swift # @main
│   ├── pages/
│   │   ├── NearbyPage.swift   # 4 设备列表 (digital crown 选)
│   │   ├── ReceivePage.swift  # incoming file 接收
│   │   ├── TransferPage.swift # 进行中传输 mini view
│   │   └── ComplicationView.swift # ★ Complication "● 5 LIVE"
│   ├── components/
│   │   ├── Avatar.swift
│   │   ├── FileChip.swift     # mini 版
│   │   └── MeshDropLogo.swift
│   ├── mock/
│   │   └── MockData.swift
│   └── theme/
│       └── MeshDropColor.swift
```

### Wear OS

```
wearos/                                # 顶层独立目录（不和 android/ 共用工程）
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/libs.versions.toml
└── app/
    ├── build.gradle.kts            # applicationId com.welape.meshdrop.wear
    └── src/main/
        ├── AndroidManifest.xml
        ├── res/
        │   ├── values/strings.xml         # "MeshDrop"
        │   ├── drawable/                  # round adaptive icon
        │   └── font/                      # space_grotesk.ttf, geist.ttf
        └── java/com/welape/meshdrop/wear/
            ├── MeshDropWearApp.kt
            ├── MainActivity.kt
            ├── ui/
            │   ├── NearbyScreen.kt    # 圆形雷达 + 5 设备绕一圈
            │   ├── ReceiveScreen.kt
            │   ├── TransferTile.kt
            │   └── theme/
            │       ├── MeshDropColor.kt
            │       └── Type.kt
            └── mock/MockData.kt
```

## 必做页面

### Apple Watch（共 3 张 × dark only = 3 张）

1. **NearbyScreen** — 顶部 `● LIVE · 5` + "附近" 大字 + "转动表冠选人" mono 提示 +
   4 个设备 row（focus 项 lime 实底）+ 底部 "↑ 点击发送 · 长按多选"
2. **ReceiveScreen** — "来自 · FROM" + 大 Avatar（ring）+ 发送者名 + FileChip mini +
   双 CTA "×" + "接收 ✓" + 提示 "⌃ 双击侧键也行"
3. **ComplicationView** — 1 张表盘 corner / circular complication 截图："● 5 LIVE"

### Wear OS（共 2 张 × dark only = 2 张）

1. **NearbyScreen** — 圆屏！中心数字 `5` + `NEARBY` mono；5 个设备 avatar 沿一圈
   摆放（focus 项 lime ring 高亮）；底部 "转表冠选 · 按发"；顶部 MeshDrop logo
2. **ReceiveScreen** — 圆屏：上半发送者 + 中部 FileChip + 下半双 CTA（× / ✓）

## 关键页面布局

### Apple Watch · Nearby

```
┌── 49mm 方屏 440×540（OLED 黑底）──┐
│        ● LIVE · 5    ← mono 18 lime  │
│                                       │
│ 附近   ← display 30 white            │
│ 转动表冠选人  ← mono 13 muted        │
│                                       │
│ [lime 实底 row]                       │
│ [AVA] 李莉                            │
│       macOS · 18ms                    │
│ ──                                    │
│ [AVA] 坤  · Win · 32ms     [row]      │
│ [AVA] 嘉伟 · iPad · 14ms   [row]      │
│ [AVA] 孟茜 · iOS · 26ms    [row]      │
│                                       │
│ ↑ 点击发送 · 长按多选 ← mono 11      │
└───────────────────────────────────────┘
```

### Wear OS · Nearby（圆屏 460×460）

```
        ┌─ MeshDrop logo (小) ─┐
        │                       │
   ●          ●                  ← 5 个 avatar 绕中心
        ╭───────────────╮        放一圈，focus 项
   ●    │      5         │  ●     lime ring 高亮
        │   NEARBY       │
        ╰───────────────╯
              ●
        转表冠选 · 按发  ← mono bottom hint
        ┌── faint pulse Radar ──┐
        │   (variant pulse)     │ ← 背景同心圆弱
        └────────────────────────┘
```

### Apple Watch · Receive

```
┌── 49mm 方屏 440×540 ──┐
│                        │
│ 来自 · FROM            │  ← mono 12 lime
│                        │
│   [Avatar 56 ring lime]│
│   李莉                  │  ← display 22
│                        │
│ ┌─ FileChip mini ─────┐│
│ │ [PDF] 规划文档_v0.3 ││
│ │       3.4 MB        ││
│ └─────────────────────┘│
│                        │
│ [×]  [接收 ✓ lime]    │  ← 圆形 52×52 + flex 52
│                        │
│ ⌃ 双击侧键也行         │  ← mono 10 dim
└────────────────────────┘
```

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| 表冠 ↑↓ | 设备列表上下选择（focus 项 lime） |
| 点击 row | 进 send mode（mock: alert "已选 李莉"） |
| 长按 row | 进多选状态（多余设备打 ✓ 角标） |
| ◉ 点击 "接收 ✓" | mock 接收完成 + haptic .success |
| 双击侧键（Apple Watch） | 同 "接收 ✓" |
| Force Touch / 长按屏（Wear OS） | "信任 / 拒绝" 二选一 |
| 抬腕（mock） | 自动亮屏并跳到 NearbyScreen |

## 编译

### Apple Watch

```bash
cd apple/MeshDropWatch
xcodegen generate
xcodebuild -project MeshDropWatch.xcodeproj -scheme MeshDropWatch -configuration Debug \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

### Wear OS

```bash
cd wearos
gradle wrapper --gradle-version 8.11   # 首次
./gradlew :app:assembleDebug
./gradlew :app:installDebug
```

## 截图清单（PR 必须附 5 张）

```
screenshots/applewatch-{nearby|receive|complication}-dark.png  (3)
screenshots/wearos-{nearby|receive}-dark.png  (2)
```

外加 2 段 8-10s mp4（Apple Watch + Wear OS 各一），演示转表冠 / 接收 haptic。

## 验收 checklist

- [ ] Apple Watch `xcodebuild build` 一次过（watchOS Simulator）
- [ ] Wear OS `./gradlew :app:assembleDebug` 一次过
- [ ] 字号最小 ≥ 10（mono），关键 CTA 字号 ≥ 16
- [ ] 所有按钮可点击高度 ≥ 44 pt（Apple HIG 兼容 watchOS）
- [ ] OLED 黑底（不要 paper 浅色）
- [ ] Apple Watch complication 显示 "● 5 LIVE"（lime dot）
- [ ] Wear OS 圆形 chrome 设备绕中心一圈（不要做成长方形列表）
- [ ] 接收成功有 haptic（mock：WKInterfaceDevice.current().play(.success)）
- [ ] 文件 grep 无 "Shar / FreqShare / 至汝 / drop.mesh" 残留（这些是旧名）
- [ ] 5 张截图 + 2 段 mp4 全附

## 不能做（端特有）

- 不要做完整对话页 — 手表上没空间，对话操作回手机
- 不要做完整传输管理 — 进行中传输只显 1 条 mini
- 不要在 Compose for Wear OS 用普通 Material3 组件 — 必须用 wear.compose.material3
- 不要用 swipe-to-page 水平翻 — 与 Wear OS 系统水平 swipe 冲突
- 不要假定用户能看清 10 pt 以下字 — 严格 ≥ 10
- 不要在 ViewModel 调真实 MeshDropEngine（本轮 mock）
