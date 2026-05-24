# MeshDrop · tvOS Backend 接入 Prompt

## 端特定任务

把 `apple/MeshDropTV/Sources/` 里的 UI 从 mock 切到真实 `ShareEngine.shared`。

**tvOS 客户端只接收，不发送**（之前 prompt 已定）。但 ShareEngine 同时承担 receiver 角色，所以接入方式和其他 Apple 端一致——只是 UI 没有"发送"路径。

## 工作范围

- ✅ `apple/MeshDropTV/Sources/`（除 mock 子目录）
- ✅ `apple/MeshDropTV/project.yml`（把 MeshDropKit 加为 SPM 依赖如果还没加）
- ❌ 不动 `apple/Sources/MeshDropKit/`
- ❌ 其他端

## 必做

### 1. 加 MeshDropKit 依赖

检查 `apple/MeshDropTV/project.yml`：

```yaml
targets:
  MeshDropTV:
    dependencies:
      - package: MeshDropKit   # 必须有这条
```

如缺，添加。然后 `xcodegen generate`。

### 2. UI 切到真 Engine

7 个 mock 文件全部改成 `ShareEngine.shared` 引用。

tvOS 特殊：
- ReceivePage 接 `engine.pendingOffers.first`，按 ◉ select 触发 `engine.acceptOffer(id)`
- GalleryPage 接 `engine.history.filter { $0.direction == .received && ($0.kind == .file || $0.kind == .files) }`
- NearbyPage 接 `engine.devices`，但**不显示 send 按钮**（tvOS 只接收）
- SettingsPage 接 `engine.selfDevice`，能改 displayName

### 3. Engine 启动

`MeshDropTVApp.swift` 的 Scene `body` 加：

```swift
.onAppear { Task { await ShareEngine.shared.start() } }
.onDisappear { Task { await ShareEngine.shared.stop() } }
```

### 4. 错误 / Loading / 空态

tvOS 也要展示：
- TopBar 状态条："scanning · 客厅 LAN"
- NearbyPage 空态："等设备靠近…"
- 错误：浮层弹"网络异常"

### 5. 接收侧 UX

incoming file offer 到来时：
- 自动从 NearbyPage 切到 ReceivePage（如果当前不在 receive tab）
- 巨型 lime CTA "接收并播放"
- 按 ▶︎ 播放进入 slideshow（mock 即可，本轮不实装真播放器）
- 拒绝走 `engine.rejectOffer(id)`

## 验证

```bash
cd apple/MeshDropTV
xcodegen generate
xcodebuild -project MeshDropTV.xcodeproj -scheme MeshDropTV -configuration Debug \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

互通：装到真 Apple TV（或 simulator + 同 LAN mac），从 mac 推一张照片 + 一段文字。

## PR 标题

`backend(tvos): UI 接入 ShareEngine（只接收模式）`

## 互通证据

- 1 段 ≥ 15s mp4：mac 推送照片 + 文本到 tvos，tvos 显示并保存

## 不能做

- 不动 MeshDropKit
- 不删 mock
- 不改 protocol/ 核心
- 不在 tvOS UI 上做发送（按钮 / 拖拽都不应触发 sendText/sendFile）
- 不实装真实 slideshow 播放器（mock 即可，下一轮）
