// models/transaction.dart
import 'package:objectbox/objectbox.dart';
import 'dart:convert'; // For jsonEncode/jsonDecode and utf8
import 'package:test1/utilities.dart';


// Add this class to represent a single modification
class ModificationRecord {
  DateTime timestamp;
  String description;
  String fieldChanged; // e.g., "price", "discount", "cart item"
  int oldValue;
  int newValue;
  String? changedBy; // Optional: user who made the change
  
  ModificationRecord({
    required this.timestamp,
    required this.description,
    required this.fieldChanged,
    required this.oldValue,
    required this.newValue,
    this.changedBy,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'fieldChanged': fieldChanged,
      'oldValue': oldValue,
      'newValue': newValue,
      'changedBy': changedBy,
    };
  }
  
  factory ModificationRecord.fromMap(Map<String, dynamic> map) {
    return ModificationRecord(
      timestamp: DateTime.parse(map['timestamp']),
      description: map['description'],
      fieldChanged: map['fieldChanged'],
      oldValue: map['oldValue'],
      newValue: map['newValue'],
      changedBy: map['changedBy'],
    );
  }
  
  @override
  String toString() {
    return 'ModificationRecord(timestamp: $timestamp, description: $description, fieldChanged: $fieldChanged, oldValue: $oldValue, newValue: $newValue, changedBy: $changedBy)';
  }
}









@Entity()
class Transaction {
  int id = 0;
  int syid;
  @Property(type: PropertyType.date)
  DateTime time;
  int? tableNo;
  int total;
  int? cashamount;
  int? upiamount;
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
  String? orderType;
  String? reserved;
  String hotelName;
  String modificationsHistory; // Store as JSON string
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
    required this.syid,
    this.tableNo,
    required this.total,
    required this.cartData,
    required this.payment_mode,
    required this.hotelName,
    this.cashamount,
    this.upiamount,
    this.synced = false,
    this.status="",
    this.serviceCharge,
    this.discount,
    this.discountPercent,
    this.billNo,
    this.customerName,
    this.mobileNo,
    this.orderType,
    this.reserved,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
    this.modificationsHistory = '[]', // Initialize as empty JSON array
  });

  @override
  String toString() {
    return 'Transaction(id: $id, syid: $syid synced: $synced time: $time, tableNo: $tableNo, total: $total, status: $status, payment_mode: $payment_mode, synced: $synced, orderType: $orderType, mobileNo: $mobileNo, customerName: $customerName billNo: $billNo, discountPercent: $discountPercent discount: $discount serviceCharge: $serviceCharge reserved: $reserved, modificationsHistory: $modificationsHistory cartData: $cartData, upiamount: $upiamount cashamount: $cashamount hotelName$hotelName reserved_field: $reserved_field reserved_field1: $reserved_field1 reserved_field2: $reserved_field2 reserved_field3: $reserved_field3 reserved_field4: $reserved_field4 reserved_field5: $reserved_field5)';
  }

  List<Map<String, dynamic>> get decodedCart => List<Map<String, dynamic>>.from(jsonDecode(cartData));

  // Getter for modifications history as list of ModificationRecord objects
  List<ModificationRecord> get modifications {
    if (modificationsHistory.isEmpty) return [];
    try {
      List<dynamic> decoded = jsonDecode(modificationsHistory);
      return decoded.map((item) => ModificationRecord.fromMap(item)).toList();
    } catch (e) {
      return [];
    }
  }
  
  // Setter to update modifications history from list of ModificationRecord objects
  set modifications(List<ModificationRecord> records) {
    modificationsHistory = jsonEncode(records.map((r) => r.toMap()).toList());
  }
  
  // Helper method to add a single modification record
  void addModification({
    required String description,
    required String fieldChanged,
    required dynamic oldValue,
    required dynamic newValue,
    String? changedBy,
  }) {
    List<ModificationRecord> currentMods = modifications;
    currentMods.add(ModificationRecord(
      timestamp: DateTime.now(),
      description: description,
      fieldChanged: fieldChanged,
      oldValue: oldValue,
      newValue: newValue,
      changedBy: changedBy,
    ));
    this.modifications = currentMods;
  }

/// Converts a Transaction instance into a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'syid': syid,
      'time': time.toIso8601String(),
      'tableNo': tableNo,
      'total': total,
      'cartData': cartData, // Keep raw string just in case
      'payment_mode': payment_mode,
      'status': status,
      'serviceCharge': serviceCharge,
      'discount': discount,
      'discountPercent': discountPercent,
      'billNo': billNo,
      'customerName': customerName,
      'mobileNo': mobileNo,
      'reserved': reserved,
      'orderType': orderType,
      'upiamount': upiamount,
      'cashamount': cashamount,
      'synced': synced,
      'modificationsHistory': modificationsHistory,
      'hotelName': hotelName,
      'reserved_field': reserved_field,
      'reserved_field1': reserved_field1,
      'reserved_field2': reserved_field2, // This is the one your note logic needs!
      'reserved_field3': reserved_field3,
      'reserved_field4': reserved_field4,
      'reserved_field5': reserved_field5,
    };
  }

  /// Creates a Transaction instance from a map.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      syid: map['syid'] ?? 1,
      time: map['time'] != null ? DateTime.parse(map['time']) : DateTime.now(),
      tableNo: map['tableNo'],
      total: map['total'] ?? 0,
      cashamount:map['cashamount'],
      upiamount:map['upiamount'],
      cartData: map['cartData'] ?? '[]',
      payment_mode: map['payment_mode'] ?? '',
      synced: true,
      status: map['status'] ?? '',
      serviceCharge: map['serviceCharge']?.toDouble(),
      discount: map['discount']?.toDouble(),
      discountPercent: map['discountPercent']?.toDouble(),
      billNo: map['billNo'],
      customerName: map['customerName'],
      mobileNo: map['mobileNo'],
      orderType: map['orderType'],
      reserved: map['reserved'],
      modificationsHistory: map['modificationsHistory'] is String ? map['modificationsHistory'] : jsonEncode(map['modificationsHistory'] ?? []),
      hotelName: map['hotelName'] ?? '',
      reserved_field: map['reserved_field'] ?? '',
      reserved_field1: map['reserved_field1'] ?? '',
      reserved_field2: map['reserved_field2'] ?? '',
      reserved_field3: map['reserved_field3'] ?? '',
      reserved_field4: map['reserved_field4'] ?? '',
      reserved_field5: map['reserved_field5'] ?? '',
    );
  }


}





