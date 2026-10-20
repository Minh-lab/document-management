import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_storage_service.dart';
import 'struct/category_model.dart';
import 'struct/document_model.dart';
import 'struct/user_model.dart';
import 'struct/permission_model.dart';

final supabaseService = SupabaseService();
final storageService = SupabaseStorageService();
final googleSignIn = GoogleSignIn();

/// Khởi tạo Supabase và Firebase
Future<void> initializeServices() async {
  // Supabase đã được initialize ở main.dart
  // Chỉ cần ensure user signed in và seed categories
  
  // Đảm bảo user đã đăng nhập và sync với Supabase
  await _ensureUserSignedInAndSyncSupabase();
  
  // Seed default categories
  await supabaseService.seedDefaultCategories();
}

/// Đảm bảo user đã đăng nhập Firebase và sync session với Supabase
Future<firebase_auth.User> _ensureUserSignedInAndSyncSupabase() async {
  final auth = firebase_auth.FirebaseAuth.instance;
  
  // Đảm bảo Firebase user đã đăng nhập
  if (auth.currentUser == null) {
    final credential = await auth.signInAnonymously();
    // Sync với Supabase
    await _syncFirebaseUserToSupabase(credential.user!);
    return credential.user!;
  }
  
  // Sync user hiện tại với Supabase
  await _syncFirebaseUserToSupabase(auth.currentUser!);
  return auth.currentUser!;
}

/// Sync Firebase user với Supabase Auth (gọi Edge Function để verify Firebase token và tạo Supabase JWT)
Future<void> _syncFirebaseUserToSupabase(firebase_auth.User firebaseUser) async {
  try {
    print('🔄 Starting sync of Firebase user: ${firebaseUser.uid}');
    
    // Lấy Firebase ID token
    final idToken = await firebaseUser.getIdToken(true);
    print('🔑 Got Firebase ID token for user: ${firebaseUser.uid}');
    
    // Gọi Supabase Edge Function để verify Firebase token và lấy Supabase JWT
    final response = await http.post(
      Uri.parse('https://lwebnjcszbldlqwjrcan.supabase.co/functions/v1/verify-firebase-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );
    
    print('📡 Edge Function response status: ${response.statusCode}');
    print('📡 Edge Function response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('📦 Parsed response data: $data');
      final supabaseToken = data['token'] as String?;
      
      if (supabaseToken != null) {
        // Set Supabase session với token từ Edge Function
        await Supabase.instance.client.auth.setSession(supabaseToken);
        print('✅ Synced Firebase user to Supabase: ${firebaseUser.uid}');
        print('🔐 Supabase session set successfully');
      } else {
        print('⚠️ No token in response data');
      }
    } else {
      print('⚠️ Edge Function failed with status: ${response.statusCode}');
    }
  } catch (e, stackTrace) {
    print('❌ Exception during sync Firebase user to Supabase: $e');
    print('📍 Stack trace: $stackTrace');
  }
}

/// Đăng nhập bằng Google
Future<firebase_auth.UserCredential?> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    
    final credential = firebase_auth.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
    
    // Sync Google user với Supabase
    if (userCredential.user != null) {
      await _syncFirebaseUserToSupabase(userCredential.user!);
    }
    
    return userCredential;
  } catch (e) {
    print('Google Sign-In error: $e');
    return null;
  }
}

/// Đăng xuất
Future<void> signOut() async {
  await googleSignIn.signOut();
  await firebase_auth.FirebaseAuth.instance.signOut();
  await Supabase.instance.client.auth.signOut();
}

/// Lấy user ID hiện tại
String get currentUserId => firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';

/// Lấy stream user auth state
Stream<firebase_auth.User?> get authStateChanges => firebase_auth.FirebaseAuth.instance.authStateChanges();

// ==================== CATEGORIES ====================

Future<List<CategoryModel>> getCategories() async {
  return await supabaseService.getCategories();
}

// ==================== DOCUMENTS ====================

Future<List<DocumentModel>> getDocuments({
  String? keyword,
  int? categoryId,
}) async {
  return await supabaseService.getDocuments(
    keyword: keyword,
    categoryId: categoryId,
    userId: currentUserId,
  );
}

Future<DocumentModel?> getDocumentById(int id) async {
  return await supabaseService.getDocumentById(id);
}

/// Thêm tài liệu mới (với upload file lên Firebase Storage nếu có)
Future<DocumentModel> addDocument({
  required String title,
  String? description,
  PlatformFile? file,
  required int categoryId,
}) async {
  String? filePath;
  String? fileUrl;
  String? storagePath;
  
  // Upload file lên Firebase Storage nếu có
  if (file != null) {
    // Lấy bytes từ PlatformFile (hỗ trợ Android content:// URI)
    final bytes = await file.readAsBytes();
    
    final uploadResult = await storageService.uploadDocument(
      bytes: bytes,
      userId: currentUserId,
      docId: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
      fileName: file.name,
      onProgress: (progress) {
        // Progress will be handled by UI via stream or callback
      },
    );
    
    if (uploadResult.success) {
      fileUrl = uploadResult.downloadUrl;
      storagePath = uploadResult.storagePath;
    } else {
      throw Exception('Upload file thất bại: ${uploadResult.error}');
    }
  }
  
  // Lưu metadata vào Supabase (sẽ trả về document với ID thật)
  final document = await supabaseService.addDocument(
    title: title,
    description: description,
    filePath: filePath,
    fileUrl: fileUrl,
    storagePath: storagePath,
    categoryId: categoryId,
    userId: currentUserId,
  );
  
  // Nếu có file, cần update storage path với docId thật
  if (file != null && storagePath != null) {
    final newStoragePath = storagePath.replaceFirst(
      RegExp(r'temp_\d+'),
      document.id.toString(),
    );
    
    // Di chuyển file trong Firebase Storage (copy + delete)
    await _moveFileInStorage(storagePath, newStoragePath);
    
    // Update document với storage path mới
    return await supabaseService.updateDocument(
      id: document.id,
      title: title,
      description: description,
      filePath: filePath,
      fileUrl: fileUrl,
      storagePath: newStoragePath,
      categoryId: categoryId,
    );
  }
  
  return document;
}

/// Cập nhật tài liệu (có thể thay đổi file)
Future<DocumentModel> updateDocument({
  required int id,
  required String title,
  String? description,
  PlatformFile? file,
  required int categoryId,
  String? existingFileUrl,
  String? existingStoragePath,
}) async {
  String? filePath;
  String? fileUrl = existingFileUrl;
  String? storagePath = existingStoragePath;
  
  // Nếu có file mới, upload lên Firebase Storage
  if (file != null) {
    // Xóa file cũ nếu có
    if (existingStoragePath != null) {
      await storageService.deleteDocument(existingStoragePath);
    }
    
    // Lấy bytes từ PlatformFile
    final bytes = await file.readAsBytes();
    
    final uploadResult = await storageService.uploadDocument(
      bytes: bytes,
      userId: currentUserId,
      docId: id.toString(),
      fileName: file.name,
    );
    
    if (uploadResult.success) {
      fileUrl = uploadResult.downloadUrl;
      storagePath = uploadResult.storagePath;
    } else {
      throw Exception('Upload file thất bại: ${uploadResult.error}');
    }
  }
  
  return await supabaseService.updateDocument(
    id: id,
    title: title,
    description: description,
    filePath: filePath,
    fileUrl: fileUrl,
    storagePath: storagePath,
    categoryId: categoryId,
  );
}

/// Xóa tài liệu (kèm xóa file trên Firebase Storage)
Future<void> deleteDocument(int id, {String? storagePath}) async {
  if (storagePath != null) {
    await storageService.deleteDocument(storagePath);
  }
  await supabaseService.deleteDocument(id);
}

// ==================== REALTIME ====================

Stream<List<DocumentModel>> getDocumentsStream() {
  // Sử dụng realtime subscription
  // Implementation sẽ ở UI level
  throw UnimplementedError('Use SupabaseService.subscribeToDocuments directly');
}

// Helper: Di chuyển file trong Supabase Storage (copy + delete)
Future<void> _moveFileInStorage(String oldPath, String newPath) async {
  try {
    // Download from old path
    final bytes = await storageService.getFileBytes(oldPath);
    
    if (bytes == null) {
      throw Exception('Failed to download file from $oldPath');
    }
    
    // Upload to new path
    await storageService.uploadBytes(newPath, bytes);
    
    // Delete old file
    await storageService.deleteDocument(oldPath);
  } catch (e) {
    print('Error moving file: $e');
  }
}

// ==================== USERS ====================

/// Sync user profile từ Firebase Auth
Future<UserModel> syncCurrentUser({
  String? displayName,
  String? photoURL,
}) async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not authenticated');
  
  return await supabaseService.upsertUser(
    id: user.uid,
    email: user.email,
    displayName: displayName ?? user.displayName,
    avatarUrl: photoURL ?? user.photoURL,
  );
}

/// Tìm kiếm user để chia sẻ
Future<List<UserModel>> searchUsers(String query) async {
  return await supabaseService.searchUsers(
    query: query,
    excludeUserId: currentUserId,
  );
}

/// Lấy thông tin user hiện tại từ Supabase
Future<UserModel?> getCurrentUserProfile() async {
  return await supabaseService.getUserById(currentUserId);
}

// ==================== PERMISSIONS (SHARING) ====================

/// Chia sẻ tài liệu cho user khác
Future<PermissionModel> shareDocument({
  required int documentId,
  required String userId,
  required PermissionRole role,
}) async {
  return await supabaseService.shareDocument(
    documentId: documentId,
    userId: userId,
    role: role,
    grantedBy: currentUserId,
  );
}

/// Xóa quyền chia sẻ
Future<void> removeShare(int documentId, String userId) async {
  await supabaseService.removePermission(documentId, userId);
}

/// Cập nhật quyền chia sẻ
Future<PermissionModel> updateShare({
  required int documentId,
  required String userId,
  required PermissionRole role,
}) async {
  return await supabaseService.updatePermission(
    documentId: documentId,
    userId: userId,
    role: role,
  );
}

/// Lấy danh sách người được chia sẻ tài liệu
Future<List<PermissionModel>> getDocumentShares(int documentId) async {
  return await supabaseService.getDocumentPermissions(documentId);
}

/// Lấy tài liệu được chia sẻ cho user hiện tại
Future<List<DocumentModel>> getSharedWithMe() async {
  return await supabaseService.getSharedDocuments(currentUserId);
}