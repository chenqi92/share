# 服务发现（discovery）

使用 mDNS / DNS-SD（RFC 6762、RFC 6763）进行同网段设备发现。

## 服务类型

```
_meshdrop._tcp.local.
```

每台设备启动时同时承担 **responder**（广告自身）与 **querier**（浏览其他设备）
两个角色。

## TXT 记录

DNS-SD TXT 记录承载发现阶段需要的元数据。字段如下，全部为 ASCII 键、UTF-8 值
（RFC 6763 §6 规定单条 TXT 字符串 ≤ 255 字节；本协议下所有字段加起来不会超过
该上限）：

| key   | 必选 | 含义                                                                  |
| ----- | ---- | --------------------------------------------------------------------- |
| `v`   | 是   | 协议版本号，十进制 ASCII，例如 `1`                                    |
| `id`  | 是   | 设备 UUID，32 位小写 hex（去掉短横）                                  |
| `name`| 是   | 显示名。原始 UTF-8 经 **base64url**（无 padding）编码后写入；接收端解码 |
| `os`  | 是   | `ios` / `android` / `macos` / `windows` / `linux` 之一                |
| `model`| 否  | 设备型号字符串，例如 `iPhone16,1`、`Pixel 8 Pro`；用于 UI 显示图标    |
| `fp`  | 是   | 公钥指纹：`SHA-256(ed25519_public_key)` 取前 16 字节，转 32 位小写 hex |
| `port`| 是   | 业务 TCP 端口，十进制 ASCII                                            |

**字段约束**：

- `name` 用 base64url 编码是因为 mDNS TXT 字符串原则上 ASCII 可打印；中文 / Emoji
  显示名直接写会出现实现间差异。各端解码后再展示。
- 未列出的额外 key 接收端必须忽略，不能据此判断设备非法。

## 行为约定

1. **启动**：分配端口 → 注册服务 `_meshdrop._tcp.local.` → 同时开始浏览同类型
   服务。
2. **自发现过滤**：浏览到的服务若其 TXT 中的 `id` 等于本机 `id`，必须过滤掉。
   不能依赖 hostname 或 IP 来判断（多接口、多 IP 场景下不可靠）。
3. **更新通知**：用户改名后，更新本机 ServiceProfile 的 TXT 记录并重新广告
   （DNS-SD goodbye + 新公告）。
4. **离线**：应用退出前应发送 mDNS goodbye 包（TTL=0），便于其他端及时下线
   该设备。平台 API 一般会自动处理；杀进程场景下其他端依赖 TTL 自然过期。

## 各端 API 对照

| 平台    | API                                                                  |
| ------- | -------------------------------------------------------------------- |
| Apple   | `Network.framework`: `NWListener.Service`、`NWBrowser.Descriptor.bonjourWithTXTRecord` |
| Android | `android.net.nsd.NsdManager` + `NsdServiceInfo`（PROTOCOL_DNS_SD）   |
| Windows | NuGet `Makaretu.Dns.Multicast.New`：`ServiceProfile` + `ServiceDiscovery` |
| Linux   | crate `mdns-sd`：`ServiceDaemon::register` + `browse`                |

## iOS / macOS Info.plist 要求

iOS 14+ / macOS 11+ 访问本地网络需声明：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>用于发现同网络下的 MeshDrop 设备</string>
<key>NSBonjourServices</key>
<array>
    <string>_meshdrop._tcp</string>
</array>
```

## Android 权限

`AndroidManifest.xml` 需声明：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
```

并在 Android 13+ 对 `NEARBY_WIFI_DEVICES` 运行时申请（用于在不获取定位权限的
前提下使用 Wi-Fi 服务发现）：

```xml
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
    android:usesPermissionFlags="neverForLocation"/>
```

## 测试

合规实现需通过以下自检：
- 启动后能在另一端 `dns-sd -B _meshdrop._tcp` 中看到自己；
- TXT 字段全部存在，`v=1`、`os` 取值合法、`name` 能 base64url 解码回 UTF-8；
- 改名后 5 秒内其他端能看到新名字；
- 退出后其他端在 ≤ 75 秒（mDNS 默认 TTL）内将其下线。
