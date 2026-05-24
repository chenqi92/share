# 互通一致性测试（conformance tests）

各端实装必须能通过本目录列出的用例。每个用例编号 `Cn` 全仓库稳定，PR /
commit message / issue 可直接引用。新增用例统一追加在末尾，**已分配编号永不重排**。

## 一、运行约定

### 环境

- **网络**：同一 LAN（千兆有线或同一 Wi-Fi BSSID，不跨 VLAN）。
- **可见性**：测试期间所有参与设备均启用「全设备可见」模式。
- **协议版本**：`v=1`（mDNS TXT `v` 字段与 HELLO `protocol_versions` 都是 `[1]`）。
- **加密**：v0.1 骨架阶段允许明文；v1.0 起 conformance 必须在 TLS 1.3 + mTLS 下跑。
  本表先按明文跑，加密接入后整体重跑一次并标记 `Cn-TLS`。
- **构建**：所有参与端的 commit 必须在 `main` 上；测试时把 commit hash 写进 RESULT.md。

### 证据采集

每个用例的证据落到 **双端各自仓库目录** 下的同名子目录：

```
<端目录>/screenshots/conformance/C<n>-<YYYYMMDD>/
  ├── RESULT.md           — 通过 / 失败 + 关键观察 + 双方 commit hash
  ├── send.mp4            — 发送端屏录（≥ 用例完整时长）
  ├── recv.mp4            — 接收端屏录
  ├── send.log            — 发送端 console / app log 节选（仅 frame / engine 相关行）
  ├── recv.log            — 接收端 console / app log 节选
  └── sha256.txt          — 涉及文件传输的用例：双方 sha256sum 输出
```

端目录映射：

| 端         | 目录                                    |
| ---------- | --------------------------------------- |
| macos      | `apple/MeshDropMac/screenshots/conformance/` |
| ios        | `apple/MeshDropiOS/screenshots/conformance/` |
| tvos       | `apple/MeshDropTV/screenshots/conformance/`  |
| visionos   | `apple/MeshDropVision/screenshots/conformance/` |
| android    | `android/screenshots/conformance/`     |
| windows    | `windows/screenshots/conformance/`     |
| linux-gui  | `linux/screenshots/gui/conformance/`   |
| linux-tui  | `linux/screenshots/tui/conformance/`   |
| watch      | `apple/MeshDropWatch/screenshots/conformance/` |
| wearos     | `wearos/screenshots/conformance/`      |

### RESULT.md 模板

```markdown
# C<n> - <用例名> - YYYY-MM-DD

| 项             | 值                            |
| -------------- | ----------------------------- |
| 发送端 commit  | <hash>                        |
| 接收端 commit  | <hash>                        |
| 网络           | <wifi/eth + 带宽>             |
| 结果           | PASS / FAIL                   |
| 耗时           | <实测>                        |

## 关键观察
- ...

## 偏离 / 异常
- ...（若 PASS 且无异常写"无"）

## 协议层引用
- discovery.md §...
- transport.md §...
- messages.md §0xXX
- security.md §...
```

### 失败处理

- 失败也必须出 PR + RESULT.md 注明 FAIL 原因。
- 怀疑是 **规范问题**：在 PR 描述里指出，不直接修业务代码；另起 `protocol/proposal-*.md` 走规范修订流程（见 README §兼容性策略）。
- 怀疑是 **某端实装 bug**：在 PR 描述里 `@` 该端 owner，并打开对应 issue；conformance PR 仍然合（记录证据），bug 在另一 PR 修。

## 二、用例矩阵

每个 cell 标注首要 conformance 编号；同一对端可有多个用例的写多个。

|              | mac     | ios     | android | win | linux-gui | linux-tui |
| ------------ | ------- | ------- | ------- | --- | --------- | --------- |
| **mac**      | --      | C1 C4 C7 | C2     |     |           |           |
| **ios**      | C1 C4 C7 | --     |         |     |           |           |
| **android**  | C2 C5   |         | --      |     |           |           |
| **win**      |         |         |         | --  | C3        | C6        |
| **linux-gui**|         |         |         | C3  | --        |           |
| **linux-tui**|         |         |         | C6  |           | --        |
| **共余**     | C8 (mac↔android, 任一方拔网) |

> 矩阵留白处不代表"不需要测"，只是当前 8 用例没覆盖；新加用例往末尾追加并填入矩阵。

## 三、用例

### C1 — mac ↔ ios 文本互发

**目的**：HELLO 握手 + TEXT (`0x10`) 在跨 Swift 端的双向 wire 兼容；中文 / Emoji 不乱码。

**协议层覆盖**：discovery.md TXT 解析 · transport.md framing · messages.md §0x01 §0x02 §0x10

**前置**：
- mac 与 iPhone 在同一 Wi-Fi
- 双方 trusted 库已包含对方 `fp`（或先跑一遍 C5 完成 TOFU）

**步骤**：
1. mac 选 iPhone → 发文本 `测试 1 · ASCII abc 123`
2. iPhone 收到 → UI 显示该条 → 回复 `测试 2 · 中文 + Emoji 🌧️🚀`
3. mac 收到 iPhone 的回复 → UI 显示在历史

**期望**：
- 双方 UI 显示对方消息 < 2s
- 中文 + Emoji 字节完全一致（log 中打印消息 hex 对比）
- 两端 history 都有这两条
- 无 frame parse error

**PASS 判据**：双方收到的 TEXT JSON `content` 字段 bytes 相等；history 各有 2 条。

**证据**：屏录双方 + log 中 `rx/tx TEXT 0x10` 节选 + 收到内容 hex dump。

---

### C2 — mac → android 文件互发（含中文名）

**目的**：FILE_OFFER → ACCEPT → CHUNK → COMPLETE 全链路；中文文件名跨平台无乱码；SHA-256 校验通过。

**协议层覆盖**：messages.md §0x20–0x23 §0x30 · 文件名 UTF-8

**前置**：双方已配对；android 有 100 MB 可用空间。

**步骤**：
1. mac 准备文件 `测试报告 v2 · 含中文与 Emoji 🌧️.pdf`（5.2 MB）
2. 记录 `shasum -a 256 <file>` 到 `sha256.txt`
3. mac DiscoverTab 选 Android → 发送该文件
4. Android 弹出 FileOfferSheet → 接受
5. 等待传输完成 → Android 自动 SHA-256 校验
6. Android 上对落盘文件 `sha256sum <file>` 追加到 `sha256.txt`

**期望**：
- Android FileOfferSheet 文件名显示完全正确（中文 + Emoji）
- chunk 流速 ≥ 5 MB/s（千兆有线 / 5GHz Wi-Fi）
- Android 收到 FILE_COMPLETE
- 双方 sha256 一致

**PASS 判据**：`sha256.txt` 两行 hash 相同；Android UI 显示「已接收」。

**证据**：屏录双方 + sha256.txt + Android Downloads 截图。

---

### C3 — windows → linux-gui 16 KB 小文件

**目的**：小文件单 chunk 完成（chunk 大小自适应到 ≤ 16 KB）；跨 .NET ↔ Rust 实装兼容。

**协议层覆盖**：messages.md §0x30 chunk 头部 `transfer_id` (16) / `index` (4) / `offset` (8) 编码

**前置**：双方已配对。

**步骤**：
1. Windows 端准备 `small.bin`（16 384 字节随机数据，shasum 记录）
2. Windows 发送 → linux-gui
3. linux-gui 接受 → 落盘
4. 双方 `sha256sum`

**期望**：
- 该文件用 1 个 FILE_CHUNK 完成（log 中只见一次 chunk tx/rx）
- chunk header 中 `transfer_id` 16 bytes / `index=0` / `offset=0`
- 总耗时 < 1s

**PASS 判据**：sha256 一致；log 中 chunk 计数 = 1。

**证据**：屏录 + sha256.txt + 双方 log 中 chunk frame 解析行。

---

### C4 — ios → mac 大文件 4 GiB 分片

**目的**：大文件分片正确；单 chunk ≤ 4 MiB（transport.md §大小限制）；progress 平稳；耗时合理。

**协议层覆盖**：messages.md §0x30 · transport.md §大小限制

**前置**：mac 有 5 GiB 可用空间；iOS 端有 4 GiB 视频或可用 `dd` 生成的占位文件。

**步骤**：
1. iOS 准备 `bigfile.bin`（4 294 967 296 字节，准确 4 GiB；`shasum` 记录）
2. iOS DiscoverTab 选 mac → 发送
3. mac 接受
4. 双方观察 progress
5. 完成后双方 `sha256sum`

**期望**：
- progress 单调上升、无回退、无卡死 > 3s
- log 中任何一个 FILE_CHUNK 的 frame length ≤ 4 MiB + 29（chunk header）
- 千兆环境总耗时 35-50s（理论极限 ~34s）
- 双方 sha256 一致

**PASS 判据**：sha256 一致；所有 chunk 大小合法。

**证据**：屏录双方 (≥ 30s 拼接) + sha256.txt + log 中 chunk size 统计（`awk` 或 `grep`）。

---

### C5 — android → mac 配对（TOFU）

**目的**：首次连接配对对话框 + 信任写入 + 复用；指纹显示规则（4 字符 × 8 组）。

**协议层覆盖**：security.md §配对 · §指纹显示规则

**前置**：mac trusted 库**完全清空**；mac 设置里执行「移除所有信任」或删 keychain item。

**步骤**：
1. Android 首次发送任意文本 → mac 弹配对卡
2. mac 配对卡上对照指纹格式：`AB12 34CD 56EF 7890 1234 5678 9ABC DEF0`（4×8 大写 hex 分组）
3. 与 Android 设置页中显示的本机 fp 用同样格式核对
4. mac 选「拒绝」→ 验证 Android 收到 reject + 未写入 mac trusted 库
5. Android 再次发送 → mac 弹配对卡 → 选「允许并记住」
6. 验证 mac trusted 库出现该 fp 条目
7. Android 第三次发送 → mac 直接收到（无弹卡）

**期望**：
- 指纹两侧严格一致
- 步骤 4 后 mac trusted 列表无新条目
- 步骤 5 后 mac trusted 列表新增 1 条：`fp` + `name` 快照 + 时间戳
- 步骤 7 < 2s 完成，无任何对话框

**PASS 判据**：上述全部观察通过。

**证据**：3 段屏录（拒绝 / 允许并记住 / 直连）+ mac trusted 列表截图（步骤 6 后）。

---

### C6 — linux-tui → windows 拒收

**目的**：FILE_REJECT 流程 + 发送端正确传播失败状态 + CLI 退出码规范。

**协议层覆盖**：messages.md §0x22

**前置**：双方已配对。

**步骤**：
1. linux-tui 执行：
   ```
   meshdrop-tui send-file <windows-id> ./reject-test.bin
   ```
   （`reject-test.bin` 1 MiB）
2. Windows 弹 FileOfferSheet
3. Windows 选「拒绝」
4. linux-tui 收到 reject → 退出
5. 检查 linux-tui exit code + windows Downloads

**期望**：
- linux-tui stderr 输出 `rejected: user_declined`（或同义中文）
- linux-tui exit code 非 0（约定 `3` for `rejected`，未来加 CLI 规范文档时固定）
- Windows Downloads 目录无 `reject-test.bin`
- 双方 log 中可见 `FILE_OFFER` 与 `FILE_REJECT` frame；**无 FILE_CHUNK**

**PASS 判据**：上述全部观察通过；linux-tui 进程未泄漏。

**证据**：屏录（Windows 端弹窗→点拒绝）+ linux-tui terminal cast (asciinema 或 mp4) + `echo $?` 截图 + windows Downloads 目录截图。

---

### C7 — mac ↔ ios 同时双向发文件

**目的**：transport.md「允许多条并发」；transfer_id 不冲突；UI 双进度条独立。

**协议层覆盖**：transport.md §连接 · messages.md `transfer_id` 唯一性

**前置**：双方已配对；各自准备 100 MiB 文件，sha 记录。

**步骤**：
1. 同步操作：mac 选 iOS 发 `mac-to-ios.bin`；iOS 选 mac 发 `ios-to-mac.bin`（两侧操作差 < 1s）
2. 双方 UI 应各出现 2 条 transfer：1 条 out + 1 条 in
3. 等待两条都完成
4. 双方 sha256 对各自收到的文件

**期望**：
- 两条 transfer 进度各自单调推进，互不阻塞
- 两个 transfer_id 不同（log 验证）
- 总耗时 ≤ 单向耗时 × 1.6（千兆双向竞争实测值）

**PASS 判据**：两份 sha256 都一致；UI 同时显示 2 条 transfer。

**证据**：屏录双方（同一时间窗口）+ sha256.txt 含 4 行 hash + log 中 2 个 transfer_id。

---

### C8 — 拔网重连恢复（mac ↔ android）

**目的**：chunk 中断后接收方持久化进度；重连后 `FILE_ACCEPT.resume_offset > 0`；不重传已收部分。

**协议层覆盖**：messages.md §0x21 `resume_offset` · transport.md §错误处理「连接中断」

**前置**：双方已配对；android 存储足够；mac 用 Wi-Fi（便于断连）。

**步骤**：
1. mac 准备 500 MiB 文件 `resume-test.bin`（shasum 记录）
2. mac 发送 → android 接受
3. 等待进度到 **40-60% 之间**
4. mac 关 Wi-Fi（菜单栏点关闭，非物理拔）
5. 等 10s
6. mac 重开 Wi-Fi（同一 SSID）
7. android UI 提示「连接中断 / 等待续传」；mac 重新发起同一 transfer
8. android 接受 → mac 应从 ~50% 处续传
9. 完成 → sha256 校验

**期望**：
- 步骤 8 中 mac 收到的 `FILE_ACCEPT.resume_offset` ≈ android 持久化的偏移（log 验证）
- 续传耗时 ≈ 剩余 50% 时长（不是 100%）
- 最终 sha256 一致

**PASS 判据**：sha256 一致；log 中 `resume_offset > 0`。

**证据**：屏录（含拔/复网络瞬间）+ sha256.txt + log 中 `resume_offset` 行。

## 四、扩展与版本

- 新增用例：在本文档末尾加 `### Cn — <名>`，**编号自增不重排**；同时在矩阵
  对应 cell 加编号。
- 协议 v2 起：用例编号空间共享，但每条用例的「前置」需注明 `protocol >= v?`。
- TLS 接入后：所有 C1–C8 需重跑一次明文 + 一次 TLS，证据目录分别加后缀 `-cleartext` / `-tls`。

## 五、PR 引用约定

实装 PR 应在描述里引用本次涵盖的用例编号，例如：

```
backend(android): 修 chunk offset 计算
verified: C2, C3, C5 (重跑)
fails: C4 (offset 越界，issue #42)
```

合规 PR 走 conformance owner（不绑定单端），合并条件：双方端 owner 任一 ✓ + 所有 RESULT.md PASS（或 FAIL 已有对应 issue）。
