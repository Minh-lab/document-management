class TagModel {
  final int id;
  final String name;
  final String? color;

  const TagModel({required this.id, required this.name, this.color});

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'color': color};
  }
}
