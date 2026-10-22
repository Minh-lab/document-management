import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Lưu bytes ra thư mục tạm rồi mở bằng ứng dụng bên ngoài.
/// Trả về true nếu mở thành công.
Future<bool> openFileBytes(Uint8List bytes, String fileName) async {
  try {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.isEmpty ? 'document' : fileName;
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  } catch (_) {
    return false;
  }
}
