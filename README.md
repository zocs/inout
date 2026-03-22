<div align="center">

# 📦 inout

**One tap, file sharing is live.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20iOS-lightgrey)]()

A graphical interface built on [dufs](https://github.com/sigoden/dufs) — zero configuration, zero barrier.

[中文文档](README_zh.md) · [Privacy Policy](PRIVACY.md)

</div>

---

## ✨ Why inout?

> **The other side doesn't need an app.** Just install inout on ONE device, start the server, and anyone with a browser can access and transfer files — no apps, no accounts, no setup.

- 📱 **One device is enough** — the rest use a browser
- ⬆️⬇️ **Bidirectional** — upload AND download, not just send
- 🔗 **Just open a link** — QR code or URL, that's all the other side needs

| Feature | |
|:---:|:---:|
| 📂 **Pick & Share** | Select any folder, one tap to start sharing |
| 📱 **Scan to Connect** | QR code for instant access from any device |
| ⬆️⬇️ **Full Control** | Upload, download, search, archive — you decide |
| 🔐 **Secure** | Optional password auth, CORS control |
| 🎨 **Customizable** | 6 color schemes + dark / light mode |
| 🌐 **Multilingual** | 简体中文 · 繁體中文 · English |
| 📦 **Zero Setup** | Self-contained — no external dependencies |

## 🚀 Quick Start

```
1. Pick a folder
2. Tap "Start Server"
3. Scan QR code on another device
4. Share files — that's it!
```

## 🌐 Network

> **Simplest setup:** All devices on the same WiFi or hotspot.

- 🏠 **Same WiFi** — just connect and share
- 📱 **Phone hotspot** — one device creates a hotspot, others join, no router needed
- 🌍 **Remote access** — works with ZeroTier, Tailscale, EasyTier, or any VPN

> 🔒 All transfers happen directly between your devices. No data passes through third-party servers.

## 📱 Platforms

| Platform | Status |
|:--------:|:------:|
| 🪟 Windows | ✅ Tested |
| 🤖 Android | 🔜 In Progress |
| 🍎 macOS | 📋 Planned |
| 🍏 iOS | 📋 Planned |
| 🐧 Linux | 📋 Planned |

## 🛠️ Build

```bash
# Clone
git clone https://github.com/zocs/inout.git
cd inout

# Get dependencies
flutter pub get

# Run
flutter run -d windows    # Windows
flutter run -d android    # Android

# Build
flutter build windows --debug
flutter build apk --debug
```

## 🧱 Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | [Flutter](https://flutter.dev) 3.41 + Dart |
| File Server | [dufs](https://github.com/sigoden/dufs) v0.45.0 (Rust) |
| Design | Material Design 3 |

## 📄 License

[MIT](LICENSE) © 2026 [zocs](https://github.com/zocs)

---

<div align="center">

**[inout](https://github.com/zocs/inout)** — files in, files out.

</div>
