class NotificationModel {
  final int id;
  final String userId;
  final String title;
  final String? body;
  final String type;
  final int? documentId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.type,
    this.documentId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Thông báo',
      body: json['body'] as String?,
      type: json['type'] as String? ?? 'system',
      documentId: json['document_id'] == null
          ? null
          : (json['document_id'] as num).toInt(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      documentId: documentId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
