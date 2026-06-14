# MeshDrop · Wear OS

Wear OS 端 MeshDrop。本端**不直接连 LAN**，通过 `WearableDataLayer` 桥到一台
配对的 Android phone（运行 `android/` 端的 MeshDrop app），由 phone 端代为接入 LAN。

桥接协议见 [protocol/companion-bridges.md §4.2](../protocol/companion-bridges.md)。

## 构建

```bash
cd wearos
./gradlew :app:assembleDebug
```

需要 ANDROID_HOME 指向 Android SDK；Wear OS app 需要装 Wear OS Companion 系统镜像。

在 Android Studio 中：File → Open → 选 `wearos/`，等同步完成后选 Wear OS
模拟器 → ▶ 运行。

## 当前覆盖（v0.1）

- ✅ Compose for Wear UI（Nearby radar / Receive / Pairing 三页，HorizontalPager 可见切换）
- ✅ WearableDataLayer 接 phone companion proxy
- ✅ 快捷消息发送（替代写死的 wave / mock）
- ✅ 同步显示 phone 端的设备列表 / 历史 / 待审 offer / 待审配对
- ✅ 处理 phone 推送的 incoming offer（accept / reject）
- ✅ 处理 phone 推送的 pairing_pending（信任 / 拒绝，TOFU 显式确认）

## 不支持（设计如此）

- ❌ 直接挂 LAN（带宽 / 电池预算不允许）
- ❌ 文件发送：桥接链路（`sendFileRef` / `putFileAsset`）已实装且带 >10 MiB 上限校验，
  但尚未接入可达的发送 UI 入口（表上无文件选择器）；当前仅作为接口预留，需发文件请用 phone。
- ❌ 单独身份（身份与 phone 共享）

> 传输安全：v0.1 LAN 为明文 TCP，UI 不宣称端到端加密；身份/指纹为 Ed25519 + SHA-256。

## 与 Apple Watch 的对应关系

| 项 | Apple Watch | Wear OS |
| --- | --- | --- |
| 桥接技术 | WatchConnectivity (WCSession) | WearableDataLayer (MessageClient / DataClient) |
| Companion path | iOS phone | Android phone |
| 大文件 | 直接拒 | >10 MiB 直接拒（发送 UI 未接入） |
| 短信发送 | ✓ | ✓ |
| 接收 offer 响应 | ✓ | ✓ |
| 单独身份 | × | × |

视觉与交互保持一致（圆形表盘、上下滑动、最小可点 ≥ 10pt）。
