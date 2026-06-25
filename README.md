# MeshDrop

**AirDrop for everyone — cross-platform, peer-to-peer LAN file & text sharing.**
Devices on the same network discover each other automatically; pick a target and
send a note or a batch of files. **Every client is natively implemented** — no
Electron, Flutter, or React Native — for the best performance and platform feel.

[![Download on the App Store](https://img.shields.io/badge/App_Store-MeshDrop-0D96F6?style=flat&logo=apple&logoColor=white)](https://apps.apple.com/cn/app/meshdrop/id6772689903)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-macOS%20·%20iOS%20·%20Android%20·%20Windows%20·%20Linux%20·%20Web-blue)

**English** · [简体中文](README.zh-CN.md)

---

## Screenshots

<table>
  <tr>
    <td align="center"><img src="screenshots/macos-discovery-dark.png" width="420"><br><sub>macOS · discovery</sub></td>
    <td align="center"><img src="screenshots/macos-dragdrop-dark.png" width="420"><br><sub>macOS · drag &amp; drop to send</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/linux-gui-chat-dark.png" width="420"><br><sub>Linux (GTK4) · chat</sub></td>
    <td align="center"><img src="screenshots/macos-pairing-dark.png" width="420"><br><sub>macOS · TOFU pairing</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/android-phone-discovery-dark.png" width="200"><br><sub>Android</sub></td>
    <td align="center"><img src="screenshots/tvos-nearby-dark.png" width="420"><br><sub>tvOS (receive-only)</sub></td>
  </tr>
</table>

> Wearables too: Apple Watch & Wear OS act as companions to the phone app
> (`screenshots/applewatch-nearby-dark.png`, `screenshots/wearos-nearby-dark.png`).

## Features

- **Zero setup, zero servers** — mDNS / DNS-SD discovery + direct TCP. No signaling
  server, no cloud relay, no account, no internet required.
- **Send text or files** to any device on the LAN, with a full offer / accept /
  reject / cancel flow.
- **Resumable transfers** — interrupted file transfers resume from where they stopped
  (`FILE_ACCEPT.resume_offset`).
- **Trust on first use (TOFU)** — first connection asks you to confirm the peer's
  fingerprint; trusted devices are remembered, SSH `known_hosts`-style.
- **Native on every platform** — SwiftUI, Jetpack Compose, WinUI 3, GTK4/ratatui,
  React — each client follows its platform's HIG.
- **Browser access** — desktop clients expose a built-in Web Gateway (TLS 1.3,
  self-signed) so a browser on the LAN can join.
- **Wearable companions** — Apple Watch (WatchConnectivity) and Wear OS
  (Wearable Data Layer) bridge to the phone app.
- **Share integration** — iOS Share Extension and Android Share Target.

## Download / Install

| Platform | How to get it |
| --- | --- |
| **iOS / iPadOS / macOS / tvOS / visionOS / watchOS** | [**App Store**](https://apps.apple.com/cn/app/meshdrop/id6772689903) (1.0, build 2) |
| Android / Windows / Linux / Web | Build from source (pre-release `0.1.0`) — see the per-platform READMEs below |

## Platforms

| Platform | Stack | Status |
| --- | --- | --- |
| macOS | SwiftUI + Network.framework | Builds / MeshDropKit tests pass |
| iOS 17+ / iPadOS | SwiftUI + Network.framework | ✅ Shipped on the App Store (1.0, build 2) |
| iOS 26 | + Liquid Glass (`.glassEffect()`) | UI wired |
| tvOS | SwiftUI focus engine (receive-only) | Shares the Apple core |
| visionOS | SwiftUI spatial + glass | Engine adapter wired (preview mock retained) |
| watchOS | SwiftUI + WatchConnectivity bridge to iPhone | Companion bridge |
| Android | Jetpack Compose + `NsdManager` | Build + unit/screenshot tests |
| Wear OS | Compose for Wear + Wearable Data Layer bridge to Android | Builds |
| Windows | WinUI 3 (.NET 8) + `Makaretu.Dns` | Builds with .NET 8 + Windows App SDK |
| Linux GUI | Rust + gtk4-rs + libadwaita + `mdns-sd` | Core tests + GUI build |
| Linux TUI | Rust + ratatui + `mdns-sd` | Build/test pass (10 unit tests) |
| Web | React + Vite, via the Gateway bridge | Builds; mock only with explicit `?mock=1` |

> **Versioning:** only the Apple targets (iOS / iPadOS / macOS / tvOS / visionOS /
> watchOS) are at `1.0.0` (build 2) and shipped to the App Store. Android / Wear OS /
> Linux / Web are still `0.1.0` pre-release.
>
> **Bundle identifiers are per-platform, not unified:** Apple = `com.welape.landrop`,
> Android = `com.welape.meshdrop`, Wear OS = `com.welape.meshdrop.wear`.

## How it works

Every client implements one self-designed, language-agnostic protocol
(see [protocol/](protocol/README.md)):

1. **Discovery** — advertise/browse `_meshdrop._tcp` over mDNS / DNS-SD.
2. **Connect & handshake** — TCP framing + `HELLO` / `HELLO_ACK` with version
   negotiation.
3. **Pair** — on first contact the receiver confirms the sender's fingerprint (TOFU);
   trusted devices skip this afterwards.
4. **Transfer** — `TEXT`, or `FILE_OFFER → ACCEPT → CHUNK → COMPLETE` with SHA-256
   integrity check and resume support.

Desktop clients additionally run a Web Gateway (TLS 1.3 self-signed cert + WebSocket
control channel + multipart upload) so browsers can join from the LAN
(see [protocol/companion-bridges.md](protocol/companion-bridges.md)).

## Security status (v0.1) ⚠️

Please read before relying on this for sensitive data:

- LAN transport is **plaintext TCP** in v0.1.
- The TOFU fingerprint **only prevents accidental mis-connection — it does not resist an
  active MITM** (the `fp` is not yet bound to a key or certificate).
- The Web Gateway itself uses TLS 1.3 (self-signed), but the device-to-device channel
  does not.
- End-to-end application-layer encryption is on the roadmap (added in v0.2, enforced from v1.0).

**Do not market or treat the current version as "end-to-end encrypted / secure
transport."** Details: [protocol/security.md](protocol/security.md).

## Build from source

Each platform subdirectory has its own README with prerequisites and steps:

- [apple/README.md](apple/README.md) — Swift Package `MeshDropKit` + the Apple apps.
  Requires macOS + Xcode + [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  (`xcodegen generate` per target). **The committed `DEVELOPMENT_TEAM` is the original
  author's Apple team — forks must replace it with their own** to sign/run.
- [android/README.md](android/README.md) — Gradle (AGP 8.13.2, Kotlin 2.4.0, JDK 17+; project targets Java 17).
- [wearos/README.md](wearos/README.md) — Wear OS (Gradle).
- [windows/README.md](windows/README.md) — .NET 8 + Windows App SDK (build on Windows).
- [linux/README.md](linux/README.md) — Cargo workspace (Rust + GTK4 + ratatui).
- [web/README.md](web/README.md) — React + Vite (`npm install && npm run build`).

A convenience script runs whatever the current machine can build/test:

```bash
./scripts/verify-local.sh
```

## Project layout

```
share/
├── protocol/   # Protocol spec (language-agnostic) — the source of truth for all clients
├── apple/      # Swift Package MeshDropKit + macOS / iOS / iPadOS / tvOS / visionOS / watchOS
├── android/    # Gradle project (Kotlin + Compose)
├── wearos/     # Wear OS (Kotlin)
├── windows/    # .NET 8 + WinUI 3 solution
├── linux/      # Cargo workspace (Rust + GTK4 + ratatui)
└── web/        # React + Vite
```

## Roadmap (v0.2)

- End-to-end application-layer encryption (X25519 + ChaCha20-Poly1305, on top of TLS)
- Recursive / batch folder transfer
- Clipboard sharing across all clients (the `CLIPBOARD` message type already exists)
- Push notifications to wake the receiver
- Upgrade Linux identity storage to libsecret (Android already uses EncryptedSharedPreferences)

## Contributing

Issues and pull requests are welcome. The [protocol/](protocol/README.md) spec is the
source of truth — keep clients conformant to it. Note that the per-platform native
toolchains differ (Xcode / Gradle / .NET / Cargo / npm); build the platform you touch
before opening a PR, and replace any signing identity (e.g. Apple `DEVELOPMENT_TEAM`)
with your own.

## License

[MIT](LICENSE) © 2026 chenqi92
