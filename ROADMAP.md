# inout Roadmap

## v0.2.3 — 稳定性重构 ✅ 已完成（未发版）

- [x] Android Native Service 架构重构（dufs 进程由 Service 管理）
- [x] codeview bug 修复（拖放逻辑、权限按钮、orphan 进程检查）
- [x] 返回键确认退出（服务运行中）
- [x] 地址列表始终显示
- [x] stopServer 等待进程退出
- [x] Linux/macOS orphan 进程名检查

**待办**：发版 GitHub Release v0.2.3

---

## v0.3.0 — 构建优化 + 体验打磨（下一版本）

### CI/CD 优化
- [ ] Flutter SDK 缓存 + pub-cache 缓存（减少 30-50% 构建时间）
- [ ] Linux ARM64 统一用 flutter-action（去掉手动 git clone）
- [ ] 所有平台 build 加 `--obfuscate --split-debug-info`（包体瘦身）
- [ ] 无效 release pattern 清理（`.rpm`、`.dmg` 匹配不到任何文件）
- [ ] 生成 checksums.txt

### 体验优化
- [ ] 检测到服务运行中退出时，通知栏 Service 也同步停止
- [ ] 首次启动引导加网络说明（热点/局域网）
- [ ] 拖放文件时显示进度/loading 状态

### 代码卫生
- [ ] `_killOrphanDufs` 与 `killOrphanOnPort` 合并（消除 ~30 行重复）
- [ ] tray 临时图标文件清理
- [ ] `_trackActivity` 正则加强（防误匹配）

---

## v0.4.0 — 功能扩展（未来）

### 高优先级
- [ ] HTTPS 支持（自签证书或 Let's Encrypt）
- [ ] 上传进度条（大文件上传体验）
- [ ] 文件预览（图片/文本/视频）
- [ ] 批量操作（批量下载为 zip、批量删除）

### 中优先级
- [ ] 分享链接有效期（自动过期）
- [ ] 访问日志（谁访问了什么文件）
- [ ] 文件夹密码（per-directory auth）
- [ ] 暗色模式自动跟随系统（Android 10+）

### 低优先级
- [ ] WebDAV 支持
- [ ] 多语言扩展（日语、韩语）
- [ ] 自定义主题（用户自选颜色）
- [ ] 分享统计面板（总流量、连接数）

---

## v0.5.0 — 平台增强（远期）

- [ ] Android 桌面小部件（快速启动/停止）
- [ ] Android 快捷方式（直接分享指定目录）
- [ ] Windows 右键菜单集成（"用 inout 分享此文件夹"）
- [ ] macOS DMG 安装包
- [ ] Android AAB 格式（Play Store 准备）
- [ ] iPad 适配

---

## 已知问题

| 问题 | 严重性 | 状态 |
|------|--------|------|
| AppImage dufs 外部无法访问 | 中 | 待查（deb 正常，可能 FUSE 限制） |
| macOS 未签名，需手动 xattr | 低 | 无法自动签名 |
| `withValues(alpha:)` 需 Flutter 3.27+ | 低 | 当前版本无问题 |
| `_killOrphanDufs` 与 `killOrphanOnPort` 代码重复 | 低 | 功能正常 |
