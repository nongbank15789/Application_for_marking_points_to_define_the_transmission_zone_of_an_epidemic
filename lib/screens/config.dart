// config.dart
class ApiConfig {
  // แก้ IP/Port ที่นี่จุดเดียว
  static String host = '10.0.2.2:80';   // หรือ '192.168.1.45:80'
  static String basePath = '/api';

  /// คืนค่า Uri พร้อม query (ใช้กับ http.get/post)
  static Uri u(String endpoint, [Map<String, dynamic>? query]) {
    return Uri.http(
      host,
      '$basePath/$endpoint',
      query?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
  }

  /// คืนค่า URL แบบ String (ใช้กับ NetworkImage ฯลฯ)
  static String url(String path) {
    return Uri.http(host, '$basePath/$path').toString();
  }
}
