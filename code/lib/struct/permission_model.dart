import 'user_model.dart';

enum PermissionRole {
  viewer('viewer', 'Người xem'),
  editor('editor', 'Người chỉnh sửa'),
  owner('owner', 'Chủ sở hữu');

  const PermissionRole(this.value, this.label);
  final String value;
  final String label;
}

class PermissionModel {
  final int id;
  final int documentId;
  final String userId;
  final PermissionRole role;
  final String grantedBy;
  final DateTime createdAt;
  final UserModel? user; // populated when joined

  PermissionModel({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.role,
    required this.grantedBy,
    required this.createdAt,
    this.user,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    UserModel? user;
    if (json['users'] != null) {
      user = UserModel.fromJson(json['users'] as Map<String, dynamic>);
    }
    
    return PermissionModel(
      id: json['id'] as int,
      documentId: json['document_id'] as int,
      userId: json['user_id'] as String,
      role: PermissionRole.values.firstWhere(
        (r) => r.value == json['role'],
        orElse: () => PermissionRole.viewer,
      ),
      grantedBy: json['granted_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'document_id': documentId,
      'user_id': userId,
      'role': role.value,
      'granted_by': grantedBy,
    };
  }
}