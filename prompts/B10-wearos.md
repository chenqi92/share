# MeshDrop · Wear OS Backend 接入 Prompt（Companion via WearableDataLayer）

## 端特定任务

Wear OS 端 **不直连 LAN**，所有操作通过 `WearableDataLayer` 桥接 Android phone。
phone 端的 `WearBridgeService` 由 **B03 Android prompt** 实装。本 prompt 只做 wear 侧。

## 工作范围

- ✅ `wearos/app/src/main/java/com/welape/meshdrop/wear/`（除 mock 包）
- ✅ `wearos/app/build.gradle.kts`（加 play-services-wearable 依赖，**先问**）
- ❌ 其他端、android/ 目录、protocol/ 核心

## 必做

### 1. WearableDataLayer 客户端

新增包 `bridge/`：

```
bridge/
├── WearSessionClient.kt       # 启动 + 节点发现 + 命令发送
├── WearEngineProxy.kt          # 模拟 ShareEngine 接口
├── WearListenerService.kt     # WearableListenerService 子类，接收 /meshdrop/evt
└── CommandTypes.kt             # JSON 编解码（按 protocol/companion-bridges.md）
```

`WearEngineProxy` API 形状（和 Android `ShareEngine` 一致）：

```kotlin
class WearEngineProxy private constructor(context: Context) {
    val devices: StateFlow<List<Device>>
    val history: StateFlow<List<HistoryItem>>
    val pendingOffers: StateFlow<List<Offer>>
    val isOnline: StateFlow<Boolean>   // companion 桥接状态

    suspend fun sendText(peerId: String, text: String): Result<Unit>
    suspend fun sendFileRef(peerId: String, fileUri: Uri, name: String): Result<Unit>
    suspend fun acceptOffer(offerId: String): Result<Unit>
    suspend fun rejectOffer(offerId: String): Result<Unit>

    companion object { val instance: WearEngineProxy }
}
```

内部实装：

- 启动：`Wearable.getNodeClient(context).connectedNodes` 取第一个 companion 节点 id
- 命令：JSON → `MessageClient.sendMessage(nodeId, "/meshdrop/cmd", bytes)`
- 命令回执：监听 path `/meshdrop/cmdresp`
- 事件：`WearableListenerService` 注册到 path `/meshdrop/evt`，分发更新 StateFlow
- 文件 send：`DataClient.putDataItem(...)` path `/meshdrop/files/<id>`，把 Uri 转成 Asset

### 2. UI 切到 Proxy

把 wear 端 mock 引用全部换 `WearEngineProxy.instance`。

- 圆屏 Nearby 上 5 个 avatar 绕一圈 ← `proxy.devices.collectAsState()`
- 转表冠选定 → 按发文本 → 调 `proxy.sendText(peerId, text)`
- 离线（`!isOnline`）→ 中心数字变灰 + "OFFLINE · phone 不在身边" 文字

### 3. App 启动 / 关闭

`MeshDropWearApp.kt` 的 Application.onCreate：

```kotlin
WearEngineProxy.instance.start()
```

`onTerminate()` 调 `stop()`（断开 listener）。

### 4. 错误处理

- 无 companion 节点（`connectedNodes.isEmpty()`）→ 显示 "OFFLINE"
- 命令 10s 无回执 → 显示 "命令超时"
- phone 端 `WearBridgeService` 不存在 → 显示 "请在手机端打开 MeshDrop"

### 5. 加依赖（先问）

`wearos/app/build.gradle.kts`：

```kotlin
dependencies {
    implementation("com.google.android.gms:play-services-wearable:18.2.0")
}
```

## 验证

```bash
cd wearos
./gradlew :app:assembleDebug
```

互通：Wear OS simulator 配对 Android phone simulator + mac 同 LAN。
wear → phone bridge → mac 互发文本测试。

## 依赖

**前置：** B03 Android prompt 必须先合。同 B09 watch 处理方式。

## PR 标题

`backend(wearos): 实装 WearableDataLayer companion proxy`

## 互通证据

- 1 段 ≥ 15s mp4：wear 选 peer 发文本 → phone 中转 → mac 收到

## 不能做

- 不在 wear 端引 mDNS / 直连 LAN socket
- 不删 mock
- 不改 protocol/companion-bridges.md
- 不在 Composable 里直调 Wearable API（统一走 bridge/）
- 不用 wear.compose.material3 之外的 Material 组件
