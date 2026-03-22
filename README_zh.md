<div align="center">

# 📦 inout

**轻点一下，文件分享即刻在线。**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20iOS-lightgrey)]()

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
| 🎨 **自由配色** | 6 种配色方案 + 深色/浅色模式 |
| 🌐 **多语言** | 简体中文 · 繁體中文 · English |
| 📦 **零依赖** | 自包含，无需额外安装任何东西 |

## 🚀 快速开始

```
1. 选择要分享的文件夹
2. 点击「启动服务」
3. 其他设备扫描二维码
4. 开始传文件 — 就这么简单！
```

## 🌐 网络

> **最简单的方式：** 所有设备连同一个 WiFi 或手机热点。

- 🏠 **同一 WiFi** — 连上就能传
- 📱 **手机热点** — 没有路由器？一台手机开热点，其他设备加入就能用
- 🌍 **远程访问** — 支持 ZeroTier、Tailscale、EasyTier 等组网工具

> 🔒 所有传输直接在设备之间进行，不经过任何第三方服务器。

## 📱 平台支持

| 平台 | 状态 |
|:----:|:----:|
| 🪟 Windows | ✅ 已测试 |
| 🤖 Android | 🔜 测试中 |
| 🍎 macOS | 📋 计划中 |
| 🍏 iOS | 📋 计划中 |
| 🐧 Linux | 📋 计划中 |

## 🛠️ 构建

```bash
# 克隆
git clone https://github.com/zocs/inout.git
cd inout

# 安装依赖
flutter pub get

# 运行
flutter run -d windows    # Windows
flutter run -d android    # Android

# 构建
flutter build windows --debug
flutter build apk --debug
```

## 🧱 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | [Flutter](https://flutter.dev) 3.41 + Dart |
| 文件服务 | [dufs](https://github.com/sigoden/dufs) v0.45.0 (Rust) |
| 设计 | Material Design 3 |

## 📄 许可证

[MIT](LICENSE) © 2026 [zocs](https://github.com/zocs)

---

<div align="center">

**[inout](https://github.com/zocs/inout)** — 让文件来去自如。

</div>
