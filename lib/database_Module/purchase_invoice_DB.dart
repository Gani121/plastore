// lib/models/purchase_invoice.dart
// lib/objectbox.g.dart will be generated, but create this entity:
import 'package:objectbox/objectbox.dart';

@Entity()
class PurchaseInvoiceEntity {
  @Id()
  int id; // ObjectBox internal ID
    int syid;
  bool synced;
  @Property(type: PropertyType.date)
  DateTime createdDate = DateTime.now();
  
  String invoiceData; // Store JSON string
  
  PurchaseInvoiceEntity({
    this.id = 0,
        required this.syid,
    this.synced = false,
    required this.invoiceData,
    DateTime? createdDate,
  }) : createdDate = createdDate ?? DateTime.now();
}









class PurchaseInvoice {
  final String id;
  final String invoiceNumber;
  final String supplierName;
  final double totalAmount;
  final DateTime date;
  final String? photoPath;
  final List<PurchaseItem> items;
  final String? notes;
  final PaymentStatus paymentStatus;
  final DateTime? dueDate;

  PurchaseInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.supplierName,
    required this.totalAmount,
    required this.date,
    this.photoPath,
    required this.items,
    this.notes,
    required this.paymentStatus,
    this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'supplierName': supplierName,
      'totalAmount': totalAmount,
      'date': date.toIso8601String(),
      'photoPath': photoPath,
      'items': items.map((item) => item.toMap()).toList(),
      'notes': notes,
      'paymentStatus': paymentStatus.index,
      'dueDate': dueDate?.toIso8601String(),
    };
  }

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoice(
      id: map['id'].toString(),
      invoiceNumber: map['invoiceNumber']?.toString() ?? '',
      supplierName: map['supplierName']?.toString() ?? '',
      totalAmount: double.tryParse(map['totalAmount'].toString()) ?? 0.0,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      photoPath: map['photoPath']?.toString(),
      items: (map['items'] as List? ?? [])
          .map((item) => PurchaseItem.fromMap(item))
          .toList(),
      notes: map['notes']?.toString(),
      paymentStatus: PaymentStatus.values[map['paymentStatus'] ?? 0],
      dueDate: map['dueDate'] != null 
          ? DateTime.tryParse(map['dueDate'].toString()) 
          : null,
    );
  }

  PurchaseInvoice copyWith({
    String? invoiceNumber,
    String? supplierName,
    double? totalAmount,
    DateTime? date,
    String? photoPath,
    List<PurchaseItem>? items,
    String? notes,
    PaymentStatus? paymentStatus,
    DateTime? dueDate,
  }) {
    return PurchaseInvoice(
      id: id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierName: supplierName ?? this.supplierName,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      photoPath: photoPath ?? this.photoPath,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

class PurchaseItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? unit;
  final String? type;

  PurchaseItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.unit,
    this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'unit': unit,
      'type': type,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      name: map['name']?.toString() ?? '',
      quantity: double.tryParse(map['quantity'].toString()) ?? 0.0,
      unitPrice: double.tryParse(map['unitPrice'].toString()) ?? 0.0,
      totalPrice: double.tryParse(map['totalPrice'].toString()) ?? 0.0,
      unit: map['unit']?.toString(),
      type: map['type']?.toString(),
    );
  }
}

enum PaymentStatus {
  paid,
  pending,
  overdue,
  partial
}