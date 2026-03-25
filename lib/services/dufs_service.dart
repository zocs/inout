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
  List<String> _allAddresses = [];
  /// 网卡名称列表，与 allAddresses 一一对应
  List<String> _allInterfaceNames = [];

  bool get isRunning => _isRunning;
  String? get serverUrl => _serverUrl;
  String? get localIp => _localIp;
  String? get error => _error;
  int get totalRequests => _totalRequests;
  String? get lastActivity => _lastActivity;
  List<String> get allAddresses => _allAddresses;
  List<String> get allInterfaceNames => _allInterfaceNames;

  void _log(String msg) {
    debugPrint(msg);
    // ignore: body_might_complete_normally_catch_error
    if (Platform.isAndroid) _ch.invokeMethod('log', {'msg': msg}).catchError((_) {});
  }

  Future<String?> _getWifiIP() async {
    try { return await NetworkInfo().getWifiIP(); } catch (_) { return null; }
  }

  /// 获取所有可用网络接口的 IPv4 地址及网卡名称
  Future<Map<String, List<String>>> _getAllAddresses() async {
    final addresses = <String>[];
    final names = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.address != '127.0.0.1' && !addresses.contains(addr.address)) {
            addresses.add(addr.address);
            names.add(iface.name);
          }
        }
      }
    } catch (_) {}
    return {'addresses': addresses, 'names': names};
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

  /// 检查端口是否被占用（公共方法，用于恢复状态检测）
  Future<bool> isPortInUse(int port) async => !(await _isPortAvailable(port));

  /// 强制清理占用端口的 dufs 孤儿进程
  Future<void> killOrphanOnPort(int port) async {
    try {
      if (Platform.isAndroid) {
        await Process.run('pkill', ['-f', 'libdufs.so']).catchError((_) => ProcessResult(0, 1, '', ''));
      } else if (Platform.isLinux || Platform.isMacOS) {
        final r = await Process.run('lsof', ['-ti', ':$port']).catchError((_) => ProcessResult(0, 1, '', ''));
        final pids = r.stdout.toString().trim().split('\n');
        for (final pid in pids) {
          if (pid.isEmpty) continue;
          final cmd = await Process.run('ps', ['-p', pid, '-o', 'comm=']).catchError((_) => ProcessResult(0, 1, '', ''));
          if (cmd.stdout.toString().toLowerCase().contains('dufs')) {
            _log('Killing orphan dufs PID=$pid on port $port');
            await Process.run('kill', [pid]).catchError((_) => ProcessResult(0, 1, '', ''));
          }
        }
      }
      _log('Cleaned up orphan on port $port');
    } catch (e) {
      _log('Failed to clean orphan on port $port: $e');
    }
  }

  /// 清理可能残留的 dufs 孤儿进程（占用了目标端口的）
  Future<void> _killOrphanDufs(int port) async {
    try {
      if (Platform.isWindows) {
        // Find process using the port and kill it if it's dufs
        final result = await Process.run('netstat', ['-ano', '-p', 'TCP']);
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          if (line.contains(':$port ') && line.contains('LISTENING')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            final pid = int.tryParse(parts.last);
            if (pid != null) {
              // Check if it's a dufs process
              final taskResult = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/FO', 'CSV']);
              final output = taskResult.stdout as String;
              if (output.toLowerCase().contains('dufs')) {
                _log('Killing orphan dufs process PID=$pid on port $port');
                await Process.run('taskkill', ['/F', '/PID', '$pid']);
              }
            }
          }
        }
      } else if (Platform.isAndroid) {
        // On Android, kill any dufs process that might be orphaned
        await Process.run('pkill', ['-f', 'libdufs.so']).catchError((_) => ProcessResult(0, 1, '', ''));
      } else if (Platform.isMacOS || Platform.isLinux) {
        final r = await Process.run('lsof', ['-ti', ':$port']).catchError((_) => ProcessResult(0, 1, '', ''));
        final pids = r.stdout.toString().trim().split('\n');
        for (final pid in pids) {
          if (pid.isEmpty) continue;
          final cmd = await Process.run('ps', ['-p', pid, '-o', 'comm=']).catchError((_) => ProcessResult(0, 1, '', ''));
          if (cmd.stdout.toString().toLowerCase().contains('dufs')) {
            _log('Killing orphan dufs PID=$pid on port $port');
            await Process.run('kill', [pid]).catchError((_) => ProcessResult(0, 1, '', ''));
          }
        }
      }
    } catch (e) {
      _log('Failed to kill orphan dufs: $e');
    }
  }

  Future<void> startServer(ServerConfig config) async {
    if (_isRunning) return;
    if (config.path.isEmpty) { _error = 'No directory'; notifyListeners(); return; }
    // 单文件模式检查文件是否存在，目录模式检查目录是否存在
    if (config.shareSingleFile) {
      if (!await File(config.path).exists()) { _error = 'File not found'; notifyListeners(); return; }
      final parentDir = p.dirname(config.path);
      if (!await Directory(parentDir).exists()) { _error = 'Parent directory not found'; notifyListeners(); return; }
    } else {
      if (!await Directory(config.path).exists()) { _error = 'Directory not found'; notifyListeners(); return; }
    }
    // Validate permission consistency
    final permError = config.validatePermissions();
    if (permError != null) { _error = permError; notifyListeners(); return; }
    // Check port availability, kill orphan dufs if needed
    if (!await _isPortAvailable(config.port)) {
      _log('Port ${config.port} in use, attempting to kill orphan dufs...');
      await _killOrphanDufs(config.port);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!await _isPortAvailable(config.port)) {
        _error = '端口 ${config.port} 已被占用，请更换端口';
        notifyListeners();
        return;
      }
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
      final allNet = await _getAllAddresses();
      _allAddresses = allNet['addresses'] ?? [];
      _allInterfaceNames = allNet['names'] ?? [];
      // 确保默认 WiFi IP 在列表首位
      if (_localIp != null && _allAddresses.contains(_localIp)) {
        final idx = _allAddresses.indexOf(_localIp!);
        _allAddresses.removeAt(idx);
        _allInterfaceNames.removeAt(idx);
        _allAddresses.insert(0, _localIp!);
        _allInterfaceNames.insert(0, 'WiFi');
      } else if (_localIp != null && !_allAddresses.contains(_localIp)) {
        _allAddresses.insert(0, _localIp!);
        _allInterfaceNames.insert(0, 'WiFi');
      }
      if (_allAddresses.isEmpty) { _allAddresses.add('127.0.0.1'); _allInterfaceNames.add('Local'); }
      _serverUrl = 'http://${_allAddresses.first}:${config.port}';
      _log('server: $_serverUrl, all: $_allAddresses');
      // Start Android foreground service to keep dufs alive
      if (Platform.isAndroid) {
        _ch.invokeMethod('startForegroundService', {'port': config.port, 'path': config.path}).catchError((_) {});
      }
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
    } else if (Platform.isIOS) {
      // iOS: dufs binary bundled in Frameworks directory
      final frameworksDir = p.dirname(Platform.resolvedExecutable);
      return p.join(frameworksDir, 'dufs');
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
      if (c.allowSymlink) args.add('--allow-symlink');
    }
    if (c.auth != null && c.auth!.isNotEmpty) args.addAll(['--auth', '${c.auth!}@/:rw']);
    if (c.cors) args.add('--enable-cors');
    // dufs 只能服务目录，单文件模式传父目录
    if (c.shareSingleFile) {
      args.add(p.dirname(c.path));
    } else {
      args.add(c.path);
    }
    return args;
  }

  // ==================== Start dufs process ====================
  Future<void> _startDufsProcess(ServerConfig config) async {
    final binPath = await _resolveBinPath();
    if (!await File(binPath).exists()) {
      throw Exception('dufs 服务组件缺失，请重新安装应用。路径: $binPath');
    }
    final args = _buildArgs(config);
    // dufs 只能服务目录，单文件模式用父目录作 root
    final workDir = config.shareSingleFile ? p.dirname(config.path) : config.path;
    _log('dufs: $binPath ${args.join(' ')}');
    _process = await Process.start(binPath, args, workingDirectory: workDir);
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
  /// dufs 日志格式示例: "2024-01-01 12:00:00 | 200 | GET /path"
  void _trackActivity(String line) {
    // 只匹配包含 " | 状态码 |" 格式的行，避免匹配端口号等
    final isRequest = RegExp(r'\|\s*[1-5]\d{2}\s*\|').hasMatch(line);
    if (isRequest) {
      _totalRequests++;
      _lastActivity = DateTime.now().toIso8601String().substring(11, 19); // HH:mm:ss
      notifyListeners();
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;
    if (_process != null) {
      _process!.kill();
      // Wait briefly for port release
      try { await _process!.exitCode.timeout(const Duration(seconds: 2)); } catch (_) {}
      _process = null;
    }
    if (Platform.isAndroid) {
      _ch.invokeMethod('stopForegroundService').catchError((_) {});
    }
    _isRunning = false; _serverUrl = null; _totalRequests = 0; _lastActivity = null;
    _allAddresses = []; _allInterfaceNames = [];
    notifyListeners();
  }

  /// 恢复到孤儿 dufs 进程的状态（Activity 重建后端口仍被占用）
  Future<void> restoreFromOrphan(int port) async {
    _isRunning = true;
    _localIp = await _getWifiIP();
    final allNet = await _getAllAddresses();
    _allAddresses = allNet['addresses'] ?? [];
    _allInterfaceNames = allNet['names'] ?? [];
    if (_localIp != null && _allAddresses.contains(_localIp)) {
      final idx = _allAddresses.indexOf(_localIp!);
      _allAddresses.removeAt(idx);
      _allInterfaceNames.removeAt(idx);
      _allAddresses.insert(0, _localIp!);
      _allInterfaceNames.insert(0, 'WiFi');
    } else if (_localIp != null && !_allAddresses.contains(_localIp)) {
      _allAddresses.insert(0, _localIp!);
      _allInterfaceNames.insert(0, 'WiFi');
    }
    if (_allAddresses.isEmpty) { _allAddresses.add('127.0.0.1'); _allInterfaceNames.add('Local'); }
    _serverUrl = 'http://${_allAddresses.first}:$port';
    _log('restored orphan dufs: $_serverUrl');
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
