class Category {
  final int? id;
  final int? userId;
  final String name;
  final String categoryType;
  final String? iconName;

  Category({
    this.id,
    this.userId,
    required this.name,
    required this.categoryType,
    this.iconName,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category_type': categoryType,
      'icon_name': iconName,
      'user_id': userId,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      categoryType: json['category_type'],
      iconName: json['icon_name'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Category &&
      other.id == id &&
      other.name == name &&
      other.categoryType == categoryType;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ categoryType.hashCode;
}
