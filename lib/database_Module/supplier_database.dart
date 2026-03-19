// lib/database_Module/supplier_database.dart
import 'package:objectbox/objectbox.dart';

@Entity()
class Supplier {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  String supplierName;
  String? mobileNumber;
  String? address;
  String? gstNumber;
  String? category;
  String? paymentTerms;
  DateTime? createdDate;
  
  // Reserved fields for future use
  String? reserved_field;
  String? reserved_field1;
  String? reserved_field2;
  String? reserved_field3;

  Supplier({
    required this.supplierName,
        required this.syid,
    this.synced = false,
    this.mobileNumber,
    this.address,
    this.gstNumber,
    this.category,
    this.paymentTerms,
    DateTime? createdDate,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
  }) : createdDate = createdDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
            'syid': syid, // Add category
      'synced': synced, // Add category
      'supplierName': supplierName,
      'mobileNumber': mobileNumber,
      'address': address,
      'gstNumber': gstNumber,
      'category': category,
      'paymentTerms': paymentTerms,
      'createdDate': createdDate?.toIso8601String(),
      'reserved_field': reserved_field,
      'reserved_field1': reserved_field1,
      'reserved_field2': reserved_field2,
      'reserved_field3': reserved_field3,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
            syid: map['syid'] ?? 1,
      synced: map['synced'] ?? false,
      supplierName: map['supplierName'] ?? '',
      mobileNumber: map['mobileNumber'],
      address: map['address'],
      gstNumber: map['gstNumber'],
      category: map['category'],
      paymentTerms: map['paymentTerms'],
      createdDate: map['createdDate'] != null 
          ? DateTime.tryParse(map['createdDate']) 
          : null,
    );
  }
}