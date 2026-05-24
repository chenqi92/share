# MeshDrop · Windows 端 UI Prompt

## 端特定任务

重做 Windows 桌面 app 的全部 UI。保留 `windows/ShareWindows/Protocol|Transport
|Models|Discovery/` 等协议层代码，**本轮只重做 `Views/` + `MainWindow.*` +
新增 TrayIcon / Toast，用 mock 数据驱动**，不动 backend。

## 风格关键

MeshDrop 在 Windows 上是"**暗灰底 + lime 强调 + mono 终端感**"。Discovery 右侧
details rail 必须有那块**终端样式黑底 + lime 文字的"network details"** 区块
（仿 ANSI 终端字段：`ip 192.168.1.31 / os macOS 15.3 / rtt 18 ms · jitter 0.4
/ bw 940 Mbps (LAN) / e2e ✓ verified / fpr ZX8K · L72M · 9FQ3`）。

**不要用 Fluent default 蓝**。Windows 上默认进 dark 主题。

## 技术栈

- .NET 8
- WinUI 3（Windows App SDK 1.6+）
- C# 12, nullable enable
- 字体嵌入：`Assets\Fonts\*.ttf` + XAML FontFamily resource
- 通知：CommunityToolkit.WinUI.Notifications
- 已有依赖：CommunityToolkit.Mvvm 8.4 / Makaretu.Dns.Multicast.New 0.38 /
  NSec.Cryptography 24.4
- 新增依赖（要装）：`H.NotifyIcon.WinUI`（系统托盘）

## 文件组织

```
windows/
├── MeshDrop.sln                       # rename from ShareWindows.sln
└── MeshDrop/                          # rename from ShareWindows
    ├── MeshDrop.csproj                # AssemblyName MeshDrop, RootNamespace MeshDrop
    ├── App.xaml + .cs
    ├── MainWindow.xaml + .cs       # 全重写
    ├── Protocol/                  # 保留
    ├── Transport/                  # 保留
    ├── Models/                    # 保留，rename namespace
    ├── Discovery/                  # 保留
    ├── Mock/
    │   └── MockData.cs            # ★ COMMON §9 C# 化
    ├── ViewModels/
    │   ├── ShellViewModel.cs       # 整窗 nav 状态
    │   ├── DiscoveryViewModel.cs
    │   ├── ChatViewModel.cs
    │   ├── TransfersViewModel.cs
    │   ├── HistoryViewModel.cs
    │   ├── TrustViewModel.cs
    │   └── SettingsViewModel.cs
    ├── Views/
    │   ├── Shell/
    │   │   ├── ShellSidebar.xaml  # nav + paired + 本机卡片
    │   │   └── ShellStatusBar.xaml # 底部 mono 状态条
    │   ├── Pages/
    │   │   ├── DiscoveryPage.xaml  # Radar + 右侧 details rail (terminal block)
    │   │   ├── ChatPage.xaml
    │   │   ├── TransfersPage.xaml  # 顶部 3 个 DashTile + 任务列表
    │   │   ├── HistoryPage.xaml
    │   │   ├── TrustPage.xaml
    │   │   └── SettingsPage.xaml
    │   ├── Controls/
    │   │   ├── Radar.xaml + .cs    # ★ Win2D / Composition Canvas
    │   │   ├── MeshDropLogo.xaml + .cs
    │   │   ├── AvatarControl.xaml + .cs
    │   │   ├── ChipControl.xaml + .cs
    │   │   ├── MsgBubble.xaml + .cs
    │   │   ├── FileChip.xaml + .cs
    │   │   ├── TransferRowControl.xaml + .cs
    │   │   ├── DashTile.xaml + .cs  # mini speed bars
    │   │   ├── KindGlyph.xaml + .cs
    │   │   └── AsciiDivider.xaml
    │   └── Dialogs/
    │       ├── SendDialog.xaml + .cs        # 文本/文件 segment
    │       ├── PairingDialog.xaml + .cs     # 含 QX-8K7-L2M
    │       ├── FileOfferDialog.xaml + .cs   # 含文字便签
    │       └── OnboardingDialog.xaml + .cs
    ├── TrayIcon/
    │   ├── TrayIconHost.cs        # H.NotifyIcon.WinUI
    │   └── TrayFlyout.xaml + .cs  # 顶部 mini live transfer + Nearby + 打开按钮
    ├── Notifications/
    │   └── ToastBuilder.cs        # Toast XML 含 接收/拒绝/查看 三按钮
    ├── Theme/
    │   ├── MeshDropColors.xaml         # ★ COMMON §5 token (light) ResourceDictionary
    │   ├── MeshDropColors.Dark.xaml
    │   ├── MeshDropFonts.xaml          # Space Grotesk + Geist FontFamily resources
    │   └── Generic.xaml
    ├── Assets/
    │   ├── AppIcon.ico            # 多分辨率
    │   ├── AppIcon.png            # 256 圆角
    │   └── Fonts/                 # Space Grotesk + Geist + Geist Mono OFL TTF
    ├── app.manifest
    └── Package.appxmanifest 不用
```

## 必做页面（共 13 张 × (light + dark) = 26 张）

基线 10 张（COMMON §8）+ Windows 特有：

11. **TrayIcon Flyout**（仿 WinTrayScreen）：弹出含 mini live transfer bar +
    Nearby 列表 + 打开 / 设置按钮，**WIN+S 全局热键**展开
12. **Toast notification**（仿 WinToast）：含 接收 / 拒绝 / 查看 三按钮
13. **Status bar**：底部 26 高 mono 状态条 `● ONLINE · ACME-LAN ·
    192.168.1.42 · 5 peers · ↑ 8.4 MB/s · ↓ 11.7 MB/s · 1.24 GB`

## 关键页面布局

### Discovery 页

```
┌─ MeshDrop — 附近 Discovery ────────────────────────────────────┐
│ ┌─ MESHDROP ──────┐                                            │
│ │ 附近 Nearby ◎│  附近设备 · 5 台          [发送文件…][+]│  ← breadcrumb
│ │ 消息 ◌ (2)   │                                            │
│ │ 传输 ↕      │                                            │
│ │ 历史 ◉      │  ┌───────────────────┬─────────────────┐  │
│ │              │  │                   │ Selected · 已选│  │
│ │ 已配对 PAIRED│  │   Radar 400×400   │ [李莉] LL      │  │
│ │ [李莉  ]    │  │   grid variant    │ Lily's MacBook │  │
│ │ [坤    ]    │  │                   │                │  │
│ │ [嘉伟  ]    │  │                   │ ┌─ terminal ──┐│  │
│ │ [孟茜  ]    │  │                   │ │ip   192.168.│ │  │
│ │              │  │                   │ │os   macOS   │ │  │
│ │ ─────────    │  │                   │ │rtt  18 ms   │ │  │
│ │ [我Avatar]   │  │                   │ │bw   940Mbps │ │  │
│ │ DEV-01 · 我 │  │                   │ │e2e  ✓verified│ │  │
│ │ Win 11 LAN  │  │                   │ │fpr  ZX8K... │ │  │
│ └──────────────┘  └───────────────────┴─────────────────┤  │
│                                       │ [→ 发送文件]    │  │
│                                       │ [开始聊天]      │  │
│                                       │ [同步剪贴板]    │  │
│                                       │ ┌─ drop zone ─┐│  │
│                                       │ │  ⤓ 拖文件   ││  │
│                                       │ └─────────────┘│  │
│                                       └─────────────────┘  │
├─ ● ONLINE · ACME-LAN · 192.168.1.42 · 5 peers · ↑ ↓ · 1.24 GB │
└────────────────────────────────────────────────────────────┘
```

### Transfers 页

```
传输 · Transfers · 6 个任务 · 2 进行中    [全部][活跃 · 2][已完成]
─────────────────────────────────────────────────────────────────
┌─ 传输总量 SESSION ─┬─ 上行 ↑ UP ──────┬─ 下行 ↓ DOWN ───┐
│ 2.41 GB (lime)     │ 46.8 MB/s (flame)│ 12.4 MB/s (sky) │
│ 自 09:12 起        │ 峰值 58.2        │ 峰值 14.1       │
│ [mini bars]        │ [mini bars]      │ [mini bars]     │
└────────────────────┴──────────────────┴─────────────────┘
─────────────────────────────────────────────────────────────────
[TransferRow × 6]
─────────────────────────────────────────────────────────────────
● CONNECTED · 5 peers           ↑ 46.8 MB/s    ↓ 12.4 MB/s
```

### TrayFlyout (WIN+S 弹出)

```
meshdrop (LOGO)                         ● 5 ONLINE
─────────────────────────────────
↑ datasets-2026Q1.parquet  73% · 46.8 MB/s
[▰▰▰▰▰▰▰▰▰░░░░░] flame
─────────────────────────────────
NEARBY
[李莉  ] macOS · 18ms        [发送]
[坤    ] Win   · 32ms        [发送]
[嘉伟  ] iOS   · 14ms        [发送]
[孟茜  ] ...                  [发送]
─────────────────────────────────
[打开 meshdrop] [⚙]
```

### Toast (incoming)

```
┌─ meshdrop — Internet Sharing      now × ─┐
│                                       │
│ [Avatar 坤] 坤 想发文件给你          │
│             IMG_4821~4838.heic       │
│             128 MB · 18 张            │
│                                       │
│ [接收] [拒绝] [查看]                  │
└───────────────────────────────────────┘
```

## 关键交互

| 触发 | 行为（mock） |
| --- | --- |
| 点设备 row（sidebar） | 主区域切换 Chat or Discovery details |
| 右键 device | contextMenu：发送文件…/开始聊天/同步剪贴板/撤销信任 |
| 拖文件到设备 row | drop zone 高亮 (lime dashed) → 释放 alert "已发送（mock）" |
| WIN+S | 唤出 TrayFlyout |
| Ctrl+, | 打开 SettingsPage |
| Toast "接收" 按钮 | mock 完成接收 |
| 任务栏图标点击 | 唤出主窗口 |

## 编译

```powershell
cd windows
dotnet restore
dotnet build MeshDrop.sln -c Debug -p:Platform=x64
dotnet run --project MeshDrop -c Debug -p:Platform=x64
```

## 截图清单（PR 必须附 28 张）

```
screenshots/win-{discovery|chat|transfers|history|settings|trust|pairing|onboarding|receive}-{light|dark}.png  (18)
screenshots/win-statusbar-{light|dark}.png  (2)（局部截 status bar）
screenshots/win-tray-flyout-{collapsed|expanded}.png  (2)
screenshots/win-toast-incoming-{file|text}.png  (2)
screenshots/win-terminal-block-detail.png  (1)（局部截 Discovery 右侧 terminal 区）
```

## 验收 checklist

- [ ] `dotnet build` 一次过
- [ ] 任务栏图标显示 meshdrop mark（lime dot 可见）
- [ ] Discovery 右侧 terminal block 字体真的是 Geist Mono（等宽）
- [ ] **没有 Fluent 默认蓝**（除了 hyperlink）— 所有强调色用 lime
- [ ] TrayFlyout WIN+S 能展开
- [ ] Toast 三按钮可点击
- [ ] outgoing 气泡 dark 模式用 lime 底
- [ ] 文件 grep 无 "Shar / FreqShare / 至汝 / drop.mesh" 残留（这些是旧名）
- [ ] 25 张截图全附

## 不能做（端特有）

- 不要用 `#0078D4`（Fluent 默认蓝）作为 accent — 改用 lime
- 不要用 default `Accent` SystemBrush — 引用自定义 MeshDropColors
- TrayFlyout 必须用 `H.NotifyIcon.WinUI`（不是 deprecated System.Drawing.NotifyIcon）
- 不要在 ViewModel 调真实 MeshDropEngine.Send*（本轮 mock）
