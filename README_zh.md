<div align="center">

# 📦 inout

**轻点一下，文件分享即刻在线。**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)]()
[![Build](https://img.shields.io/github/actions/workflow/status/zocs/inout/build.yml?label=build)](https://github.com/zocs/inout/actions)
[![Privacy](https://img.shields.io/badge/Privacy-Policy-green.svg)](PRIVACY.md)

基于开源项目 [dufs](https://github.com/sigoden/dufs) 开发的图形界面版本，让文件分享零配置、零门槛。

[English](README.md) · [隐私政策](PRIVACY.md)

</div>

---

## ✨ 为什么选 inout？

> **对方不需要装 app。** 只需一端安装 inout 并开启服务，其他设备用浏览器即可访问和双向传输文件 —— 无需 app、无需注册、零配置。

- 📱 **一端安装就够** — 其他端只需浏览器
- ⬆️⬇️ **双向传输** — 不只是发送，上传下载都行
- 🔗 **打开就用** — 扫码或输入地址，对方零门槛

| 功能 | |
|:---:|:---:|
| 📂 **选好就分享** | 选择任意文件夹，一键开启文件服务 |
| 📱 **扫码即连接** | 生成二维码，其他设备扫码即可访问 |
| ⬆️⬇️ **完整控制** | 上传、下载、搜索、打包下载 |
| 🔐 **安全可选** | 用户名密码认证，CORS 控制 |
| 🔀 **自定义权限** | 细粒度开关：上传、删除、搜索、归档下载 |
| 🎨 **自由配色** | 6 种配色方案 + 深色/浅色模式 |
| 🌐 **多语言** | 简体中文 · 繁體中文 · English |
| 📦 **零依赖** | 自包含，无需额外安装任何东西 |

## 🚀 快速开始

1. 从 [GitHub Releases](https://github.com/zocs/inout/releases/latest) 下载对应平台的安装包：

   | 平台 | 文件 |
   |------|------|
   | Android | `inout-*-android-arm64.apk` |
   | Windows | `inout-*-windows-x64-setup.exe`（安装版）或 `.zip`（便携版） |
   | macOS | `inout-*-macos-arm64.zip` — ⚠️ 未经实机测试，请反馈问题 |
   | Linux x64 | `.AppImage`（零依赖）或 `.deb` |
   | Linux ARM64 | `.AppImage`（零依赖）或 `.deb`（兼容麒麟/UOS） |

2. 选择要分享的文件夹
3. 点击「启动服务」
4. 其他设备扫描二维码或输入地址
5. 开始传文件 — 就这么简单！

## 🌐 网络

> **最简单的方式：** 所有设备连同一个 WiFi 或手机热点。

- 🏠 **同一 WiFi** — 连上就能传
- 📱 **手机热点** — 没有路由器？一台手机开热点，其他设备加入就能用
- 🌍 **远程访问** — 支持 ZeroTier、Tailscale、EasyTier 等组网工具

> 🔒 所有传输直接在设备之间进行，不经过任何第三方服务器。

## 📱 平台支持

| 平台 | 状态 | 备注 |
|:----:|:----:|------|
| 🪟 Windows | ✅ 已测试 | NSIS 安装包 + ZIP 便携版 |
| 🤖 Android | ✅ 已测试 | ARM64 APK |
| 🍎 macOS | ⚠️ 未实测 | CI 已构建，欢迎反馈 |
| 🐧 Linux x64 | ⚠️ 未实测 | AppImage / deb / rpm / tar.gz |
| 🐧 Linux ARM64 | ⚠️ 未实测 | AppImage / deb（麒麟/UOS 兼容） |

## 🛠️ 开发

### 环境要求

- Flutter SDK 3.41+
- Windows: VS Build Tools 2022 (C++ workload)
- Android: Android SDK, NDK
- Linux: clang, lld, llvm, libgtk-3-dev
- macOS: Xcode

### 构建

```bash
# 克隆
git clone https://github.com/zocs/inout.git
cd inout

# 安装依赖
flutter pub get

# 运行（调试）
flutter run -d windows
flutter run -d android

# Windows 构建
flutter build windows --release

# Android 构建
flutter build apk --release
```

### 构建脚本

项目提供了自动化构建脚本：

```bash
# Linux（x64 或 ARM64）
bash scripts/build_linux.sh x86_64
bash scripts/build_linux.sh aarch64

# macOS（ARM64）
bash scripts/build_macos.sh aarch64
```

构建产物包括：AppImage、deb、rpm、tar.gz（Linux）和 zip（macOS）。

### CI/CD

GitHub Actions 在 tag push（`v*`）时自动构建全平台安装包并创建 Release：

```
v0.1.1 → build-android → build-windows → build-linux-x64 → build-linux-arm64 → build-macos-arm64 → release
```

### Android 注意事项

Android 需要 `MANAGE_EXTERNAL_STORAGE` 权限，且在 Android 12+ 的 SELinux 环境下需要：

- `AndroidManifest.xml`: `android:extractNativeLibs="true"`
- `build.gradle.kts`: `packaging.jniLibs.useLegacyPackaging = true`

dufs 二进制通过 jniLibs 路径执行（SELinux 允许读取）。

## 🧱 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | [Flutter](https://flutter.dev) 3.41 + Dart |
| 文件服务 | [dufs](https://github.com/sigoden/dufs) v0.45.0 (Rust) |
| 设计 | Material Design 3 |
| 持久化 | SharedPreferences |
| 窗口管理 | window_manager |
| 安装包 | NSIS (Windows)、dpkg (Linux)、linuxdeploy (AppImage) |

## 📁 项目结构

```
lib/
├── main.dart                  # 入口 + 窗口初始化
├── app.dart                   # MaterialApp + 主题
├── l10n/app_localizations.dart # 三语国际化
├── models/server_config.dart  # 配置模型 + 持久化
├── pages/
│   ├── home_page.dart         # 主页：目录/权限/启停/二维码
│   ├── settings_page.dart     # 设置：主题/配色/语言
│   └── setup_wizard_page.dart # 首次启动向导
└── services/
    └── dufs_service.dart      # dufs 进程管理
```

## 📄 许可证

[MIT](LICENSE) © 2026 [zocs](https://github.com/zocs)

---

<div align="center">

**[inout](https://github.com/zocs/inout)** — 让文件来去自如。

</div>
