import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/server_config.dart';
import '../models/transfer_log.dart';
import 'dufs_ffi.dart';

/// Whether to use FFI (in-process) instead of spawning dufs as child process.
/// Desktop platforms (Linux/macOS/Windows) use FFI to avoid AppImage sandbox,
/// antivirus interception, and orphan process issues.
bool get _useFfi => Platform.isLinux || Platform.isMacOS || Platform.isWindows;

class DufsService extends ChangeNotifier {
  static const _ch = MethodChannel('cc.merr.inout/native');

  final DufsFfi _dufsFfi = DufsFfi();
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

  /// 传输日志（最新的在前）
  final List<TransferLog> _transferLogs = [];

  bool get isRunning => _isRunning;
  String? get serverUrl => _serverUrl;
  String? get localIp => _localIp;
  String? get error => _error;
  int get totalRequests => _totalRequests;
  String? get lastActivity => _lastActivity;
  List<String> get allAddresses => _allAddresses;
  List<String> get allInterfaceNames => _allInterfaceNames;
  List<TransferLog> get transferLogs => List.unmodifiable(_transferLogs);

  void _log(String msg) {
    debugPrint(msg);
    // ignore: body_might_complete_normally_catch_error
    if (Platform.isAndroid)
      _ch.invokeMethod('log', {'msg': msg}).catchError((_) {});
  }

  Future<String?> _getWifiIP() async {
    try {
      return await NetworkInfo().getWifiIP();
    } catch (_) {
      return null;
    }
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
          if (addr.address != '127.0.0.1' &&
              !addresses.contains(addr.address)) {
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
        await Process.run('pkill', [
          '-f',
          'libdufs.so',
        ]).catchError((_) => ProcessResult(0, 1, '', ''));
      } else if (Platform.isLinux || Platform.isMacOS) {
        final r = await Process.run('lsof', [
          '-ti',
          ':$port',
        ]).catchError((_) => ProcessResult(0, 1, '', ''));
        final pids = r.stdout.toString().trim().split('\n');
        for (final pid in pids) {
          if (pid.isEmpty) continue;
          final cmd = await Process.run('ps', [
            '-p',
            pid,
            '-o',
            'comm=',
          ]).catchError((_) => ProcessResult(0, 1, '', ''));
          if (cmd.stdout.toString().toLowerCase().contains('dufs')) {
            _log('Killing orphan dufs PID=$pid on port $port');
            await Process.run('kill', [
              pid,
            ]).catchError((_) => ProcessResult(0, 1, '', ''));
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
    // FFI 模式下 dufs 运行在进程内，无需清理孤儿进程
    if (_useFfi) return;
    try {
      if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano', '-p', 'TCP']);
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          if (line.contains(':$port ') && line.contains('LISTENING')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            final pid = int.tryParse(parts.last);
            if (pid != null) {
              final taskResult = await Process.run('tasklist', [
                '/FI',
                'PID eq $pid',
                '/FO',
                'CSV',
              ]);
              final output = taskResult.stdout as String;
              if (output.toLowerCase().contains('dufs')) {
                _log('Killing orphan dufs process PID=$pid on port $port');
                await Process.run('taskkill', ['/F', '/PID', '$pid']);
              }
            }
          }
        }
      } else if (Platform.isAndroid) {
        await Process.run('pkill', [
          '-f',
          'libdufs.so',
        ]).catchError((_) => ProcessResult(0, 1, '', ''));
      } else if (Platform.isMacOS || Platform.isLinux) {
        final r = await Process.run('lsof', [
          '-ti',
          ':$port',
        ]).catchError((_) => ProcessResult(0, 1, '', ''));
        final pids = r.stdout.toString().trim().split('\n');
        for (final pid in pids) {
          if (pid.isEmpty) continue;
          final cmd = await Process.run('ps', [
            '-p',
            pid,
            '-o',
            'comm=',
          ]).catchError((_) => ProcessResult(0, 1, '', ''));
          if (cmd.stdout.toString().toLowerCase().contains('dufs')) {
            _log('Killing orphan dufs PID=$pid on port $port');
            await Process.run('kill', [
              pid,
            ]).catchError((_) => ProcessResult(0, 1, '', ''));
          }
        }
      }
    } catch (e) {
      _log('Failed to kill orphan dufs: $e');
    }
  }

  Future<void> startServer(ServerConfig config) async {
    if (_isRunning) return;
    // Set up log file path
    final tmpDir = await getTemporaryDirectory();
    _logFilePath = '${tmpDir.path}/inout_dufs.log';
    // Clear previous log file
    try {
      await File(_logFilePath!).writeAsString('');
    } catch (_) {}
    _logFilePosition = 0;
    _logFileRemainder = '';
    if (config.path.isEmpty) {
      _error = 'No directory';
      notifyListeners();
      return;
    }
    // 单文件模式检查文件是否存在，目录模式检查目录是否存在
    if (config.shareSingleFile) {
      if (!await File(config.path).exists()) {
        _error = 'File not found';
        notifyListeners();
        return;
      }
      final parentDir = p.dirname(config.path);
      if (!await Directory(parentDir).exists()) {
        _error = 'Parent directory not found';
        notifyListeners();
        return;
      }
    } else {
      if (!await Directory(config.path).exists()) {
        _error = 'Directory not found';
        notifyListeners();
        return;
      }
    }
    // Validate permission consistency
    final permError = config.validatePermissions();
    if (permError != null) {
      _error = permError;
      notifyListeners();
      return;
    }
    // Check port availability, kill orphan dufs if needed
    if (!await _isPortAvailable(config.port)) {
      _log('Port ${config.port} in use, attempting to kill orphan dufs...');
      await _killOrphanDufs(config.port);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!await _isPortAvailable(config.port)) {
        // In FFI mode, let the FFI binding retry handle TIME_WAIT — don't block here
        if (!_useFfi) {
          _error = '端口 ${config.port} 已被占用，请更换端口';
          notifyListeners();
          return;
        }
        _log('Port still in use, but FFI will retry binding...');
      }
    }
    try {
      _error = null;
      notifyListeners();
      if (Platform.isAndroid) {
        final granted =
            await _ch.invokeMethod<bool>('isStorageGranted') ?? false;
        _log('MANAGE_EXTERNAL_STORAGE granted: $granted');
        if (!granted) {
          _error = '需要开启"所有文件访问权限"才能正常列出文件。请在系统设置中开启后重试。';
          notifyListeners();
          await _ch.invokeMethod('requestStorage');
          return;
        }
      }
      if (Platform.isAndroid) {
        // Android: start dufs via Native Service (process lives in Service, not Dart)
        final args = _buildArgs(config);
        await _ch.invokeMethod('startForegroundService', {
          'port': config.port,
          'path': config.path,
          'args': args,
        });
        // Startup verification: wait for Native Service to start dufs, then confirm
        await Future.delayed(const Duration(milliseconds: 500));
        final info = await _ch.invokeMethod<Map>('getServiceInfo');
        if (info == null || info['isRunning'] != true) {
          final svcError = info?['error'] as String? ?? '';
          _error = '服务启动失败${svcError.isNotEmpty ? ': $svcError' : ''}';
          _isRunning = false;
          notifyListeners();
          return;
        }
      } else if (Platform.isIOS) {
        // iOS: start dufs as child process (not signed for FFI)
        await _startDufsProcess(config);
      } else {
        // Desktop (Linux/macOS/Windows): use FFI
        await _startDufsFfi(config);
      }

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
      if (_allAddresses.isEmpty) {
        _allAddresses.add('127.0.0.1');
        _allInterfaceNames.add('Local');
      }
      _serverUrl = 'http://${_allAddresses.first}:${config.port}';
      _log('server: $_serverUrl, all: $_allAddresses');
      // Start polling log file for transfer records
      _startLogFilePolling();
      notifyListeners();
    } catch (e) {
      _error = 'Start failed: $e';
      _isRunning = false;
      notifyListeners();
      _log('failed: $e');
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
    if (c.auth != null && c.auth!.isNotEmpty)
      args.addAll(['--auth', '${c.auth!}@/:rw']);
    if (c.cors) args.add('--enable-cors');
    if (c.hideSystemFiles)
      args.addAll([
        '--hidden',
        '.git,.DS_Store,Thumbs.db,.env,.idea,.vscode,__pycache__,.svn,.hg',
      ]);
    if (c.renderTryIndex) args.add('--render-try-index');
    // Write HTTP logs to a temp file so we can read them on all platforms
    if (_logFilePath != null) args.addAll(['--log-file', _logFilePath!]);
    // dufs supports serving a single file directly.
    args.add(c.path);
    return args;
  }

  /// Path to the dufs log file (set before start, cleared on stop)
  String? _logFilePath;

  /// Timer to poll the log file for new entries (Android/workaround)
  Timer? _logFileTimer;

  /// Last position read in the log file
  int _logFilePosition = 0;

  /// Partial line buffered between incremental reads
  String _logFileRemainder = '';

  // ==================== Start dufs via FFI (desktop) ====================
  Future<void> _startDufsFfi(ServerConfig config) async {
    if (!_dufsFfi.isLoaded) {
      final libPath = await resolveDufsLibPath();
      _log('Loading dufs FFI library: $libPath');
      _dufsFfi.load(libPath);
    }
    final args = _buildArgs(config);
    final argsStr = args.join(' ');
    _log('dufs ffi start: $argsStr');
    final ret = _dufsFfi.start(argsStr);
    if (ret != 0) {
      _log('dufs FFI start returned $ret (failure)');
      throw Exception('dufs FFI start returned $ret');
    }
    _log('dufs FFI start returned 0 (success)');
    // Give the server a moment to bind
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ==================== Start dufs process (iOS) ====================
  Future<void> _startDufsProcess(ServerConfig config) async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final binPath = p.join(exeDir, 'dufs');
    if (!await File(binPath).exists()) {
      throw Exception('dufs 服务组件缺失，请重新安装应用。路径: $binPath');
    }
    final args = _buildArgs(config);
    final workDir = config.shareSingleFile
        ? p.dirname(config.path)
        : config.path;
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

  /// 解析 dufs 输出行，更新请求计数和日志列表
  void _trackActivity(String line) {
    final isRequest =
        RegExp(r'[1-5]\d{2}').hasMatch(line) &&
        (line.contains('GET') ||
            line.contains('POST') ||
            line.contains('PUT') ||
            line.contains('DELETE'));
    if (isRequest) {
      _totalRequests++;
      _lastActivity = DateTime.now().toIso8601String().substring(11, 19);
      final entry = TransferLog.parse(line);
      if (entry != null && _isFileTransfer(entry)) {
        _transferLogs.insert(0, entry);
        if (_transferLogs.length > 200) {
          _transferLogs.removeRange(200, _transferLogs.length);
        }
      }
      notifyListeners();
    }
  }

  bool _isFileTransfer(TransferLog entry) {
    final path = entry.path;
    if (path == '/' || path.isEmpty) return false;
    if (path.endsWith('/')) return false;
    if (path.endsWith('.css') || path.endsWith('.js') || path.endsWith('.ico'))
      return false;
    if (path.contains('/dufs-assets/')) return false;
    if (entry.method == 'MKCOL' ||
        entry.method == 'OPTIONS' ||
        entry.method == 'PROPFIND')
      return false;
    if (entry.isDownload && !path.contains('.')) return false;
    return entry.isDownload || entry.isUpload || entry.isDelete;
  }

  void clearLogs() {
    _transferLogs.clear();
    notifyListeners();
  }

  void _startLogFilePolling() {
    _logFileTimer?.cancel();
    _logFileTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _readLogFile(),
    );
  }

  Future<void> _readLogFile() async {
    if (_logFilePath == null) return;
    try {
      final file = File(_logFilePath!);
      if (!await file.exists()) return;
      final raf = await file.open();
      try {
        final length = await raf.length();
        if (length < _logFilePosition) {
          _logFilePosition = 0;
          _logFileRemainder = '';
        }
        if (length == _logFilePosition) return;

        await raf.setPosition(_logFilePosition);
        final bytes = await raf.read(length - _logFilePosition);
        _logFilePosition = length;

        final chunk = utf8.decode(bytes, allowMalformed: true);
        final merged = _logFileRemainder + chunk;
        final endsWithNewline = merged.endsWith('\n');
        final lines = merged.split('\n');
        _logFileRemainder = endsWithNewline ? '' : lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) _trackActivity(trimmed);
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;
    if (_useFfi && _dufsFfi.isLoaded) {
      // FFI mode: stop the in-process server
      _dufsFfi.stop();
      // Wait for the server to release the port (accept() may be blocking)
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!_dufsFfi.isRunning()) break;
      }
      // Extra delay for OS to fully release the port (TIME_WAIT on Windows)
      await Future.delayed(const Duration(milliseconds: 800));
    } else if (_process != null) {
      // Process mode (iOS): kill child process
      _process!.kill();
      try {
        await _process!.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}
      _process = null;
    }
    if (Platform.isAndroid) {
      _ch.invokeMethod('stopForegroundService').catchError((_) {});
    }
    _isRunning = false;
    _serverUrl = null;
    _totalRequests = 0;
    _lastActivity = null;
    _allAddresses = [];
    _allInterfaceNames = [];
    _transferLogs.clear();
    _logFileTimer?.cancel();
    _logFileTimer = null;
    _logFilePath = null;
    _logFilePosition = 0;
    _logFileRemainder = '';
    notifyListeners();
  }

  /// 恢复到 Native Service 管理的 dufs 进程状态（Activity 重建后查询 Service）
  Future<void> restoreFromService() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await _ch.invokeMethod<Map>('getServiceInfo');
      if (info != null && info['isRunning'] == true) {
        final port = info['port'] as int? ?? 0;
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
        if (_allAddresses.isEmpty) {
          _allAddresses.add('127.0.0.1');
          _allInterfaceNames.add('Local');
        }
        _serverUrl = 'http://${_allAddresses.first}:$port';
        _isRunning = true;
        _log('restored from native service: $_serverUrl');
        notifyListeners();
      }
    } catch (e) {
      _log('Failed to restore from service: $e');
    }
  }

  @override
  void dispose() {
    if (_useFfi && _dufsFfi.isLoaded) {
      try {
        _dufsFfi.stop();
      } catch (_) {}
    }
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
    _isRunning = false;
    super.dispose();
  }
}
