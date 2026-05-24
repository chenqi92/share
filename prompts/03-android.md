# MeshDrop · Android 端 UI Prompt（Phone + Tablet）

## 端特定任务

重做 Android app（**单一 APK，phone + tablet 共用**，按 Compose
`WindowSizeClass` 分支）。保留现有 protocol/transport 层，**本轮只重做 UI，
用 mock 数据驱动**，不接 backend。

## 技术栈

- Kotlin 2.1+
- Compose Material 3 1.3+（**关闭 dynamicColor**，MeshDrop 有自己的色板）
- AGP 8.7+，minSdk 26，targetSdk 35
- 字体：把 OFL Space Grotesk / Geist / Geist Mono TTF 放 `res/font/`，Compose
  `FontFamily(Font(R.font.space_grotesk))`

## 文件组织

```
android/
├── settings.gradle.kts             # rootProject.name = "MeshDrop"
├── build.gradle.kts
├── gradle/libs.versions.toml
└── app/
    ├── build.gradle.kts            # applicationId/namespace = "com.welape.meshdrop"
    └── src/main/
        ├── AndroidManifest.xml     # android:label "MeshDrop"，NEARBY_WIFI_DEVICES
        ├── res/
        │   ├── values/
        │   │   ├── strings.xml         # "MeshDrop"
        │   │   └── themes.xml          # Theme.MeshDrop (Material3 disable dynamic color)
        │   ├── values-night/
        │   ├── mipmap-anydpi-v26/      # adaptive icon (meshdrop mark + paper background)
        │   ├── mipmap-*dpi/
        │   └── font/                   # space_grotesk.ttf, geist.ttf, geist_mono.ttf
        ├── java/com/welape/meshdrop/
        │   ├── MeshDropApplication.kt
        │   ├── MainActivity.kt         # CompositionLocalProvider(LocalMockData)
        │   ├── data/                   # 保留（rename package drop.mesh → com.welape.meshdrop）
        │   ├── protocol/               # 保留
        │   ├── transport/              # 保留（service type 改 _meshdrop._tcp）
        │   ├── discovery/              # 保留
        │   ├── mock/
        │   │   └── MockData.kt         # ★ COMMON §9 Kotlin 化
        │   └── ui/
        │       ├── theme/
        │       │   ├── Color.kt        # ★ COMMON §5 token
        │       │   ├── Type.kt         # Space Grotesk / Geist
        │       │   └── Theme.kt        # 关 dynamicColor，强制 MeshDrop 配色
        │       ├── MeshDropApp.kt         # 入口 + WindowSizeClass 分发
        │       ├── PhoneRoot.kt        # bottom NavBar 4 tab
        │       ├── TabletRoot.kt       # NavRail + 内容区 row
        │       ├── tabs/
        │       │   ├── DiscoverScreen.kt
        │       │   ├── ChatListScreen.kt
        │       │   ├── ChatDetailScreen.kt
        │       │   ├── TransferScreen.kt
        │       │   └── MeScreen.kt
        │       ├── sheets/
        │       │   ├── SendBottomSheet.kt
        │       │   ├── DevicePickerSheet.kt  # 多选 grid
        │       │   ├── PairingSheet.kt
        │       │   └── FileOfferSheet.kt
        │       ├── components/
        │       │   ├── MeshDropLogo.kt / Avatar.kt / Chip.kt / KindGlyph.kt
        │       │   ├── DeviceRow.kt / MsgBubble.kt / FileChip.kt / TransferRow.kt
        │       │   ├── Radar.kt        # ★ Compose Canvas + animation
        │       │   ├── SpeedChart.kt
        │       │   ├── Photo.kt
        │       │   └── AsciiDivider.kt
        │       └── notifications/
        │           ├── IncomingChannel.kt # heads-up
        │           └── TransferForegroundService.kt # 大文件保活（mock 占位）
```

## 必做页面（共 13 张 × (light + dark) = 26 张）

基线 10 张（COMMON §8）+ Android 特有：

11. **底部 NavBar**（phone）：附近 / 聊天 / 传输 / 我
12. **Tablet 双栏**：左 NavRail + 设备列表，右 ChatDetail
13. **多选 DevicePicker**：长按设备进入多选状态，下方固定 CTA bar"发送给 N 台"
14. **Heads-up notification** (AndroidHeadsUp 还原)：incoming file 弹通知 +
    expanded 含 接收/拒绝/保存到相册 三按钮

> 共：Phone 11 × 2 + Tablet 5 × 2 + Heads-up notif × 2 = **32 张**

## 关键页面布局

### Discover Screen (Phone)

```
┌─ Pixel 8 ──────────────────────────┐
│ 14:08      (status bar)            │
│                                    │
│ meshdrop.                  [🔍][⋯]    │
│                                    │
│ 附近的                              │  ← display 34
│ 5 台设备   ← linear gradient text  │  ← flame → lime 渐变
│ Pixel 8 · LAN-only · scanning…     │  ← mono 11
│                                    │
│   ┌─────────────────────┐          │
│   │   Radar 300×300     │          │
│   │   pulse variant     │          │
│   └─────────────────────┘          │
│                                    │
│ ↑ 长按设备开始发送                 │  ← mono 10 center
│                                    │
│                            [+]     │  ← FAB lime 64×64, bottom-right
│                                    │
│  附近 | 聊天(2) | 传输 | 我       │  ← Bottom NavBar
└────────────────────────────────────┘
```

### Transfer Screen (Phone)

```
传输 · Transfers                          [⋯]
────────────────────────────────────────────
┌─ 本会话 SESSION ─────────────────────────┐
│                                          │
│   1.24 GB sent                           │  ← display 38, lime 色
│                                          │
│   ↑ 上行   ↓ 下行    活跃 ACTIVE        │
│   8.4 MB/s 11.7 MB/s  2 任务           │
└──────────────────────────────────────────┘

进行中 · IN PROGRESS
[TransferRow][TransferRow]

已完成 · COMPLETED · 今天
[TransferRow × 3]
```

### DevicePicker (long-press 多选)

```
← 取消                           已选 2 台

发送到多台设备
已选附件 · 3 张图片 · 12.4 MB

[Photo][Photo][Photo]   ← payload preview

附近 · NEARBY

[李莉 ✓][坤  ][嘉伟]   ← 3 列 grid
[孟茜 ✓][DEV01]         lime 填充 + ink 边框 + ✓ 角标

                                                
                  ┌────────────────────────────┐
                  │ 发送给 2 台                │
                  │ 李莉 · 孟茜    [发送 →]   │  ← bottom CTA bar (ink 底)
                  └────────────────────────────┘
```

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| 点设备 row | push ChatDetail |
| 长按设备 row | 进多选模式 → DevicePicker，下方 CTA bar |
| FAB + | 弹快捷面板（bottom sheet）：文件 / 相册 / 文字便签 |
| 系统 Share Intent | MeshDrop 在选择器中显示，触发 DevicePicker |
| 收 incoming file（mock 触发） | 弹 heads-up notification + 进 app 弹 FileOfferSheet |
| 通知"接收"按钮 | 关闭通知 + mock 触发文件保存 |

## 编译 / 验证

```bash
cd android
gradle wrapper --gradle-version 8.11   # 首次
./gradlew :app:assembleDebug
./gradlew :app:installDebug
adb shell am start -n com.welape.meshdrop/.MainActivity
adb shell dumpsys nsdservice | head -50
```

## 截图清单（PR 必须附 32 张）

```
screenshots/android-phone-{discovery|chatlist|chat|transfers|history|settings|trust|pairing|onboarding|receive|picker}-{light|dark}.png   (22)
screenshots/android-tablet-{split|chat|transfers|history|settings}-{light|dark}.png   (10)
screenshots/android-headsup-notif-{collapsed|expanded}.png   (2)
```

> 实际数 24+10+2 = 36（按 13 张基线，不严格 32）

## 验收 checklist

- [ ] `assembleDebug` 一次过
- [ ] adaptive icon dock 显示 meshdrop mark（lime dot 可见）
- [ ] Material You 动态色已关，强制 MeshDrop 配色
- [ ] 字体真的是 Space Grotesk（在 Me/About 页可见对比 Roboto）
- [ ] 长按设备进入多选 + bottom CTA bar 显示
- [ ] heads-up 通知"接收"按钮可点击（mock 行为）
- [ ] outgoing 气泡 dark 模式用 lime 底
- [ ] 文件 grep 无 "Shar / FreqShare / 至汝 / drop.mesh" 残留（这些是旧名）
- [ ] 36 张截图全附

## 不能做（端特有）

- 不要启用 Material You 动态色（与 MeshDrop 报纸 + lime 调子冲突）
- 不要用 `MaterialTheme.colorScheme.primary` 系统默认色
- BottomNavBar 必须 4 tab，不是 5 个
- 不要在 Composable 里调 MeshDropEngine（本轮 mock）
