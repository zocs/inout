import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/server_config.dart';

class DufsService extends ChangeNotifier {
  static const _ch = MethodChannel('cc.merr.inout/native');

  Process? _process;
  bool _isRunning = false;
  String? _serverUrl;
  String? _localIp;
  String? _error;
  int _totalRequests = 0;
  String? _lastActivity;

  bool get isRunning => _isRunning;
  String? get serverUrl => _serverUrl;
  String? get localIp => _localIp;
  String? get error => _error;
  int get totalRequests => _totalRequests;
  String? get lastActivity => _lastActivity;

  void _log(String msg) {
    debugPrint(msg);
    if (Platform.isAndroid) _ch.invokeMethod('log', {'msg': msg}).catchError((_) {});
  }

  Future<String?> _getWifiIP() async {
    try { return await NetworkInfo().getWifiIP(); } catch (_) { return null; }
  }

  Future<bool> _isPortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> startServer(ServerConfig config) async {
    if (_isRunning) return;
    if (config.path.isEmpty) { _error = 'No directory'; notifyListeners(); return; }
    if (!await Directory(config.path).exists()) { _error = 'Directory not found'; notifyListeners(); return; }
    // Validate permission consistency
    final permError = config.validatePermissions();
    if (permError != null) { _error = permError; notifyListeners(); return; }
    // Check port availability
    if (!await _isPortAvailable(config.port)) {
      _error = '端口 ${config.port} 已被占用，请更换端口';
      notifyListeners();
      return;
    }
    try {
      _error = null; notifyListeners();
      if (Platform.isAndroid) {
        final granted = await _ch.invokeMethod<bool>('isStorageGranted') ?? false;
        _log('MANAGE_EXTERNAL_STORAGE granted: $granted');
        if (!granted) {
          _error = '需要开启"所有文件访问权限"才能正常列出文件。请在系统设置中开启后重试。';
          notifyListeners();
          await _ch.invokeMethod('requestStorage');
          return;
        }
      }
      await _startDufsProcess(config);
      _isRunning = true;
      _localIp = await _getWifiIP();
      _serverUrl = 'http://${_localIp ?? '127.0.0.1'}:${config.port}';
      _log('server: $_serverUrl');
      notifyListeners();
    } catch (e) {
      _error = 'Start failed: $e'; _isRunning = false; notifyListeners();
      _log('failed: $e');
    }
  }

  // ==================== Platform-specific binary path ====================
  Future<String> _resolveBinPath() async {
    if (Platform.isWindows) {
      final appDir = await getApplicationDocumentsDirectory();
      final bin = p.join(appDir.path, 'dufs.exe');
      if (!await File(bin).exists()) {
        final data = await rootBundle.load('assets/dufs/dufs-windows.exe');
        await File(bin).writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      return bin;
    } else if (Platform.isAndroid) {
      final nativeDir = await _ch.invokeMethod<String>('getNativeLibraryDir');
      _log('nativeLibraryDir: $nativeDir');
      return '$nativeDir/libdufs.so';
    } else {
      // Linux & macOS: dufs binary next to the app executable
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return p.join(exeDir, 'dufs');
    }
  }

  // ==================== Build dufs CLI args ====================
  List<String> _buildArgs(ServerConfig c) {
    final args = <String>['-b', '0.0.0.0', '-p', '${c.port}'];
    if (!c.readonly) {
      if (c.allowUpload) args.add('--allow-upload');
      if (c.allowDelete) args.add('--allow-delete');
      if (c.allowSearch) args.add('--allow-search');
      if (c.allowArchive) args.add('--allow-archive');
    }
    if (c.auth != null && c.auth!.isNotEmpty) args.addAll(['--auth', '${c.auth!}@/:rw']);
    if (c.cors) args.add('--enable-cors');
    args.add(c.path);
    return args;
  }

  // ==================== Start dufs process ====================
  Future<void> _startDufsProcess(ServerConfig config) async {
    final binPath = await _resolveBinPath();
    if (!await File(binPath).exists()) {
      throw Exception('dufs binary not found at $binPath');
    }
    final args = _buildArgs(config);
    _log('dufs: $binPath ${args.join(' ')}');
    _process = await Process.start(binPath, args, workingDirectory: config.path);
    _process!.stdout.listen((d) {
      final line = String.fromCharCodes(d).trim();
      _log('out: $line');
      _trackActivity(line);
    });
    _process!.stderr.listen((d) {
      final line = String.fromCharCodes(d).trim();
      _log('err: $line');
      _trackActivity(line);
    });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// 解析 dufs 输出行，更新请求计数和最后活跃时间
  /// dufs 日志格式: "2024-01-01 12:00:00 | 200 | GET /path"
  void _trackActivity(String line) {
    // dufs logs requests with HTTP method + status code patterns
    final hasMethod = RegExp(r'\b(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\b').hasMatch(line);
    final hasStatus = RegExp(r'\b[2-5]\d{2}\b').hasMatch(line);
    if (hasMethod || hasStatus) {
      _totalRequests++;
      _lastActivity = DateTime.now().toIso8601String().substring(11, 19); // HH:mm:ss
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;
    if (_process != null) { _process!.kill(); _process = null; }
    _isRunning = false; _serverUrl = null; _totalRequests = 0; _lastActivity = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Synchronous cleanup - don't await in dispose
    try { _process?.kill(); } catch (_) {}
    _process = null;
    _isRunning = false;
    super.dispose();
  }
}
