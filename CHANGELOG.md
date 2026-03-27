# Changelog

## v0.2.6 (2026-03-27)

### 🔧 Refactor: dufs FFI Architecture

dufs is now compiled as a shared library (.so/.dll/.dylib) and loaded via Dart FFI instead of running as a child process. This eliminates orphan processes, avoids antivirus false positives, and fixes the AppImage network isolation issue caused by FUSE sandboxing.

dufs 现在编译为共享库（.so/.dll/.dylib），通过 Dart FFI 加载，不再作为子进程运行。消除了孤儿进程问题，规避杀毒软件误报，并修复了 AppImage 因 FUSE 沙箱导致的网络隔离问题。

### ✨ Features (since v0.2.3)

- **Transfer log** — track file downloads/uploads with a real-time log viewer
- **传输记录** — 实时查看文件下载/上传记录
- **Source-compiled dufs** — all platforms build dufs from source, F-Droid compatible
- **源码编译 dufs** — 全平台从源码编译，兼容 F-Droid
- **Android Native Service** — dufs runs in a native Android Service, survives Activity destruction (fixes low-memory devices like Mi 6)
- **Android 原生服务** — dufs 在原生 Android Service 中运行，Activity 被回收后服务不中断（修复小米 6 等低内存设备）
- **Back key confirmation** — pressing back while server is running prompts to stop before exiting
- **返回键确认** — 服务运行中按返回键会弹窗询问是否停止服务再退出
- **Multi-address display** — shows all available network interfaces with names
- **多地址显示** — 显示所有可用网络接口地址及网卡名称

### 🐛 Fixes

- **Windows antivirus** — dufs binary no longer triggers Windows Defender / antivirus false positives (now a .dll loaded via FFI)
- **Windows 杀毒软件** — dufs 不再触发 Windows Defender / 杀毒软件误报（改为 .dll 通过 FFI 加载）
- **AppImage network** — fixed dufs server unreachable inside AppImage due to FUSE sandbox isolation
- **AppImage 网络** — 修复 AppImage 内 dufs 服务因 FUSE 沙箱隔离导致无法访问
- **Linux packaging** — fixed CMAKE_INSTALL_PREFIX permission error on some distros
- **Linux 打包** — 修复部分发行版上 CMAKE_INSTALL_PREFIX 权限错误
- **Android API level** — target API 24 for freeifaddrs compatibility
- **Android API 级别** — 目标 API 24 以兼容 freeifaddrs

### 🏗️ Build

- **CI: compile dufs from source** — all platforms (Android/Windows/Linux/macOS/iOS) build dufs from the zocs/dufs fork
- **CI: 源码编译 dufs** — 全平台从 zocs/dufs fork 编译
- **CI: AAB for Play Store** — added Android App Bundle build for Google Play
- **CI: Play Store AAB** — 新增 Android App Bundle 构建用于 Google Play 发布

---

## v0.2.3 (2026-03-25)

### ✨ Features

- **Android Native Service** — dufs process managed by native Kotlin Service
- **Transfer log** — file transfer history with dufs --log-file polling
- **Back key exit** — double-tap or confirm-stop dialog
- **Address list** — show all network interfaces

### 🐛 Fixes

- Fixed dufs process orphaning on low-memory Android devices
- Fixed port conflict detection

---

## v0.2.2 (2026-03-20)

### 🐛 Fixes

- **Linux AppImage** — fixed dufs binary not found in AppImage (FUSE path issue)
- **CI encoding** — fixed UTF-8 BOM in Windows CI builds

---

## v0.2.1 (2026-03-18)

### ✨ Features

- **New icon** — hand-drawn pencil sketch style icon for all platforms + system tray

---

## v0.2.0 (2026-03-15)

### ✨ Features

- **Desktop drag & drop** — drag files/folders onto the window to set share path
- **System tray** — minimize to tray, right-click menu
- **Close behavior** — choose minimize-to-tray or exit on close
- **Multi-address** — show all network interface IPs
- **Android 8 fix** — storage permission for older devices
- **Animated splash** — pixel-art "inout" splash with smooth Flutter transition
- **Orphan cleanup** — detect and kill orphaned dufs processes on startup

---

## v0.1.0 (2026-03-01)

### 🎉 Initial Release

- Directory & single-file sharing
- Permission presets (readonly / upload / full)
- Auth support (dufs format)
- CORS toggle
- QR code generation
- Multi-language (简中/繁中/English)
- Material 3 theming with 6 color schemes
- Android + Windows + Linux packages
