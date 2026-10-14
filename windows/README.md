# Windows

WinUI 3 (Windows App SDK 1.7) + .NET 8 + C# 12。最低支持 Windows 10 1809
(17763)，同时支持 Windows 11。

与 macOS、iPhone、iPad 上的 MeshDrop 1.1 或更新版本通过同一局域网互传；
双方收发时保持应用打开。Windows 暂不支持蓝牙传输或 Apple 点对点 Wi-Fi。

- [Apple App Store：iPhone / iPad / Mac](https://apps.apple.com/app/meshdrop/id6772689903)
- [GitHub 开源仓库（MIT）](https://github.com/chenqi92/share)
- [官网与使用介绍](https://kkape.com/tools/share)
- [隐私政策](https://kkape.com/privacy/share/)

```
windows/
├── MeshDrop.sln
└── MeshDrop/
    ├── MeshDrop.csproj             # net8.0-windows10.0.19041.0, UseWinUI=true
    ├── App.xaml + App.xaml.cs      # Application + Program.Main
    ├── MainWindow.xaml + .cs       # Sidebar | Pages | StatusBar
    ├── app.manifest                # DPI, longPathAware
    ├── Theme/                      # MeshDropColors (light/dark) + Fonts + Generic
    ├── Mock/MockData.cs            # UI DTO + preview sample（运行时由 EngineProjection 投影）
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
| Microsoft.WindowsAppSDK 1.7              | WinUI 3 运行时                |
| Makaretu.Dns.Multicast.New 0.38          | mDNS responder + querier      |
| NSec.Cryptography 24.4                   | Ed25519 (libsodium 绑定)      |
| BouncyCastle.Cryptography 2.7           | Windows 10 / 11 上的 TLS 1.3 |
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

## Microsoft Store 打包

在 Windows 上安装 .NET 8 SDK 后，从仓库根目录运行：

```powershell
.\windows\build-store.ps1 -Architecture x64
.\windows\build-store.ps1 -Architecture ARM64
```

脚本按现有图案生成包含透明遮罩的多尺寸 ICO、任务栏的浅色／深色无底板 PNG 和 Store 磁贴资源，构建 Release MSIX，并将 .NET 和
Windows App SDK 运行时包含在包内。输出位于 `windows/artifacts/store/`。
这些包供 Partner Center 上传，由 Microsoft Store 签名；未签名的输出不能直接
双击安装。常规 `dotnet build` / `dotnet run` 仍使用未打包开发模式。

`MeshDrop/Package.appxmanifest` 已关联 Store 产品 `9P08D0SRNPZ2`，包名为
`KKAPE.MeshDrop`，发布者为 `KKAPE`。版本号需要同步维护清单的四段版本和
`MeshDrop.csproj` 中的 `Version`。MSIX 自启使用系统 `StartupTask`，
未打包版本继续使用当前用户启动文件夹快捷方式。

原生传输使用 TLS 1.3 双向认证，P-256 传输证书绑定现有 Ed25519 设备身份，
与 Apple 的证书协议对齐；浏览器入口也使用随包提供的 TLS 1.3 实现，不依赖
Windows 11 的 SChannel。旧版明文客户端不能连接。

传输回归测试：`dotnet test windows/MeshDrop.Transport.Tests`（从仓库根目录）。
其中独立系统 TLS 互操作用例需在支持 TLS 1.3 的系统（如 Windows 11）运行。
提交前还需在 Windows 10 实机以及已上线 Apple 版本上验证启动、发现和文本/文件
双向互传；构建、回环测试和本地认证均不能替代这些实机检查。

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
- ✅ Toast 构造器（文件 接收 / 拒绝 / 查看；TOFU 配对 允许并记住 / 允许一次 / 拒绝）
- ✅ UI 主路径已通过 `EngineProjection` 接 ShareEngine；`MockData.cs` 只保留 DTO / preview sample
- ✅ Chat composer（发送文本 / 选文件 / 拖拽发送）、Trust 页 TOFU 待审审批与撤销信任、配对对话框均已接线
- ✅ 文件待接收横幅与传输页接收／拒绝卡片；关闭系统通知时仍可处理照片和文件
- ✅ 会话按时间正序排列、跟随最新消息，并显示失败原因；未完成的接收文件不可打开或转存

## 协议层状态

已接入：Protocol/Frame、Messages；Models/Identity、TXTRecord、TrustStore；
Discovery/MdnsDiscovery；Transport/ShareEngine、Connection；WebGatewayHost。

当前限制：
- Windows WinUI 项目必须在 Windows + .NET 8 / Windows App SDK 环境构建；macOS 上无法验证。
- 文件断点续传已接入 `FILE_ACCEPT.resume_offset`：接收侧持久化半成品进度，重发同一文件时自动从已落盘 offset 续传。
- LAN 传输强制 TLS 1.3、ALPN `meshdrop/1`，验证双方证书和 HELLO 身份；Web Gateway 同样强制 TLS 1.3。
- TLS 的同步流通过独立读写任务适配，接收循环等待数据时仍能发送接收确认；回归测试覆盖延迟确认后传送 517 KB 文件。
- TEXT / FILE_OFFER 接收侧已做 5 分钟窗口重放去重。
- Settings 已接入可见性、设备信任与登录自启；自定义接收目录的浏览按钮仍禁用。
