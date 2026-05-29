# C5 - android → mac 配对（TOFU） - 2026-05-25

> 发送端（android）侧 RESULT。Mac 侧见
> `apple/MeshDropMac/screenshots/conformance/C5-20260525/RESULT.md`。

| 项                | 值                                       |
| ----------------- | ---------------------------------------- |
| 发送端 commit     | 587b2ffe140d41721a0c32062507aa4eaa501d0c |
| 接收端 commit     | <mac commit hash>                        |
| 网络              | <wifi/eth + 带宽>                        |
| 结果              | PASS / FAIL                              |
| 耗时（步骤 1-7）  | <实测>                                   |

## 三轮观察表

| 轮次 | 操作                                | 期望                                          | 实测 |
| ---- | ----------------------------------- | --------------------------------------------- | ---- |
| 1    | 选 mac 设备 → 发文本（如 `hello 1`） | 显示「等待对方批准」                          | <填> |
| 1    | mac 端拒绝                          | android 端 UI 显示「对方拒绝」+ 连接断开       | <填> |
| 2    | 重发文本（如 `hello 2`）            | 显示「等待对方批准」                          | <填> |
| 2    | mac 端允许并记住                    | android 收到 ACK + 文本投递成功                | <填> |
| 3    | 再发文本（如 `hello 3`）            | **无任何对话框**，直接 ACK + 投递，耗时 < 2s   | <填> |

## 指纹一致性

> 规范：4 字符 × 8 组、空格分隔、全大写，共 32 hex 字符。

- android 设置页 / Me Tab 本机 fp：`<填实测>`
- android 发送时显示的对端（mac）fp：`<填实测>`
- mac 配对卡显示的 android fp：`<填实测>`
- 双端对照一致：✅ / ❌

## 关键观察
- ...

## 偏离 / 异常
- ...（见根 PR 描述的「代码级 spot check 发现」段；尤其 `PairingSheet` 未实装）

## 协议层引用
- protocol/security.md §配对
- protocol/security.md §指纹显示规则
- protocol/conformance-tests.md §C5

## 证据清单（本目录）
- `RESULT.md`              — 本文件
- `send.mp4`               — 发送端（android emulator/真机）屏录，三轮拼接
- `recv.mp4`               — 接收端（mac）屏录副本
- `send.log`               — `adb logcat -s ShareEngine:* MdnsDiscovery:* PairingSheet:*` 节选
- `recv.log`               — mac Console.app 导出
- `me-tab-fp.png`          — android Me Tab 上本机指纹截图（人工核对源）
- `pairing-pending.png`    — 步骤 1/2 android 端「等待对方批准」状态截图
- `pairing-rejected.png`   — 步骤 1 拒绝后 android 端 UI 状态截图
- `direct-receipt.png`     — 步骤 3 直接投递成功截图
