import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/supabase_service.dart';
import 'services/supabase_storage_service.dart';
import 'struct/category_model.dart';
import 'struct/document_model.dart';
import 'struct/user_model.dart';
import 'struct/permission_model.dart';
import 'struct/notification_model.dart';
import 'struct/recommendation_model.dart';
import 'struct/document_location_model.dart';
import 'utils/recommendation_scorer.dart';

export 'struct/category_model.dart';
export 'struct/document_model.dart';
export 'struct/user_model.dart';
export 'struct/permission_model.dart';
export 'struct/notification_model.dart';
export 'struct/document_location_model.dart';

final supabaseService = SupabaseService();
final storageService = SupabaseStorageService();
final googleSignIn = GoogleSignIn();

/// Khởi tạo phiên làm việc sau khi người dùng đã đăng nhập.
/// Không tự đăng nhập ẩn danh để màn hình đăng nhập luôn hiển thị khi chưa có phiên.
Future<void> initializeServices() async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await _syncFirebaseUserToSupabase(user);
  await supabaseService.seedDefaultCategories();
}

/// Đồng bộ lại phiên Supabase từ Firebase (dùng sau khi đăng nhập/đăng ký).
Future<void> syncSessionWithSupabase() async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('Chưa có người dùng đăng nhập');
  }
  await _syncFirebaseUserToSupabase(user);
}

/// Sync Firebase user với Supabase Auth (gọi Edge Function để verify Firebase token và tạo Supabase JWT)
Future<void> _syncFirebaseUserToSupabase(
  firebase_auth.User firebaseUser,
) async {
  try {
    print('🔄 Starting sync of Firebase user: ${firebaseUser.uid}');

    // Lấy Firebase ID token
    final idToken = await firebaseUser.getIdToken(true);
    print('🔑 Got Firebase ID token for user: ${firebaseUser.uid}');

    // Gọi Supabase Edge Function để verify Firebase token và lấy Supabase JWT
    final response = await http.post(
      Uri.parse(
        'https://lwebnjcszbldlqwjrcan.supabase.co/functions/v1/verify-firebase-token',
      ),
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

/// Đăng nhập bằng Email/Mật khẩu
Future<firebase_auth.UserCredential> signInWithEmail({
  required String email,
  required String password,
}) async {
  final credential = await firebase_auth.FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email.trim(), password: password);

  if (credential.user != null) {
    await _syncFirebaseUserToSupabase(credential.user!);
  }
  return credential;
}

/// Đăng ký tài khoản mới bằng Email/Mật khẩu
Future<firebase_auth.UserCredential> registerWithEmail({
  required String email,
  required String password,
  String? displayName,
}) async {
  final credential = await firebase_auth.FirebaseAuth.instance
      .createUserWithEmailAndPassword(email: email.trim(), password: password);

  final user = credential.user;
  if (user != null) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    }
    await _syncFirebaseUserToSupabase(user);
  }
  return credential;
}

/// Đăng nhập ẩn danh để dùng thử
Future<void> signInAsGuest() async {
  final credential = await firebase_auth.FirebaseAuth.instance
      .signInAnonymously();
  if (credential.user != null) {
    await _syncFirebaseUserToSupabase(credential.user!);
  }
}

/// Đăng nhập bằng Google
Future<firebase_auth.UserCredential?> signInWithGoogle() async {
  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  if (googleUser == null) return null; // Người dùng hủy

  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

  final credential = firebase_auth.GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  final userCredential = await firebase_auth.FirebaseAuth.instance
      .signInWithCredential(credential);

  // Sync Google user với Supabase
  if (userCredential.user != null) {
    await _syncFirebaseUserToSupabase(userCredential.user!);
  }

  return userCredential;
}

/// Chuyển lỗi Firebase thành thông báo tiếng Việt dễ hiểu.
String friendlyAuthError(Object error) {
  if (error is firebase_auth.FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng dùng ít nhất 6 ký tự.';
      case 'missing-password':
        return 'Vui lòng nhập mật khẩu.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được bật trong Firebase.';
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.';
      case 'too-many-requests':
        return 'Bạn đã thử quá nhiều lần. Vui lòng đợi một lát rồi thử lại.';
      default:
        return error.message ?? 'Đăng nhập thất bại. Vui lòng thử lại.';
    }
  }

  final raw = error.toString();
  return raw.replaceFirst('Exception: ', '');
}

/// Đăng xuất
Future<void> signOut() async {
  await googleSignIn.signOut();
  await firebase_auth.FirebaseAuth.instance.signOut();
  await Supabase.instance.client.auth.signOut();
}

/// Người dùng Firebase hiện tại
firebase_auth.User? get currentFirebaseUser =>
    firebase_auth.FirebaseAuth.instance.currentUser;

/// Lấy user ID hiện tại
String get currentUserId => currentFirebaseUser?.uid ?? '';

/// Lấy stream user auth state
Stream<firebase_auth.User?> get authStateChanges =>
    firebase_auth.FirebaseAuth.instance.authStateChanges();

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
  // Kiểm tra quyền chỉnh sửa trước khi cho phép cập nhật
  if (currentUserId.isEmpty) {
    throw Exception('Bạn cần đăng nhập để chỉnh sửa tài liệu');
  }
  final permission = await supabaseService.getUserPermission(id, currentUserId);
  if (permission != PermissionRole.owner &&
      permission != PermissionRole.editor) {
    throw Exception('Bạn không có quyền chỉnh sửa tài liệu này');
  }

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

/// Cập nhật thông tin tài khoản hiện tại (tên hiển thị, ảnh đại diện).
/// Firebase Auth là nguồn chính; Supabase được đồng bộ lại nếu có thể.
Future<firebase_auth.User> updateAccountProfile({
  required String displayName,
  String? photoURL,
}) async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Chưa có người dùng đăng nhập');

  final name = displayName.trim();
  if (name.isEmpty) throw Exception('Tên hiển thị không được để trống');

  await user.updateDisplayName(name);

  // photoURL = null nghĩa là giữ nguyên ảnh hiện tại;
  // chuỗi rỗng nghĩa là xóa ảnh đại diện.
  if (photoURL != null) {
    final avatar = photoURL.trim();
    await user.updatePhotoURL(avatar.isEmpty ? null : avatar);
  }

  await user.reload();

  try {
    await syncCurrentUser(displayName: name);
  } catch (error) {
    // Không chặn cập nhật Firebase nếu Supabase tạm thời không đồng bộ được.
    debugPrint('⚠️ Không đồng bộ được hồ sơ lên Supabase: $error');
  }

  return user;
}

// ==================== PERMISSIONS (SHARING) ====================

/// Chia sẻ tài liệu cho user khác
Future<PermissionModel> shareDocument({
  required int documentId,
  required String userId,
  required PermissionRole role,
}) async {
  final permission = await supabaseService.shareDocument(
    documentId: documentId,
    userId: userId,
    role: role,
    grantedBy: currentUserId,
  );

  // Gửi thông báo trong ứng dụng cho người được chia sẻ.
  try {
    final document = await getDocumentById(documentId);
    final actor = await getCurrentUserProfile();
    final actorName =
        actor?.displayNameOrEmail ??
        currentFirebaseUser?.displayName ??
        'Một người dùng';
    await createNotification(
      userId: userId,
      title: 'Tài liệu được chia sẻ',
      body:
          '$actorName đã chia sẻ "${document?.title ?? 'một tài liệu'}" với bạn.',
      type: 'share',
      documentId: documentId,
    );
  } catch (error) {
    debugPrint('⚠️ Không tạo được thông báo chia sẻ: $error');
  }

  return permission;
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

// ==================== NOTIFICATIONS ====================

/// Lấy thông báo của người dùng hiện tại.
Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
  if (currentUserId.isEmpty) return [];
  return supabaseService.getNotifications(userId: currentUserId, limit: limit);
}

/// Đếm thông báo chưa đọc của người dùng hiện tại.
Future<int> getUnreadNotificationCount() async {
  if (currentUserId.isEmpty) return 0;
  return supabaseService.getUnreadNotificationCount(userId: currentUserId);
}

/// Đánh dấu một thông báo đã đọc.
Future<void> markNotificationRead(int id) async {
  await supabaseService.markNotificationRead(id);
}

/// Đánh dấu tất cả thông báo của người dùng hiện tại đã đọc.
Future<void> markAllNotificationsRead() async {
  if (currentUserId.isEmpty) return;
  await supabaseService.markAllNotificationsRead(currentUserId);
}

/// Tạo thông báo mới cho một người dùng.
Future<void> createNotification({
  required String userId,
  required String title,
  String? body,
  String type = 'system',
  int? documentId,
}) async {
  await supabaseService.createNotification(
    userId: userId,
    title: title,
    body: body,
    type: type,
    documentId: documentId,
  );
}

// ==================== RECOMMENDATION (UC-11) ====================

/// Gợi ý tối đa [limit] tài liệu cho người dùng hiện tại, kèm lý do.
Future<List<RecommendationModel>> getRecommendations({int limit = 5}) async {
  if (currentUserId.isEmpty) return [];
  final results = await Future.wait([
    supabaseService.getUserInterests(currentUserId),
    supabaseService.getRecommendationCandidates(currentUserId),
  ]);
  return rankRecommendations(
    interests: results[0] as Map<String, double>,
    candidates: results[1] as List<RecommendationCandidate>,
    limit: limit,
  );
}

/// Ghi nhận người dùng mở tài liệu: lưu lượt xem và tăng sở thích theo tag.
/// Lỗi (ví dụ chưa chạy SQL) không được làm hỏng màn hình chi tiết.
Future<void> recordDocumentView(int documentId) async {
  if (currentUserId.isEmpty) return;
  try {
    await supabaseService.recordDocumentView(
      userId: currentUserId,
      documentId: documentId,
    );
  } catch (error) {
    debugPrint('⚠️ Không ghi được lượt xem: $error');
  }
}

/// Gọi sau khi người dùng gán tag cho tài liệu (UC-06) để tăng sở thích.
Future<void> recordTagging(List<int> tagIds) async {
  if (currentUserId.isEmpty) return;
  try {
    await supabaseService.bumpTagInterests(
      userId: currentUserId,
      tagIds: tagIds,
    );
  } catch (error) {
    debugPrint('⚠️ Không cập nhật được sở thích: $error');
  }
}

// ==================== DOCUMENT LOCATIONS ====================

/// Lấy vị trí vật lý của tài liệu.
Future<DocumentLocationModel?> getDocumentLocation(int documentId) async {
  return supabaseService.getDocumentLocation(documentId);
}

/// Lưu (upsert) vị trí vật lý của tài liệu.
Future<DocumentLocationModel?> upsertDocumentLocation({
  required int documentId,
  double? latitude,
  double? longitude,
  String? placeName,
  String? shelf,
  String? note,
}) async {
  return supabaseService.upsertDocumentLocation(
    documentId: documentId,
    latitude: latitude,
    longitude: longitude,
    placeName: placeName,
    shelf: shelf,
    note: note,
  );
}

/// Xóa vị trí vật lý của tài liệu.
Future<void> deleteDocumentLocation(int documentId) async {
  await supabaseService.deleteDocumentLocation(documentId);
}
