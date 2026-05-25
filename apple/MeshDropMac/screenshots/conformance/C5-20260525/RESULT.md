# C5 - android → mac 配对（TOFU） - 2026-05-25

> 接收端（mac）侧 RESULT。Android 侧见
> `android/screenshots/conformance/C5-20260525/RESULT.md`。

| 项                | 值                                       |
| ----------------- | ---------------------------------------- |
| 发送端 commit     | <android commit hash>                    |
| 接收端 commit     | 587b2ffe140d41721a0c32062507aa4eaa501d0c |
| 网络              | <wifi/eth + 带宽，例：Wi-Fi 5GHz 866Mbps> |
| 结果              | PASS / FAIL                              |
| 耗时（步骤 1-7）  | <实测>                                   |

## 三轮观察表

| 轮次 | 操作                  | 期望                                    | 实测 |
| ---- | --------------------- | --------------------------------------- | ---- |
| 1    | android 首次发送      | mac 弹配对卡，trusted 无新条目          | <pass/fail + 备注> |
| 1    | mac 点「拒绝」        | android 收到 reject，mac trusted 仍空   | <pass/fail + 备注> |
| 2    | android 再次发送      | mac 再弹配对卡                          | <pass/fail + 备注> |
| 2    | mac 点「允许并记住」  | mac trusted 列表新增 1 条该 fp          | <pass/fail + 备注> |
| 3    | android 第三次发送    | mac 直接收到，**不弹卡**，< 2s          | <pass/fail + 备注> |

## 指纹一致性

> 规范：4 字符 × 8 组、空格分隔、全大写，共 32 hex 字符。

- mac 配对卡（PairingPage）显示：`<填实测，如 AB12 34CD ... DEF0>`
- android 设置页 / Me Tab 显示：`<填实测>`
- 是否字节相等：✅ / ❌
- 如果不等：在 PR 描述区列 hex 对比并开 issue（这是协议 bug）

## mac trusted 列表

- 步骤 4 后（拒绝后）：`trusted-list-after-reject.png` — 应无该 fp 条目
- 步骤 6 后（允许并记住后）：`trusted-list-screenshot.png` — 应有该 fp 条目
- 持久化文件：`~/Library/Application Support/MeshDrop/trust.json`
  - 录入快照：`trust.json.snapshot` 保留步骤 6 后的内容（结构化对照）

## 关键观察
- ...

## 偏离 / 异常
- 见 PR 描述的「代码级 spot check 发现」段落（如 Android PairingSheet 未实装、Mac TrustPage 分隔符等）。
- ...

## 协议层引用
- protocol/security.md §配对（TOFU 三选项 + trusted 写入语义）
- protocol/security.md §指纹显示规则（4×8 大写 hex 空格分隔）
- protocol/conformance-tests.md §C5

## 证据清单（本目录）
- `RESULT.md`                       — 本文件
- `recv.mp4`                        — 接收端（mac）屏录，三轮拼接：拒绝 / 允许并记住 / 直连
- `send.mp4`                        — 发送端（android）屏录副本（与 android 端目录同源）
- `recv.log`                        — mac 端 `Console.app` 中 `subsystem == com.welape.meshdrop` 的过滤导出
- `send.log`                        — android `adb logcat -s ShareEngine:* MdnsDiscovery:*` 节选
- `trusted-list-after-reject.png`   — 步骤 4 后 trusted 列表截图（应为空）
- `trusted-list-screenshot.png`     — 步骤 6 后 trusted 列表截图（应有新条目）
- `trust.json.snapshot`             — 步骤 6 后 `~/Library/Application Support/MeshDrop/trust.json` 的 JSON 快照
