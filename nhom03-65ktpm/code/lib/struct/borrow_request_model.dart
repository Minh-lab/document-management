enum BorrowRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
  returnRequested,
  returned,
  expired;

  static BorrowRequestStatus fromValue(String value) {
    return switch (value) {
      'pending' => pending,
      'approved' => approved,
      'rejected' => rejected,
      'cancelled' => cancelled,
      'return_requested' => returnRequested,
      'returned' => returned,
      'expired' => expired,
      _ => throw FormatException(
        'Trạng thái yêu cầu mượn không hợp lệ: $value',
      ),
    };
  }

  String get value => switch (this) {
    pending => 'pending',
    approved => 'approved',
    rejected => 'rejected',
    cancelled => 'cancelled',
    returnRequested => 'return_requested',
    returned => 'returned',
    expired => 'expired',
  };

  String get label => switch (this) {
    pending => 'Chờ duyệt',
    approved => 'Đang mượn',
    rejected => 'Đã từ chối',
    cancelled => 'Đã hủy',
    returnRequested => 'Chờ xác nhận trả',
    returned => 'Đã trả',
    expired => 'Quá hạn',
  };
}

class BorrowRequestModel {
  final int id;
  final int documentId;
  final String documentTitle;
  final String borrowerId;
  final String ownerId;
  final String? borrowerName;
  final String? ownerName;
  final String? note;
  final String? rejectionReason;
  final BorrowRequestStatus status;
  final DateTime dueAt;
  final DateTime createdAt;

  const BorrowRequestModel({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.borrowerId,
    required this.ownerId,
    this.borrowerName,
    this.ownerName,
    this.note,
    this.rejectionReason,
    required this.status,
    required this.dueAt,
    required this.createdAt,
  });

  factory BorrowRequestModel.fromJson(Map<String, dynamic> json) {
    final document = json['documents'] as Map<String, dynamic>?;
    final borrower = json['borrower'] as Map<String, dynamic>?;
    final borrowerName =
        borrower?['display_name'] as String? ?? borrower?['email'] as String?;
    final owner = json['owner'] as Map<String, dynamic>?;
    final ownerName =
        owner?['display_name'] as String? ?? owner?['email'] as String?;

    return BorrowRequestModel(
      id: (json['id'] as num).toInt(),
      documentId: (json['document_id'] as num).toInt(),
      documentTitle:
          document?['title'] as String? ?? 'Tài liệu #${json['document_id']}',
      borrowerId: json['borrower_id'] as String,
      ownerId: json['owner_id'] as String,
      borrowerName: borrowerName,
      ownerName: ownerName,
      note: json['note'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      status: BorrowRequestStatus.fromValue(json['status'] as String),
      dueAt: DateTime.parse(json['due_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isOverdue =>
      status == BorrowRequestStatus.approved && dueAt.isBefore(DateTime.now());
}
