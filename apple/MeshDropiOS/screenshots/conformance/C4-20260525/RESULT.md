# C4 — ios → mac 大文件 4 GiB 分片 — 发送端（iOS）— 2026-05-25

> 本文件由 conformance/c4 脚手架预填，**真机跑完后需回填**：
> 1. 发送端 / 接收端 commit hash（必须在 `main` 上）
> 2. 网络环境与实测耗时
> 3. 结果 PASS / FAIL（由 chunk-size-histogram.txt 与 sha256.txt 决定）
> 4. 「关键观察」与「偏离 / 异常」

| 项             | 值                                              |
| -------------- | ----------------------------------------------- |
| 发送端 commit  | `<TODO: git rev-parse HEAD>`                    |
| 接收端 commit  | `<TODO: git rev-parse HEAD>`                    |
| 网络           | `<TODO: wifi/eth + 带宽，例：千兆有线 1 Gbps>` |
| 结果           | `<TODO: PASS / FAIL>`                           |
| 耗时           | `<TODO: 实测，例：42s>`                         |

## 关键观察

- `<TODO: progress 是否单调上升、有无回退、最长卡顿 < 3s>`
- `<TODO: chunk-size-histogram.txt 中 max frame length 与 4 MiB + 29 = 4194333 的对比>`
- `<TODO: 双方 sha256 是否一致（见 sha256.txt）>`

## 偏离 / 异常

- `<TODO: 若 PASS 且无异常写"无"；若 FAIL 写明现象 + 是规范问题还是端实装 bug>`

## 协议层引用

- transport.md §大小限制（frame.length ≤ 16 MiB；FILE_CHUNK data ≤ 4 MiB）
- messages.md §0x30 `FILE_CHUNK`（`transfer_id` 16B / `index` u32 BE / `offset` u64 BE）
- messages.md §0x20 `FILE_OFFER` / §0x21 `FILE_ACCEPT` / §0x23 `FILE_COMPLETE`

## 代码层静态预判（脚手架预填，仅供参考）

参考 commit：`587b2ff` (`protocol: 新增互通一致性测试规范 (C1-C8) (#21)`)

| 项                         | 实装值                | 规范要求          | 结论 |
| -------------------------- | --------------------- | ----------------- | ---- |
| `Frame.maxLength`          | 16 MiB (`16*1024*1024`) | ≤ 16 MiB          | 合规 |
| `FileChunkHeader.size`     | 28 B (16+4+8)         | 28 B              | 合规 |
| 发送 chunk data 大小       | 256 KiB (`256*1024`)  | ≤ 4 MiB           | 合规 |
| 单 FILE_CHUNK frame.length | 28 + 1 + 256 KiB ≈ 262 173 B | ≤ 4 MiB + 29 = 4 194 333 B | 合规 |

引用：
- [apple/Sources/MeshDropKit/Frame.swift:12](../../../../Sources/MeshDropKit/Frame.swift)
- [apple/Sources/MeshDropKit/Messages.swift:76](../../../../Sources/MeshDropKit/Messages.swift)
- [apple/Sources/MeshDropKit/ShareEngine.swift:540](../../../../Sources/MeshDropKit/ShareEngine.swift)

静态预期：4 GiB / 256 KiB = **16 384 个 chunk**，每个 frame ≈ 262 173 B，max 应远小于 4 MiB + 29。

## 跑测步骤（与 `run-c4.sh` 配合）

1. iOS 端 `xcodebuild` 出 .app，装到真机 / Simulator；Mac 端同样。
2. 两端在同一 Wi-Fi / 有线网；先完成 TOFU 配对（C5 路径）。
3. Mac 上 `bash run-c4.sh prepare`：在本目录生成 `bigfile.bin` (4 GiB) + 写入 `sha256.txt` 上半（发送侧 hash）。
4. 把 `bigfile.bin` 传入 iOS 端（Simulator 用 `xcrun simctl push` 或直接 drag；真机用 AirDrop）。
5. iOS DiscoverTab → 选 Mac → 选 `bigfile.bin` 发送 → 同时开 iOS 屏录。
6. Mac 接受 → 等完成（千兆 35–50s）→ 同时开 Mac 屏录（Cmd+Shift+5）。
7. 双方屏录截 ≥ 30s 拼接段，保存 `send.mp4` / `recv.mp4`。
8. Mac 上 `bash run-c4.sh collect`：
   - 抓取 osLog subsystem=`com.welape.meshdrop` 的 Engine 行 → `send.log` / `recv.log`
   - awk 统计 frame length → `chunk-size-histogram.txt`
   - 接收侧 sha256sum 追加到 `sha256.txt` 下半
9. 回填本 RESULT.md 中 `<TODO>` 项 → commit。
