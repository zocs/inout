import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/server_config.dart';

class DufsService extends ChangeNotifier {
  static const _ch = MethodChannel('com.inout.inout_flutter/native');

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

  Future<void> startServer(ServerConfig config) async {
    if (_isRunning) return;
    if (config.path.isEmpty) { _error = 'No directory'; notifyListeners(); return; }
    if (!await Directory(config.path).exists()) { _error = 'Directory not found'; notifyListeners(); return; }
    try {
      _error = null; notifyListeners();
      if (Platform.isWindows) {
        await _startDufs(config);
      } else {
        // Check MANAGE_EXTERNAL_STORAGE on Android
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
        await _startDart(config);
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

  // ==================== Android: try dufs binary first, fallback to Dart ====================
  Future<void> _startDart(ServerConfig config) async {
    // Check MANAGE_EXTERNAL_STORAGE
    final granted = await _ch.invokeMethod<bool>('isStorageGranted') ?? false;
    _log('MANAGE_EXTERNAL_STORAGE: $granted');
    if (!granted) {
      _error = '需要开启"所有文件访问权限"才能正常工作。请在系统设置中开启后重试。';
      notifyListeners();
      await _ch.invokeMethod('requestStorage');
      return;
    }

    // Try dufs binary from jniLibs
    final nativeDir = await _ch.invokeMethod<String>('getNativeLibraryDir');
    _log('nativeLibraryDir: $nativeDir');
    if (nativeDir != null) {
      final binPath = '$nativeDir/libdufs.so';
      _log('checking: $binPath exists=${await File(binPath).exists()}');
      if (await File(binPath).exists()) {
        try {
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
          _log('trying dufs: $binPath ${args.join(' ')}');
          _process = await Process.start(binPath, args);
          _process!.stdout.listen((d) => _log('dufs: ${String.fromCharCodes(d).trim()}'));
          _process!.stderr.listen((d) => _log('dufs ERR: ${String.fromCharCodes(d).trim()}'));
          await Future.delayed(const Duration(milliseconds: 500));
          return;
        } catch (e) {
          _log('dufs failed, falling back to Dart: $e');
        }
      }
    }

    // Fallback: Dart HTTP server
    _log('using Dart HTTP server');
    final root = config.path;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, config.port);
    _log('dart:${config.port} root=$root');
    _server!.listen((req) {
      _totalRequests++;
      _lastActivity = DateTime.now().toString().substring(11, 19);
      notifyListeners();
      _handleRequest(req, root, config);
    });
  }

  Future<void> _handleRequest(HttpRequest req, String root, ServerConfig config) async {
    try {
      // CORS
      if (config.cors) {
        req.response.headers.set('Access-Control-Allow-Origin', '*');
        req.response.headers.set('Access-Control-Allow-Methods', 'GET,HEAD,POST,PUT,DELETE,OPTIONS,MKCOL');
        req.response.headers.set('Access-Control-Allow-Headers', '*');
        if (req.method == 'OPTIONS') { req.response.statusCode = 204; await req.response.close(); return; }
      }
      // Auth
      if (config.auth != null && config.auth!.isNotEmpty) {
        final auth = req.headers.value('Authorization');
        if (auth == null || !_auth(auth, config.auth!)) {
          req.response.statusCode = 401;
          req.response.headers.set('WWW-Authenticate', 'Basic realm="inout"');
          await req.response.close(); return;
        }
      }
      final uriPath = Uri.decodeComponent(req.uri.path);
      final rel = _resolve(uriPath);
      final fs = rel.isEmpty ? root : '$root${Platform.pathSeparator}$rel';
      _log('${req.method} $uriPath -> $fs');
      switch (req.method) {
        case 'GET': case 'HEAD': await _get(req, fs, uriPath, config); break;
        case 'PUT': if (!config.allowUpload) { _resp(req, 403); return; } await _put(req, fs); break;
        case 'DELETE': if (!config.allowDelete) { _resp(req, 403); return; } await _del(req, fs); break;
        case 'MKCOL': if (!config.allowUpload) { _resp(req, 403); return; } await _mkcol(req, fs); break;
        default: _resp(req, 405);
      }
    } catch (e, st) {
      _log('ERR: $e'); debugPrint('$st');
      _resp(req, 500);
    }
  }

  String _resolve(String uriPath) {
    if (uriPath == '/' || uriPath.isEmpty) return '';
    final parts = <String>[];
    for (final s in uriPath.split('/')) {
      if (s.isEmpty || s == '.') continue;
      if (s == '..') { if (parts.isNotEmpty) parts.removeLast(); continue; }
      parts.add(s);
    }
    return parts.join(Platform.pathSeparator);
  }

  Future<void> _get(HttpRequest req, String fs, String uriPath, ServerConfig config) async {
    final type = FileSystemEntity.typeSync(fs);
    if (type == FileSystemEntityType.directory) {
      await _listDir(req, fs, uriPath, config);
    } else if (type == FileSystemEntityType.file) {
      final file = File(fs);
      final name = p.basename(fs);
      req.response.headers.set('Content-Type', 'application/octet-stream');
      req.response.headers.set('Content-Disposition', 'attachment; filename="$name"');
      req.response.headers.set('Content-Length', '${file.lengthSync()}');
      await file.openRead().pipe(req.response);
    } else { _resp(req, 404); }
  }

  Future<void> _listDir(HttpRequest req, String fs, String uriPath, ServerConfig config) async {
    final dir = Directory(fs);
    final dirs = <String>[];
    final files = <String, int>{};
    _log('listDir: $fs');
    try {
      int count = 0;
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        count++;
        final name = p.basename(entity.path);
        _log('  $name (${entity.runtimeType})');
        if (entity is Directory) { dirs.add(name); }
        else if (entity is File) { int sz = 0; try { sz = await entity.length(); } catch (_) {} files[name] = sz; }
      }
      _log('  total: $count');
    } catch (e) {
      _log('  ERROR: $e');
      _resp(req, 403); return;
    }
    dirs.sort();
    final sFiles = files.keys.toList()..sort();
    final bp = uriPath.endsWith('/') ? uriPath : '$uriPath/';
    final h = StringBuffer();
    h.write('<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">');
    h.write('<title>inout</title><style>body{font-family:system-ui;padding:16px;background:#f8f9fa}a{color:#1a73e8;text-decoration:none}a:hover{text-decoration:underline}table{width:100%;border-collapse:collapse;background:#fff;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,.1)}th{background:#f1f3f4;padding:10px;text-align:left;font-size:12px;color:#666}td{padding:10px;border-bottom:1px solid #eee;font-size:14px}.sz{text-align:right;color:#888;font-size:13px}.ops a{color:#d32f2f;font-size:13px}.panel{margin-top:16px;padding:16px;background:#fff;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,.1)}.btn{padding:7px 16px;border:none;border-radius:6px;background:#1a73e8;color:#fff;cursor:pointer;font-size:14px}</style></head><body>');
    h.write('<h3>$uriPath</h3>');
    if (uriPath != '/') h.write('<p><a href="${bp}../">.. back</a></p>');
    h.write('<table><tr><th>Name</th><th>Size</th>');
    if (config.allowDelete) h.write('<th>Op</th>');
    h.write('</tr>');
    for (final d in dirs) {
      h.write('<tr><td><a href="$bp$d/">$d/</a></td><td class="sz">-</td>');
      if (config.allowDelete) h.write('<td class="ops"><a href="javascript:void(0)" onclick="del(\'$bp$d/\')">del</a></td>');
      h.write('</tr>');
    }
    for (final f in sFiles) {
      h.write('<tr><td><a href="$bp$f" download>$f</a></td><td class="sz">${_fmt(files[f] ?? 0)}</td>');
      if (config.allowDelete) h.write('<td class="ops"><a href="javascript:void(0)" onclick="del(\'$bp$f\')">del</a></td>');
      h.write('</tr>');
    }
    h.write('</table>');
    if (config.allowUpload) {
      h.write('<div class="panel"><h3>Upload</h3><input type="file" id="fi" multiple><button class="btn" onclick="upload()">Upload</button><div id="st"></div>');
      h.write('<h3>New folder</h3><input type="text" id="dn" placeholder="name"><button class="btn" onclick="mkdir()">Create</button></div>');
      h.write('<script>const B=location.pathname;async function upload(){const s=document.getElementById("st"),fs=document.getElementById("fi").files;if(!fs.length){s.textContent="select file";return}s.textContent="uploading...";let ok=0;for(const f of fs){if(await(await fetch(B+f.name,{method:"PUT",body:f})).ok)ok++}s.textContent=ok+"/"+fs.length+" done";if(ok)setTimeout(location.reload,1000)}async function mkdir(){const n=document.getElementById("dn").value.trim();if(!n)return;if(await(await fetch(B+n+"/",{method:"MKCOL"})).ok)location.reload()}async function del(p){if(!confirm("delete?"))return;if(await(await fetch(p,{method:"DELETE"})).ok)location.reload()}</script>');
    }
    h.write('</body></html>');
    req.response.headers.set('Content-Type', 'text/html; charset=utf-8');
    req.response.write(h.toString());
    await req.response.close();
  }

  Future<void> _put(HttpRequest req, String fs) async {
    final file = File(fs);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    await for (final chunk in req) { sink.add(chunk); }
    await sink.close();
    _log('uploaded: $fs (${await file.length()} bytes)');
    _resp(req, 201);
  }

  Future<void> _del(HttpRequest req, String fs) async {
    final type = FileSystemEntity.typeSync(fs);
    if (type == FileSystemEntityType.directory) { await Directory(fs).delete(recursive: true); }
    else if (type == FileSystemEntityType.file) { await File(fs).delete(); }
    else { _resp(req, 404); return; }
    _resp(req, 204);
  }

  Future<void> _mkcol(HttpRequest req, String fs) async {
    await Directory(fs).create(recursive: true);
    _resp(req, 201);
  }

  bool _auth(String header, String auth) {
    if (!header.startsWith('Basic ')) return false;
    return utf8.decode(base64Decode(header.substring(6))) == auth.split('@').first;
  }

  void _resp(HttpRequest req, int code) { req.response.statusCode = code; req.response.close(); }

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(1)} GB';
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;
    if (_process != null) { _process!.kill(); _process = null; }
    if (_server != null) { await _server!.close(force: true); _server = null; }
    _isRunning = false; _serverUrl = null; _totalRequests = 0; _lastActivity = null;
    notifyListeners();
  }

  @override
  void dispose() { stopServer(); super.dispose(); }
}
