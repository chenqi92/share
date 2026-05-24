# MeshDrop · 设计宪法

> **所有端 AI 在动工前必读。** 这是跨平台设计语言、组件库、状态规范的真相。
> 任何违反本规范的实现都会被打回重做。视觉参考: `__DESIGN_MESHDROP_PATH__*.jsx`（React 预览源）。

---

## 0. 品牌身份

| 项目 | 值 |
| --- | --- |
| **正式名** | **MeshDrop**（首字母大写） |
| **Wordmark** | `meshdrop.`（小写 + 末尾一个 lime 圆点，**点不能省略**） |
| **副标题** | `An intranet drop · radar discovery · drag-to-send · E2E encryption` |
| **中文 slogan** | "一个内网，任何设备，**谁都能 ping 到。**" |
| **五端文案** | "雷达式发现 · 端对端加密 · 拖即发送 · 剪贴板同步 · 文字便签" |
| **Bundle/包标识 prefix** | `com.welape.meshdrop`（iOS/macOS）、`com.welape.meshdrop`（Android applicationId）、`com.welape.MeshDrop`（Windows namespace）、`com.welape.meshdrop.linux`（Linux APP_ID） |
| **mDNS service type** | `_meshdrop._tcp.local.`（**注意：从 `_meshdrop._tcp` 迁移到 `_meshdrop._tcp`，所有 5 端必须同步**） |

### Logo

参考 `brand.jsx`：

```
两个重叠圆环 (stroke) + 中间一个 lime 实心圆点
半径 6.5 · stroke 2px · 圆心相距 6 个单位
颜色: stroke = ink（深色背景下为 paper），dot = lime
```

每端必须实现一个矢量版的 `MeshDropMark`（24×24 viewBox 起步，可任意缩放）。

---

## 1. Design Tokens（精确复制，**不要自己改色**）

```
// COLORS · LIGHT (paper background)
ink:    #0A0A0A             // 主文字 / 边框
ink80:  rgba(10,10,10,.80)
ink60:  rgba(10,10,10,.60)  // 次文字
ink45:  rgba(10,10,10,.45)  // 三级文字 / muted
ink30:  rgba(10,10,10,.30)
ink12:  rgba(10,10,10,.12)  // 描边
ink06:  rgba(10,10,10,.06)  // 浅底
paper:  #F5F2EC             // 主背景（报纸感的米白）
paper2: #EDE8DD             // 次背景
card:   #FFFFFF             // 卡片纯白
line:   #E2DCCD             // 分隔线

// COLORS · DARK
dink:   #0E0C09             // 主背景（暖黑，不是纯黑）
dink2:  #181612             // 次背景 / 卡片
dink3:  #23201A             // 三级
dpaper: #E8E3D6             // 主文字
dline:  rgba(255,255,255,.10)

// SEMANTIC ACCENTS · 三色语义系统（必须严格区分）
lime:      #DDF94B          // ✅ 发现 / 在线 / 已连接 / Live / Trusted
limeDeep:  #A8C800          // lime 的深色变体（小元素 / 描边）
flame:     #FF5A2C          // 🟠 发送中 (outgoing) / 主动 / 警告 / Active transfer
flameDeep: #C73E15
sky:       #4DB8FF          // 🔵 接收中 (incoming) / 收到的文件方向

// SEMANTIC ACCENTS · 状态色
limeDeep   for state=online
flame      for state=sending (outgoing)
sky        for state=receiving (incoming)
limeDeep   for state=done / completed
#C4322B    for state=failed / error
ink45      for state=offline / queued / muted
```

**所有端实现必须把这些值定义在一个常量集合**（Swift: `enum MeshDropColor`, Kotlin: `object MeshDropColor`, C#: `static class MeshDropColor`, Rust: `mod color`）。

---

## 2. 字体堆栈

```
fdisp (Display):  "Space Grotesk", "PingFang SC", "Noto Sans SC", system-ui, sans-serif
fbody (Body):     "Geist", "PingFang SC", "Noto Sans SC", -apple-system, system-ui, sans-serif
fmono (Mono):     "Geist Mono", "SF Mono", ui-monospace, Menlo, monospace
fchin (Chinese):  "PingFang SC", "Noto Sans SC", system-ui, sans-serif
```

- **display 用于大标题** / 数字 (字号 ≥ 18)，weight 700, letterSpacing 接近 -0.5 ~ -1
- **body 用于正文 / 按钮**, weight 400/500/600
- **mono 用于** 时间戳、IP、端口、指纹、tag、ETA、bytes、ASCII 装饰、CODE 区块
- **混排中英文** 必须先 try Space Grotesk/Geist，再 fallback PingFang SC（保证字形协调）

### 字号阶梯（典型）

| 用途 | 字号 | 字重 | 字体 |
| --- | --- | --- | --- |
| Hero title (Discovery 主屏) | 26 ~ 38 | 700 | display |
| Section title | 18 ~ 24 | 700 | display |
| Card title (设备名) | 14 ~ 16 | 600/700 | body / display |
| Body | 13 ~ 14 | 400/500 | body |
| Secondary (model/timestamp) | 10 ~ 11 | 400 | mono |
| Tag / Chip | 11 | 600 | body or mono |
| ASCII divider | 10 | 700 (uppercase, letterSpacing 1.5+) | mono |

---

## 3. 共享组件库（每端必须 1:1 实装）

### 3.1 `MeshDropMark` / `MeshDropWordmark` / `MeshDropLockup`

矢量 logo + 字标。规范见 `brand.jsx`。

### 3.2 `Avatar`

圆形彩色 + initials 字符（中文姓名取首字 / 英文取首字母）。
- size 28 / 32 / 36 / 40 / 48 可选
- `ring=true` 选中时加双层 ring（外圈用 lime/flame）

### 3.3 `Chip`（小胶囊标签）

5 种 tone：
- `mute` — 浅底 + 灰字（默认）
- `lime` — lime 底 + ink 字（live / verified）
- `ink`  — 黑底 + paper 字（已激活的 filter）
- `outline` — 透明 + ink12 描边 + ink60 字
- `flame` — flame 底 + 白字（active / warning）

固定 height 20，radius 999，padding 0/8，font 11px 600。可加 `mono` 让字体走 mono。

### 3.4 `KindGlyph`

每个 OS（mac/win/ipad/ios/android）一个小线条 svg icon，用于设备 row 副标题前置标签。

### 3.5 `DeviceCard`

侧栏 / 列表行用的小卡片。
- avatar (32) + name (13.5 600) + KindGlyph + OS + RTT（mono 10.5）
- selected 时背景 `rgba(221,249,75,.32)`（light） / `.16`（dark）+ 1px lime 描边
- 右下小绿点（在线状态）

### 3.6 `MsgBubble`

聊天气泡：
- `side="in"` / `"out"`，圆角 16，**非尖角方向圆角 6**（incoming top-left 6, outgoing top-right 6）
- incoming 背景 white / dark `rgba(255,255,255,.07)`，文字 ink
- outgoing 背景 **ink**（dark 模式 **lime**），文字 paper（dark `ink`）
- 时间戳行：mono 10，已送达加 `· 已送达` + `limeDeep` 色
- `kind="text" | "file" | "image"`，padding 不同：text `8px 12px`、file `10`、image `4`

### 3.7 `FileChip`

文件 chip：左侧"纸样"icon（白底 + 右上角折角阴影 + 中下方 mono 全大写扩展名彩色），右侧 name + size。
可选 `progress` (0..100) 显示底部进度条。

### 3.8 `TransferRow`

下载管理器风格的传输项：
- 文件图标 (38×46) + name + size + progress + speed + ETA
- 状态色：sending=flame `↑` / receiving=sky `↓` / done=limeDeep `✓` / failed=#C4322B `×` / queued=ink45 `·`
- 进度条 4px 高，颜色随 state

### 3.9 `Radar`（核心）

参考 `radar.jsx`。每端必须实现自己的版本（不能用 web 嵌入）：
- 中心 60×60 实心黑圆 (dark: dink2)，写 `YOU` + 小 mono IP
- 同心圆 3 环（33% / 66% / 100% 半径）
- 4 个变体：
  - `sweep` — 旋转扫描臂（lime 透明渐变 + 4.5s 一圈）
  - `pulse` — 设备点周期呼吸（2.6s）
  - `grid` — 圆形点阵填充
  - `orbit` — 设备点缓慢轨道运动
- 设备点：lime 色脉冲 halo + avatar dot (34px) + 旁边小 label（名字 + ms + OS）
- selected 时点变 flame 色，从中心拉一条 flame 虚线
- 可选 N/E/S/W 罗盘字母（sweep 变体下）

### 3.10 `Photo`（占位 / 缩略图）

渐变 + 假地平线 + 假太阳 + 假山形 svg。用于历史 / 收件 / 演示。
实现可任意但**配色基于 hue 参数**。

### 3.11 `IconBtn`

圆形/方形小按钮，size 32 默认；`accent=true` 时 lime 底 + ink 字。

### 3.12 `Divider`（ASCII 风格）

`<hr>` 两侧用 mono 全大写 label，字体 10 letterSpacing 1.5。营造极客感。

---

## 4. 必须实装的页面（每端最少 6 个）

按重要性排序：

1. **Discovery（主屏 / 雷达）** — 含本机信息卡 + 雷达 + 设备列表 + 状态条
2. **Chat（消息流）** — 与单个设备的对话，含消息历史 + composer + 拖入 overlay
3. **Transfer Manager（传输）** — 速度图 + 任务列表（含进度/速度/ETA）+ filter
4. **History / Library（历史 / 资源库）** — 按日分组的图片/文件/文字 grid
5. **Settings（设置）** — 至少三组：可见性、安全/加密、行为/接收
6. **Trust Manager（信任设备）** — 表格列出已配对设备 + 指纹 + 撤销
7. **Pairing（配对）** — QR 码扫一扫 + 6 字符代码 + 指纹核对（强制对端用户确认）
8. **Onboarding（首启引导）** — 3 ~ 4 步介绍（发现 / 拖即发 / E2E）
9. **Receive Confirmation（接收弹窗 / 模态）** — 文件 offer 弹框，含可选"文字便签"
10. **Empty / Offline / Failed States** — 至少 3 种空态

**移动端**（iOS/Android）：bottom tab bar 4 个 tab — 附近 / 消息 / 传输 / 我。
**桌面端**（macOS/Windows/Linux）：左侧 sidebar，含 nav + 已配对设备 + "本机"标签。

---

## 5. 文案规则

- **双语原则**：所有功能性 label 用 `中文 · English`（小圆点分隔）。例：`附近 · Nearby`、`传输 · Transfers`、`已配对 · Paired`。
- **uppercase tag**：所有 mono 状态字（ONLINE / OFFLINE / LIVE / E2E / LAN ONLY / BUSY）必须大写 + letterSpacing 1.5+。
- **没有 emoji 装饰**：除了 `→ ←  ↑ ↓ ✓ × · ●` 这 7 个抽象符号，不要在 UI 文字里加 emoji（图标用 SF Symbol / Material Symbol / 矢量绘制）。**唯一例外**：`房间 Rooms` 可以用 `🏠 ◫ ✱` 这种几何符号；"快速操作"行可以用单色 emoji（剪贴板/相册/文件/文字便签）。
- **数字 + 单位**：mono 字体，单位字号比数字小 30%。例：`2.41 GB`、`8.4 MB/s`、`18 ms`。
- **时间**：mono `HH:mm` / `HH:mm:ss` / `今天 · 14:00` / `8s ago` / `刚刚`。
- **指纹**：4 字符一组，`·` 分隔，全大写 mono。例：`ZX8K · L72M · 9FQ3`。
- **错误**：不说"出错了"，说原因。`对方拒收`、`校验失败`、`对方进入睡眠`、`没连上局域网`。
- **永远不说"AI / Claude"**。

---

## 6. 动效规则

- **雷达扫描周期** = 4.5s/圈（不要更快或更慢）
- **设备点脉冲** = 2.6s 周期 + 渐进延迟（i × 0.3s）
- **halo expand pulse** = 2.4s ease-out（从 0.3× → 1.0×，opacity 0.9 → 0）
- **hover/active scale**：1.0 → 1.02 (卡片) / 1.05 (focus 区域如 tvOS) / 1.15 (设备 dot)
- **transition**：spring(response: 0.32, dampingFraction: 0.8)，CSS `cubic-bezier(.32,.72,.21,1)`
- **新数据 / 弹框出现**：scale 0.92 → 1.0 + opacity 0 → 1，duration 220ms
- **拖入 drop overlay**：lime 半透明 + 黑色虚线边框 + 大字"放手即发 · Drop to send · N 个文件 · X MB → 目标名"

---

## 7. 暗色模式映射

| 元素 | Light | Dark |
| --- | --- | --- |
| 主背景 | `paper` `#F5F2EC` | `dink` `#0E0C09` |
| 卡片 | `card` `#FFFFFF` | `dink2` `#181612` |
| 文字主 | `ink` | `dpaper` |
| 文字次 | `ink45` | `rgba(255,255,255,.5)` |
| 描边 | `line` `#E2DCCD` | `dline` `rgba(255,255,255,.10)` |
| sidebar 玻璃 | `rgba(255,255,255,.55)` + blur(40px) saturate(180%) | `rgba(255,255,255,.025)` + 同上 |
| outgoing 气泡 | `ink` 底 + `paper` 字 | **`lime`** 底 + `ink` 字（注意：暗色下用 lime！） |
| lime 区域 | `rgba(221,249,75,.32)` | `rgba(221,249,75,.10)` 或 `.16` |

---

## 8. 无障碍 + 国际化

- **对比度**：所有正文 ≥ 4.5:1，UI 控件 ≥ 3:1。lime/ink 已满足。
- **触达区**：按钮最小 32×32（桌面），44×44（移动），56×56（tvOS）。
- **焦点环**：tvOS 必须 4px lime 光晕 + 5% scale；桌面键盘焦点用 2px lime outline。
- **本地化**：所有用户可见字符串走 i18n 文件（不是硬编码），即使当前只有 zh-CN + en。
- **字体回退**：见 §2。

---

## 9. 隐私与安全（文案约束）

`meshdrop` 的人设是「内网工具，永不出 LAN」。所有设置 / Onboarding / 设置项必须强化这点：

- **不开账号、不进群、不出公司网络**
- **服务端不留拷贝**（事实上没有服务端）
- **每 24 小时轮换会话密钥**
- **指纹一旦变化（更换设备 / 重装系统）会立刻提示——这是设计上的提醒，不是 bug**

不要说"安全"、"放心"、"保护"这种空洞词。说事实：`X25519 + ChaCha20-Poly1305`、`公钥钉死`、`mTLS`、`指纹一致才接收`。

---

## 10. 不许做的事

- ❌ 不要用 Material 3 / Apple 默认蓝紫色调（与 MeshDrop 报纸 + lime 调子冲突）
- ❌ 不要用 emoji 替代 status icon（除了 §5 列出的几个抽象符号）
- ❌ 不要做"渐变背景 + 玻璃卡片"那种早期 Mac UI 风格（用户在此之前明确说丑）
- ❌ 不要把 outgoing 气泡做成蓝色（iMessage 蓝是 Apple 的，MeshDrop 用 ink/lime）
- ❌ 不要给设备 row 加大尺寸渐变 OS icon（用 KindGlyph 线条小标签）
- ❌ 不要把"已配对"/"信任"做得像 toggle（必须显式表格 + 指纹列 + 撤销按钮）
- ❌ Onboarding 不要超过 4 步
- ❌ 不要省略 ASCII Divider 和 mono tag —— 这是 MeshDrop 的视觉签名
- ❌ Logo 末尾的 lime dot **永远不能省**

---

## 11. 验收门槛

每端实装完成后，必须能截 9 张图（亮 + 暗 = 18 张）对应：
Discovery / Chat / Transfer / History / Settings / Trust / Pairing / Onboarding / Receive。

视觉对照 `__DESIGN_MESHDROP_PATH__scrn-1.jpg` 和 `__DESIGN_MESHDROP_PATH__*.jsx`，**色彩 / 字体 / 间距 / 文案** 4 个维度必须吻合。

不通过的端：设计宪法 + 端 prompt 重新读一遍再做。
