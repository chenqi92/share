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

仓库根：`<repo-root>`（GitHub：
[__ORG__/__REPO__](https://github.com/__ORG__/__REPO__)）
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
