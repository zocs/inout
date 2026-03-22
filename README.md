# inout

**One tap, file sharing is live.**

A graphical interface built on [dufs](https://github.com/sigoden/dufs) — zero configuration, zero barrier.

[中文文档](README_zh.md)

## Features

- 📱 Select a directory and start sharing instantly
- 📷 QR code for quick access from other devices
- ⬆️ Upload, download, search, and archive download
- 🔐 Optional username/password authentication
- 🎨 6 color schemes + dark/light mode
- 🌐 简体中文 / 繁體中文 / English
- 📦 Self-contained — dufs binary included

## Quick Start

1. Select the folder you want to share
2. Tap **Start Server**
3. Other devices scan the QR code or enter the URL
4. Start uploading and downloading files

## Network

- Best used on local network (LAN / WLAN) — connect all devices to the same network
- Also works with ZeroTier, Tailscale, EasyTier, etc.
- File transfers happen directly between devices — no third-party servers

## Platforms

| Platform | Status |
|----------|--------|
| Windows | ✅ Tested |
| Android | 🔜 In progress |
| macOS | 📋 Planned |
| iOS | 📋 Planned |
| Linux | 📋 Planned |

## Build

```bash
flutter pub get
flutter run -d windows    # Windows debug
flutter run -d android    # Android debug
flutter build windows --debug
flutter build apk --debug
```

## Tech Stack

- Flutter 3.41 + Dart
- [dufs](https://github.com/sigoden/dufs) v0.45.0 (Rust static file server)
- Material Design 3

## Privacy

inout does NOT collect, store, or transmit any personal data. File sharing happens locally between your devices. See [PRIVACY.md](PRIVACY.md) for details.

## License

[MIT License](LICENSE)

---

*inout — files in, files out.*
