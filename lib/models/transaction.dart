// models/transaction.dart
import 'package:objectbox/objectbox.dart';
import 'dart:convert'; // For jsonEncode/jsonDecode and utf8

@Entity()
class Transaction {
  int id = 0;
  @Property(type: PropertyType.date)
  DateTime time;
  int? tableNo;
  int total;
  String cartData;
  String payment_mode;
  bool synced;
  String status; 
  double? serviceCharge;
  double? discount;
  double? discountPercent;
  int? billNo;
  String? customerName;
  String? mobileNo;
  String? reserved;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';

  //run this if changes are done
  //flutter pub run build_runner build --delete-conflicting-outputs
  Transaction({
    required this.time,
    this.tableNo,
    required this.total,
    required this.cartData,
    required this.payment_mode,
    this.synced = false,
    this.status="",
    this.serviceCharge,
    this.discount,
    this.discountPercent,
    this.billNo,
    this.customerName,
    this.mobileNo,
    this.reserved,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });

  @override
  String toString() {
    return 'Transaction(id: $id, time: $time, tableNo: $tableNo, total: $total, mobileNo:$mobileNo, customerName: $customerName billNo :$billNo, discountPercent: $discountPercent discount: $discount  serviceCharge:$serviceCharge reserved :$reserved, cartData: $cartData,)';
  }

  List<Map<String, dynamic>> get decodedCart =>
      List<Map<String, dynamic>>.from(jsonDecode(cartData));


  /// Converts a Transaction instance into a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // Storing DateTime as an ISO 8601 string is a common practice
      'time': time.toIso8601String(),
      'tableNo': tableNo,
      'total': total,
      'cart': jsonDecode(cartData),
      'payment_mode': payment_mode,
      'synced': synced,
      'status': status,
      'serviceCharge': serviceCharge,
      'discount': discount,
      'discountPercent': discountPercent,
      'billNo': billNo,
      'customerName': customerName,
      'mobileNo': mobileNo,
      'reserved': reserved,
    };
  }

  /// Creates a Transaction instance from a map.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      // id is handled by ObjectBox, but you might need it from other sources
      // id: map['id'] ?? 0,
      time: DateTime.parse(map['time']),
      tableNo: map['tableNo'],
      total: map['total'],
      cartData: map['cartData'],
      payment_mode: map['payment_mode'],
      synced: map['synced'] ?? false,
      status: map['status'] ?? '',
      serviceCharge: map['serviceCharge'],
      discount: map['discount'],
      discountPercent: map['discountPercent'],
      billNo: map['billNo'],
      customerName: map['customerName'],
      mobileNo: map['mobileNo'],
      reserved: map['reserved'],
    );
  }


}
