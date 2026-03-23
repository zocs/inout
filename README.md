<div align="center">

# 📦 inout

**In and out, that's all.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)]()
[![Build](https://img.shields.io/github/actions/workflow/status/zocs/inout/build.yml?label=build)](https://github.com/zocs/inout/actions)
[![Privacy](https://img.shields.io/badge/Privacy-Policy-green.svg)](PRIVACY.md)

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
| 🔀 **Custom Permissions** | Fine-grained toggle for each capability |
| 🎨 **Customizable** | 6 color schemes + dark / light mode |
| 🌐 **Multilingual** | 简体中文 · 繁體中文 · English |
| 📦 **Zero Setup** | Self-contained — no external dependencies |

## 🚀 Quick Start

1. [Download](https://github.com/zocs/inout/releases/latest) the latest release for your platform:

   | Platform | File |
   |----------|------|
   | Android | `inout-*-android-arm64.apk` |
   | Windows | `inout-*-windows-x64-setup.exe` (installer) or `.zip` (portable) |
   | macOS | `inout-*-macos-arm64.zip` — ⚠️ untested, please report issues |
   | Linux x64 | `.AppImage` (zero deps) or `.deb` |
   | Linux ARM64 | `.AppImage` (zero deps) or `.deb` (Kylin/UOS compatible) |

2. Pick a folder
3. Tap "Start Server"
4. Scan QR code or enter URL in browser (port required)
5. Share files — that's it!

## 🌐 Network

> **Simplest setup:** All devices on the same WiFi or hotspot.

- 🏠 **Same WiFi** — just connect and share
- 📱 **Phone hotspot** — one device creates a hotspot, others join, no router needed
- 🌍 **Remote access** — works with ZeroTier, Tailscale, EasyTier, or any VPN

> 🔒 All transfers happen directly between your devices. No data passes through third-party servers.

## 📱 Platform Support

| Platform | Status | Notes |
|:--------:|:------:|-------|
| 🪟 Windows | ✅ Tested | NSIS installer + ZIP portable |
| 🤖 Android | ✅ Tested | ARM64 APK |
| 🍎 macOS | ⚠️ Untested | CI builds ready, feedback welcome |
| 🐧 Linux x64 | ⚠️ Untested | AppImage / deb / rpm / tar.gz |
| 🐧 Linux ARM64 | ⚠️ Untested | AppImage / deb (Kylin/UOS compatible) |

## 🛠️ Development

### Requirements

- Flutter SDK 3.41+
- Windows: VS Build Tools 2022 (C++ workload)
- Android: Android SDK, NDK
- Linux: clang, lld, llvm, libgtk-3-dev
- macOS: Xcode

### Build

```bash
# Clone
git clone https://github.com/zocs/inout.git
cd inout

# Get dependencies
flutter pub get

# Run (debug)
flutter run -d windows
flutter run -d android

# Windows build
flutter build windows --release

# Android build
flutter build apk --release
```

### Build Scripts

Automated packaging scripts are provided:

```bash
# Linux (x64 or ARM64)
bash scripts/build_linux.sh x86_64
bash scripts/build_linux.sh aarch64

# macOS (ARM64)
bash scripts/build_macos.sh aarch64
```

Output: AppImage, deb, rpm, tar.gz (Linux) and zip (macOS).

### CI/CD

GitHub Actions automatically builds all platforms on tag push (`v*`) and creates a release:

```
v0.1.1 → build-android → build-windows → build-linux-x64 → build-linux-arm64 → build-macos-arm64 → release
```

### Android Notes

Android requires `MANAGE_EXTERNAL_STORAGE` permission. On Android 12+ (SELinux), the dufs binary needs:

- `AndroidManifest.xml`: `android:extractNativeLibs="true"`
- `build.gradle.kts`: `packaging.jniLibs.useLegacyPackaging = true`

The dufs binary runs from the jniLibs path (SELinux-readable).

## 🧱 Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | [Flutter](https://flutter.dev) 3.41 + Dart |
| File Server | [dufs](https://github.com/sigoden/dufs) v0.45.0 (Rust) |
| Design | Material Design 3 |
| Persistence | SharedPreferences |
| Window Mgmt | window_manager |
| Packaging | NSIS (Windows), dpkg (Linux), linuxdeploy (AppImage) |

## 📁 Project Structure

```
lib/
├── main.dart                  # Entry point + window init
├── app.dart                   # MaterialApp + theming
├── l10n/app_localizations.dart # i18n (zh/en/zhTW)
├── models/server_config.dart  # Config model + persistence
├── pages/
│   ├── home_page.dart         # Home: dir picker / perms / start / QR
│   ├── settings_page.dart     # Settings: theme / color / language
│   └── setup_wizard_page.dart # First-run wizard
└── services/
    └── dufs_service.dart      # dufs process management
```

## 📄 License

[MIT](LICENSE) © 2026 [zocs](https://github.com/zocs)

---

<div align="center">

**[inout](https://github.com/zocs/inout)** — files in and out, that's all.

</div>
