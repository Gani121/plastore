class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? photoPath;
  final String? supplierName;
  final double? quantity;
  final String? unit;
  final String? paymentMethod;
  final double? receivedAmount;
  final String? description;
  final String? expenseType;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.photoPath,
    this.supplierName,
    this.quantity,
    this.unit,
    this.paymentMethod,
    this.receivedAmount,
    this.description,
    this.expenseType,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'] ?? 'Other',
      photoPath: map['photoPath'],
      supplierName: map['supplierName'],
      quantity: map['quantity']?.toDouble(),
      unit: map['unit'],
      paymentMethod: map['paymentMethod'],
      receivedAmount: map['receivedAmount']?.toDouble(),
      description: map['description'],
      expenseType: map['expenseType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'photoPath': photoPath,
      'supplierName': supplierName,
      'quantity': quantity,
      'unit': unit,
      'paymentMethod': paymentMethod,
      'receivedAmount': receivedAmount,
      'description': description,
      'expenseType': expenseType,
    };
  }

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? photoPath,
    String? supplierName,
    double? quantity,
    String? unit,
    String? paymentMethod,
    double? receivedAmount,
    String? description,
    String? expenseType,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      photoPath: photoPath ?? this.photoPath,
      supplierName: supplierName ?? this.supplierName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      description: description ?? this.description,
      expenseType: expenseType ?? this.expenseType,
    );
  }
}