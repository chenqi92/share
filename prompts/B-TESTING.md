# MeshDrop · Backend 接入轮测试 + 验收标准

## 测试矩阵（C1~C8）

每端 PR 必须通过其中 **至少 3 个用例**（含 C1）。所有用例都对 `macOS` 这个 reference 端互通。

| 用例 | 内容 | 必过 |
| --- | --- | --- |
| **C1** | 与 macOS 互发一段文本（≤ 100 字符），双方 history 出现该条 | ✅ |
| **C2** | 与 macOS 互发一个 1~10 MB 文件，SHA-256 校验通过 | 推荐 |
| **C3** | 与 macOS 完成一次配对（TOFU），下次连接不再提示 | 推荐 |
| **C4** | 大文件（≥ 100 MB）分片传输，中途无中断 | 可选 |
| **C5** | 与 macOS 同时双向发文件（双工） | 可选 |
| **C6** | 拔网 → 等 ≥ 30s → 重连，对端能自动重新发现并标 online | 可选 |
| **C7** | 拒绝 incoming offer，对端能看到 "已拒绝" 状态 | 可选 |
| **C8** | 中文文件名 / emoji 文件名传输不乱码 | 可选 |

## Companion 端的额外用例

| 端 | 用例 | 说明 |
| --- | --- | --- |
| Apple Watch | C-W1: 通过 iPhone 桥接发文本给 mac | 用 WatchConnectivity 走通 |
| Apple Watch | C-W2: phone 断连时 watch UI 提示 OFFLINE | |
| Wear OS | C-W3: 通过 Android 桥接发文本给 mac | DataLayer |
| Wear OS | C-W4: phone 断连时 wear UI 提示 OFFLINE | |
| Web | C-W5: Safari 进 mac gateway 收发文本 | TLS 自签证书首次接受流程 |
| Web | C-W6: 浏览器关页 → 重开，session 失效 / 重新输入 6 字符码 | |

## 验收 checklist（PR 必带）

```
- [ ] UI 已删 MockData 引用（Preview 仍用 mock 不计）
- [ ] Engine 已接入（grep ShareEngine.shared / MeshDropEngine.Instance / Engine::new 等可见）
- [ ] Loading 态 / 错误态 / 空态都已实装（COMMON §错误处理）
- [ ] 跑过 C1（至少与 mac 互发文本成功）
- [ ] 屏录 ≥ 10s 演示真实互通（不是 mock）
- [ ] commit 中文，无 AI 署名
- [ ] git status 显示只动了本端目录
- [ ] 没动 protocol/{discovery,messages,transport,security}.md
- [ ] 编译一次过（各端 build 命令在 B-prompt 末尾）
```

## 跨端互通测试矩阵（最终回归测试，所有端都合后跑一遍）

```
         mac  ios  ipd  and  win  lgu  ltu  tv   vis  wch  wer  web
   mac    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   ios    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   ipd    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   and    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   win    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   lgu    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓
   ltu    ✓    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓
   tv     ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓
   vis    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓
   wch    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    -    -
   wer    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    -    -
   web    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    -    -
```

`-` 表示**不要求**互通（companion 端不直接互发）。

回归测试不是每端 PR 必须，是 **本轮全部 PR 合完后**单独做一次。

## PR 模板（复制到 PR body）

```markdown
## 端
<端名>

## 接入方式
- [ ] Native LAN（用 Engine.shared）
- [ ] Watch Bridge（WatchConnectivity）
- [ ] Wear Bridge（WearableDataLayer）
- [ ] Web Gateway client

## 跑过的用例
- [ ] C1 文本互通 ✓ <附 mp4 链接>
- [ ] C2 文件互通 ✓ <附 mp4 链接>
- [ ] C3 配对  
- [ ] ...

## 互通证据
- 屏录 mp4: <附件>
- 日志摘要:
  ```
  <log>
  ```

## 协议歧义（如有）
PROTOCOL ISSUE: <无 / 描述>

## 验收 checklist
- [ ] UI 已删 MockData 引用
- [ ] Loading/错误/空态都有
- [ ] commit 无 AI 署名
- [ ] git status 只动本端目录
- [ ] 编译一次过
```
