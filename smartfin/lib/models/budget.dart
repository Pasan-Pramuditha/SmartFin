class Budget {
  final int? id;
  final int? userId;
  final int categoryId;
  final double monthlyLimit;
  final String monthYear;

  // UI Helper fields
  final String categoryName;
  final double spentAmount;

  Budget({
    this.id,
    this.userId,
    required this.categoryId,
    required this.monthlyLimit,
    required this.monthYear,
    this.categoryName = 'Unknown',
    this.spentAmount = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'monthly_limit': monthlyLimit,
      'month_year': monthYear,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json, {String cName = 'Unknown', double spent = 0.0}) {
    return Budget(
      id: json['id'],
      userId: json['user_id'],
      categoryId: json['category_id'],
      monthlyLimit: (json['monthly_limit'] as num).toDouble(),
      monthYear: json['month_year'],
      categoryName: cName,
      spentAmount: spent,
    );
  }
}
