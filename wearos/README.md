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

- ✅ Compose for Wear UI（Tile / Detail / Quick Send sheet）
- ✅ WearableDataLayer 接 phone companion proxy
- ✅ 快捷消息发送（替代写死的 wave / mock）
- ✅ 同步显示 phone 端的设备列表 / 历史 / 待审 offer
- ✅ 处理 phone 推送的 incoming offer（accept / reject）

## 不支持（设计如此）

- ❌ 直接挂 LAN（带宽 / 电池预算不允许）
- ❌ 大文件发送（>10 MB 时 UI 直接拒绝并提示用 phone）
- ❌ 单独身份（身份与 phone 共享）

## 与 Apple Watch 的对应关系

| 项 | Apple Watch | Wear OS |
| --- | --- | --- |
| 桥接技术 | WatchConnectivity (WCSession) | WearableDataLayer (MessageClient / DataClient) |
| Companion path | iOS phone | Android phone |
| 大文件 | 直接拒 | 直接拒 |
| 短信发送 | ✓ | ✓ |
| 接收 offer 响应 | ✓ | ✓ |
| 单独身份 | × | × |

视觉与交互保持一致（圆形表盘、上下滑动、最小可点 ≥ 10pt）。
