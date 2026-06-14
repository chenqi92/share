# MeshDropVision · visionOS 端 UI

Vision Pro 上的 MeshDrop 空间 UI。已接 MeshDropKit `ShareEngine`：`EngineAdapter` 把 live 设备 / 历史 / 传输进度投影到空间视图（见 [Sources/integration/EngineAdapter.swift](Sources/integration/EngineAdapter.swift)、[Sources/MeshDropVisionApp.swift](Sources/MeshDropVisionApp.swift)）。`MockData` 仅供 SwiftUI Preview / 离线截图。

## 构建

```bash
cd apple/MeshDropVision
xcodegen generate
```

### 标准 destination 形式（需先在 Xcode > Settings > Components 装 visionOS 平台）

```bash
xcodebuild -project MeshDropVision.xcodeproj \
  -scheme MeshDropVision \
  -configuration Debug \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

### 仅有 SDK / 没装 Simulator runtime 时（CI 友好）

```bash
xcodebuild -project MeshDropVision.xcodeproj \
  -target MeshDropVision \
  -configuration Debug \
  -sdk xrsimulator26.5 -arch arm64 \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

构建产物：`build/Debug-xrsimulator/MeshDrop.app`（`PRODUCT_NAME=MeshDrop`）

## 设计要点

| 维度 | 实装位置 |
| --- | --- |
| 中央 960×640 真磨砂玻璃面板 | [Sources/components/GlassCard.swift](Sources/components/GlassCard.swift) + [Sources/shell/MainWindow.swift](Sources/shell/MainWindow.swift) |
| 5 个 PeerOrb 分 3 深度层（near / mid / far） | [Sources/spatial/PeerOrb.swift](Sources/spatial/PeerOrb.swift) + [Sources/mock/MockData.swift](Sources/mock/MockData.swift) `DepthLayer` |
| Gaze reticle（4 段弧 + 中央十字 + lime 标签） | [Sources/spatial/GazeReticle.swift](Sources/spatial/GazeReticle.swift) |
| 飞行 payload 轨迹（dashed + 粒子残影） | [Sources/spatial/FlyingPayload.swift](Sources/spatial/FlyingPayload.swift) |
| 4 张主页 | [Sources/pages/](Sources/pages/) |

## 字体（待嵌入）

仓库目前未提供 OFL 字体文件。运行时使用系统 rounded / monospaced 回退；后续把
Space Grotesk 和 Geist 放入 `Resources/Fonts/` 并在 Info.plist 加 `UIAppFonts` 即可。
