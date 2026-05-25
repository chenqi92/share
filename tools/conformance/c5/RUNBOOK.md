# C5 — android → mac 配对（TOFU）RUNBOOK

> 本 runbook 走完整三轮：拒绝 → 允许并记住 → 直连复用。
> 规范见 [protocol/conformance-tests.md §C5](../../../protocol/conformance-tests.md#c5--android--mac-配对tofu) 与
> [protocol/security.md §配对](../../../protocol/security.md#配对pairing)。

## ⚠️ 跑测前必读

代码 spot check 已经发现 android 端 `PairingSheet` 在
[android/app/src/main/java/com/welape/meshdrop/ui/sheets/PairingSheet.kt](../../../android/app/src/main/java/com/welape/meshdrop/ui/sheets/PairingSheet.kt:124)
仍然 100% mock 驱动（三按钮全 `onClose`）。**接收端**配对决策走得通（Mac
PairingPage + AppState 已接 engine），但**发送端**的 android 在被对端反向连接、
或 android 自身作为 receiver 时，UI 上无法响应配对。

C5 的设备方向是 **android（发送方）→ mac（接收方）**，配对卡在 mac 端弹出，
理论上**应当**能完整跑通；android 侧的 UI 漏接对 C5 不构成阻塞，但**仍是
backend(android) bug**，要在 PR 描述里指出并开 issue。

如果跑测时发现 android 端因「自己也收到 mac 的反向 HELLO 弹卡，但 sheet 不能
响应」而卡死，记入 RESULT.md 偏离段，并在 PR 里开 issue。

## 前置环境

| 项 | 要求 |
| - | - |
| mac | 同一 LAN；本机当前 commit；MeshDropMac.app 可启动 |
| android | 真机优先（emulator mDNS 经常不通）；同 Wi-Fi |
| commit | mac / android 双方都从 main HEAD = 587b2ff 或更新 |
| ffmpeg | `brew install ffmpeg`（拼接屏录用） |

## 步骤

### 步骤 0 — 清空 mac trusted 库

```bash
# 先完全退出 MeshDropMac.app（dock 右键 → 退出），再：
bash tools/conformance/c5/clear-mac-trust.sh
# 然后重启 MeshDropMac.app
open apple/MeshDropMac/build/.../MeshDropMac.app   # 或在 Xcode Run
```

确认：

```bash
ls ~/Library/Application\ Support/MeshDrop/trust.json 2>&1 || echo "OK 已清空"
```

### 步骤 1 — 启动 mac 端 Console 抓 log（可选但推荐）

```bash
# 另开终端
log stream --predicate 'subsystem == "com.welape.meshdrop"' --style compact \
    > apple/MeshDropMac/screenshots/conformance/C5-20260525/recv.log &
echo $! > /tmp/c5-mac-log.pid
```

或直接打开 Console.app → 过滤 `com.welape.meshdrop`，跑完手动导出。

### 步骤 2 — 启动 android logcat

```bash
adb logcat -c   # 先清
adb logcat ShareEngine:* MdnsDiscovery:* AndroidRuntime:E *:S \
    > android/screenshots/conformance/C5-20260525/send.log &
echo $! > /tmp/c5-android-log.pid
```

### 步骤 3 — 截 android 本机 fp（人工核对用）

android 上：设置 / Me Tab → 找到本机 fingerprint，截图存为
`android/screenshots/conformance/C5-20260525/me-tab-fp.png`。

可用：

```bash
adb exec-out screencap -p > android/screenshots/conformance/C5-20260525/me-tab-fp.png
```

### 步骤 4 — 录屏 + 跑第一轮（拒绝）

启动录屏（两个终端）：

```bash
# 终端 A（mac）
bash tools/conformance/c5/record-mac.sh round1
```

```bash
# 终端 B（android）
bash tools/conformance/c5/record-android.sh round1
```

操作：

1. android：选 mac 设备 → 发文本 `C5 round 1: reject`
2. mac：弹配对卡 → 对照指纹 4×8 大写 hex 分隔格式，与 android Me Tab 截图核对
3. mac：截 trusted 列表（应空）：

```bash
# 另开终端
screencapture -i apple/MeshDropMac/screenshots/conformance/C5-20260525/trusted-list-after-reject.png
```

4. mac：点「拒绝」
5. android：确认 UI 显示「对方拒绝」（如果没显示，记 RESULT.md 偏离）
6. 两个终端 Ctrl+C 停录屏

验证：

```bash
ls ~/Library/Application\ Support/MeshDrop/trust.json 2>&1 || echo "OK trusted 仍空"
```

### 步骤 5 — 跑第二轮（允许并记住）

```bash
bash tools/conformance/c5/record-mac.sh round2
bash tools/conformance/c5/record-android.sh round2
```

操作：

1. android：再发 `C5 round 2: trust`
2. mac：弹配对卡 → 点「允许并记住」
3. android：确认收到 ACK + 文本投递
4. Ctrl+C 停录屏
5. 截 trusted 列表 + 抓 trust.json 快照：

```bash
screencapture -i apple/MeshDropMac/screenshots/conformance/C5-20260525/trusted-list-screenshot.png
bash tools/conformance/c5/snapshot-mac-trust.sh
```

### 步骤 6 — 跑第三轮（直连复用）

```bash
bash tools/conformance/c5/record-mac.sh round3
bash tools/conformance/c5/record-android.sh round3
```

操作：

1. android：再发 `C5 round 3: silent`
2. mac：**不应**弹卡；文本应直接落 history
3. 计时 < 2s
4. Ctrl+C 停录屏

### 步骤 7 — 拼接 + 收尾

```bash
# 停 log 后台
kill $(cat /tmp/c5-mac-log.pid /tmp/c5-android-log.pid) 2>/dev/null || true
rm -f /tmp/c5-mac-log.pid /tmp/c5-android-log.pid

# 拼三段
bash tools/conformance/c5/concat-rounds.sh

# 截 android 三轮关键状态截图（用 adb exec-out screencap 任选时机）
# 文件名：pairing-pending.png / pairing-rejected.png / direct-receipt.png

# 清 raw 目录（拼接后不再需要；如果想保留改名 raw → raw-backup）
rm -rf apple/MeshDropMac/screenshots/conformance/C5-20260525/raw
rm -rf android/screenshots/conformance/C5-20260525/raw
```

### 步骤 8 — 填 RESULT.md

打开两份 RESULT.md，把 `<填实测>` 全部替换：

- `apple/MeshDropMac/screenshots/conformance/C5-20260525/RESULT.md`
- `android/screenshots/conformance/C5-20260525/RESULT.md`

关键字段：发送端 commit（android）、接收端 commit（mac）、网络、耗时、
指纹双端文本、三轮观察。

### 步骤 9 — 通知我提 PR

跑完告诉我，我帮你：
- `git add` 证据 + commit（描述写「conformance(C5): android→mac TOFU 配对实测证据」）
- push + 把 draft PR 转 ready-for-review
- 在 PR 描述同步代码 spot check 发现 + 开 issue
