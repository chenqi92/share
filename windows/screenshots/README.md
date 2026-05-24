# windows/screenshots

WinUI 3 (.NET 8) 必须在 Windows 上构建并运行才能抓图。本目录用于
存放 28 张验收截图。**未上传的截图需在 Windows 环境下生成后补齐。**

## 拍摄清单 (28 张)

亮 / 暗双模式：

| # | 文件名 | 拍摄方式 |
|---|---|---|
| 1 | `win-discovery-light.png` | Discovery 全屏，Light 主题 |
| 2 | `win-discovery-dark.png` | Discovery 全屏，Dark 主题 |
| 3 | `win-chat-light.png` | Chat 与李莉的会话流 |
| 4 | `win-chat-dark.png` | 同上 Dark |
| 5 | `win-transfers-light.png` | Transfers 页（3 DashTile + 任务列表） |
| 6 | `win-transfers-dark.png` | 同上 Dark |
| 7 | `win-history-light.png` | History（含 Clipboard + Today） |
| 8 | `win-history-dark.png` | 同上 Dark |
| 9 | `win-settings-light.png` | Settings 页 |
| 10 | `win-settings-dark.png` | 同上 Dark |
| 11 | `win-trust-light.png` | Trust manager |
| 12 | `win-trust-dark.png` | 同上 Dark |
| 13 | `win-pairing-light.png` | PairingDialog 打开 |
| 14 | `win-pairing-dark.png` | 同上 Dark |
| 15 | `win-onboarding-light.png` | OnboardingDialog 打开 |
| 16 | `win-onboarding-dark.png` | 同上 Dark |
| 17 | `win-receive-light.png` | FileOfferDialog 打开 |
| 18 | `win-receive-dark.png` | 同上 Dark |

局部 / 特殊：

| # | 文件名 | 拍摄方式 |
|---|---|---|
| 19 | `win-statusbar-light.png` | 仅截 main window 底部 26px 状态条 |
| 20 | `win-statusbar-dark.png` | 同上 Dark |
| 21 | `win-tray-flyout-collapsed.png` | 系统托盘图标（任务栏右下角） |
| 22 | `win-tray-flyout-expanded.png` | 点击托盘图标展开的 Flyout |
| 23 | `win-toast-incoming-file.png` | ToastBuilder.BuildIncomingFile 触发的系统通知 |
| 24 | `win-toast-incoming-text.png` | ToastBuilder.BuildIncomingText 触发的系统通知 |
| 25 | `win-terminal-block-detail.png` | 仅截 Discovery 右侧 "network details" 黑底 lime 区 |
| 26 | `win-send-dialog-light.png` | SendDialog 打开 |
| 27 | `win-send-dialog-dark.png` | 同上 Dark |
| 28 | `win-radar-detail.png` | 单独截雷达本体（sweep 转一圈） |

## 抓图脚本

```powershell
# 准备
cd windows
dotnet restore
dotnet build MeshDrop.sln -c Debug -p:Platform=x64

# 启动
dotnet run --project MeshDrop -c Debug -p:Platform=x64

# 切主题
# 启动时 App.xaml.cs 默认进 Dark。要切 Light：在 App.cs 改
# RequestedTheme = ApplicationTheme.Light 后重新运行。
# 或者直接在系统设置切 → 配色 → 浅色，因为本应用所有 brush 都走 ThemeResource。

# 用 Win+Shift+S（截图工具）截屏，按上表命名保存到 windows/screenshots/
```

## 字体注意

`MeshDrop/Assets/Fonts/` 里需要先放入 Space Grotesk / Geist / Geist Mono
（OFL），否则 Discovery 右侧 terminal block 不会渲染 Geist Mono，会回退到
Cascadia Mono。视觉差异较小但 PR 验收要求是 Geist Mono。
