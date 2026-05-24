# MeshDrop · linux-tui 端 UI 完整开发 Prompt（自动拼接）

> 这份 prompt 由 prompts/feed.sh 拼接 COMMON.md + 06-linux-tui.md + TESTING_AND_ACCEPTANCE.md 生成。
> 复制整段给 AI，它将拥有从零做出 linux-tui 端 UI 的全部信息。

---

# MeshDrop · 跨端共享上下文

> 这份内容会拼在每个端 prompt 的最前面。AI 读完这份就拥有 MeshDrop 的全部
> 品牌、视觉、组件、mock 数据上下文。**端特定的页面 / 文件组织 / 截图清单
> 在你拿到的 prompt 后半部分。**

---

## 1. 项目是什么

**MeshDrop** 是一款跨 5 平台（macOS / iOS / iPadOS / Android / Windows / Linux）的
局域网分享工具。同一 Wi-Fi 下，任何两台装了 MeshDrop 的设备互相 ping 得到；可发送
文本、文件、剪贴板、文字便签。所有传输走内网 TCP，端到端加密（X25519 +
ChaCha20-Poly1305），不经过云端。

仓库根：`/Users/chenqi/Projects/__WS_FREQ_MESHDROPE__`（GitHub：
[__CHENQI_MESHDROPE__](https://github.com/__CHENQI_MESHDROPE__)）
当前 main 分支。

## 2. 本轮你做什么（UI-FIRST）

**你只做 UI 静态展示，用 mock 数据驱动**。不接 backend、不写网络代码、不动协议
逻辑。等所有端 UI 都做完对齐后，下一轮才把 MeshDropEngine 接进来。

**许做**：
- 全新建 UI 文件（view / component / theme）
- 改 bundle id / package id / namespace（按表）
- 改 service type 字符串到 `_meshdrop._tcp`
- 删掉 / 替换旧的 UI 文件（旧的"MeshDrop / 至汝"全部按下面的视觉重做）
- 用 mock data hardcode 渲染所有页面

**不许做**：
- 改 `protocol/` 目录任何文档
- 改任何与传输 / mDNS / 握手相关的 backend 代码
- 真的接入 MeshDropEngine（保留它，但 UI 用 mock data，不调用真 API）
- 写 socket / TCP / 加密代码
- 创建你这端 prompt 没要求的额外 markdown 文件
- commit / PR 里出现 AI 署名 / 协作者署名

## 3. 历史包袱与重命名

仓库现存的是上一次失败迭代（早期叫 FreqShare → 中期改名 MeshDrop / 至汝），
UI 被用户判定为太丑。**本轮**：品牌中英文统一叫 **MeshDrop**，按新设计语言
（lime + 报纸感 + mono 终端风）重做 UI。

仓库里残留的命名你必须查一遍并清理（grep 应**搜不到**以下旧值）：

| 旧值（仓库可能残留） | 新值 |
| --- | --- |
| `FreqShare` / `freq-share` / `freqshare` | `MeshDrop` / `meshdrop` |
| 至汝（中文名） | MeshDrop（中文也叫 MeshDrop，不再有中文名） |
| `_freqshare._tcp`（更早 service type） | `_meshdrop._tcp` |
| `_shar._tcp`（设计稿曾出现） | `_meshdrop._tcp` |
| `drop.mesh` (Kotlin package) | `com.welape.meshdrop` |
| `drop.mesh.linux` (Linux APP_ID) | `com.welape.meshdrop.linux` |
| `Shar` / `shar` (设计稿曾出现) | `MeshDrop` / `meshdrop` |

**iOS / macOS bundle id 保留** `com.welape.landrop`（你在 App Store Connect
已注册的 App ID，不要动）。

**协议字节序不动**：Frame 格式、消息 type 编号、JSON schema、SHA-256 流程
都不能改。如果你这端代码里还出现 `_freqshare._tcp` 或 `_shar._tcp`，改成
`_meshdrop._tcp` 即可（一行字符串改动）。

## 4. 品牌身份

| 项目 | 值 |
| --- | --- |
| 正式名 | **MeshDrop** |
| Wordmark | `meshdrop.`（小写 + 末尾一个 lime 实心圆点，**点不能省**） |
| 副标题 | `An intranet drop · radar discovery · drag-to-send · E2E encryption` |
| 中文 slogan | "一个内网，任何设备，**谁都能 ping 到。**" |
| 五端特性文案 | "雷达式发现 · 端对端加密 · 拖即发送 · 剪贴板同步 · 文字便签" |
| Bundle id 通用前缀 | `com.welape.meshdrop`（Apple/Android），`MeshDrop`（C# namespace），`com.welape.meshdrop.linux`（Linux APP_ID） |
| mDNS service type | `_meshdrop._tcp.local.` |

### Logo（必须矢量实装）

两个**重叠**圆环（stroke），**中间一个 lime 实心圆点**。viewBox 24×24：

```
<svg viewBox="0 0 24 24">
  <circle cx="9"  cy="12" r="6.5" fill="none" stroke="#0A0A0A" stroke-width="2"/>
  <circle cx="15" cy="12" r="6.5" fill="none" stroke="#0A0A0A" stroke-width="2"/>
  <circle cx="12" cy="12" r="1.8" fill="#DDF94B"/>
</svg>
```

暗色背景下 stroke 改 `#E8E3D6`（dpaper）。

Wordmark：`meshdrop` 小写 + 紧贴的 lime 实心圆点。字体 Space Grotesk weight 600，
letterSpacing -2.5%（负字距）。

## 5. 设计 Tokens（精确复制到你这端的 theme 常量集合）

```
// ─── 颜色 · LIGHT ─────────────────────────────────────────
ink:    #0A0A0A             // 主文字 / 描边
ink80:  rgba(10,10,10,.80)
ink60:  rgba(10,10,10,.60)  // 次文字
ink45:  rgba(10,10,10,.45)  // 三级文字 / muted
ink30:  rgba(10,10,10,.30)
ink12:  rgba(10,10,10,.12)
ink06:  rgba(10,10,10,.06)
paper:  #F5F2EC             // 主背景（报纸感的米白，不是纯白！）
paper2: #EDE8DD             // 次背景
card:   #FFFFFF             // 卡片纯白
line:   #E2DCCD             // 分隔线

// ─── 颜色 · DARK（暗模式不是 light 反相） ─────────────────
dink:   #0E0C09             // 主背景（暖黑，不是 #000）
dink2:  #181612             // 次背景 / 卡片
dink3:  #23201A
dpaper: #E8E3D6             // 主文字
dline:  rgba(255,255,255,.10)

// ─── 三色语义 accent（必须严格按语义分配） ───────────────
lime:      #DDF94B          // ✅ 在线 / 已连接 / Live / Trusted / Discovery
limeDeep:  #A8C800          // lime 深色变体（描边 / 小色块 / done 状态）
flame:     #FF5A2C          // 🟠 发送中 (outgoing) / 主动 / 警告
flameDeep: #C73E15
sky:       #4DB8FF          // 🔵 接收中 (incoming)
error:     #C4322B          // ❌ 失败

// ─── 状态色映射 ───────────────────────────────────────────
state=online      → limeDeep
state=offline     → ink45 (light) / rgba(255,255,255,.5) (dark)
state=sending     → flame (outgoing 方向)
state=receiving   → sky   (incoming 方向)
state=done        → limeDeep + ✓
state=failed      → error + ×
state=queued      → ink45 + ·
```

### 暗模式映射（不能简单反相）

| 元素 | Light | Dark |
| --- | --- | --- |
| 主背景 | `paper` `#F5F2EC` | `dink` `#0E0C09` |
| 卡片底 | `#FFFFFF` | `dink2` `#181612` |
| 文字主 | `ink` | `dpaper` |
| 文字次 | `ink45` | `rgba(255,255,255,.5)` |
| 描边 | `line` `#E2DCCD` | `dline` `rgba(255,255,255,.10)` |
| sidebar/玻璃 | `rgba(255,255,255,.55)` + blur(40px) saturate(180%) | `rgba(255,255,255,.025)` 同 blur |
| **outgoing 气泡** | `ink` 黑底 + `paper` 字 | **`lime` 底 + `ink` 字**（注意！暗色用 lime 黄绿） |
| lime 区域填充 | `rgba(221,249,75,.32)` | `rgba(221,249,75,.10)` 或 `.16` |

## 6. 字体堆栈

```
display: "Space Grotesk", "PingFang SC", "Noto Sans SC", system-ui, sans-serif
body:    "Geist", "PingFang SC", "Noto Sans SC", -apple-system, system-ui, sans-serif
mono:    "Geist Mono", "SF Mono", ui-monospace, Menlo, monospace
```

- **display 字体用于**：大标题、数字（字号 ≥ 18），weight 700，letterSpacing 接近 -0.5 ~ -1
- **body 字体用于**：正文、按钮、标签
- **mono 字体用于**：时间戳、IP、端口、指纹、tag、ETA、bytes、ASCII 装饰、CODE 区块

### 字号阶梯

| 用途 | 字号 | 字重 | 字体 |
| --- | --- | --- | --- |
| Hero 大标题（Discovery 主屏） | 26~38 | 700 | display |
| Section 标题 | 18~24 | 700 | display |
| 卡片标题 / 设备名 | 14~16 | 600/700 | body / display |
| 正文 | 13~14 | 400/500 | body |
| 次要（model/timestamp/IP） | 10~11 | 400 | mono |
| Tag / Chip | 11 | 600 | body 或 mono |
| ASCII divider | 10 | 700 + uppercase + letterSpacing 1.5+ | mono |

### 字体文件

OFL 字体存放在 `design/fonts/`（用户已下载到本地，**不入 git**）。
**你这端要做字体嵌入**：把对应平台格式的字体文件 copy 到你端的 Resources 目录
并注册（macOS Info.plist `ATSApplicationFontsPath` / iOS Info.plist `UIAppFonts`
/ Android `res/font/` / Windows `<Content>` + FontFamily XAML resource /
Linux `data/fonts/` + Fontconfig）。

如果 `design/fonts/` 不存在，从这几个 URL 下载并放进去（OFL 协议，可入仓）：
- Space Grotesk: <https://fonts.google.com/specimen/Space+Grotesk>
- Geist + Geist Mono: <https://vercel.com/font>

## 7. 12 个共享组件（每端必须 1:1 实装）

每个组件给出**关键参数**，端 prompt 不再重复。

### 7.1 `MeshDropMark` / `MeshDropWordmark` / `MeshDropLockup`
矢量 logo（见 §4）+ 字标（小写 meshdrop + lime dot）+ logo+wordmark 横排锁定组合。

### 7.2 `Avatar`
圆形彩色 + initials 字符。size 28/32/36/40/48。`ring=true` 时双层 ring（外圈 lime/flame）。

### 7.3 `Chip`（胶囊标签）
5 种 tone：
- `mute` — 浅底 + 灰字
- `lime` — lime 底 + ink 字
- `ink` — 黑底 + paper 字
- `outline` — 透明 + 描边 + 次字色
- `flame` — flame 底 + 白字

固定 height 20px，radius 999，padding 0/8，font 11px weight 600。`mono=true` 时字体走 mono。

### 7.4 `KindGlyph`
每 OS 一个小线条 svg：mac=方框+底线 / win=4 格田字 / ipad=圆角矩形+小圆 / ios&android=圆角窄矩形+底线。size 10-12，用于设备 row 副标题前置。

### 7.5 `DeviceCard`
侧栏 / 列表行用的小卡片。
avatar(32) + KindGlyph + 设备名(13.5/600) + 副标题（OS · RTT）+ 右下角小绿点（在线）。
selected 时背景 `rgba(221,249,75,.32)` (light) / `.16` (dark) + 1px lime 描边。

### 7.6 `MsgBubble`（聊天气泡）
- side="in" / "out"，圆角 16，**非尖角方向圆角 6**（incoming top-left 6, outgoing top-right 6）
- incoming 背景 white (dark `rgba(255,255,255,.07)`)，文字 ink
- outgoing 背景 **ink** 黑（dark **lime**），文字 paper（dark ink）
- 时间戳行：mono 10，"已送达" 加 `· 已送达` + limeDeep 色
- kind="text" / "file" / "image"，padding 不同（text `8/12`, file `10`, image `4`）

### 7.7 `FileChip`
左侧"纸样"icon（白底 + 右上折角阴影 + 中下方 mono 大写扩展名 + 彩色），右侧文件名 + 大小。
可选 `progress` (0-100) 显示底部进度条。

### 7.8 `TransferRow`（下载管理器行）
- 文件 icon (38×46) + name + size + 状态行 + （进行中时）进度条 + speed + ETA
- 状态色对应 §5：sending=flame ↑ / receiving=sky ↓ / done=limeDeep ✓ / failed=error × / queued=ink45 ·
- 进度条 4px 高，色随 state

### 7.9 `Radar`（核心组件，每端必做）
- 中心 60×60 实心黑圆（dark: dink2），写 `YOU` + 小 mono IP
- 同心圆 3 环（33% / 66% / 100% 半径）
- 4 个变体（必须至少实装 sweep 和 pulse 两个）：
  - **sweep** — 旋转扫描臂（lime 透明渐变，4.5s 一圈）+ 十字线 + N/E/S/W 罗盘字母
  - **pulse** — 设备点周期呼吸 halo（2.6s）
  - **grid** — 圆形点阵填充背景
  - **orbit** — 设备点缓慢轨道
- 设备点：lime 色脉冲 halo (52×52) + avatar dot (34px) + 旁边小 label（名字 + RTT + OS）
- selected 时点色变 flame，从中心拉一条 flame 虚线到该点

### 7.10 `Photo`（占位 / 缩略图）
渐变背景 + 假地平线 + 假太阳 + 假山形 svg。按 hue 参数调色。

### 7.11 `IconBtn`
圆形 / 方形小按钮。size 32 默认。`accent=true` 时 lime 底 + ink 字。

### 7.12 `Divider`（ASCII 分隔线）
左右两条 hr + 中间 mono 全大写 label（letterSpacing 1.5+，opacity 0.45）。
例：`── TODAY · 今天 · 5 件 ──`。营造极客感。

## 8. 必做页面（基线 10 张，端 prompt 会加端特有）

每端最少 10 张：

1. **Discovery / Nearby** — 本机卡 + 雷达 + 设备列表 + 状态条
2. **Chat** — 与某设备对话流，含 composer + drag overlay + 收件浮窗
3. **Transfers** — 速度图 + 任务列表 + filter chips
4. **History / Library** — 按日分组的图/文件/文字 grid
5. **Settings** — 至少三组：可见性、安全/加密、行为/接收
6. **Trust Manager** — 已配对设备表格 + 指纹 + 撤销
7. **Pairing** — QR + 6 字符代码 + 三步说明（或对端验证大字号代码）
8. **Onboarding** — 3~4 步介绍（发现 / 拖即发 / E2E / 菜单栏）
9. **Receive Confirmation** — 文件 offer 弹框，可选"文字便签"显示
10. **Empty / Offline / Failed States** — 至少 3 种

每页都要 **light + dark 双模式**。

## 9. Mock 数据（直接复制到你这端的代码常量里，渲染所有页面）

### 9.1 5 个设备（含中文姓名、kind、配色）

```
MESHDROP_DEVICES = [
  { id: 'lily',    name: "Lily's MacBook",   who: '李莉',    kind: 'mac',     dist: 0.55, angle: 35,  color: '#FFB4A1', initials: 'LL', os: 'macOS',    rtt: 18 },
  { id: 'kun',     name: "Kun · Pixel 8",    who: '坤',      kind: 'android', dist: 0.78, angle: 110, color: '#B7E5C8', initials: 'K',  os: 'Pixel',    rtt: 32 },
  { id: 'jiawei',  name: "Jiawei · iPad",    who: '嘉伟',    kind: 'ipad',    dist: 0.40, angle: 200, color: '#C7B8FF', initials: 'JW', os: 'iPadOS',   rtt: 14 },
  { id: 'mengxi',  name: "Meng Xi · iPhone", who: '孟茜',    kind: 'ios',     dist: 0.62, angle: 265, color: '#FFD970', initials: 'MX', os: 'iOS',      rtt: 26 },
  { id: 'dev01',   name: "DEV-01 · Win 11",  who: '工位机',  kind: 'win',     dist: 0.88, angle: 320, color: '#9AD0FF', initials: 'D1', os: 'Win 11',   rtt: 41 },
]
```

雷达放置坐标：(dist 0-1) × maxRadius，按 angle 极坐标算笛卡尔。

### 9.2 6 条历史

```
MESHDROP_HISTORY = [
  { id: 'h6', dir: 'incoming', peer: '孟茜', time: '14:18', kind: 'image', count: 2, status: 'done' },
  { id: 'h5', dir: 'outgoing', peer: '孟茜', time: '14:10', kind: 'file',  name: '设计稿_v3_final.fig', size: '14.2 MB', ext: 'fig', status: 'done' },
  { id: 'h4', dir: 'outgoing', peer: '李莉', time: '14:09', kind: 'text',  content: '改完了，整理一下发你 👇', status: 'done' },
  { id: 'h3', dir: 'outgoing', peer: '嘉伟', time: '14:08', kind: 'file',  name: 'iOS-mocks-final.zip', size: '48.6 MB', ext: 'zip', progress: 67, status: 'transferring' },
  { id: 'h2', dir: 'incoming', peer: '坤',   time: '13:58', kind: 'file',  name: 'IMG_4821~38.heic',    size: '128 MB',  ext: 'heic', progress: 12, status: 'transferring' },
  { id: 'h1', dir: 'outgoing', peer: '李莉', time: '13:42', kind: 'file',  name: 'demo-video.mp4',      size: '512 MB',  ext: 'mp4',  status: 'queued' },
]
```

### 9.3 1 个待审配对

```
MESHDROP_PENDING_PAIRING = {
  id: 'pp-1', peer: '李莉', deviceName: "Lily's MacBook",
  fingerprint: 'ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF',  // 4 字符 8 组
  receivedAt: '8s ago',
}
```

### 9.4 1 个待审文件 offer

```
MESHDROP_PENDING_OFFER = {
  id: 'po-1', peer: '嘉伟', deviceName: 'Jiawei · iPad',
  fileName: '规划文档_v0.3.pages',
  fileSize: '3.4 MB',
  note: '改完了帮我看下第二章，特别是 §2.3 那段',   // 文字便签
  receivedAt: 'just now',
}
```

### 9.5 5 个剪贴板条目

```
MESHDROP_CLIPBOARD = [
  { id: 'cb1', who: '嘉伟', kind: 'link', body: 'https://internal.acme.io/specs/auth-v3', ago: '8s' },
  { id: 'cb2', who: '孟茜', kind: 'text', body: '"1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配"', ago: '12m' },
  { id: 'cb3', who: '李莉', kind: 'code', lang: 'sh', body: 'docker run --rm -v $PWD:/app meshdrop/build:latest', ago: '34m' },
  { id: 'cb4', who: '坤',   kind: 'text', body: '"会议室 B 已订到 16:00–17:30"', ago: '1h' },
  { id: 'cb5', who: '我',   kind: 'link', body: 'figma://file/Q8xK2/MeshDrop?node-id=42:108', ago: '2h' },
]
```

### 9.6 6 个传输任务

```
MESHDROP_TRANSFERS = [
  { name: '设计稿_v3_final.fig',  size: '14.2 MB', ext: 'fig',  from: '我',   to: '孟茜', progress: 100, state: 'done',  eta: '00:08' },
  { name: 'iOS-mocks-final.zip',   size: '48.6 MB', ext: 'zip',  from: '我',   to: '孟茜', progress: 67,  state: 'sending',   speed: '8.4 MB/s', eta: '00:02' },
  { name: 'spec_PRD_2026Q1.pdf',   size: '2.1 MB',  ext: 'pdf',  from: '我',   to: '嘉伟', progress: 34,  state: 'sending',   speed: '3.1 MB/s', eta: '00:01' },
  { name: 'IMG_4821~IMG_4838.heic',size: '128 MB · 18 张', ext: 'heic', from: '坤', to: '我', progress: 12, state: 'receiving', speed: '11.7 MB/s', eta: '00:09' },
  { name: 'release-notes.md',      size: '4.8 KB',  ext: 'md',   from: '我',   to: 'DEV-01', progress: 100, state: 'done', eta: '00:01' },
  { name: 'demo-video.mp4',        size: '512 MB',  ext: 'mp4',  from: '我',   to: '李莉', progress: 0,  state: 'queued' },
]
```

### 9.7 速度图历史采样（双向）

```
MESHDROP_UPLOAD_BARS   = [3,5,8,7,9,6,11,12,14,11,10,11,12,11]   // 0-14, ↑ 上行 (flame)
MESHDROP_DOWNLOAD_BARS = [8,9,7,6,5,7,10,12,11,12,11,12,11,12]   // 0-14, ↓ 下行 (sky)
MESHDROP_SESSION_BARS  = [2,3,5,4,6,8,7,9,10,12,11,12,11,12,14]  // 15-point session 总量
```

### 9.8 本机信息（自卡）

```
MESHDROP_ME = {
  name: '我',                                    // 或具体设备名
  fingerprint: 'ZX8K · L72M · 9FQ3 · 7HD2',       // 显示前 4 组
  ip: '192.168.1.42',
  os: 'macOS',                                   // 或 iOS / Win 11 / Android
  visibility: '可见',
}
```

## 10. 文案规则

- **双语原则**：所有功能 label `中文 · English` 中间小圆点。例：`附近 · Nearby`、
  `传输 · Transfers`、`已配对 · Paired`
- **uppercase mono tag**：所有状态字（ONLINE / OFFLINE / LIVE / E2E / LAN ONLY /
  BUSY）必须**大写 + letterSpacing 1.5+ + mono 字体**
- **没有装饰 emoji**：除了 `→ ← ↑ ↓ ✓ × · ●` 这 7 个抽象符号；唯一例外：
  房间名前可用 🏠 ◫ ✱；快捷操作 strip 可用单色 emoji（剪贴板/相册/文件/文字便签）
- **数字 + 单位**：mono 字体，单位字号比数字小 30%。例 `2.41 GB`、`8.4 MB/s`、`18 ms`
- **时间**：mono `HH:mm` / `HH:mm:ss` / `今天 · 14:00` / `8s ago` / `刚刚`
- **指纹**：4 字符一组 · 分隔，全大写 mono。例：`ZX8K · L72M · 9FQ3`
- **错误说原因**：`对方拒收` / `校验失败` / `对方进入睡眠` / `没连上局域网`

## 11. 动效规则

- **雷达扫描周期** = 4.5s/圈
- **设备点呼吸** = 2.6s 周期 + 渐进延迟 (i × 0.3s)
- **halo expand pulse** = 2.4s ease-out（scale 0.3→1.0，opacity 0.9→0）
- **hover/active scale**：1.0 → 1.02 (卡片) / 1.05 (focus) / 1.15 (设备 dot)
- **transition spring**：response 0.32, damping 0.8（SwiftUI `.spring(...)` / CSS
  `cubic-bezier(.32,.72,.21,1)`）
- **新数据出现**：scale 0.92→1.0 + opacity 0→1，duration 220ms
- **drop overlay**：lime 半透明 + 黑色虚线边框 + 大字 "放手即发 · Drop to send · N
  个文件 · X MB → <目标名>"

## 12. 11 条绝对不能做

1. ❌ Material 3 默认蓝紫色调（与 MeshDrop 报纸 + lime 调子冲突）
2. ❌ 用 emoji 替代状态 icon（除 §10 列出的 7 个抽象符号）
3. ❌ "渐变背景 + 玻璃卡片"那种早期 Mac UI 风（用户在此之前明确说丑）
4. ❌ outgoing 气泡做成蓝色（iMessage 蓝是 Apple 的，MeshDrop 用 ink/lime）
5. ❌ 设备 row 加大尺寸渐变 OS icon（要用 KindGlyph 线条小标签）
6. ❌ "已配对" / "信任" 做成 toggle（必须显式表格 + 指纹列 + 撤销按钮）
7. ❌ Onboarding 超过 4 步
8. ❌ 省略 ASCII Divider 和 mono uppercase tag —— 这是 MeshDrop 视觉签名
9. ❌ Logo 末尾的 lime dot 省掉
10. ❌ commit / PR 出现 AI 署名（"Co-Authored-By: Claude" 等）
11. ❌ 用 `git push --force` / `git reset --hard` / 跳 pre-commit hook

## 13. Git Workflow

```bash
git checkout -b meshdrop/<端>             # 例：meshdrop/macos
# 做事
git commit -m "<中文动词开头 · 用户视角能力变化>"
git push -u origin meshdrop/<端>
gh pr create --base main --title "MeshDrop 端 UI: <一句话>"
```

commit message 写**用户视角能力变化**：
- ✅ `重做 macOS 主屏：雷达 Discovery + 玻璃 sidebar + 剪贴板同步卡片`
- ❌ `修复 import` / `根据用户反馈调整` / `调试日志清理`

## 14. PR 模板（你 push 后开 PR 必须填）

```markdown
## 摘要
<一句话>

## 截图（亮 + 暗）
<对应端要求的全部 PNG，按端 prompt 中"截图清单"列出>

## 测试
- [ ] 你这端 build 一次过
- [ ] 9 张基线页 + 端特有页全部出图
- [ ] 视觉对齐：lime/flame/sky 三色语义正确，outgoing 暗色用 lime
- [ ] 没有 MeshDrop / 至汝 / drop.mesh 残留（grep 一遍）

## 已知 TODO
（实装 backend 是下一轮的事，但这一轮没做完的 UI 列出来）

## 风险点
（任何用户合 PR 前应该知道的）
```

## 15. 如果你卡住

- 设计稿原型（jsx 预览）在用户本地 `__DESIGN_MESHDROP_PATH__`，**不在 git 仓**。如果你
  需要参考具体细节，让用户截图 / 描述
- 协议层不要碰；如有疑问让用户决定
- **不要默默删功能**：宁可标 TODO 留 stub，也不要静默砍页

---

**到这里 COMMON 结束。下面是你这端的特定指令。**


# MeshDrop · Linux TUI 端 UI Prompt（ratatui 终端 UI）

## 端特定任务

重做 MeshDrop 的终端版（cli + 全屏 TUI 两种模式），适合 SSH / headless / 容器 /
服务器场景。保留 `linux/crates/meshdrop-core/`（rename → `meshdrop-core`），重做
`linux/crates/meshdrop-tui/`（rename → `meshdrop-tui`）。**本轮只做 TUI 展示，用
mock 数据驱动**，cli 子命令可以预留 stub 暂时不接 backend。

## 风格关键

TUI 没有图形资源——你的目标是把 MeshDrop 设计语言（lime accent + mono + ASCII
divider + 大字号 hero）**翻译成纯文本 / Unicode 块字符 / ANSI 色**。

色彩映射（COMMON §5 → ratatui Color）：

```
truecolor 模式（COLORTERM=truecolor）:
  lime      → Color::Rgb(0xDD, 0xF9, 0x4B)
  flame     → Color::Rgb(0xFF, 0x5A, 0x2C)
  sky       → Color::Rgb(0x4D, 0xB8, 0xFF)
  ink       → Color::Rgb(0x0A, 0x0A, 0x0A)
  paper     → Color::Rgb(0xF5, 0xF2, 0xEC)
  limeDeep  → Color::Rgb(0xA8, 0xC8, 0x00)

256-color 模式 fallback:
  lime      → Color::Indexed(190)   # bright yellow-green
  flame     → Color::Indexed(202)   # bright orange-red
  sky       → Color::Indexed(75)    # bright blue
  limeDeep  → Color::Indexed(148)
```

字符画 device dot 优先用 braille `⣿⠿⠉` 半图形字符（最像 dot），fallback 用
`●`。

## 技术栈

- Rust 2021，rustc ≥ 1.80
- ratatui 0.29
- crossterm 0.28
- tokio 1
- `clap` 4 derive (cli 模式)
- `dialoguer` 4 (cli 模式的密码 / 确认 prompts)

## 文件组织

```
linux/crates/meshdrop-tui/
├── Cargo.toml                 # bin "meshdrop-tui"
└── src/
    ├── main.rs                # 入口 + CLI 参数 + 模式分发
    ├── app.rs                 # 全屏 TUI 主循环
    ├── cli.rs                 # 单命令子命令
    ├── mock.rs                # ★ COMMON §9 Rust 化（与 GUI 共享或独立）
    ├── ui/
    │   ├── theme.rs           # ANSI 色 + 字符 fallback 检测
    │   ├── widgets/
    │   │   ├── radar.rs       # braille 雷达
    │   │   ├── device_list.rs
    │   │   ├── history.rs
    │   │   ├── chip.rs        # 反白色块
    │   │   ├── status_bar.rs
    │   │   ├── ascii_divider.rs
    │   │   ├── transfer_row.rs
    │   │   └── meshdrop_logo.rs   # ASCII art
    │   ├── modals/
    │   │   ├── send.rs        # 文本/文件输入
    │   │   ├── pairing.rs     # 大字号 QX·8K7·L2M 块字符
    │   │   └── file_offer.rs
    │   └── help.rs            # ? 键 help overlay
    └── input.rs               # keybindings 状态机
```

## CLI 模式（headless friendly）— 本轮预留 stub 即可

```bash
# 列设备（json 给脚本消费 / table 给人看）
meshdrop-tui list-devices [--json | --table]

# 发文本（mock 立刻返回 OK）
meshdrop-tui send <peer> "<text>"
echo "hello" | meshdrop-tui send <peer> -

# 发文件（mock 进度条到 stderr，假装成功）
meshdrop-tui send-file <peer> ./report.pdf

# 接收守护（mock 假装挂着等）
meshdrop-tui daemon --auto-accept-trusted --save-dir ~/Downloads/meshdrop/

# 默认无参 → 全屏 TUI
meshdrop-tui
```

CLI subcommand 实装可以是 mock 实装：返回固定字符串 / 1.5 秒后假装完成；用户
后续轮接入真 backend。

## 全屏 TUI 布局

```
┌─ MESHDROP · DEV-01 · 192.168.1.42 · LIVE 5 ─────────────────────────────────────┐
│                                                                              │
│  ┌─ NEARBY · 附近 ────────┐  ┌─ HISTORY · 历史 ──────────────────────────┐ │
│  │ ▶ 李莉 · mac · 18ms    │  │ ↗ 14:09  → 孟茜  📄 设计稿_v3.fig ✓        │ │
│  │   坤   · pix · 32ms    │  │ ↙ 14:08  ← 嘉伟  💬 "下午开会"             │ │
│  │   嘉伟 · ipad· 14ms    │  │ ↗ 14:07  → 李莉  📄 周会.m4a  54.2 MB ↑   │ │
│  │   孟茜 · ios · 26ms    │  │   ▰▰▰▰▰▰▰▰▰▰░░░░ 67%                       │ │
│  │   DEV01 · win · 41ms   │  │ ↙ 14:00  ← 坤    🖼 3 张照片  ✓             │ │
│  └────────────────────────┘  └────────────────────────────────────────────┘ │
│                                                                              │
│   ┌─── RADAR ────────────────┐                                              │
│   │       N                  │                                              │
│   │       ·                  │     ╔══════════════════════════════════╗   │
│   │   ⣿       ⣿              │     ║  ↑↓ 选择 · Enter 发文本 · :命令  ║   │
│   │ ·   ⣿ YOU ⣿  ·           │     ║  a/r/t 待审操作 · q 退出          ║   │
│   │   ⣿       ⣿              │     ╚══════════════════════════════════╝   │
│   │       ·                  │                                              │
│   │       S                  │                                              │
│   └──────────────────────────┘                                              │
│                                                                              │
│ ▶ INPUT · 文本 · Esc 取消 · Enter 发送                                       │
│   下午我做完那个 part 给你_                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

布局规则：
- 顶部 1 行 status bar (LIVE/OFFLINE + IP + peers)
- 左侧 NEARBY (~30% 宽) 上下选择，`▶` 高亮选中
- 右侧 HISTORY (~70% 宽) 时间线 + 状态色
- 雷达放底部左半，help/info 放右半
- 最底 input area，模式切换：Normal / InputText / Command / Pairing / FileOffer

## 必做功能（本轮）

1. **TUI 主屏**：4 区布局
2. **Pairing modal**：大字号 6 字符代码 `QX·8K7·L2M`（multi-line block 字符）+
   完整指纹 8 组（含 mock 数据）
3. **FileOffer modal**：发送方 + 文件名 + 大小 + 可选文字便签 + a/r/t 三键
4. **Settings**：`:set` 命令模式，可改 displayName / 默认保存路径 / 是否
   自动接受信任（mock 写到内存即可）
5. **Search**：按 `/` 在设备列表过滤（mock 即时过滤）
6. **Help overlay**：`?` 键打开
7. **Color theme**：自动检测终端 truecolor / 256 / 16，降级映射

## 关键按键

| 按键 | 行为 |
| --- | --- |
| `j/k` `↑↓` | 设备 / 历史区域内上下 |
| `Tab` | 切换焦点区（设备列表 ↔ 历史） |
| `Enter` / `i` | 进入文本输入模式 |
| `:` | 命令模式（`:f <path>`, `:set k=v`, `:q`, `:trust`, `:revoke <fp>`） |
| `/` | 设备过滤 |
| `a` | 接受待审（pairing or file offer） |
| `r` | 拒绝待审 |
| `t` | 接受配对并信任 |
| `d` | 删除选中历史项 |
| `c` | 清空历史 |
| `?` | help overlay |
| `q` / `Esc` | 退出（或退出当前模式） |

## 编译 / 验证

```bash
cd linux
cargo build --release -p meshdrop-tui
./target/release/meshdrop-tui              # 全屏 TUI
./target/release/meshdrop-tui list-devices --table
./target/release/meshdrop-tui send 李莉 "hello"
./target/release/meshdrop-tui daemon --auto-accept-trusted
```

## 截图清单（PR 必须附）

ANSI screenshot（直接截图或 `asciinema rec` GIF）：

1. 全屏 TUI 主屏（truecolor）
2. 同上 256-color 模式（diff 对比）
3. Pairing modal（含大字号代码）
4. FileOffer modal
5. Search mode `/`
6. Command mode `:`
7. Help overlay `?`
8. `meshdrop-tui list-devices --table` 输出

外加 1 段 10-15s GIF / asciinema cast，演示：进入 TUI → 选设备 → 发文本 →
看见历史新条目。

> 8 张图 + 1 段 cast = 9 件交付物

## 验收 checklist

- [ ] `cargo build --release -p meshdrop-tui` 一次过
- [ ] CLI `meshdrop-tui list-devices --table` 输出 mock 5 个设备（含 RTT 列）
- [ ] daemon 模式 nohup 跑不崩，可 Ctrl+C 干净退出
- [ ] 在 alacritty / kitty / WezTerm / iTerm2 / Windows Terminal 5 种终端
      显示正常（无乱码 / 颜色泄漏）
- [ ] 无 ANSI 转义符泄漏到 stderr 或 piped output
- [ ] `--help` 输出完整、中英双语
- [ ] 9 件交付物全附

## 不能做（端特有）

- 不要假定终端必然支持 truecolor（必须自适配 256 / 16）
- 不要在 cli 模式（非全屏）泄漏 raw mode 状态（exit code 1 时终端不能乱）
- daemon 模式不能产生交互式 prompt（headless 友好）
- 雷达字符画必须有 ASCII fallback（terminal 不支持 braille 时）


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
