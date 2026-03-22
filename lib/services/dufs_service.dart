import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/server_config.dart';

/// Dufs 文件服务管理器
/// 负责启动/停止 dufs 子进程，管理服务状态
class DufsService extends ChangeNotifier {
  Process? _process;
  bool _isRunning = false;
  String? _serverUrl;
  String? _localIp;
  String? _error;

  // Connection tracking
  int _activeConnections = 0;
  int _totalRequests = 0;
  String? _lastActivity;

  bool get isRunning => _isRunning;
  String? get serverUrl => _serverUrl;
  String? get localIp => _localIp;
  String? get error => _error;
  int get activeConnections => _activeConnections;
  int get totalRequests => _totalRequests;
  String? get lastActivity => _lastActivity;

  /// 获取本机 WiFi IP 地址
  Future<String?> _getWifiIP() async {
    try {
      final info = NetworkInfo();
      return await info.getWifiIP();
    } catch (e) {
      debugPrint('get IP failed: $e');
      return null;
    }
  }

  /// 获取 dufs 二进制文件路径
  /// 先检查 app documents 目录，没有则从 assets 复制
  Future<String> _getDufsBinaryPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    String binaryName;
    String assetName;

    if (Platform.isWindows) {
      binaryName = 'dufs.exe';
      assetName = 'assets/dufs/dufs-windows.exe';
    } else if (Platform.isAndroid) {
      binaryName = 'dufs';
      assetName = 'assets/dufs/dufs-android-arm64';
    } else {
      binaryName = 'dufs';
      assetName = 'assets/dufs/dufs-linux';
    }

    final binaryPath = p.join(appDir.path, binaryName);
    final binaryFile = File(binaryPath);

    if (!await binaryFile.exists()) {
      debugPrint('copying dufs from assets: $assetName');
      final data = await rootBundle.load(assetName);
      await binaryFile.writeAsBytes(
        data.buffer.asUint8List(),
        flush: true,
      );
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', binaryPath]);
      }
    }

    return binaryPath;
  }

  /// 构建 dufs 命令行参数列表
  List<String> _buildArgs(ServerConfig config) {
    final args = <String>[];

    args.add('-b');
    args.add('0.0.0.0');

    args.add('-p');
    args.add('${config.port}');

    if (config.readonly) {
      // Default: dufs allows read-only access, no extra flags needed
    } else {
      if (config.allowUpload) args.add('--allow-upload');
      if (config.allowDelete) args.add('--allow-delete');
      if (config.allowSearch) args.add('--allow-search');
      if (config.allowArchive) args.add('--allow-archive');
      if (config.allowSymlink) args.add('--allow-symlink');
    }

    if (config.auth != null && config.auth!.isNotEmpty) {
      args.add('--auth');
      // dufs auth format: user:pass@/:rw  (root dir, read-write)
      args.add('${config.auth!}@/:rw');
    }

    if (config.cors) {
      args.add('--enable-cors');
    }

    args.add(config.path);

    return args;
  }

  /// 启动 dufs 文件服务
  Future<void> startServer(ServerConfig config) async {
    if (_isRunning) {
      debugPrint('server already running');
      return;
    }

    if (config.path.isEmpty) {
      _error = 'Please select a directory first';
      notifyListeners();
      return;
    }

    final dir = Directory(config.path);
    if (!await dir.exists()) {
      _error = 'Directory does not exist: ${config.path}';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      notifyListeners();

      final binaryPath = await _getDufsBinaryPath();
      final args = _buildArgs(config);

      debugPrint('starting dufs: $binaryPath ${args.join(' ')}');

      _process = await Process.start(
        binaryPath,
        args,
        workingDirectory: config.path,
      );

      _process!.stdout.listen((data) {
        final output = String.fromCharCodes(data).trim();
        debugPrint('dufs stdout: $output');
        if (output.contains('serving') || output.contains('listening')) {
          _updateServerUrl(config);
        }
        // Parse request logs for connection tracking
        _parseDufsLog(output);
      });

      _process!.stderr.listen((data) {
        final output = String.fromCharCodes(data).trim();
        debugPrint('dufs stderr: $output');
        _parseDufsLog(output);
      });

      await Future.delayed(const Duration(milliseconds: 500));

      try {
        final exitCode = await _process!.exitCode.timeout(
          const Duration(milliseconds: 100),
        );
        _error = 'dufs failed to start, exit code: $exitCode';
        _process = null;
        notifyListeners();
        return;
      } catch (_) {
        // timeout means process is still running - success
      }

      _isRunning = true;
      await _updateServerUrl(config);
      debugPrint('dufs server started');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to start server: $e';
      _isRunning = false;
      notifyListeners();
      debugPrint('start dufs failed: $e');
    }
  }

  /// 更新服务 URL
  Future<void> _updateServerUrl(ServerConfig config) async {
    _localIp = await _getWifiIP();
    final ip = _localIp ?? '127.0.0.1';
    _serverUrl = 'http://$ip:${config.port}';
    notifyListeners();
  }

  /// Parse dufs log output for connection tracking
  void _parseDufsLog(String line) {
    // dufs logs: "INFO - 127.0.0.1 - GET /path - 200"
    // or similar request patterns
    final upper = line.toUpperCase();
    if (upper.contains('GET') || upper.contains('POST') || upper.contains('PUT') ||
        upper.contains('DELETE') || upper.contains('MKCOL') || upper.contains('PROPFIND')) {
      _totalRequests++;
      _lastActivity = DateTime.now().toString().substring(11, 19);

      // Detect upload (PUT) or download (GET) for display
      if (upper.contains('PUT') || upper.contains('MKCOL')) {
        _lastActivity = 'Upload $_lastActivity';
      } else if (upper.contains('DELETE')) {
        _lastActivity = 'Delete $_lastActivity';
      }
      notifyListeners();
    }
  }

  /// 停止 dufs 文件服务
  Future<void> stopServer() async {
    if (!_isRunning || _process == null) return;

    try {
      _process!.kill(ProcessSignal.sigterm);
      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      debugPrint('dufs stopped, exit code: $exitCode');
    } catch (e) {
      debugPrint('stop dufs error: $e');
      try {
        _process!.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }

    _process = null;
    _isRunning = false;
    _serverUrl = null;
    _activeConnections = 0;
    _totalRequests = 0;
    _lastActivity = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
