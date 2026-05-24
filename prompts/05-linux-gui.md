# MeshDrop · Linux GUI 端 UI Prompt（GTK4 / libadwaita）

## 端特定任务

重做 Linux 桌面 GUI。保留 `linux/crates/meshdrop-core/`（rename → `meshdrop-core`，
本轮只改 service type + logger subsystem 字符串），重做
`linux/crates/meshdrop-gui/`（rename → `meshdrop-gui`）的 UI 层。**本轮只做 UI，
用 mock 数据驱动**，不接 backend。

## 风格关键

Linux 端没有独立设计稿——主要借鉴 macOS 布局（sidebar + content），但用
**GTK4 + libadwaita 原生 widget** 表达 MeshDrop 风格。**不要硬塞 macOS 玻璃感**。
关键是：
- paper #F5F2EC 主背景（不是 GNOME 默认 #FAFAFA）
- lime accent（不是 GNOME blue）
- mono 终端块（参照 Windows 端 Discovery 右侧 terminal block 风格）
- AdwActionRow 配合 ASCII Divider 营造极客感

## 技术栈

- Rust 2021，rustc ≥ 1.80
- gtk4-rs 0.9（v4_12 features）
- libadwaita-rs 0.7（v1_5）
- tokio 1（multi-thread runtime，已有）
- notify-rust 4 用于桌面通知
- 字体：把 OFL Space Grotesk / Geist TTF 放 `data/fonts/`，运行期通过
  Fontconfig `FcConfigAppFontAddFile` 注册（GTK 自动 pick up）

## 文件组织

```
linux/
├── Cargo.toml                     # workspace
├── crates/
│   ├── meshdrop-core/                  # rename from meshdrop-core
│   │   └── src/ ...                # service type _meshdrop._tcp; logger subsystem
│   ├── meshdrop-gui/                   # rename from meshdrop-gui
│   │   ├── Cargo.toml              # bin name "meshdrop"
│   │   └── src/
│   │       ├── main.rs             # adw::Application, APP_ID com.welape.meshdrop.linux
│   │       ├── ui.rs               # 入口框架
│   │       ├── mock.rs             # ★ COMMON §9 Rust 化
│   │       ├── theme.rs            # 加载 CSS 资源
│   │       ├── pages/
│   │       │   ├── discovery.rs    # Radar + 设备 list + sidebar
│   │       │   ├── chat.rs
│   │       │   ├── transfers.rs    # SpeedChart drawing area
│   │       │   ├── history.rs
│   │       │   ├── trust.rs
│   │       │   └── settings.rs
│   │       ├── dialogs/
│   │       │   ├── send.rs
│   │       │   ├── pairing.rs      # AdwMessageDialog
│   │       │   ├── file_offer.rs
│   │       │   └── onboarding.rs
│   │       ├── components/
│   │       │   ├── radar.rs        # ★ cairo / gtk::DrawingArea + queue_draw 60fps
│   │       │   ├── device_row.rs   # AdwActionRow 包装
│   │       │   ├── speed_chart.rs
│   │       │   ├── msg_bubble.rs
│   │       │   ├── file_chip.rs
│   │       │   ├── chip.rs
│   │       │   ├── meshdrop_logo.rs    # cairo path
│   │       │   └── ascii_divider.rs
│   │       └── notify.rs
│   └── meshdrop-tui/                   # 见 06 prompt（不在本端范围）
├── data/
│   ├── meshdrop.desktop                # rename from meshdrop.desktop
│   ├── com.welape.meshdrop.linux.gschema.xml
│   ├── icons/hicolor/*/apps/com.welape.meshdrop.linux.png
│   ├── fonts/                      # Space Grotesk + Geist OFL TTF
│   └── css/
│       └── meshdrop.css                # ★ 全部 token + widget 自定义样式
└── README.md
```

## CSS 关键（必须放 `data/css/meshdrop.css`）

```css
/* ───── TOKEN ───────────────────────────────── */
@define-color meshdrop_paper #F5F2EC;
@define-color meshdrop_card  #FFFFFF;
@define-color meshdrop_ink   #0A0A0A;
@define-color meshdrop_ink45 alpha(@meshdrop_ink, .45);
@define-color meshdrop_line  #E2DCCD;
@define-color meshdrop_lime  #DDF94B;
@define-color meshdrop_lime_deep #A8C800;
@define-color meshdrop_flame #FF5A2C;
@define-color meshdrop_sky   #4DB8FF;
@define-color meshdrop_dink  #0E0C09;
@define-color meshdrop_dink2 #181612;
@define-color meshdrop_dpaper #E8E3D6;

window { background-color: @meshdrop_paper; }
.dark window { background-color: @meshdrop_dink; }

/* card */
.meshdrop-card { background: @meshdrop_card; border-radius: 12px;
  border: 1px solid @meshdrop_line; padding: 12px 14px; }
.dark .meshdrop-card { background: @meshdrop_dink2; border-color: alpha(white, .10); }

/* chips */
.meshdrop-chip-lime { background: @meshdrop_lime; color: @meshdrop_ink;
  padding: 2px 8px; border-radius: 10px; font-family: "Geist"; font-weight: 600; }
.meshdrop-chip-ink { background: @meshdrop_ink; color: @meshdrop_paper;
  padding: 2px 8px; border-radius: 10px; font-weight: 600; }

/* mono */
.meshdrop-mono { font-family: "Geist Mono"; }
.meshdrop-ascii-divider { font-family: "Geist Mono"; font-weight: 700;
  letter-spacing: 1.5px; text-transform: uppercase; opacity: 0.45; }

/* chat bubbles */
.meshdrop-bubble-out { background: @meshdrop_ink; color: @meshdrop_paper;
  border-radius: 16px 4px 16px 16px; padding: 8px 12px; }
.dark .meshdrop-bubble-out { background: @meshdrop_lime; color: @meshdrop_ink; }
.meshdrop-bubble-in { background: @meshdrop_card; color: @meshdrop_ink;
  border-radius: 4px 16px 16px 16px; padding: 8px 12px; }
.dark .meshdrop-bubble-in { background: alpha(white, .07); color: @meshdrop_dpaper; }

/* terminal block (Discovery details rail 仿 Windows) */
.meshdrop-terminal { background: @meshdrop_ink; color: @meshdrop_lime;
  font-family: "Geist Mono"; font-size: 11px; padding: 12px;
  border-radius: 6px; line-height: 1.7; }
```

## 必做页面（共 11 张 × (light + dark) = 22 张）

基线 10 张（COMMON §8） + Linux 特有：

11. **顶层 sidebar + 状态条** 主窗口框架（与 Mac 不同：libadwaita 标准 widget
    风格但**强制 MeshDrop 配色**）

Linux 简化项（**不做**）：
- 群组房间（留 stretch）
- DragOut 桌面交互（GTK4 拖出文件复杂，留 TODO）
- 系统托盘（StatusNotifier 在各 DE 实现差异大，留 stretch）

但 **Drop In**（拖文件到设备 row）必须做：用 `gtk::DropTarget`。

## Radar 实装提示

用 `gtk::DrawingArea`：
- `connect_draw` 调用 cairo 绘制 paths
- `add_tick_callback` 60fps 重绘
- sweep arm 用 4.5s rotation
- 设备点：用单独 `gtk::Fixed` 容器放 `gtk::Box`（avatar + label），让用户能
  实际点击交互；雷达背景只画环、扫描臂、halo

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| 点设备 row | 切到 Chat page（mock 显示该 device 对话） |
| 拖文件 → 设备 row | 高亮 (lime dashed border) + 释放 toast "已发送（mock）" |
| Ctrl+, | 设置 |
| Ctrl+K | sidebar 搜索 |
| AdwMessageDialog "撤销" | mock 移除该 trust 行 |

## 编译 / 验证

需 GTK4 系统库：

```bash
# Ubuntu 24.04+
sudo apt install libgtk-4-dev libadwaita-1-dev

# Fedora 40+
sudo dnf install gtk4-devel libadwaita-devel

cd linux
cargo build --release -p meshdrop-gui
cargo run --release -p meshdrop-gui
```

如果你在 macOS 开发（没 GTK），用 `cargo check -p meshdrop-gui` 验证类型；真测试推
Linux VM / docker。

## 截图清单（PR 必须附 22 张）

```
screenshots/linux-gui-{discovery|chat|transfers|history|settings|trust|pairing|onboarding|receive|empty}-{light|dark}.png   (20)
screenshots/linux-gui-shell-{light|dark}.png  (2)（截 sidebar + status 框架）
```

## 验收 checklist

- [ ] `cargo build --release -p meshdrop-gui` 干净通过
- [ ] 在 Ubuntu 24.04 / Fedora 40 实际跑起来，截图无 GNOME 默认蓝
- [ ] Window background 是 paper #F5F2EC（不是 GNOME 默认 light grey）
- [ ] 字体真的是 Space Grotesk（Settings → About 截图）
- [ ] outgoing 气泡 dark 模式用 lime 底
- [ ] desktop file 安装后 Activities 里能搜到 "MeshDrop"
- [ ] 22 张截图全附

## 不能做（端特有）

- 不要用 GNOME 默认 accent（Adwaita blue）— CSS 强覆盖为 lime
- 不要直接用 `AdwApplicationWindow` 默认背景（必须 CSS override 到 paper）
- 不要在 Composable 调真实 MeshDropEngine（本轮 mock）
