// lib/database_Module/expense_model.dart
import 'package:objectbox/objectbox.dart';
import 'package:test1/utilities.dart';

@Entity()
class expences {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  @Property(type: PropertyType.date)
  DateTime createTime = DateTime.now();

  String expence; // JSON string containing all expense data
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';

  expences({
    required this.expence,
        required this.syid,
    this.synced = false,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'syid': syid, // Add category
      'synced': synced, // Add category
      'createTime': createTime.toIso8601String(),
      'expence': expence,
    };
  }

  // Create from JSON
  factory expences.fromJson(Map<String, dynamic> json) {
    return expences(
      syid: json['syid'] ?? 1,
      synced: json['synced'] ?? false,
      expence: json['expence'] ?? '',
    )..id = json['id'] ?? 0
      ..createTime = DateTime.parse(json['createTime'] ?? DateTime.now().toIso8601String());
  }
}

// Enhanced Expense class with all fields
class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? photoPath;
  final String hotelName;

  // New fields
  final String? supplierName;
  final double? quantity;
  final String? unit;
  final String? paymentMethod;
  final double? receivedAmount;
  final String? description;
  final String? expenseType; // 'Expense' or 'Consumption'

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.hotelName,
    this.photoPath,
    this.supplierName,
    this.quantity,
    this.unit,
    this.paymentMethod,
    this.receivedAmount,
    this.description,
    this.expenseType,
  });

  // Calculate due amount (if payment method is Credit)
  double? get dueAmount {
    if (paymentMethod == 'Credit' && receivedAmount != null) {
      return amount - receivedAmount!;
    }
    return null;
  }

  // Check if payment is fully paid
  bool get isFullyPaid {
    if (paymentMethod != 'Credit') return true;
    return receivedAmount != null && receivedAmount! >= amount;
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
      'hotelName': hotelName,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    print_log("$map");
    return Expense(
      id: map['id'].toString(),
      title: map['title']?.toString() ?? '',
      amount: double.tryParse((map['amount'] ?? "").toString()) ?? 0.0,
      date: DateTime.tryParse((map['date'] ?? "").toString()) ?? DateTime.now(),
      category: (map['category'] ?? 'Other').toString(),
      photoPath: map['photoPath']?.toString(),
      supplierName: map['supplierName']?.toString(),
      quantity: map['quantity'] != null ? double.tryParse(map['quantity'].toString()) : null,
      unit: map['unit']?.toString(),
      paymentMethod: map['paymentMethod']?.toString(),
      receivedAmount: map['receivedAmount'] != null ? double.tryParse(map['receivedAmount'].toString()) : null,
      description: map['description']?.toString(),
      expenseType: map['expenseType']?.toString(),
      hotelName: map['hotelName']?.toString() ?? '',
    );
  }

  Expense copyWith({
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
    String? hotelName,
    String? expenseType,
  }) {
    return Expense(
      id: id,
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
      hotelName: hotelName ?? this.hotelName,
    );
  }
}