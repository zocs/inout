import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 服务器配置数据模型
/// 包含 dufs 服务启动所需的全部参数
class ServerConfig {
  /// 分享目录路径
  String path;

  /// 监听端口，默认 5000
  int port;

  /// 允许上传
  bool allowUpload;

  /// 允许删除
  bool allowDelete;

  /// 允许搜索
  bool allowSearch;

  /// 允许归档 (zip/tar 下载)
  bool allowArchive;

  /// 允许符号链接
  bool allowSymlink;

  /// 只读模式
  bool readonly;

  /// 认证信息，格式: "user:pass"
  String? auth;

  /// 启用 CORS
  bool cors;

  /// 语言设置 (zh / en / zhTW)
  String language;

  /// 主题模式 (system / light / dark)
  String themeMode;

  /// 配色方案 (coral / teal / violet / ocean / sunset / forest)
  String colorScheme;

  /// 是否已完成首次设置
  bool setupDone;

  /// 关闭行为: 'ask'(询问), 'tray'(最小化到托盘), 'exit'(直接退出)
  String closeAction;

  /// 是否在分享单文件模式（dufs 指定单文件）
  bool shareSingleFile;

  /// 隐藏系统文件（.git, .DS_Store, Thumbs.db 等）
  bool hideSystemFiles;

  /// 目录有 index.html 时自动渲染
  bool renderTryIndex;

  ServerConfig({
    this.path = '',
    this.port = 5000,
    this.allowUpload = false,
    this.allowDelete = false,
    this.allowSearch = false,
    this.allowArchive = false,
    this.allowSymlink = false,
    this.readonly = true,
    this.auth,
    this.cors = false,
    this.language = 'zh',
    this.themeMode = 'system',
    this.colorScheme = 'coral',
    this.setupDone = false,
    this.closeAction = 'ask',
    this.shareSingleFile = false,
    this.hideSystemFiles = true,
    this.renderTryIndex = false,
  });

  /// 转为 JSON Map
  Map<String, dynamic> toJson() => {
        'path': path,
        'port': port,
        'allowUpload': allowUpload,
        'allowDelete': allowDelete,
        'allowSearch': allowSearch,
        'allowArchive': allowArchive,
        'allowSymlink': allowSymlink,
        'readonly': readonly,
        'auth': auth,
        'cors': cors,
        'language': language,
        'themeMode': themeMode,
        'colorScheme': colorScheme,
        'setupDone': setupDone,
        'closeAction': closeAction,
        'shareSingleFile': shareSingleFile,
        'hideSystemFiles': hideSystemFiles,
        'renderTryIndex': renderTryIndex,
      };

  /// 从 JSON Map 创建实例
  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        path: json['path'] as String? ?? '',
        port: json['port'] as int? ?? 5000,
        allowUpload: json['allowUpload'] as bool? ?? false,
        allowDelete: json['allowDelete'] as bool? ?? false,
        allowSearch: json['allowSearch'] as bool? ?? false,
        allowArchive: json['allowArchive'] as bool? ?? false,
        allowSymlink: json['allowSymlink'] as bool? ?? false,
        readonly: json['readonly'] as bool? ?? true,
        auth: json['auth'] as String?,
        cors: json['cors'] as bool? ?? false,
        language: json['language'] as String? ?? 'zh',
        themeMode: json['themeMode'] as String? ?? 'system',
        colorScheme: json['colorScheme'] as String? ?? 'coral',
        setupDone: json['setupDone'] as bool? ?? false,
        closeAction: json['closeAction'] as String? ?? 'ask',
        shareSingleFile: json['shareSingleFile'] as bool? ?? false,
        hideSystemFiles: json['hideSystemFiles'] as bool? ?? true,
        renderTryIndex: json['renderTryIndex'] as bool? ?? false,
      );

  /// 从 SharedPreferences 加载配置
  static Future<ServerConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('server_config');
    if (jsonStr != null) {
      return ServerConfig.fromJson(jsonDecode(jsonStr));
    }
    return ServerConfig();
  }

  /// 保存配置到 SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_config', jsonEncode(toJson()));
  }

  /// 权限预设: 只读
  void applyReadonly() {
    readonly = true;
    allowUpload = false;
    allowDelete = false;
    allowSearch = false;
    allowArchive = false;
    allowSymlink = false;
  }

  /// 权限预设: 允许上传
  void applyUpload() {
    readonly = false;
    allowUpload = true;
    allowDelete = false;
    allowSearch = true;
    allowArchive = false;
    allowSymlink = false;
  }

  /// 权限预设: 完全权限
  void applyFull() {
    readonly = false;
    allowUpload = true;
    allowDelete = true;
    allowSearch = true;
    allowArchive = true;
    allowSymlink = false;
  }

  /// 校验权限字段一致性，返回冲突描述（null = 无冲突）
  String? validatePermissions() {
    if (readonly && (allowUpload || allowDelete || allowArchive)) {
      return 'readonly 模式下不允许开启上传/删除/归档权限';
    }
    return null;
  }

  @override
  String toString() => 'ServerConfig(path: $path, port: $port)';

  /// 创建默认配置
  factory ServerConfig.defaultConfig() => ServerConfig();
}
