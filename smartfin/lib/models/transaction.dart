
enum TransactionType { income, expense }

class Transaction {
  final int? id;
  final int? userId;
  final int categoryId;
  final double amount;
  final String description; // Backend uses 'description' instead of 'title'
  final DateTime date;
  final String? paymentMethod;
  final String? notes;
  final String? receiptImageUrl;
  
  // UI helper fields (these might not come directly from backend but are used to render)
  final String categoryName;
  final TransactionType type;

  Transaction({
    this.id,
    this.userId,
    required this.categoryId,
    required this.amount,
    required this.description,
    required this.date,
    this.paymentMethod,
    this.notes,
    this.receiptImageUrl,
    this.categoryName = 'Unknown', // Default value for UI
    this.type = TransactionType.expense, // Default value for UI
  });

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'amount': amount,
      'description': description,
      // FastAPI datetime format requires strict ISO 8601 formatting or string parsing. 
      'date': date.toIso8601String(), 
      'payment_method': paymentMethod,
      'notes': notes,
      'receipt_image_url': receiptImageUrl,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json, {String cName = 'Unknown', TransactionType cType = TransactionType.expense}) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'],
      categoryId: json['category_id'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
      date: DateTime.parse(json['date']),
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      receiptImageUrl: json['receipt_image_url'],
      categoryName: cName,
      type: cType,
    );
  }
}
