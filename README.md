# inout

**轻点一下，文件分享即刻在线。**

基于开源项目 [dufs](https://github.com/sigoden/dufs) 开发的图形界面版本，让文件分享零配置、零门槛。

## 功能

- 📱 选好目录，一键开启 HTTP 文件服务
- 📷 生成二维码，手机扫码即可访问
- ⬆️ 支持上传、下载、搜索、打包下载
- 🔐 可选用户名密码认证
- 🎨 6 种配色方案 + 深色/浅色模式
- 🌐 简体中文 / 繁體中文 / English
- 📦 零依赖，内置 dufs 二进制

## 使用方法

1. 选择要分享的文件夹
2. 点击「启动服务」
3. 其他设备扫描二维码或输入地址
4. 开始上传/下载文件

## 网络说明

- 优先使用局域网（LAN / WLAN），连接同一网络获得最佳体验
- 支持 ZeroTier、Tailscale、EasyTier 等组网工具
- 文件传输直接在设备之间进行，不经过第三方服务器

## 平台

| 平台 | 状态 |
|------|------|
| Windows | ✅ 已测试 |
| Android | 🔜 待测试 |
| macOS | 📋 计划中 |
| iOS | 📋 计划中 |
| Linux | 📋 计划中 |

## 构建

```bash
flutter pub get
flutter run -d windows    # Windows 调试
flutter run -d android    # Android 调试
flutter build windows --debug
flutter build apk --debug
```

## 技术栈

- Flutter 3.41 + Dart
- dufs v0.45.0（Rust 编写的静态文件服务器）
- Material Design 3

## 许可证

[MIT License](LICENSE)

---

*inout — 让文件来去自如。*
