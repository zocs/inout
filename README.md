<div align="center">

# <img src="fastlane/metadata/android/en-US/icon.png" width="40"> inout

**In and out, that's all.** — 轻点一下，文件分享即刻在线。

[![Release](https://img.shields.io/github/v/release/zocs/inout)](https://github.com/zocs/inout/releases)
[![License](https://img.shields.io/github/license/zocs/inout)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/zocs/inout/total)](https://github.com/zocs/inout/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.41+-blue)](https://flutter.dev)
[![Windows](https://img.shields.io/badge/Windows-green)](https://github.com/zocs/inout/releases)
[![Android](https://img.shields.io/badge/Android-green)](https://github.com/zocs/inout/releases)
[![Linux](https://img.shields.io/badge/Linux-green)](https://github.com/zocs/inout/releases)
[![macOS](https://img.shields.io/badge/macOS-yellow)](https://github.com/zocs/inout/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/zocs/inout/build.yml?label=build)](https://github.com/zocs/inout/actions)
[![F-Droid](https://img.shields.io/badge/F-Droid-pending-blue)](https://gitlab.com/fdroid/fdroiddata)

[中文文档](./README_zh.md) · [Privacy Policy](./PRIVACY.md) · [📥 Releases](https://github.com/zocs/inout/releases)

</div>

---

A graphical file sharing tool based on [dufs](https://github.com/sigoden/dufs). **Zero config, zero barrier** — run inout on one device, and anyone with a browser can access and transfer files. The other side needs no app.

---

## 📱 Screenshots

[![Screenshots](fastlane/metadata/android/en-US/phoneScreenshots/screenshots_overview.jpg)](fastlane/metadata/android/en-US/phoneScreenshots/screenshots_overview.jpg)

---

## ✨ Why inout?

> **The other side doesn't need an app.** Install inout on ONE device, start the server, and anyone with a browser can upload and download files.

| Feature | |
|:---|:---:|
| 📱 **One device is enough** | The rest use a browser |
| ⬆️⬇️ **Bidirectional** | Upload AND download, not just send |
| 🔗 **Just open a link** | QR code or URL — that's all the other side needs |
| 🔐 **Secure** | Optional password auth, CORS control |
| 🎨 **Customizable** | 6 color schemes + dark / light mode |
| 🌐 **Multilingual** | 简体中文 · 繁體中文 · English |
| 📦 **Zero setup** | Self-contained — no external dependencies |

---

## 💡 Use Cases

| Scenario | How |
|:---|:---:|
| 🏠 **Home file sharing** | Phone hotspot → browser access → transfer photos / docs |
| 💼 **Office quick transfer** | One PC starts → colleagues scan → share project files |
| 🎓 **Classroom distribution** | Teacher starts → students scan → download courseware |
| 🔧 **Device debugging** | Embedded device → phone hotspot → download logs |
| 📷 **Photo dump** | Camera/phone starts → PC bulk downloads |

---

## 🚀 Quick Start

### Download

| Platform | File | |
|:---|:---|:---:|
| 🪟 **Windows** | `inout-*-windows-x64-setup.exe` (installer) or `.zip` (portable) | ✅ Tested |
| 🤖 **Android** | `inout-*-android-arm64.apk` | ✅ Tested |
| 🐧 **Linux x64** | `.AppImage` (zero deps) or `.deb` | ✅ Tested |
| 🐧 **Linux ARM64** | `.AppImage` or `.deb` (Kylin/UOS compatible) | ✅ Tested |
| 🍎 **macOS** | `inout-*-macos-arm64.zip` | ⚠️ Untested |

> 📥 [Download latest release](https://github.com/zocs/inout/releases)
>
> 🤖 Also available on [F-Droid](https://f-droid.org/) (pending review)

### Steps

1. Pick a folder
2. Tap "Start Server"
3. Scan QR code or enter URL in browser (port required)
4. Share files — done!

---

## 🌐 Network

> **Simplest setup:** All devices on the same WiFi or hotspot.

| Environment | |
|:---|:---:|
| 🏠 **Same WiFi** | Just connect and share |
| 📱 **Phone hotspot** | One device creates a hotspot, others join — no router needed |
| 🌍 **Remote access** | Works with ZeroTier, Tailscale, EasyTier, or any VPN |

> 🔒 **All transfers happen directly between your devices. No data passes through third-party servers.**

---

## 🔒 Security

> ⚠️ inout binds to all network interfaces by default (`0.0.0.0`)

| Network | Recommendation |
|:---|:---:|
| Home WiFi | ✅ Safe — LAN only |
| Public WiFi | ⚠️ Enable password auth |
| Corporate network | ⚠️ Watch firewall policies |
| Public internet | ❌ Not recommended — use VPN instead |

**Best practices:**
1. Enable auth in public environments
2. Stop the server when done
3. Review access logs periodically

---

## 🔧 Troubleshooting

### Android — Storage Permission

**Symptom:** Can't list files, "Need all files access permission"

**Fix:** Settings → Apps → inout → Permissions → Allow "All files access"

### Port in Use

**Symptom:** Start fails, "Port XXX already in use"

**Fix:** Change port (try 8080–9000 range) or kill the occupying process

### Linux — AppImage Won't Launch

**Symptom:** Double-click does nothing

**Fix:**
```bash
chmod +x inout-*.AppImage
./inout-*.AppImage
```

### macOS — Developer Verification Blocked

**Symptom:** "Can't verify developer" on open

**Fix:**
```bash
xattr -d com.apple.quarantine inout.app
```

### Windows — Firewall Blocking

**Symptom:** Other devices can't connect

**Fix:** Allow inout through Windows Firewall (you'll be prompted on first launch)

---

## ❓ FAQ

**Q: Does the other side need inout?**
A: No! Only one device runs inout. Others just open a browser.

**Q: Can I access it remotely?**
A: LAN by default. For remote access, use ZeroTier / Tailscale / EasyTier.

**Q: Is HTTPS supported?**
A: Not yet. Planned for a future release.

**Q: Max file size?**
A: Depends on dufs and browser. Keep individual files under 2GB for best results.

**Q: How many devices can connect at once?**
A: No hard limit — depends on bandwidth and device performance.

**Q: Are files uploaded to the cloud?**
A: No! Everything stays local. Transfers are device-to-device.

---

## 🛠️ Development

### Requirements

- Flutter SDK 3.41+
- Windows: VS Build Tools 2022 (C++ workload)
- Android: Android SDK, NDK
- Linux: clang, lld, llvm, libgtk-3-dev
- macOS: Xcode

### Build

```bash
git clone https://github.com/zocs/inout.git
cd inout
flutter pub get

# Run (debug)
flutter run -d windows
flutter run -d android

# Build
flutter build windows --release
flutter build apk --release
```

### Packaging Scripts

```bash
# Linux (x64 or ARM64)
bash scripts/build_linux.sh x86_64
bash scripts/build_linux.sh aarch64

# macOS (ARM64)
bash scripts/build_macos.sh aarch64
```

Output: AppImage, deb, rpm, tar.gz (Linux) and zip (macOS).

### CI/CD

GitHub Actions builds all platforms on tag push (`v*`) and creates a release automatically.

### Project Structure

```
lib/
├── main.dart                       # Entry + window init
├── app.dart                        # MaterialApp + theming
├── l10n/app_localizations.dart     # i18n (zh/en/zhTW)
├── models/
│   ├── server_config.dart          # Config model + persistence
│   └── transfer_log.dart           # Transfer log parser
├── pages/
│   ├── home_page.dart              # Home: dir / perms / start / QR
│   ├── settings_page.dart          # Settings: theme / color / language
│   ├── setup_wizard_page.dart      # First-run wizard
│   └── log_page.dart               # Transfer log viewer
└── services/
    ├── dufs_service.dart           # dufs lifecycle (platform dispatch)
    └── dufs_ffi.dart               # FFI bindings (desktop)
scripts/
├── build_dufs.sh                   # Cross-compile dufs (7 platforms)
├── build_linux.sh                  # Linux packaging (AppImage/deb)
├── build_macos.sh                  # macOS packaging
└── dufs-ffi/lib.rs                 # Rust FFI wrapper
android/app/src/main/kotlin/.../DufsForegroundService.kt  # Android native service
installer/inout.nsi                 # Windows NSIS installer
```

---

## 🙏 Acknowledgments

inout is built on top of [dufs](https://github.com/sigoden/dufs) — a brilliant utility file server by [sigoden](https://github.com/sigoden). Without dufs, inout wouldn't exist. Thanks for making file sharing so simple.

---

## 📄 License

[MIT](LICENSE) © 2026 [zocs](https://github.com/zocs)

---

<div align="center">

**inout** — files in and out, that's all.

</div>
