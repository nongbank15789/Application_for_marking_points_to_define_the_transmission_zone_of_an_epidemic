// config.dart
class ApiConfig {
  //static String host = '10.40.83.88';
  static String host = '10.0.2.2';
  static int port = 80; // เพิ่ม port ที่นี่ (เช่น 80 หรือ 8080)
  static String basePath = '/api';

  static Uri u(String endpoint, [Map<String, dynamic>? query]) {
    return Uri.http(
      '$host:$port', // ✅ ต้องรวม host:port
      '$basePath/$endpoint',
      query?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
  }

  static String url(String path) {
    return Uri.http('$host:$port', '$basePath/$path').toString();
  }
}