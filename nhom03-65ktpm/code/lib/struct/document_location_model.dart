class DocumentLocationModel {
  final int? id;
  final int documentId;
  final double? latitude;
  final double? longitude;
  final String? placeName;
  final String? shelf;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DocumentLocationModel({
    this.id,
    required this.documentId,
    this.latitude,
    this.longitude,
    this.placeName,
    this.shelf,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasPhysicalDetails =>
      (placeName != null && placeName!.isNotEmpty) ||
      (shelf != null && shelf!.isNotEmpty) ||
      (note != null && note!.isNotEmpty);

  bool get isEmpty => !hasCoordinates && !hasPhysicalDetails;

  String get summaryText {
    final parts = <String>[];
    if (placeName != null && placeName!.trim().isNotEmpty) {
      parts.add(placeName!.trim());
    }
    if (shelf != null && shelf!.trim().isNotEmpty) {
      parts.add('Kệ/Ngăn: ${shelf!.trim()}');
    }
    if (note != null && note!.trim().isNotEmpty) {
      parts.add('(${note!.trim()})');
    }
    if (parts.isEmpty && hasCoordinates) {
      return 'Tọa độ: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    }
    return parts.join(' - ');
  }

  factory DocumentLocationModel.fromJson(Map<String, dynamic> json) {
    return DocumentLocationModel(
      id: json['id'] != null ? (json['id'] as num).toInt() : null,
      documentId: (json['document_id'] as num).toInt(),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      placeName: json['place_name'] as String?,
      shelf: json['shelf'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'latitude': latitude,
      'longitude': longitude,
      'place_name': placeName,
      'shelf': shelf,
      'note': note,
    };
  }
}
