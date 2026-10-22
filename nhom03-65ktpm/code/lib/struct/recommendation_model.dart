/// Tài liệu ứng viên cho gợi ý (UC-11): chỉ có thông tin mô tả, không có đường dẫn file.
class RecommendationCandidate {
  final int id;
  final String title;
  final String? description;
  final String categoryName;
  final String ownerName;
  final DateTime createdAt;
  final List<String> tags;
  final int viewCount;

  /// Người dùng đã có quyền xem (được chia sẻ) – mở được trang chi tiết.
  final bool canOpen;

  RecommendationCandidate({
    required this.id,
    required this.title,
    this.description,
    required this.categoryName,
    required this.ownerName,
    required this.createdAt,
    this.tags = const [],
    this.viewCount = 0,
    this.canOpen = false,
  });

  factory RecommendationCandidate.fromJson(Map<String, dynamic> json) {
    return RecommendationCandidate(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      categoryName: json['category_name'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      tags: List<String>.from(json['tags'] as List? ?? const []),
      viewCount: (json['view_count'] as num? ?? 0).toInt(),
      canOpen: json['can_open'] as bool? ?? false,
    );
  }
}

/// Một gợi ý đã chấm điểm, kèm điểm thành phần và lý do hiển thị.
class RecommendationModel {
  final RecommendationCandidate document;
  final double score;
  final double tagScore;
  final double recencyScore;
  final double viewScore;
  final String reason;

  RecommendationModel({
    required this.document,
    required this.score,
    required this.tagScore,
    required this.recencyScore,
    required this.viewScore,
    required this.reason,
  });
}
