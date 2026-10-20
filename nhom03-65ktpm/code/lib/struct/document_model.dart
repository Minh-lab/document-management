class DocumentModel {
  final int id;
  final String title;
  final String? description;
  final String? filePath; // Local file path (for offline)
  final String? fileUrl; // Firebase Storage download URL
  final String? storagePath; // Firebase Storage path
  final String categoryName;
  final int categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentModel({
    required this.id,
    required this.title,
    this.description,
    this.filePath,
    this.fileUrl,
    this.storagePath,
    required this.categoryName,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper để lấy URL mở file (ưu tiên fileUrl từ Firebase, fallback filePath local)
  String? get openUrl => fileUrl ?? filePath;

  // Kiểm tra có file đính kèm không
  bool get hasAttachment =>
      fileUrl != null || (filePath != null && filePath!.isNotEmpty);
}
