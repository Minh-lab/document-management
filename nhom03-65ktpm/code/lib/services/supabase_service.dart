import 'package:supabase_flutter/supabase_flutter.dart';

import '../struct/category_model.dart';
import '../struct/document_model.dart';
import '../struct/user_model.dart';
import '../struct/permission_model.dart';
import '../struct/notification_model.dart';
import '../struct/recommendation_model.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ==================== CATEGORIES ====================

  Future<List<CategoryModel>> getCategories() async {
    final response = await _client
        .from(SupabaseConfig.categoriesTable)
        .select()
        .order('name');

    return (response as List)
        .map(
          (json) => CategoryModel(
            id: json['id'] as int,
            name: json['name'] as String,
          ),
        )
        .toList();
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    final response = await _client
        .from(SupabaseConfig.categoriesTable)
        .select()
        .filter('id', 'eq', id)
        .maybeSingle();

    if (response == null) return null;
    return CategoryModel(
      id: response['id'] as int,
      name: response['name'] as String,
    );
  }

  Future<void> seedDefaultCategories() async {
    final existing = await _client
        .from(SupabaseConfig.categoriesTable)
        .select('id')
        .limit(1);

    if (existing.isEmpty) {
      await _client.from(SupabaseConfig.categoriesTable).insert([
        {'name': 'Bài giảng'},
        {'name': 'Bài tập'},
        {'name': 'Tham khảo'},
      ]);
    }
  }

  // ==================== DOCUMENTS ====================

  Future<List<DocumentModel>> getDocuments({
    String? keyword,
    int? categoryId,
    String? userId,
  }) async {
    // Fetch documents first (without embedded join to allow filters)
    // Apply filters FIRST, then order
    // Use dynamic to avoid type issues with filter/order chain
    dynamic query = _client.from(SupabaseConfig.documentsTable).select();

    if (keyword != null && keyword.isNotEmpty) {
      query = query.filter('title', 'ilike', '%$keyword%');
    }
    if (categoryId != null) {
      query = query.filter('category_id', 'eq', categoryId);
    }
    if (userId != null) {
      query = query.filter('user_id', 'eq', userId);
    }

    // Apply order AFTER filters
    query = query.order('created_at', ascending: false);

    final docsResponse = await query;
    final docs = docsResponse as List;

    if (docs.isEmpty) return [];

    // Fetch categories separately
    final categoryIds = docs.map((d) => d['category_id'] as int).toSet();
    final categoriesResponse = await _client
        .from(SupabaseConfig.categoriesTable)
        .select()
        .filter('id', 'in', categoryIds.toList());

    final categoriesMap = {
      for (var c in categoriesResponse as List)
        c['id'] as int: c['name'] as String,
    };

    return docs.map((json) {
      final categoryId = json['category_id'] as int;
      return DocumentModel(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        filePath: json['file_path'] as String?,
        fileUrl: json['file_url'] as String?,
        storagePath: json['storage_path'] as String?,
        categoryName: categoriesMap[categoryId] ?? '',
        categoryId: categoryId,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
    }).toList();
  }

  Future<DocumentModel?> getDocumentById(int id) async {
    final response = await _client
        .from(SupabaseConfig.documentsTable)
        .select()
        .filter('id', 'eq', id)
        .maybeSingle();

    if (response == null) return null;

    // Fetch category name
    final categoryResponse = await _client
        .from(SupabaseConfig.categoriesTable)
        .select()
        .filter('id', 'eq', response['category_id'] as int)
        .maybeSingle();

    return DocumentModel(
      id: response['id'] as int,
      title: response['title'] as String,
      description: response['description'] as String?,
      filePath: response['file_path'] as String?,
      fileUrl: response['file_url'] as String?,
      storagePath: response['storage_path'] as String?,
      categoryName: categoryResponse?['name'] as String? ?? '',
      categoryId: response['category_id'] as int,
      createdAt: DateTime.parse(response['created_at'] as String),
      updatedAt: DateTime.parse(response['updated_at'] as String),
    );
  }

  Future<DocumentModel> addDocument({
    required String title,
    String? description,
    String? filePath,
    String? fileUrl,
    String? storagePath,
    required int categoryId,
    required String userId,
  }) async {
    final now = DateTime.now().toIso8601String();

    final docResponse = await _client
        .from(SupabaseConfig.documentsTable)
        .insert({
          'title': title,
          'description': description,
          'file_path': filePath,
          'file_url': fileUrl,
          'storage_path': storagePath,
          'category_id': categoryId,
          'user_id': userId,
          'created_at': now,
          'updated_at': now,
        })
        .select()
        .single();

    // Tự động tạo quyền owner cho người tạo tài liệu
    await _client.from(SupabaseConfig.permissionsTable).insert({
      'document_id': docResponse['id'] as int,
      'user_id': userId,
      'role': 'owner',
      'granted_by': userId,
    });

    final category = docResponse['categories'] as Map<String, dynamic>;
    return DocumentModel(
      id: docResponse['id'] as int,
      title: docResponse['title'] as String,
      description: docResponse['description'] as String?,
      filePath: docResponse['file_path'] as String?,
      fileUrl: docResponse['file_url'] as String?,
      storagePath: docResponse['storage_path'] as String?,
      categoryName: category['name'] as String,
      categoryId: docResponse['category_id'] as int,
      createdAt: DateTime.parse(docResponse['created_at'] as String),
      updatedAt: DateTime.parse(docResponse['updated_at'] as String),
    );
  }

  Future<DocumentModel> updateDocument({
    required int id,
    required String title,
    String? description,
    String? filePath,
    String? fileUrl,
    String? storagePath,
    required int categoryId,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _client
        .from(SupabaseConfig.documentsTable)
        .update({
          'title': title,
          'description': description,
          'file_path': filePath,
          'file_url': fileUrl,
          'storage_path': storagePath,
          'category_id': categoryId,
          'updated_at': now,
        })
        .filter('id', 'eq', id);

    // Fetch updated document with category
    return await getDocumentById(id) ??
        (throw Exception('Document not found after update'));
  }

  Future<void> deleteDocument(int id) async {
    await _client
        .from(SupabaseConfig.documentsTable)
        .delete()
        .filter('id', 'eq', id);
  }

  // ==================== REALTIME SUBSCRIPTIONS ====================

  RealtimeChannel subscribeToDocuments({
    required Function(List<DocumentModel>) onDocumentsChanged,
    String? userId,
  }) {
    var channel = _client
        .channel('documents_changes_${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.documentsTable,
          filter: userId != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: userId,
                )
              : null,
          callback: (payload) async {
            final docs = await getDocuments(userId: userId);
            onDocumentsChanged(docs);
          },
        )
        .subscribe();

    return channel;
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  // ==================== NOTIFICATIONS ====================

  /// Lấy danh sách thông báo của một người dùng, mới nhất trước.
  Future<List<NotificationModel>> getNotifications({
    required String userId,
    int limit = 50,
  }) async {
    final response = await _client
        .from(SupabaseConfig.notificationsTable)
        .select()
        .filter('user_id', 'eq', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Đếm số thông báo chưa đọc để hiển thị badge.
  Future<int> getUnreadNotificationCount({required String userId}) async {
    final response = await _client
        .from(SupabaseConfig.notificationsTable)
        .select('id')
        .filter('user_id', 'eq', userId)
        .filter('is_read', 'eq', false);

    return (response as List).length;
  }

  /// Đánh dấu một thông báo đã đọc.
  Future<void> markNotificationRead(int id) async {
    await _client
        .from(SupabaseConfig.notificationsTable)
        .update({'is_read': true})
        .eq('id', id);
  }

  /// Đánh dấu toàn bộ thông báo của người dùng đã đọc.
  Future<void> markAllNotificationsRead(String userId) async {
    await _client
        .from(SupabaseConfig.notificationsTable)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Tạo thông báo mới cho một người dùng.
  Future<void> createNotification({
    required String userId,
    required String title,
    String? body,
    String type = 'system',
    int? documentId,
  }) async {
    await _client.from(SupabaseConfig.notificationsTable).insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'document_id': documentId,
    });
  }

  /// Lắng nghe thông báo mới theo thời gian thực.
  RealtimeChannel subscribeToNotifications({
    required String userId,
    required Function() onChanged,
  }) {
    return _client
        .channel(
          'notifications_changes_${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.notificationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  // ==================== RECOMMENDATION (UC-11) ====================

  /// Tài liệu ứng viên: của người khác, chưa xem trong 7 ngày (hàm SQL recommendation_candidates).
  Future<List<RecommendationCandidate>> getRecommendationCandidates(
    String userId,
  ) async {
    final response = await _client.rpc(
      'recommendation_candidates',
      params: {'p_user_id': userId},
    );
    return (response as List)
        .map(
          (json) =>
              RecommendationCandidate.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  /// Sở thích của người dùng: tên tag -> trọng số.
  Future<Map<String, double>> getUserInterests(String userId) async {
    final response = await _client.rpc(
      'user_interest_weights',
      params: {'p_user_id': userId},
    );
    return {
      for (final row in response as List)
        row['tag_name'] as String: (row['weight'] as num).toDouble(),
    };
  }

  /// Ghi một lượt xem và tăng trọng số các tag của tài liệu (+1).
  Future<void> recordDocumentView({
    required String userId,
    required int documentId,
  }) async {
    await _client.rpc(
      'record_document_view',
      params: {'p_user_id': userId, 'p_document_id': documentId},
    );
  }

  /// Tăng trọng số sở thích khi người dùng gán tag cho tài liệu.
  Future<void> bumpTagInterests({
    required String userId,
    required List<int> tagIds,
    double amount = 2,
  }) async {
    if (tagIds.isEmpty) return;
    await _client.rpc(
      'bump_tag_interests',
      params: {'p_user_id': userId, 'p_tag_ids': tagIds, 'p_amount': amount},
    );
  }

  // ==================== USERS ====================

  /// Tạo hoặc cập nhật user profile (sync từ Firebase Auth)
  Future<UserModel> upsertUser({
    required String id,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) async {
    final now = DateTime.now().toIso8601String();

    final response = await _client
        .from(SupabaseConfig.usersTable)
        .upsert({
          'id': id,
          'email': email,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'updated_at': now,
        }, onConflict: 'id')
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  /// Lấy user theo ID
  Future<UserModel?> getUserById(String id) async {
    final response = await _client
        .from(SupabaseConfig.usersTable)
        .select()
        .filter('id', 'eq', id)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Tìm kiếm user theo email hoặc tên
  Future<List<UserModel>> searchUsers({
    required String query,
    String? excludeUserId,
  }) async {
    // Apply filters first, then or
    // Use dynamic to avoid type issues with filter/or chain
    dynamic queryBuilder = _client.from(SupabaseConfig.usersTable).select();

    if (excludeUserId != null) {
      queryBuilder = queryBuilder.filter('id', 'neq', excludeUserId);
    }

    // Apply or filter
    queryBuilder = queryBuilder
        .or('email.ilike.%$query%,display_name.ilike.%$query%')
        .limit(20);

    final response = await queryBuilder;
    return (response as List).map((json) => UserModel.fromJson(json)).toList();
  }

  /// Lấy danh sách user (có phân trang)
  Future<List<UserModel>> getUsers({int limit = 50, int offset = 0}) async {
    final response = await _client
        .from(SupabaseConfig.usersTable)
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => UserModel.fromJson(json)).toList();
  }

  // ==================== PERMISSIONS ====================

  /// Chia sẻ tài liệu cho user khác
  Future<PermissionModel> shareDocument({
    required int documentId,
    required String userId,
    required PermissionRole role,
    required String grantedBy,
  }) async {
    final response = await _client
        .from(SupabaseConfig.permissionsTable)
        .upsert({
          'document_id': documentId,
          'user_id': userId,
          'role': role.value,
          'granted_by': grantedBy,
        }, onConflict: 'document_id,user_id')
        .select('''
          *,
          users!permissions_user_id_fkey!inner(*)
        ''')
        .single();

    return PermissionModel.fromJson(response);
  }

  /// Xóa quyền chia sẻ
  Future<void> removePermission(int documentId, String userId) async {
    await _client
        .from(SupabaseConfig.permissionsTable)
        .delete()
        .filter('document_id', 'eq', documentId)
        .filter('user_id', 'eq', userId);
  }

  /// Cập nhật quyền
  Future<PermissionModel> updatePermission({
    required int documentId,
    required String userId,
    required PermissionRole role,
  }) async {
    final response = await _client
        .from(SupabaseConfig.permissionsTable)
        .update({'role': role.value})
        .filter('document_id', 'eq', documentId)
        .filter('user_id', 'eq', userId)
        .select('''
          *,
          users!permissions_user_id_fkey!inner(*)
        ''')
        .single();

    return PermissionModel.fromJson(response);
  }

  /// Lấy danh sách quyền của một tài liệu
  Future<List<PermissionModel>> getDocumentPermissions(int documentId) async {
    final response = await _client
        .from(SupabaseConfig.permissionsTable)
        .select('''
          *,
          users!permissions_user_id_fkey!inner(*)
        ''')
        .filter('document_id', 'eq', documentId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PermissionModel.fromJson(json))
        .toList();
  }

  /// Kiểm tra quyền của user trên tài liệu
  Future<PermissionRole?> getUserPermission(
    int documentId,
    String userId,
  ) async {
    final response = await _client
        .from(SupabaseConfig.permissionsTable)
        .select('role')
        .filter('document_id', 'eq', documentId)
        .filter('user_id', 'eq', userId)
        .maybeSingle();

    if (response == null) return null;
    return PermissionRole.values.firstWhere(
      (r) => r.value == response['role'],
      orElse: () => PermissionRole.viewer,
    );
  }

  /// Lấy tài liệu được chia sẻ cho user
  Future<List<DocumentModel>> getSharedDocuments(String userId) async {
    // Lấy document_id từ permissions
    final permResponse = await _client
        .from(SupabaseConfig.permissionsTable)
        .select('document_id')
        .filter('user_id', 'eq', userId);

    final docIds = (permResponse as List)
        .map((p) => p['document_id'] as int)
        .toList();

    if (docIds.isEmpty) return [];

    // Fetch documents
    final docsResponse = await _client
        .from(SupabaseConfig.documentsTable)
        .select()
        .filter('id', 'in', docIds)
        .order('created_at', ascending: false);

    final docs = docsResponse as List;

    if (docs.isEmpty) return [];

    // Fetch categories
    final categoryIds = docs.map((d) => d['category_id'] as int).toSet();
    final categoriesResponse = await _client
        .from(SupabaseConfig.categoriesTable)
        .select()
        .filter('id', 'in', categoryIds.toList());

    final categoriesMap = {
      for (var c in categoriesResponse as List)
        c['id'] as int: c['name'] as String,
    };

    return docs.map((json) {
      final categoryId = json['category_id'] as int;
      return DocumentModel(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        filePath: json['file_path'] as String?,
        fileUrl: json['file_url'] as String?,
        storagePath: json['storage_path'] as String?,
        categoryName: categoriesMap[categoryId] ?? '',
        categoryId: categoryId,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
    }).toList();
  }
}
