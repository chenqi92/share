# Windows

WinUI 3 (Windows App SDK 1.6) + .NET 8 + C# 12。最低支持 Windows 10 1809
(17763)，目标 Windows 11 23H2+。

```
windows/
├── ShareWindows.sln
└── ShareWindows/
    ├── ShareWindows.csproj      # net8.0-windows10.0.19041.0, UseWinUI=true
    ├── App.xaml + App.xaml.cs   # Application + Program.Main
    ├── MainWindow.xaml + .cs
    ├── app.manifest             # DPI, longPathAware
    ├── Models/                  # Device, Identity, TXTRecord
    ├── Discovery/MdnsDiscovery.cs
    ├── ViewModels/
    └── Assets/                  # 图标，TODO 补
```

## 依赖

| 包                                | 用途                            |
| --------------------------------- | ------------------------------- |
| Microsoft.WindowsAppSDK 1.6       | WinUI 3 运行时                   |
| Makaretu.Dns.Multicast.New 0.38   | mDNS responder + querier        |
| NSec.Cryptography 24.4            | Ed25519 (libsodium 绑定)        |
| CommunityToolkit.Mvvm 8.4         | `[ObservableProperty]` 等       |

## 构建

需 Visual Studio 2022 17.10+ 或 .NET 8 SDK + Windows App SDK 模板。

```powershell
cd windows
dotnet restore
dotnet build ShareWindows.sln -c Debug -p:Platform=x64
dotnet run --project ShareWindows -c Debug -p:Platform=x64
```

或 VS 打开 `ShareWindows.sln` → F5。

## 当前覆盖

- ✅ Identity（Ed25519 via NSec/libsodium，DPAPI 加密落 LocalAppData）
- ✅ mDNS 发现（Makaretu.Dns ServiceDiscovery）
- ✅ WinUI 3 设备列表 + 顶部信息卡
- ⚠️ Transport：accept 后直接 close
- ⚠️ Pairing / Text / File：未实现

## TODO

- [ ] TcpClient/TcpListener 接入 Frame 读写
- [ ] HELLO 握手 + 配对 ContentDialog
- [ ] TEXT 发送
- [ ] FILE 传输（含 FileSavePicker / FileOpenPicker）
- [ ] TLS 1.3 双向证书校验（SslStream + 自签证书）
- [ ] Mica 背景 + Acrylic
