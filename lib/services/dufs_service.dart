import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/server_config.dart';

class DufsService extends ChangeNotifier {
  static const _ch = MethodChannel('com.inout.inout/native');

  Process? _process;
  HttpServer? _server;
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
    // Check port availability
    if (!await _isPortAvailable(config.port)) {
      _error = '端口 ${config.port} 已被占用，请更换端口';
      notifyListeners();
      return;
    }
    try {
      _error = null; notifyListeners();
      if (Platform.isWindows) {
        await _startDufs(config);
      } else if (Platform.isLinux) {
        await _startDufsLinux(config);
      } else if (Platform.isMacOS) {
        await _startDufsMacos(config);
      } else if (Platform.isAndroid) {
        final granted = await _ch.invokeMethod<bool>('isStorageGranted') ?? false;
        _log('MANAGE_EXTERNAL_STORAGE granted: $granted');
        if (!granted) {
          _error = '需要开启"所有文件访问权限"才能正常列出文件。请在系统设置中开启后重试。';
          notifyListeners();
          await _ch.invokeMethod('requestStorage');
          return;
        }
        await _startDufsAndroid(config);
      }
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

  // ==================== Windows: dufs binary ====================
  Future<void> _startDufs(ServerConfig c) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bin = p.join(appDir.path, 'dufs.exe');
    if (!await File(bin).exists()) {
      final data = await rootBundle.load('assets/dufs/dufs-windows.exe');
      await File(bin).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
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
    _log('dufs: $bin ${args.join(' ')}');
    _process = await Process.start(bin, args, workingDirectory: c.path);
    _process!.stdout.listen((d) => _log('out: ${String.fromCharCodes(d).trim()}'));
    _process!.stderr.listen((d) => _log('err: ${String.fromCharCodes(d).trim()}'));
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // ==================== Linux: dufs binary ====================
  Future<void> _startDufsLinux(ServerConfig config) async {
    // dufs binary is placed next to the executable by the build script
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final binPath = p.join(exeDir, 'dufs');
    _log('linux dufs: $binPath exists=${await File(binPath).exists()}');
    if (await File(binPath).exists()) {
      final args = <String>['-b', '0.0.0.0', '-p', '${config.port}'];
      if (!config.readonly) {
        if (config.allowUpload) args.add('--allow-upload');
        if (config.allowDelete) args.add('--allow-delete');
        if (config.allowSearch) args.add('--allow-search');
        if (config.allowArchive) args.add('--allow-archive');
      }
      if (config.auth != null && config.auth!.isNotEmpty) args.addAll(['--auth', '${config.auth!}@/:rw']);
      if (config.cors) args.add('--enable-cors');
      args.add(config.path);
      _log('dufs: $binPath ${args.join(' ')}');
      _process = await Process.start(binPath, args);
      _process!.stdout.listen((d) => _log('dufs: ${String.fromCharCodes(d).trim()}'));
      _process!.stderr.listen((d) => _log('dufs ERR: ${String.fromCharCodes(d).trim()}'));
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      _log('ERROR: $binPath not found!');
      throw Exception('dufs binary not found at $binPath');
    }
  }

  // ==================== macOS: dufs binary ====================
  Future<void> _startDufsMacos(ServerConfig config) async {
    // dufs binary is in Contents/MacOS/ alongside the app executable
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final binPath = p.join(exeDir, 'dufs');
    _log('macos dufs: $binPath exists=${await File(binPath).exists()}');
    if (await File(binPath).exists()) {
      final args = <String>['-b', '0.0.0.0', '-p', '${config.port}'];
      if (!config.readonly) {
        if (config.allowUpload) args.add('--allow-upload');
        if (config.allowDelete) args.add('--allow-delete');
        if (config.allowSearch) args.add('--allow-search');
        if (config.allowArchive) args.add('--allow-archive');
      }
      if (config.auth != null && config.auth!.isNotEmpty) args.addAll(['--auth', '${config.auth!}@/:rw']);
      if (config.cors) args.add('--enable-cors');
      args.add(config.path);
      _log('dufs: $binPath ${args.join(' ')}');
      _process = await Process.start(binPath, args);
      _process!.stdout.listen((d) => _log('dufs: ${String.fromCharCodes(d).trim()}'));
      _process!.stderr.listen((d) => _log('dufs ERR: ${String.fromCharCodes(d).trim()}'));
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      _log('ERROR: $binPath not found!');
      throw Exception('dufs binary not found at $binPath');
    }
  }

  // ==================== Android: dufs binary ====================
  Future<void> _startDufsAndroid(ServerConfig config) async {
    final nativeDir = await _ch.invokeMethod<String>('getNativeLibraryDir');
    _log('nativeLibraryDir: $nativeDir');
    final binPath = '$nativeDir/libdufs.so';
    if (await File(binPath).exists()) {
      final args = <String>['-b', '0.0.0.0', '-p', '${config.port}'];
      if (!config.readonly) {
        if (config.allowUpload) args.add('--allow-upload');
        if (config.allowDelete) args.add('--allow-delete');
        if (config.allowSearch) args.add('--allow-search');
        if (config.allowArchive) args.add('--allow-archive');
      }
      if (config.auth != null && config.auth!.isNotEmpty) args.addAll(['--auth', '${config.auth!}@/:rw']);
      if (config.cors) args.add('--enable-cors');
      args.add(config.path);
      _log('dufs: $binPath ${args.join(' ')}');
      _process = await Process.start(binPath, args);
      _process!.stdout.listen((d) => _log('dufs: ${String.fromCharCodes(d).trim()}'));
      _process!.stderr.listen((d) => _log('dufs ERR: ${String.fromCharCodes(d).trim()}'));
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      _log('ERROR: $binPath not found!');
      throw Exception('dufs binary not found in jniLibs');
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;
    if (_process != null) { _process!.kill(); _process = null; }
    if (_server != null) { await _server!.close(force: true); _server = null; }
    _isRunning = false; _serverUrl = null; _totalRequests = 0; _lastActivity = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Synchronous cleanup - don't await in dispose
    try { _process?.kill(); } catch (_) {}
    _process = null;
    if (_server != null) {
      _server!.close(force: true).catchError((_) {});
      _server = null;
    }
    _isRunning = false;
    super.dispose();
  }
}
