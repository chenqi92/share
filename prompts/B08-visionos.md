# MeshDrop · visionOS Backend 接入 Prompt

## 端特定任务

把 `apple/MeshDropVision/Sources/` 里的 UI 从 mock 切到真实 `ShareEngine.shared`。
**保留所有空间布局 / 玻璃面板 / Gaze+Pinch 隐喻**，只换数据源。

## 工作范围

- ✅ `apple/MeshDropVision/Sources/`（除 mock 子目录）
- ✅ `apple/MeshDropVision/project.yml`（加 MeshDropKit 依赖）
- ❌ 不动 MeshDropKit / 其他端

## 必做

### 1. 加 MeshDropKit 依赖

`project.yml` 加 `package: MeshDropKit`，xcodegen generate。

### 2. UI 切到真 Engine

9 个 mock 文件全改。重点：

- `SpatialNearbyPage.swift` 的 PeerOrbs 接 `engine.devices`，每台设备分配空间坐标（继续用现有 z/depth 算法）
- `ReceiveCardScreen.swift` 接 `engine.pendingOffers.first`
- `TransfersInFlightPage.swift` 接 `engine.activeTransfers`（如 ShareEngine 还没暴露，新增 publisher）
- 用户**捏合（Pinch）** 在 gaze 锁定的 PeerOrb 上 → 触发 `engine.sendFile(to: peer.id, ...)`
- 用户**语音 "接收" 或 Pinch CTA** → 触发 `engine.acceptOffer(id)`

### 3. Engine 启动

`MeshDropVisionApp.swift` WindowGroup 加：

```swift
.onAppear { Task { await ShareEngine.shared.start() } }
```

### 4. 错误 / Loading / 空态

- 中央主面板顶部 status pill：`engine.isStarting` → "SCANNING · 房间"，error 红色 pill
- PeerOrb 数为 0 时显示 "等待身边的设备…"
- 飞行 trail 真实接 transfer_progress（不再只是装饰，反映真实文件进度）

### 5. Spatial 输入映射

- gaze 锁定 PeerOrb → 该 orb scale 1.05 + ring 高亮
- pinch（gaze focus on orb） → 调出 quick-send sheet（选要发的 payload）
- pinch CTA "捏合接收" → `engine.acceptOffer`
- 长按 PeerOrb → 上下文菜单 "对话 / 信息 / 撤销信任"（信任走 `engine.revokeTrust(peerId)`）

## 验证

```bash
cd apple/MeshDropVision
xcodegen generate
xcodebuild -project MeshDropVision.xcodeproj -scheme MeshDropVision -configuration Debug \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

互通：装到真 Vision Pro（或 simulator + mac 同 LAN），mac 推 PDF。

注：visionOS Simulator 上的 Bonjour 可能受限——如真机不可得，证据用 simulator + log 截图也行，但 PR 描述写明。

## PR 标题

`backend(visionos): UI 接入 ShareEngine 保留空间布局`

## 互通证据

- 1 段 ≥ 15s mp4 / simulator 截屏序列：visionOS 显示 PeerOrb（真实 LAN 设备）+ 接收一个 incoming file

## 不能做

- 不动 MeshDropKit
- 不删 mock
- 不改 protocol/ 核心
- 不退化空间设计为 sidebar/TabBar（保留 glass 漂浮）
- pinch / gaze 行为映射到 Engine，不要在 SwiftUI View 里直接做网络 I/O
