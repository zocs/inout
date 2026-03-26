// dufs_ffi.dart — Dart FFI bindings for libdufs.so / dufs.dll / libdufs.dylib

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C function signatures
typedef DufsStartNative = Int32 Function(Pointer<Utf8> args);
typedef DufsStopNative = Void Function();
typedef DufsIsRunningNative = Int32 Function();

// Dart function signatures
typedef DufsStart = int Function(Pointer<Utf8> args);
typedef DufsStop = void Function();
typedef DufsIsRunning = int Function();

class DufsFfi {
  DynamicLibrary? _lib;
  DufsStart? _start;
  DufsStop? _stop;
  DufsIsRunning? _isRunning;

  /// Load the shared library from the given path.
  void load(String libPath) {
    _lib = DynamicLibrary.open(libPath);
    _start = _lib!.lookupFunction<DufsStartNative, DufsStart>('dufs_start');
    _stop = _lib!.lookupFunction<DufsStopNative, DufsStop>('dufs_stop');
    _isRunning = _lib!.lookupFunction<DufsIsRunningNative, DufsIsRunning>('dufs_is_running');
  }

  /// Start the dufs server with CLI-style args.
  /// Returns 0 on success, -1 on error.
  int start(String args) {
    if (_start == null) throw StateError('DufsFfi not loaded');
    final ptr = args.toNativeUtf8();
    try {
      return _start!(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  /// Stop the dufs server.
  void stop() {
    if (_stop == null) throw StateError('DufsFfi not loaded');
    _stop!();
  }

  /// Check if the server is running.
  bool isRunning() {
    if (_isRunning == null) return false;
    return _isRunning!() == 1;
  }

  bool get isLoaded => _lib != null;
}

/// Resolve the path to the dufs shared library for the current platform.
Future<String> resolveDufsLibPath() async {
  if (Platform.isLinux) {
    // In AppImage, extract to /tmp to avoid FUSE isolation
    final exeDir = Directory.fromUri(Uri.file(Platform.resolvedExecutable)).parent.path;
    final libPath = '$exeDir/libdufs.so';
    if (exeDir.contains('.mount_')) {
      // Running inside AppImage — extract to /tmp
      final tmpLib = '/tmp/inout-libdufs.so';
      if (!await File(tmpLib).exists()) {
        await File(libPath).copy(tmpLib);
      }
      return tmpLib;
    }
    return libPath;
  } else if (Platform.isMacOS) {
    final exeDir = Directory.fromUri(Uri.file(Platform.resolvedExecutable)).parent.path;
    return '$exeDir/libdufs.dylib';
  } else if (Platform.isWindows) {
    // Windows: extract from asset to app data dir
    final exeDir = Directory.fromUri(Uri.file(Platform.resolvedExecutable)).parent.path;
    return '$exeDir/dufs.dll';
  }
  throw UnsupportedError('Platform not supported for FFI: ${Platform.operatingSystem}');
}
