# C4 — ios → mac 大文件 4 GiB 分片 — 接收端（macOS）— 2026-05-25

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
- `<TODO: Mac 端落盘路径（默认在 ~/Documents/MeshDrop/<peer>/bigfile.bin）+ Finder 截图>`

## 偏离 / 异常

- `<TODO: 若 PASS 且无异常写"无"；若 FAIL 写明现象 + 是规范问题还是端实装 bug>`

## 协议层引用

- transport.md §大小限制（frame.length ≤ 16 MiB；FILE_CHUNK data ≤ 4 MiB）
- messages.md §0x30 `FILE_CHUNK`（`transfer_id` 16B / `index` u32 BE / `offset` u64 BE）
- messages.md §0x20 `FILE_OFFER` / §0x21 `FILE_ACCEPT` / §0x23 `FILE_COMPLETE`

## 代码层静态预判（脚手架预填，仅供参考）

参考 commit：`587b2ff` (`protocol: 新增互通一致性测试规范 (C1-C8) (#21)`)

接收侧关键代码：[apple/Sources/MeshDropKit/ShareEngine.swift:605](../../../../Sources/MeshDropKit/ShareEngine.swift) `handleReceivedChunk`。
逐 chunk `handle.write(contentsOf: payload)` 写盘 + 累加 `receivedBytes`，
到达 `fileSize` 后流式 sha256 校验，匹配则发 `FILE_COMPLETE`，
不匹配则删文件并标 history `.failed("校验失败")`。

| 项                          | 实装值                | 规范要求          | 结论 |
| --------------------------- | --------------------- | ----------------- | ---- |
| frame 接收最大长度           | 16 MiB                | ≤ 16 MiB          | 合规 |
| chunk header 解析            | 28 B fixed            | 28 B              | 合规 |
| sha256 校验                 | 收齐后流式 1 MiB 块   | 必须校验          | 合规 |

引用：
- [apple/Sources/MeshDropKit/ShareEngine.swift:605](../../../../Sources/MeshDropKit/ShareEngine.swift) `handleReceivedChunk`
- [apple/Sources/MeshDropKit/ShareEngine.swift:686](../../../../Sources/MeshDropKit/ShareEngine.swift) `sha256OfFile`

## 跑测步骤（与 `run-c4.sh` 配合）

1. 双方 app 已起；Mac 端确认 `~/Documents/MeshDrop/` 所在盘 ≥ 5 GiB 可用。
2. iOS 端发起 FILE_OFFER → Mac 端弹 `FileOfferSheet` → 点接受 → 同时开屏录。
3. 完成后保存 ≥ 30s 拼接屏录为 `recv.mp4`。
4. 在本目录跑 `bash run-c4.sh collect-recv`：
   - 抓最近 5 分钟内 Engine 子系统 log → `recv.log`
   - 对落盘文件 sha256sum → 追加到 `sha256.txt` 下半（接收侧 hash）
   - awk 统计 `recv.log` 中 FILE_CHUNK frame length → `chunk-size-histogram.txt`
5. 回填本 RESULT.md 中 `<TODO>` 项 → commit。
