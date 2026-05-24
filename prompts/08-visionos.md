# MeshDrop · visionOS 端 UI Prompt（Apple Vision Pro）

## 端特定任务

重做 Vision Pro 上的 MeshDrop——这是 MeshDrop **最有故事感**的端。空间设计：
设备**漂浮在你的房间里**，看着它"递东西"的隐喻必须成立。窗口只是一个框，
大部分画布是透视背景（passthrough 模拟）。本轮只重做 UI 用 mock 数据驱动，
不接 backend。

## 风格关键

visionOS 三件事必须做对：

1. **磨砂玻璃面板**（`.glassBackgroundEffect()` / `ornament`）—— 80px blur +
   180% saturation + inset 1px highlight，**不要平面色块**
2. **空间深度**：附近设备**漂浮分布**在窗口四周（不是排在窗口里），近的清晰
   大、远的小且模糊；用 z scale + blur 模拟
3. **Gaze + Pinch 隐喻**：眼睛"看"设备 → 手"捏"发送。每个可交互元素必须有
   gaze reticle 视觉提示

绝不要：sidebar / TabBar / 列表 — Vision 上太"扁"。

## 技术栈

- Swift 6
- SwiftUI（visionOS 优先 API）+ RealityKit（仅做飞行轨迹粒子，可选）
- visionOS 2+ / Xcode 16+ SDK
- `.glassBackgroundEffect()` / `.ornament(attachmentAnchor:)` / `.hoverEffect()`
- `Model3D` / RealityKit（飞行 payload 粒子；本轮可降级为 2D CALayer 动画）
- XcodeGen 生成工程

## 文件组织

```
apple/MeshDropVision/
├── project.yml                # bundle id com.welape.meshdrop.vision，PRODUCT_NAME MeshDrop
├── Resources/
│   ├── Info.plist
│   ├── Assets.xcassets/       # AppIcon (3 层) + AccentColor
│   └── Fonts/                 # Space Grotesk + Geist (OFL)
├── Sources/
│   ├── MeshDropVisionApp.swift   # @main + WindowGroup + ImmersiveSpace（可选）
│   ├── shell/
│   │   ├── MainWindow.swift   # 中央磨砂面板（hero copy + 已选 payload）
│   │   ├── TabOrnament.swift  # 窗口底部 ornament: 附近 / 对话 / 传输 / 相册
│   │   ├── CloseHandleOrnament.swift  # 左下 56pt 圆形 ornament
│   │   └── StatusOrnament.swift # 头部状态条
│   ├── spatial/
│   │   ├── PeerOrb.swift      # 漂浮在空间里的设备小卡（玻璃 260×160）
│   │   ├── GazeReticle.swift  # 看向某设备时的瞄准圈
│   │   └── FlyingPayload.swift # 文件从手指飞向目光中目标的飞行轨迹
│   ├── pages/
│   │   ├── SpatialNearbyPage.swift     # 主页：飘浮设备 + 中央窗口
│   │   ├── ReceiveCardScreen.swift     # 接收弹卡（双 glass panel + 中央 CTA）
│   │   ├── ConversationsPage.swift     # 对话列表（小玻璃 cards）
│   │   ├── TransfersPage.swift         # 进行中传输（飞行轨迹可视化）
│   │   └── GalleryPage.swift           # 收件箱
│   ├── components/
│   │   ├── MeshDropLogo.swift
│   │   ├── Avatar.swift            # ring 高亮（gaze focus）
│   │   ├── Chip.swift
│   │   ├── Photo.swift
│   │   ├── GlassCard.swift     # ★ 标准磨砂玻璃面板封装
│   │   └── KindGlyph.swift
│   ├── mock/
│   │   └── MockData.swift     # ★ COMMON §9 Swift 化
│   └── theme/
│       ├── MeshDropColor.swift
│       └── MeshDropFont.swift
```

## 必做页面（共 4 张 × dark only = 4 张）

> visionOS 也只有 dark（passthrough 环境是真实房间，无需 light/dark 分主题）。

1. **SpatialNearby** — 主窗口（中央 960×640 glass panel）+ 5 个 PeerOrb 漂浮
   在窗口四周不同深度 + gaze reticle 锁定在 Lily 上 + 飞行 payload 粒子轨迹
2. **ReceiveCard** — 左侧大 glass panel（文档预览，倾斜 -3°）+ 中央 glass
   panel（来自 / 备注 / 双 CTA：不接收 / 捏合接收）+ 右上发送者 PeerOrb +
   trail 虚线连接
3. **TransfersInFlight** — 进行中传输用粒子飞行可视化展示（mock：3 个文件
   从 self 飞向不同 peer）
4. **PairingSpatial** — 配对：6 字符代码 block + 完整指纹 + "捏合确认" CTA

## 关键页面布局

### Spatial Nearby

```
┌── passthrough · 客厅 1600×1000 ───────────────────────────────────────┐
│                                                                       │
│ [Avatar 远]                                                           │
│ 嘉伟 远                                                               │
│                          ╭── center glass 960×640 ──╮                 │
│                          │ MeshDrop · SPATIAL·客厅 │ ●5            │ │
│                          │ ──────────────────────  │                │ │
│                          │   你身边的设备           │  [李莉 PeerOrb]│ │
│                          │   都已就位.   ← 渐变    │  near focus    │ │
│                          │                          │                │ │
│                          │   看向任意一台设备,捏合 │                │ │
│                          │                          │                │ │
│                          │   [已选·3 张照片·12.4 MB]│                │ │
│                          │   [Photo][Photo][Photo]  │                │ │
│                          │   ✥ GAZE · PINCH · 长按  │                │ │
│                          ╰──────────────────────────╯                │ │
│                          [附近|对话|传输|相册]  ← bottom ornament    │ │
│ [李莉 PeerOrb near]                              [李莉 PeerOrb]     │ │
│ ●ONLINE ≈2m                                       ●ONLINE ≈4m       │ │
│                                                                       │
│                                                                       │
│ [李莉 reticle 瞄准圈 + "看向 LILY · 准备捏合发送" 标签]              │
│                                                                       │
│ [PeerOrb 远]                                      [PeerOrb 远]       │
│ ●ONLINE ≈7m                                       ●ONLINE ≈7m       │
└───────────────────────────────────────────────────────────────────────┘
```

PeerOrb 规格：
- 260×160 圆角 28 玻璃卡
- 内容：Avatar 42 + 名字 + 设备种类 + RTT + ●ONLINE chip + 距离 "≈ 2m" + (focus 时) → 按钮
- 远近：`scale(z)` z ∈ [0.55, 1.0]；远的 `blur(1px) opacity(0.78)`
- focus（被 gaze）：`scale(1.05)` + 外圈 ring + Avatar.ring=true(lime)

### Receive Card

```
┌── passthrough · studio bg ───────────────────────────────────────────┐
│                                                                       │
│ [glass 520×680 倾斜 -3°]              [center glass 520×560]         │
│ ┌─ doc 预览 ─────┐                    ┌─ INCOMING · 嘉伟想发给你────┐│
│ │ [PDF] 规划文档_v0.3 │              │ INCOMING · ...              ││
│ │ ┌─ page ────────┐  │              │ 看一眼,捏合,                ││
│ │ │ 2026 Q1 设计规划│              │ 就收到. ← lime              ││
│ │ │ §1 目标         │              │                              ││
│ │ │ ...             │              │ ┌── lime tinted card ──┐    ││
│ │ │ §2.3 visionOS   │              │ │ [Avatar] 嘉伟         │    ││
│ │ └─────────────────┘              │ │ iPad·9ms·已配对 ● 验证│    ││
│ │ 3.4 MB·12页·●E2E   │              │ │ 🏷"帮我看第3节..."   │    ││
│ └────────────────┘                   │ └────────────────────┘    ││
│                                       │                              ││
│                                       │ [不接收][✥ 捏合接收]        ││
│                                       │ 或:看着这张卡片说"接收"    ││
│                                       └──────────────────────────────┘│
│                                       [嘉伟 PeerOrb top-right]       │
│   ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ trail dashed line     │
└───────────────────────────────────────────────────────────────────────┘
```

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| Gaze 一个 PeerOrb | 该 orb scale 1.05 + ring 高亮 + lime reticle |
| Pinch（gaze focus on orb 时） | 触发发送动画 + alert "已发送（mock）" |
| Pinch（gaze focus on Receive CTA） | mock 接收完成 + glass card 消失 |
| Pinch ornament tab | 切换 nearby / 对话 / 传输 / 相册 |
| 语音 "接收" / "Accept" | 同 pinch 接收 CTA |
| 长按 PeerOrb（gaze + hold pinch） | 弹"对话 / 信息 / 撤销信任"上下文菜单 |
| 拖文件入主窗口（手势） | 整窗口 lime ring + "放手发给 [gaze peer]" |

## 编译

```bash
cd apple/MeshDropVision
xcodegen generate
xcodebuild -project MeshDropVision.xcodeproj -scheme MeshDropVision -configuration Debug \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

## 截图清单（PR 必须附 4 张）

```
screenshots/visionos-{spatial-nearby|receive-card|transfers|pairing}-passthrough.png  (4)
```

外加 1 段 15-20s mp4，模拟 simulator 中 PeerOrb 漂浮 + gaze reticle + 飞行轨迹。

## 验收 checklist

- [ ] `xcodebuild -destination 'platform=visionOS Simulator...' build` 一次过
- [ ] 中央磨砂玻璃面板真的有 blur(80) saturate(180%) + inset highlight
- [ ] PeerOrb 至少分 3 深度层（near / mid / far），近大远小且远的有 blur
- [ ] Gaze reticle 视觉清晰可辨（不只是边框）
- [ ] 飞行 payload 轨迹（哪怕是静态截图也得有 dashed trail）
- [ ] outgoing 主色用 lime，incoming 用 sky（COMMON §5）
- [ ] 没有出现 sidebar / TabBar / 多层 NavigationStack
- [ ] 文件 grep 无 "Shar / FreqShare / 至汝 / drop.mesh" 残留（这些是旧名）
- [ ] 4 张截图 + 1 段 mp4 全附

## 不能做（端特有）

- 不要做"窗口里塞列表"的扁平布局 — visionOS 关键是把内容散布在空间里
- 不要用实色按钮 / 实色背景面板 — 全部 glass
- 不要用 NavigationStack 多层钻进
- 不要假定用户能"鼠标点击" — 所有 hit target 至少 56 pt 直径
- 不要在 SwiftUI 里调真实 MeshDropEngine（本轮 mock）
- 不要为了"看起来酷"加 RealityKit 3D 模型而牺牲可用性（PeerOrb 仍是 2D glass）
