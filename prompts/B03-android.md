# MeshDrop · Android Backend 接入 / 验证 + Wear Companion Bridge Prompt

## 端特定任务

Android UI 这一轮**已经接了 `ShareEngine`**（grep real=5 mock=0）。本轮要做的：

1. **验证** 接入完整性（不是只 import 但仍用假数据）
2. **新增 Wear Companion Bridge 模块**（Android phone 兼任 Wear OS 的 LAN 桥）
3. **补错误 / Loading / 空态**（B-COMMON §错误处理）

## 工作范围

- ✅ `android/app/src/main/java/com/welape/meshdrop/`（验证 + 补完）
- ✅ 新增 `android/app/src/main/java/com/welape/meshdrop/bridge/`（Wear bridge）
- ✅ `android/app/src/main/AndroidManifest.xml`（加 Wearable service + NEARBY_WIFI_DEVICES 已有就跳）
- ✅ `android/app/build.gradle.kts`（加 `play-services-wearable` 依赖，**装前先问**）
- ❌ 其他端目录、wearos/ 目录（属 B10）

## 必做

### 1. 验证 UI 真接 Engine

对每个 UI 文件 grep："看到 `MockData` / `mockData` 还是 `shareEngine.devices` / `shareEngine.history`"。

如果 UI 文件里既有 mock 又有 real，**那是没真接** — mock 在被用。修复：把 `MockData.devices` 之类的引用全删，全部走 `shareEngine.{devices,history,...}`。

### 2. Engine.start() 接到 Application

`MeshDropApplication.kt` 的 `onCreate()` 里：

```kotlin
applicationScope.launch {
    shareEngine.start()
}
```

`onTerminate()` 调 `shareEngine.stop()`。

### 3. 错误 / Loading / 空态

Compose UI 加：

```kotlin
val isStarting by shareEngine.isStarting.collectAsState()
val lastError by shareEngine.lastError.collectAsState()
val devices by shareEngine.devices.collectAsState()

if (isStarting) { ScanningBanner() }
if (lastError != null) { ErrorSnack(lastError) }
if (devices.isEmpty()) { EmptyNearbyCard() }
```

### 4. Wear Companion Bridge 模块（新增）

新增包 `bridge/`：

```
bridge/
├── WearBridgeService.kt    # WearableListenerService 子类，处理 /meshdrop/cmd path
├── WearEventPusher.kt      # 监听 shareEngine 状态变化 → /meshdrop/evt 推给 wear
└── WearAssetTransfer.kt    # DataClient 大文件分片
```

实装 `protocol/companion-bridges.md §1+§2+§4.2`：

- 注册 `WearableListenerService` 监听 `/meshdrop/cmd`
- 收到命令 → 解析 type → 转给 `shareEngine.{sendText,sendFile,accept...}` → 通过 `MessageClient.sendMessage(nodeId, "/meshdrop/cmdresp", reply)` 回执
- engine 事件订阅器：device_added / offer_pending / transfer_progress → `MessageClient.sendMessage(nodeId, "/meshdrop/evt", payload)`
- `send_file_ref` 的 fileRef 是 wear 端通过 `DataClient.putDataItem` 上传的，phone 端用 `DataClient.getDataItem(uri)` 拿到 byte stream 后传给 engine
- 自动选 nodeId：`Wearable.getNodeClient(context).connectedNodes` 取第一个

### 5. 加依赖（先问）

`android/app/build.gradle.kts`：

```kotlin
dependencies {
    implementation("com.google.android.gms:play-services-wearable:18.2.0")  // 加这条
}
```

注：CLAUDE.md 规则说 npm/gradle 加依赖是风险动作，**先在 PR 描述里说明 + 让 reviewer 知道**。

## 验证

```bash
cd android
./gradlew :app:assembleDebug
./gradlew :app:installDebug
```

互通：1 台 Android phone + 1 台 mac，互发文本 + 5 MB 文件。

Wear bridge 测试：模拟器 Wear OS pair 上 phone 模拟器，从 wear 触发 list_devices 命令。

## PR 标题

`backend(android): 验证 ShareEngine 接入 + 新增 Wear Companion Bridge`

## 互通证据

- 1 段 ≥ 15s mp4：phone ↔ mac 互发
- 1 段 ≥ 10s mp4：wear simulator 触发命令通过 phone 收发

## 不能做

- 不删 mock 文件（Preview 用）
- 不改 protocol/ 核心规范
- 不在 ViewModel 里直接调 WearableDataLayer API（统一走 bridge/ 包）
- 不在 ShareEngine 里硬编码 nodeId（动态查 connectedNodes）
