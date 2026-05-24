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
