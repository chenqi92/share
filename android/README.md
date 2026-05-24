# Android

Jetpack Compose + Material 3 + Kotlin 2.1 + AGP 8.7。最低 SDK 26 (Android 8)，
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
        ├── java/freq/share/
        │   ├── ShareApplication.kt
        │   ├── MainActivity.kt
        │   ├── data/          # Device, Identity, TXTRecord
        │   ├── discovery/     # NsdManager 包装
        │   ├── ui/            # Compose + theme
        │   └── viewmodel/
        └── res/values/{strings,themes}.xml
```

## 构建

第一次需要生成 Gradle Wrapper（用本机已安装的 Gradle）：

```bash
cd android
gradle wrapper --gradle-version 8.11
./gradlew :app:assembleDebug
./gradlew :app:installDebug
```

或者直接 Android Studio 打开 `android/` 目录，IDE 会自动同步并生成 wrapper。

## 当前覆盖

- ✅ Identity（Ed25519，SharedPreferences 存储，TODO 切到 EncryptedSharedPreferences）
- ✅ mDNS 发现（NsdManager + 协程封装）
- ✅ Compose UI（Material 3 + 动态色 / Material You）
- ✅ Android 13+ NEARBY_WIFI_DEVICES 运行时权限
- ⚠️ Transport：accept 后直接 close（骨架）
- ⚠️ Pairing / Text / File：未实现

## TODO

- [ ] EncryptedSharedPreferences 替换 SharedPreferences
- [ ] TCP I/O 协程实装 Frame 读写
- [ ] HELLO 握手 + 配对对话框
- [ ] TEXT 发送
- [ ] FILE 传输（含 SAF 选择 / 写入）
- [ ] TLS 1.3 双向证书校验
- [ ] 切到 `NsdManager.registerServiceInfoCallback`（API 33+ 替代已废弃的
      `resolveService`）
