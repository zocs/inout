# Changelog / 更新日志

> 所有版本均可在 [GitHub Releases](https://github.com/zocs/inout/releases) 下载。
> All versions available at [GitHub Releases](https://github.com/zocs/inout/releases).

## [v0.3.1](https://github.com/zocs/inout/releases/tag/v0.3.1) (2026-04-20)

**中文：**
- 🐛 修复 Android 8/9 等 API 30 以下设备因 DT_RELR packed relocations 导致的 dufs 启动崩溃
- 🐛 修复应用内版本号显示与 `pubspec.yaml` 不一致
- 🐛 修复传输日志统计无法累计文件大小的问题
- 🏗️ 传输日志改为增量读取，避免长时间运行后反复整文件扫描
- ✨ 新增显式“选择分享文件”入口，不再只依赖桌面拖放触发单文件分享

**English：**
- 🐛 Fixed dufs startup crash on Android API < 30 caused by DT_RELR packed relocations
- 🐛 Fixed in-app version display drifting from `pubspec.yaml`
- 🐛 Fixed transfer log stats not accumulating file sizes
- 🏗️ Switched transfer log reading to incremental reads to avoid full-file rescans over long sessions
- ✨ Added an explicit "select share file" entry instead of relying only on desktop drag-and-drop

---

## [v0.3.0](https://github.com/zocs/inout/releases/tag/v0.3.0) (2026-03-31)

**中文：**
- ✨ 隐藏系统文件：自动隐藏 .git、.DS_Store、Thumbs.db、.env 等系统文件（默认开启）
- ✨ 渲染首页：目录有 index.html 时自动渲染，方便简易测试网页
- 🐛 修复 Linux/macOS 构建脚本版本号提取错误（0.2.929 → 0.2.9）
- 🏗️ CI 排除 iOS 从 release 发布（仅编译测试）

**English：**
- ✨ Hide system files: auto-hide .git, .DS_Store, Thumbs.db, .env etc. (on by default)
- ✨ Render index: auto-render index.html if present in directory for quick web testing
- 🐛 Fixed Linux/macOS build script version extraction bug (0.2.929 → 0.2.9)
- 🏗️ CI excludes iOS from release (compile-only)

---

## [v0.2.8](https://github.com/zocs/inout/releases/tag/v0.2.8) (2026-03-28)

**中文：**
- ✨ Android 正式签名发布，CI 构建统一使用 release keystore，覆盖安装不再需要先卸载旧版
- ✨ F-Droid 上架材料已提交审核（Fastlane metadata、GitLab MR）
- 🐛 修复多平台版本号不一致的问题（安装包文件名和 app 内显示版本对不上）
- 🏗️ CI 全平台版本号统一从 pubspec.yaml 读取

**English：**
- ✨ Android release signing — CI builds use a unified release keystore, no need to uninstall before updating
- ✨ F-Droid submission prepared (Fastlane metadata, GitLab MR)
- 🐛 Fixed version number inconsistency across platforms (package filename vs in-app display)
- 🏗️ CI reads version from pubspec.yaml across all platforms

---

## [v0.2.7](https://github.com/zocs/inout/releases/tag/v0.2.7) (2026-03-27)

**中文：**
- 🐛 修复 Windows NSIS 安装包路径含空格时引号处理错误
- 🐛 修复 Android FFI 重复调用导致的并发崩溃
- 🐛 修复 F-Droid 构建版本号检测
- 🐛 修复版本号同步问题

**English：**
- 🐛 Fixed NSIS installer quoting error when path contains spaces
- 🐛 Fixed Android FFI concurrent crash from re-entry
- 🐛 Fixed F-Droid build version detection
- 🐛 Fixed version number sync issues

---

## [v0.2.6](https://github.com/zocs/inout/releases/tag/v0.2.6) (2026-03-27)

### 🔧 架构重构 / Refactor: dufs FFI

**中文：**

dufs 文件服务从"作为子进程运行"改为"编译成共享库通过 FFI 加载"。解决了三个实际问题：Windows 杀毒软件误报、Linux AppImage 网络隔离、以及子进程残留。

**English：**

dufs is now compiled as a shared library (.so/.dll/.dylib) and loaded via Dart FFI instead of running as a child process. This fixes antivirus false positives on Windows, network isolation in AppImage (FUSE sandbox), and orphaned processes.

### ✨ 新功能 / Features (since v0.2.3)

**中文：**
- **传输记录** — 实时查看文件下载/上传日志
- **源码编译 dufs** — 全平台从源码编译，兼容 F-Droid 要求
- **Android 原生 Service** — dufs 跑在原生 Android Service 里，Activity 被回收后服务不中断（小米 6 等 4GB 内存设备实测修复）
- **返回键确认** — 服务运行中按返回键会弹窗确认，避免误关
- **多地址显示** — 列出所有网卡的 IP 地址和网卡名称

**English：**
- **Transfer log** — real-time download/upload history viewer
- **Source-compiled dufs** — all platforms build from source, F-Droid compatible
- **Android Native Service** — dufs runs in a native Service, survives Activity destruction (fixes low-memory devices like Mi 6)
- **Back key confirmation** — prompts before exiting while server is running
- **Multi-address display** — shows all network interfaces with names

### 🐛 修复 / Fixes

**中文：**
- Windows 杀毒软件不再误报（dufs 从 .exe 改为 .dll）
- AppImage 内文件服务无法访问的问题
- 部分 Linux 发行版打包时的权限报错
- Android API 级别调整以兼容旧设备

**English：**
- Windows antivirus no longer flags dufs (changed from .exe to .dll)
- Fixed dufs unreachable inside AppImage
- Fixed CMAKE_INSTALL_PREFIX permission error on some distros
- Adjusted Android target API for older device compatibility

---

## [v0.2.3](https://github.com/zocs/inout/releases/tag/v0.2.3) (2026-03-25)

**中文：**
- ✨ Android 文件服务改用原生 Kotlin Service 管理，低内存设备不再假死
- ✨ 新增传输记录功能，查看文件传输历史
- ✨ 返回键双重确认：服务运行中按返回会弹窗询问
- ✨ 地址列表始终显示所有网卡地址
- 🐛 修复低内存设备上 dufs 进程丢失的问题
- 🐛 修复端口冲突检测

**English：**
- ✨ Android dufs process now managed by native Kotlin Service, fixes low-memory device crashes
- ✨ Transfer log — view file transfer history
- ✨ Back key confirmation when server is running
- ✨ Address list always shows all network interfaces
- 🐛 Fixed dufs process orphaning on low-memory devices
- 🐛 Fixed port conflict detection

---

## [v0.2.2](https://github.com/zocs/inout/releases/tag/v0.2.2) (2026-03-20)

**中文：**
- 🐛 修复 Linux AppImage 内找不到 dufs 的问题
- 🐛 修复 Windows CI 构建的编码问题

**English：**
- 🐛 Fixed dufs binary not found in Linux AppImage
- 🐛 Fixed UTF-8 encoding issue in Windows CI builds

---

## [v0.2.1](https://github.com/zocs/inout/releases/tag/v0.2.1) (2026-03-18)

**中文：**
- ✨ 全新铅笔手绘风格图标（应用图标 + 系统托盘图标）

**English：**
- ✨ New hand-drawn pencil sketch icon (app + system tray)

---

## [v0.2.0](https://github.com/zocs/inout/releases/tag/v0.2.0) (2026-03-15)

**中文：**
- ✨ 桌面端拖放共享——直接拖文件/文件夹到窗口设置共享目录
- ✨ 系统托盘——最小化到托盘，右键菜单操作
- ✨ 关闭行为可选——最小化到托盘还是直接退出
- ✨ 多网卡地址列表——显示所有网络接口 IP
- ✨ 修复 Android 8 存储权限问题
- ✨ 启动动画——像素风 inout + 原生到 Flutter 无缝过渡
- ✨ 启动时自动清理残留的 dufs 孤儿进程

**English：**
- ✨ Desktop drag & drop — drag files/folders to set share path
- ✨ System tray — minimize to tray with right-click menu
- ✨ Close behavior choice — minimize to tray or exit
- ✨ Multi-address list — shows all network interface IPs
- ✨ Fixed Android 8 storage permission
- ✨ Animated splash — pixel-art inout with smooth Flutter transition
- ✨ Auto-cleanup of orphaned dufs processes on startup

---

## [v0.1.0](https://github.com/zocs/inout/releases/tag/v0.1.0) (2026-03-01)

🎉 首个版本 / Initial Release

**中文：**
- 文件夹和单文件分享
- 权限预设（只读 / 可上传 / 完整控制）
- 密码认证、CORS 开关
- 二维码生成
- 三语支持（简中 / 繁中 / English）
- Material 3 主题 + 6 种配色
- Android + Windows + Linux 安装包

**English：**
- Directory & single-file sharing
- Permission presets (readonly / upload / full)
- Password auth, CORS toggle
- QR code generation
- Multilingual (Simplified Chinese / Traditional Chinese / English)
- Material 3 theming with 6 color schemes
- Android + Windows + Linux packages
