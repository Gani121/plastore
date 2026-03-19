// lib/purchase_order/purchase_order_database.dart
import 'package:objectbox/objectbox.dart';
import 'dart:convert';

@Entity()
class PurchaseOrderEntity {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  
  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();
  
  String orderData; // JSON string containing all order data
  
  String? pdfPath;
  String? signaturePath;
  
  // Indexed fields for faster queries
  @Index()
  String orderNumber = '';
  
  @Index()
  String supplierName = '';
  
  @Index()
  int statusIndex = 0;
  
  @Property(type: PropertyType.date)
  DateTime orderDate = DateTime.now();

  PurchaseOrderEntity({
    required this.orderData,
        required this.syid,
    this.synced = false,
    this.pdfPath,
    this.signaturePath,
    String? orderNumber,
    String? supplierName,
    int? statusIndex,
    DateTime? orderDate,
  }) {
    // Parse order data to extract indexed fields
    try {
      final Map<String, dynamic> data = jsonDecode(orderData);
      this.orderNumber = orderNumber ?? data['orderNumber'] ?? '';
      this.supplierName = supplierName ?? data['supplierName'] ?? '';
      this.statusIndex = statusIndex ?? data['status'] ?? 0;
      this.syid = syid;
      this.synced = synced;
      this.orderDate = orderDate ?? 
          (data['orderDate'] != null 
              ? DateTime.parse(data['orderDate']) 
              : DateTime.now());
    } catch (e) {
      this.orderNumber = orderNumber ?? '';
      this.supplierName = supplierName ?? '';
      this.statusIndex = statusIndex ?? 0;
      this.orderDate = orderDate ?? DateTime.now();
    }
  }
}