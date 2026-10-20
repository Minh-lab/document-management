import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseStorageService {
  static final SupabaseStorageService _instance = SupabaseStorageService._internal();
  factory SupabaseStorageService() => _instance;
  SupabaseStorageService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Cấu trúc: users/{userId}/documents/{docId}/{uniqueName}
  String _getDocumentPath(String userId, String docId, String fileName) {
    final extension = fileName.split('.').last;
    final uniqueName = '${_uuid.v4()}.$extension';
    return 'users/$userId/documents/$docId/$uniqueName';
  }

  // Upload file lên Supabase Storage
  Future<UploadResult> uploadDocument({
    required Uint8List bytes,
    required String userId,
    required String docId,
    required String fileName,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Validate input
      if (bytes.isEmpty) {
        return UploadResult(
          success: false,
          error: 'File rỗng (0 bytes)',
        );
      }

      if (userId.isEmpty) {
        return UploadResult(
          success: false,
          error: 'User ID rỗng - chưa đăng nhập',
        );
      }

      print('📤 Uploading file to Supabase: $fileName, size: ${bytes.length} bytes, userId: $userId');

      final storagePath = _getDocumentPath(userId, docId, fileName);

      // Upload bytes to Supabase Storage
      // bucket: 'documents' (cần tạo bucket này trong Supabase Dashboard)
      final uploadResult = await _client.storage
          .from('documents')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );

      print('✅ Upload completed: $storagePath');

      // Get public URL (hoặc signed URL nếu bucket private)
      final downloadUrl = _client.storage
          .from('documents')
          .getPublicUrl(storagePath);

      print('🔗 Download URL: $downloadUrl');

      return UploadResult(
        success: true,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        fileName: fileName,
      );
    } on StorageException catch (e) {
      print('❌ StorageException: ${e.message}');
      return UploadResult(
        success: false,
        error: _getStorageErrorMessage(e.message),
      );
    } catch (e) {
      print('❌ Unexpected error: $e');
      return UploadResult(
        success: false,
        error: 'Lỗi không xác định: $e',
      );
    }
  }

  // Xóa file khỏi Supabase Storage
  Future<DeleteResult> deleteDocument(String storagePath) async {
    try {
      await _client.storage
          .from('documents')
          .remove([storagePath]);

      return DeleteResult(success: true);
    } on StorageException catch (e) {
      return DeleteResult(
        success: false,
        error: _getStorageErrorMessage(e.message),
      );
    } catch (e) {
      return DeleteResult(
        success: false,
        error: 'Lỗi không xác định: $e',
      );
    }
  }

  // Lấy signed URL (cho bucket private)
  Future<String?> getSignedUrl(String storagePath, {int expiresIn = 3600}) async {
    try {
      final url = await _client.storage
          .from('documents')
          .createSignedUrl(storagePath, expiresIn);
      return url;
    } catch (e) {
      print('❌ Error getting signed URL: $e');
      return null;
    }
  }

  String _getStorageErrorMessage(String message) {
    if (message.contains('not found') || message.contains('404')) {
      return 'File không tồn tại trên storage';
    } else if (message.contains('permission') || message.contains('403')) {
      return 'Không có quyền truy cập file';
    } else if (message.contains('quota') || message.contains('413')) {
      return 'File quá lớn hoặc vượt quá quota';
    } else if (message.contains('unauthorized') || message.contains('401')) {
      return 'Chưa đăng nhập hoặc session hết hạn';
    } else {
      return 'Lỗi storage: $message';
    }
  }

  // Download file bytes from Supabase Storage
  Future<Uint8List?> getFileBytes(String storagePath) async {
    try {
      final bytes = await _client.storage
          .from('documents')
          .download(storagePath);
      return bytes;
    } catch (e) {
      print('❌ Error downloading file: $e');
      return null;
    }
  }

  // Upload raw bytes to a specific path
  Future<bool> uploadBytes(String storagePath, Uint8List bytes) async {
    try {
      await _client.storage
          .from('documents')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      return true;
    } catch (e) {
      print('❌ Error uploading bytes: $e');
      return false;
    }
  }
}

class UploadResult {
  final bool success;
  final String? downloadUrl;
  final String? storagePath;
  final String? fileName;
  final String? error;

  UploadResult({
    required this.success,
    this.downloadUrl,
    this.storagePath,
    this.fileName,
    this.error,
  });
}

class DeleteResult {
  final bool success;
  final String? error;

  DeleteResult({required this.success, this.error});
}