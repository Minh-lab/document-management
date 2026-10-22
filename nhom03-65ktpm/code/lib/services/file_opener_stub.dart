import 'dart:typed_data';

/// Trên nền tảng web không thể mở tệp cục bộ; trả về false để
/// trang xem chuyển sang mở URL trực tiếp bằng trình duyệt.
Future<bool> openFileBytes(Uint8List bytes, String fileName) async {
  return false;
}
