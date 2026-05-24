# MeshDrop · 跨端测试流程 + 验收标准

> 这份文档既是 AI 自测清单，也是用户合并 PR 时的对照表。
> 任何端 PR 必须能通过 **A** 单端测试 + **B** 至少与一个其他端跑通 C5 用例。

---

## A. 单端测试矩阵（每端开 PR 前必跑）

### A1 · 构建 / 静态检查

| 端 | 命令 | 退出码标准 |
| --- | --- | --- |
| macOS | `cd apple/MeshDropMac && xcodegen generate && xcodebuild -project MeshDropMac.xcodeproj -scheme MeshDropMac -destination 'platform=macOS' build` | 0，0 ⚠ error，warning ≤ 5 |
| iOS Sim | `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build` | 同上 |
| iOS 真机 | `xcodebuild ... -destination 'platform=iOS,id=<UDID>' -allowProvisioningUpdates build` | 同上 |
| Android | `cd android && ./gradlew :app:assembleDebug` | 0，0 error，lint ≤ 10 warn |
| Windows | `cd windows && dotnet build MeshDrop.sln -c Debug -p:Platform=x64` | 0，0 error |
| Linux core | `cd linux && cargo check --workspace` | 0，0 error |
| Linux GUI | `cargo build --release -p meshdrop-gui`（Linux 系统） | 0 |
| Linux TUI | `cargo build --release -p meshdrop-tui` | 0 |

### A2 · 单元测试

| 端 | 命令 | 通过率 |
| --- | --- | --- |
| Apple MeshDropKit | `cd apple && swift test` | 100%（含 Frame / Messages / TXT roundtrip） |
| Linux core | `cargo test --workspace` | 100% |
| Windows | `dotnet test` | 100% |
| Android | `./gradlew test` | 100% |

### A3 · 启动后 5 秒检查

| 端 | 期望 |
| --- | --- |
| 所有端 | 进程不崩；mDNS 注册成功；本机 self-card 显示正确 displayName + 指纹 |
| 用 `dns-sd -B _meshdrop._tcp` 浏览 | 看到自己设备的 instance 名 = 自己的 32-hex device id |
| 用 `dns-sd -L <instance> _meshdrop._tcp` | TXT 含 `v=1 id=<32hex> name=<base64url> os=<...> model=<...> fp=<32hex> port=<...>` |

### A4 · 视觉对齐（截图自查）

打开 `__DESIGN_MESHDROP_PATH__scrn-1.jpg` 和对应的 `__DESIGN_MESHDROP_PATH__screens-<platform>.jsx`，
**逐项对照**：

- [ ] **品牌**：app 内任何位置不见"MeshDrop / 至汝 / drop.mesh / __FREQ_MESHDROPE__"残留
- [ ] **logo**：dock / 任务栏 / 状态栏图标含 lime 圆点
- [ ] **配色**：paper #F5F2EC 主背景（不是纯白），lime #DDF94B 强调（不是绿松石、不是黄绿）
- [ ] **字体**：display 是 Space Grotesk，mono 是 Geist Mono（不是 SF Pro / Consolas / Roboto）
- [ ] **outgoing 气泡**：light 用 ink #0A0A0A 黑底 paper 字；dark 用 lime 底 ink 字
- [ ] **状态色**：在线 limeDeep，发送 flame，接收 sky，完成 limeDeep ✓，失败 #C4322B
- [ ] **ASCII divider**：分节标题前后用 mono 全大写 `── TODAY · TODAY · 5 件 ──`
- [ ] **指纹分组**：4 字符 · 4 字符（不是连写、不是 6-6-6）
- [ ] **chip 高度**：固定 20pt，圆角 999
- [ ] **暗模式不是反相**：按宪法 §7 逐项映射

---

## B. 跨端互通用例（C1~C8，至少 5 个通过）

测试矩阵 `M × N`（M = 你这端，N = 任意其他端）：

### C1 · 设备互发现
> 两端启动 → 1 秒内互相在 Nearby 列表显示对方 displayName + RTT
> 不通过：5 秒后仍看不到 → 检查同 Wi-Fi、`dns-sd -B _meshdrop._tcp`

### C2 · 首次配对（陌生设备）
> A 发送 → B 弹 PairingSheet 显示 A 的指纹 → B 用户点"允许并记住" →
> 双方都进入聊天流；B 端 trust store 写入 A 的指纹
> 不通过：B 没弹框 / 指纹显示不全 / 同意后仍报错

### C3 · 文本互发
> A → B 发 "hello, world. 你好"，B 端 history 立刻显示 incoming text；
> 反向 B → A 同样
> 不通过：UTF-8 中文乱码 / emoji 丢失 / 历史项缺失

### C4 · 小文件互发 + SHA-256 校验
> A 选 1 个 50 KB ~ 5 MB 文件 → 发送 →
> B 端弹 FileOfferSheet，显示文件名 + 大小 + 来源 →
> 接受 → 进度从 0% 到 100% →
> B 端 history 完成项 + 文件存到 ~/Downloads/MeshDrop/<A 名>/ 或对应 sandbox →
> 文件可打开内容完整
> 不通过：SHA 校验失败 / 文件损坏 / 进度不更新

### C5 · 大文件 + 进度 + ETA
> A → B 发 1 个 200~500 MB 文件 →
> 两端进度条 0~100% 平滑变化 / 速度 MB/s mono 字段每秒更新 / ETA 字段倒计时 →
> 完成后 B 端文件 SHA 校验通过
> 不通过：>30 秒进度卡死 / 速度 0 / 接收端进程被杀

### C6 · 历史单条删除
> A 端 history 右键 / 长按某条 → 删除 → 列表中消失（但盘上文件保留）；
> 重启 app 后该条不再出现
> 不通过：清空全部 history 才删 / 重启又恢复

### C7 · 拒绝接收
> A 发文件给 B → B 选拒绝 →
> A 端 history 项状态变为 `失败：对方拒收` 红色徽标 →
> B 端不留任何记录
> 不通过：A 端无反馈 / B 端文件仍下载

### C8 · 离线 / 网络断开恢复
> 两端互发文本，然后 B 关 Wi-Fi 10 秒，重连 →
> A 端 5~30 秒内将 B 标记为 offline（灰色 / 不在 Nearby）→
> B 重连后 5 秒内 A 端重新显示 B online
> 不通过：B 永久 stale 在列表 / 重连后必须重启 app

---

## C. 视觉对齐 checklist（PR 审核用）

针对每张提交的截图：

```
□ 背景色对（paper / dink，不是 white / pure-black）
□ 文字色对（不是 system label 默认蓝灰）
□ 字体对（一眼能看出是 Space Grotesk 几何感，不是 SF Pro）
□ logo dot 在
□ chip 是胶囊形且正确 tone
□ ASCII divider 在分节处出现
□ 指纹是 4-4-... 格式
□ 状态色对应正确语义（lime=online、flame=outgoing、sky=incoming）
□ 暗模式 outgoing 气泡是 lime 不是黑
□ Radar sweep arm 在转
□ 没有遗留 MeshDrop 字样
```

---

## D. 性能基线

| 指标 | 标准 | 测法 |
| --- | --- | --- |
| 冷启动到见首屏 | < 1.5s（移动）/ < 0.8s（桌面） | 手测秒表 |
| 雷达 ↔ 设备列表帧率 | ≥ 50 fps | macOS Instruments / Android Profiler / Win PerfView |
| 100 MB 文件传输 LAN 速度 | ≥ 30 MB/s（千兆 LAN） | 自带 SpeedChart |
| 内存峰值（空载） | < 80 MB（桌面）/ < 60 MB（移动） | Activity Monitor / Android Studio Profiler |
| 内存峰值（5 个并发传输） | < 200 MB | 同上 |
| CPU 空载 | < 1% | 同上 |

---

## E. PR 模板

每端 PR body 必须含：

```markdown
## 摘要
<一句话总结这次改了什么>

## 截图（光 + 暗）
<对应端 prompt 要求的全部截图>

## 测试
- [ ] A1 构建通过
- [ ] A2 单元测试通过
- [ ] A3 启动后 dns-sd 抓到正确 TXT
- [ ] A4 视觉对齐 checklist 全过
- [ ] B 与 <某端> 跑通 C1+C3+C4 至少
- [ ] D 性能基线满足

## 互通短视频
<5~15s 屏录，演示与其他端互发>

## 已知 TODO
<明确列出未做完的，不要静默删功能>

## 风险点
<任何用户合 PR 前需要知道的副作用 / 兼容性 / 协议升级提示>
```

---

## F. 不通过会怎样

PR 退回，理由会标注在以下分类：

- ❌ **A0 编译失败** — 必须改到 build 干净再提
- ❌ **A1 协议不合规** — TXT 字段缺失 / service type 错 / 字节序错 → 看 `protocol/`
- ❌ **A4 视觉漂移** — 截图配色 / 字体 / 文案与设计稿差太远 → 重新看 DESIGN_SPEC
- ❌ **B 互通失败** — 你的端与 macOS 实测发不出去 / 收不到 → 跨端协议层有 bug
- ❌ **D 性能崩盘** — 大文件传输卡死 / 内存爆 → 流式 + 异步该用没用
- ❌ **遗留 MeshDrop 字样** — 任何字符串里出现 → grep -r 一遍再提

---

## G. 验收会做什么

用户会同时在 5 端打开 app，依次：

1. **看见**：5 个端互相 6 秒内全部出现在 Nearby（含 RTT 和正确 OS icon）
2. **写**：在 macOS 给 Android 发一行中文 + emoji，1 秒内 Android 收到
3. **拖**：在 macOS Finder 拖 1 张 5MB 图到 macOS MeshDrop 窗口里的 iPad 设备 row，
   iPad 上弹接收 sheet，接受，3 秒内出现在 iPad 相册
4. **大**：iPhone 选 1 段 1 分钟 4K 视频（~500 MB）发到 Windows，Windows 上看见
   进度 + 速度 + ETA，完成后视频 SHA 一致
5. **关**：拔 Android 网，5~30 秒内其他 4 端把 Android 标 offline，重连后再变 online
6. **看脸**：所有端 dock/任务栏图标都是 meshdrop mark（lime dot），任何 UI 文本搜不到
   "MeshDrop / 至汝 / drop.mesh"

通过 → 合并到 main。任一项失败 → 该端 PR 退回重做。
