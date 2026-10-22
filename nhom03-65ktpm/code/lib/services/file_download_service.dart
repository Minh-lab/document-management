import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Tải nội dung tệp từ URL (thường là signed URL của Supabase Storage)
/// về bộ nhớ để hiển thị trong app hoặc lưu tạm.
class FileDownloadService {
  static final FileDownloadService _instance =
      FileDownloadService._internal();
  factory FileDownloadService() => _instance;
  FileDownloadService._internal();

  Future<Uint8List> download(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Không tải được tệp (HTTP ${response.statusCode})');
      }

      final total = response.contentLength ?? 0;
      final chunks = <int>[];
      var received = 0;

      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }

      if (chunks.isEmpty) {
        throw Exception('Tệp rỗng hoặc không có nội dung');
      }

      return Uint8List.fromList(chunks);
    } finally {
      client.close();
    }
  }
}
