# MeshDrop · Windows Backend 接入 + Web Gateway Prompt

## 端特定任务

Windows 端 UI 这一轮**部分接了 backend**（real=2 mock=5）。本轮：

1. 把剩余 5 个还在用 MockData 的 ViewModel/Page 切到真 `MeshDropEngine.Instance`
2. **新增 Web Gateway 模块**（Windows 端兼任浏览器的 LAN 桥）
3. 补错误 / Loading / 空态

## 工作范围

- ✅ `windows/MeshDrop/` 全部（除 `Mock/MockData.cs` Preview 仍可用）
- ❌ 其他端目录

## 必做

### 1. 把 mock=5 切到 real

grep 找出哪 5 个文件还用 `MockData`：

```bash
grep -rln "MockData" windows/MeshDrop --include='*.cs'
```

每个文件把 `MockData.Devices` 之类的换成 `MeshDropEngine.Instance.Devices`（用 `ObservableCollection<T>` + CommunityToolkit.Mvvm 的 ObservableProperty）。

XAML 文件里 `{Binding MockData...}` 改 `{Binding Engine.Devices}` 等。

### 2. App 启动 / 关闭

`App.xaml.cs` 的 `OnLaunched`：

```csharp
await MeshDropEngine.Instance.StartAsync();
```

`OnSuspending` 调 `StopAsync()`。

### 3. 错误 / Loading / 空态

`ShellStatusBar.xaml` 显示 engine 状态：
- `Engine.IsStarting` → "扫描中…"
- `Engine.LastError` → toast
- `Engine.Devices.Count == 0` → DiscoveryPage 显空态卡片

### 4. Web Gateway 模块（新增）

新增：

```
windows/MeshDrop/Gateway/
├── WebGatewayHost.cs      # HttpListener + WebSocket
├── GatewayCommands.cs     # 命令路由
├── GatewayCert.cs         # 自签证书（X509Certificate2，存到 Cert:\\LocalMachine\\My）
└── PairingCodeFlyout.xaml # Settings → Web 访问段
```

实装 `protocol/companion-bridges.md §1+§2+§4.3`：

- `System.Net.HttpListener` 监听 `https://*:7384/`
- 命令：解析 → 调 `MeshDropEngine.Instance.{SendText,SendFile,AcceptOffer,...}` → JSON 回执
- 事件：订阅 engine 的 `INotifyPropertyChanged`，把 device_added / offer_pending / transfer_progress 推到所有连接的 WebSocket clients
- 自签证书首次启动生成，CN = `meshdrop.local`，存 windows 证书 store
- 6 字符 pairing code 每 24h 新生成，存 `LocalSettings`
- `GET /` 返回 `windows/MeshDrop/Assets/web-fallback/index.html` 作占位

### 5. Settings → Web 访问段

`SettingsPage.xaml` 新增 expander："Web 访问 · Web access"。
显示：当前 URL（含 LAN IP）、6 字符 pairing code、QR 二维码、开关。

## 验证

```powershell
cd windows
dotnet restore
dotnet build MeshDrop.sln -c Debug -p:Platform=x64
dotnet run --project MeshDrop -c Debug -p:Platform=x64
```

互通：1 台 Windows + 1 台 mac，互发文本 + 5 MB 文件。

启动后用浏览器进 `https://<windows-ip>:7384`，看到 placeholder + pairing code 弹框即 OK。

## PR 标题

`backend(windows): 切换 UI 到 MeshDropEngine + 新增 Web Gateway`

## 互通证据

- 1 段 ≥ 15s mp4：windows ↔ mac 互发
- 1 段截图：浏览器进 gateway 看到 pairing code 输入界面

## 不能做

- 不删 `Mock/MockData.cs`（Preview 用）
- 不改 protocol/ 核心规范
- 不引第三方 web framework（用 HttpListener 手写，或 `System.Net.WebSockets`）
- 不在 ViewModel 里写 HttpListener 代码（统一在 Gateway/）
- 不在 PR 里附 mock 数据截图当互通证据
