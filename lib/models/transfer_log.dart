/// 传输日志条目
class TransferLog {
  final DateTime time;
  final String method; // GET, POST, DELETE, etc.
  final String path;
  final int status; // HTTP status code
  final int? size; // bytes transferred (null if unknown)
  final String? ip; // client IP (null if unknown)

  const TransferLog({
    required this.time,
    required this.method,
    required this.path,
    required this.status,
    this.size,
    this.ip,
  });

  /// 是否为上传操作
  bool get isUpload => method == 'POST' || method == 'PUT';

  /// 是否为下载操作
  bool get isDownload => method == 'GET';

  /// 是否为删除操作
  bool get isDelete => method == 'DELETE';

  /// 是否成功
  bool get isSuccess => status >= 200 && status < 300;

  /// 解析 dufs 日志行
  /// dufs 日志格式: "2026-03-26 12:00:00 | 200 | GET /path | 1234 | 192.168.1.100"
  /// 也可能是更简短的格式
  static TransferLog? parse(String line) {
    try {
      final parts = line.split('|').map((s) => s.trim()).toList();
      if (parts.length < 3) return null;

      // Parse timestamp
      final timeStr = parts[0];
      final time = DateTime.tryParse(timeStr);
      if (time == null) return null;

      // Parse status code
      final statusStr = parts[1];
      final status = int.tryParse(statusStr);
      if (status == null || status < 100 || status > 599) return null;

      // Parse method + path (e.g., "GET /file.txt" or "POST /upload")
      final methodPath = parts[2];
      final spaceIdx = methodPath.indexOf(' ');
      if (spaceIdx == -1) return null;
      final method = methodPath.substring(0, spaceIdx).toUpperCase();
      final path = methodPath.substring(spaceIdx + 1);

      // Optional: size
      int? size;
      if (parts.length > 3) {
        size = int.tryParse(parts[3]);
      }

      // Optional: IP
      String? ip;
      if (parts.length > 4) {
        ip = parts[4];
      }

      return TransferLog(
        time: time,
        method: method,
        path: path,
        status: status,
        size: size,
        ip: ip,
      );
    } catch (_) {
      return null;
    }
  }
}
