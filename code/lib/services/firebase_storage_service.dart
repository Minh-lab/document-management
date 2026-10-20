import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance = FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Cấu trúc: /users/{userId}/documents/{docId}/{filename}
  String _getDocumentPath(String userId, String docId, String fileName) {
    final extension = fileName.split('.').last;
    final uniqueName = '${_uuid.v4()}.$extension';
    return 'users/$userId/documents/$docId/$uniqueName';
  }

  // Upload file lên Firebase Storage
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
      
      // Debug logging
      print('📤 Uploading file: $fileName, size: ${bytes.length} bytes, userId: $userId');
      
      final storagePath = _getDocumentPath(userId, docId, fileName);
      final ref = _storage.ref().child(storagePath);
      
      // Upload bytes trực tiếp với metadata
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'userId': userId,
          'docId': docId,
          'originalName': fileName,
        },
      );
      
      final uploadTask = ref.putData(bytes, metadata);
      
      // Lắng nghe tiến trình upload
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
        print('📤 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Verify upload completed successfully
      print('✅ Upload completed, state: ${snapshot.state}, totalBytes: ${snapshot.totalBytes}');
      
      if (snapshot.state != TaskState.success) {
        return UploadResult(
          success: false,
          error: 'Upload không thành công: state=${snapshot.state}',
        );
      }
      
      if (snapshot.totalBytes != bytes.length) {
        return UploadResult(
          success: false,
          error: 'Kích thước file không khớp: expected=${bytes.length}, got=${snapshot.totalBytes}',
        );
      }
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 Download URL: $downloadUrl');
      
      return UploadResult(
        success: true,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        fileName: fileName,
      );
    } on FirebaseException catch (e) {
      print('❌ FirebaseException: ${e.code} - ${e.message}');
      return UploadResult(
        success: false,
        error: _getErrorMessage(e.code),
      );
    } catch (e) {
      print('❌ Unexpected error: $e');
      return UploadResult(
        success: false,
        error: 'Lỗi không xác định: $e',
      );
    }
  }

  // Xóa file khỏi Firebase Storage
  Future<DeleteResult> deleteDocument(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.delete();
      return DeleteResult(success: true);
    } on FirebaseException catch (e) {
      return DeleteResult(
        success: false,
        error: _getErrorMessage(e.code),
      );
    } catch (e) {
      return DeleteResult(
        success: false,
        error: 'Lỗi không xác định: $e',
      );
    }
  }

  // Lấy URL download của file
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // Lấy metadata của file
  Future<Map<String, dynamic>?> getFileMetadata(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      final metadata = await ref.getMetadata();
      return {
        'size': metadata.size,
        'contentType': metadata.contentType,
        'createdAt': metadata.timeCreated,
        'updatedAt': metadata.updated,
      };
    } catch (e) {
      return null;
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'object-not-found':
        return 'File không tồn tại';
      case 'unauthorized':
        return 'Không có quyền truy cập';
      case 'quota-exceeded':
        return 'Vượt quá giới hạn lưu trữ';
      case 'retry-limit-exceeded':
        return 'Quá nhiều lần thử, vui lòng thử lại sau';
      default:
        return 'Lỗi Firebase Storage: $code';
    }
  }

  // Public method to get reference for file operations
  Reference getReference(String path) {
    return _storage.ref().child(path);
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