# Windows

WinUI 3 (Windows App SDK 1.6) + .NET 8 + C# 12。最低支持 Windows 10 1809
(17763)，目标 Windows 11 23H2+。

```
windows/
├── MeshDrop.sln
└── MeshDrop/
    ├── MeshDrop.csproj             # net8.0-windows10.0.19041.0, UseWinUI=true
    ├── App.xaml + App.xaml.cs      # Application + Program.Main
    ├── MainWindow.xaml + .cs       # Sidebar | Pages | StatusBar
    ├── app.manifest                # DPI, longPathAware
    ├── Theme/                      # MeshDropColors (light/dark) + Fonts + Generic
    ├── Mock/MockData.cs            # COMMON §9 数据
    ├── Models/                     # 协议层（保留）
    ├── Protocol/, Transport/, Discovery/   # 协议层（保留）
    ├── ViewModels/                 # Shell + 6 个 Page 的 VM
    ├── Views/
    │   ├── Shell/  ShellSidebar, ShellStatusBar
    │   ├── Pages/  Discovery, Chat, Transfers, History, Trust, Settings
    │   ├── Controls/ MeshDropLogo, Avatar, Chip, KindGlyph, Radar,
    │   │            MsgBubble, FileChip, TransferRow, DashTile, AsciiDivider
    │   └── Dialogs/ Send, Pairing, FileOffer, Onboarding
    ├── TrayIcon/TrayIconHost + TrayFlyout    # H.NotifyIcon.WinUI
    ├── Notifications/ToastBuilder            # CommunityToolkit.WinUI.Notifications
    └── Assets/                     # 图标 + Fonts/ (OFL，按需放入)
```

## 依赖

| 包                                       | 用途                          |
| ---------------------------------------- | ----------------------------- |
| Microsoft.WindowsAppSDK 1.6              | WinUI 3 运行时                |
| Makaretu.Dns.Multicast.New 0.38          | mDNS responder + querier      |
| NSec.Cryptography 24.4                   | Ed25519 (libsodium 绑定)      |
| CommunityToolkit.Mvvm 8.4                | `[ObservableProperty]` 等     |
| CommunityToolkit.WinUI.Notifications 7.1 | Toast 构造                    |
| H.NotifyIcon.WinUI 2.1                   | 系统托盘（替代 deprecated NotifyIcon） |

## 构建

需 Visual Studio 2022 17.10+ 或 .NET 8 SDK + Windows App SDK 模板（仅 Windows）。

```powershell
cd windows
dotnet restore
dotnet build MeshDrop.sln -c Debug -p:Platform=x64
dotnet run --project MeshDrop -c Debug -p:Platform=x64
```

或 VS 打开 `MeshDrop.sln` → F5。

## 字体

`MeshDrop/Assets/Fonts/` 需要放入 OFL 协议字体：
- `SpaceGrotesk-Variable.ttf`（display）
- `Geist-Variable.ttf`（body）
- `GeistMono-Variable.ttf`（mono，Discovery 右侧终端区必须用）

文件本身不入仓（OFL 字体大且 design/fonts/ 已是全局存放地）。Theme/MeshDropFonts.xaml
的 FontFamily 资源会回退到 Cascadia Mono / Segoe UI Variable，构建仍能通过。

## 当前 UI 进度

- ✅ 主题 token (MeshDropColors light/dark) + 字体堆栈
- ✅ Discovery + Chat + Transfers + History + Trust + Settings 6 个 Page
- ✅ 12 个共享控件（Radar sweep + pulse、MsgBubble、FileChip、TransferRow、DashTile…）
- ✅ Send / Pairing / FileOffer / Onboarding 4 个对话框
- ✅ 系统托盘 + Tray Flyout (mini live transfer + Nearby)
- ✅ Toast 构造器（接收 / 拒绝 / 查看 三按钮）
- ⚠️ 本轮 UI-only，**未接** ShareEngine — 所有数据来自 Mock/MockData

## 协议层状态

保留：Protocol/Frame、Messages；Models/Identity、TXTRecord、TrustStore；
Discovery/MdnsDiscovery；Transport/ShareEngine、Connection。本轮 UI 不调用它们。
