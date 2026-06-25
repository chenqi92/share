# Android

Jetpack Compose + Material 3 + Kotlin 2.4.0 + AGP 8.13.2。最低 SDK 26 (Android 8)，
目标 SDK 35 (Android 15)。

```
android/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle.properties
├── gradle/libs.versions.toml
└── app/
    ├── build.gradle.kts
    └── src/main/
        ├── AndroidManifest.xml
        ├── java/com/welape/meshdrop/
        │   ├── ShareApplication.kt
        │   ├── MainActivity.kt
        │   ├── data/          # Device, Identity, TXTRecord
        │   ├── discovery/     # NsdManager 包装
        │   ├── ui/            # Compose + theme
        │   └── viewmodel/
        └── res/values/{strings,themes}.xml
```

## 构建 / 测试

```bash
cd android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
./gradlew :app:installDebug
```

或者直接 Android Studio 打开 `android/` 目录。

## 当前覆盖

- ✅ Identity（Ed25519，EncryptedSharedPreferences 存储，AndroidKeyStore 派生主密钥）
- ✅ mDNS 发现（NsdManager + 协程封装）
- ✅ TCP framing / HELLO / HELLO_ACK / TOFU pairing
- ✅ TEXT / CLIPBOARD / FILE offer/chunk/complete/cancel
- ✅ FILE_ACCEPT.resume_offset 断点续传
- ✅ Share Target + 待发送选择目标
- ✅ Wear OS DataLayer bridge
- ✅ Compose UI（Material 3 + 动态色 / Material You）
- ✅ Android 13+ NEARBY_WIFI_DEVICES 运行时权限
- ✅ 截图测试使用 Paparazzi `2.0.0-alpha05`
- ⚠️ UI 层仍复用 `mock/MockData.kt` 里的 DTO / preview sample；运行时入口已优先走 ShareEngine

## TODO

- [ ] TLS 1.3 双向证书校验 / 应用层端到端加密（v0.1 LAN 传输仍为明文 TCP）
- [ ] 切到 `NsdManager.registerServiceInfoCallback`（API 33+ 替代已废弃的
      `resolveService`）
- [ ] 把 UI DTO 从 `Mock*` 命名迁到 `Display*`，降低误读
