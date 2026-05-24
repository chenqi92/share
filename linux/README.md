# Linux

Rust + GTK4 + libadwaita + mdns-sd + ed25519-dalek。最低 GTK 4.12 / libadwaita 1.5
（Ubuntu 24.04、Fedora 40+ 默认满足）。

```
linux/
├── Cargo.toml
├── data/
│   └── meshdrop.desktop
└── src/
    ├── main.rs        # adw::Application 入口
    ├── ui.rs          # MainWindow（AdwApplicationWindow + 设备 ListBox）
    ├── device.rs      # Device 数据模型
    ├── identity.rs    # Ed25519 (ed25519-dalek)
    ├── txt.rs         # mDNS TXT 编解码
    └── discovery.rs   # ServiceDaemon register + browse
```

## 系统依赖

构建期需要 GTK4 / libadwaita 开发头文件：

- **Ubuntu 24.04+**: `sudo apt install libgtk-4-dev libadwaita-1-dev`
- **Fedora 40+**:    `sudo dnf install gtk4-devel libadwaita-devel`
- **Arch**:           `sudo pacman -S gtk4 libadwaita`

运行时也需要对应 runtime 包（一般和 dev 包一起装）。

## 构建

```bash
cd linux
cargo build --release
cargo run --release
```

## 安装（可选）

```bash
sudo install -Dm755 target/release/meshdrop /usr/local/bin/meshdrop
sudo install -Dm644 data/meshdrop.desktop \
    /usr/local/share/applications/meshdrop.desktop
# 多分辨率图标（hicolor 主题）
for size in 48 64 128 256 512; do
  sudo install -Dm644 "data/icons/hicolor/${size}x${size}/apps/drop.mesh.linux.png" \
    "/usr/share/icons/hicolor/${size}x${size}/apps/drop.mesh.linux.png"
done
sudo gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
```

## 当前覆盖

- ✅ Identity（Ed25519 via ed25519-dalek，明文落 `~/.local/share/MeshDrop/`）
- ✅ mDNS 发现（mdns-sd register + browse）
- ✅ GTK4 / libadwaita 设备列表（AdwActionRow + AdwStatusPage）
- ⚠️ Transport：accept 后直接 close（骨架）
- ⚠️ 私钥未走 libsecret；Pairing / Text / File：未实现

## TODO

- [ ] 私钥落 libsecret（`secret-service` crate）
- [ ] TCP 协程化（tokio）+ Frame 读写
- [ ] HELLO 握手 + AdwMessageDialog 配对确认
- [ ] TEXT 发送
- [ ] FILE 传输（含 `gtk::FileChooserNative` 选择文件）
- [ ] TLS 1.3 双向证书校验（rustls）
- [ ] Flatpak 打包（org.freedesktop.Platform/24.08）
