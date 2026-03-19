import 'package:objectbox/objectbox.dart';

enum TransactionType { gave, got }

@Entity()
class TransactionUdhari {
  @Id()
  int id = 0;
  double amount = 0.0;
    int syid = 0;
  bool synced = false;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';

  // Store enum as int
  @Property(type: PropertyType.byte)
  int typeIndex = 0;

  @Property(type: PropertyType.date)
  DateTime date = DateTime.now();

  String description = '';

    // NEW: Due date field
  @Property(type: PropertyType.date)
  DateTime? dueDate;

    // NEW: Reminder sent flag
  bool reminderSent = false;
  

  final customer = ToOne<udhariCustomer>();

  // ObjectBox needs a default constructor
  TransactionUdhari();

  // Named constructor for convenience
  TransactionUdhari.create({
    required this.amount,
    required TransactionType type,
    required this.date,
    required this.syid,
    this.synced = false,
    this.description = '',
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reminderSent = false,
    this.dueDate, // Add dueDate parameter
  }) : typeIndex = type.index;

  // Getter to access enum
  TransactionType get type => TransactionType.values[typeIndex];

  // Setter to update enum
  set type(TransactionType newType) => typeIndex = newType.index;

  // NEW: Helper getters
  bool get isOverdue {
    if (dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now());
  }
  
  int get daysOverdue {
    if (!isOverdue || dueDate == null) return 0;
    return DateTime.now().difference(dueDate!).inDays;
  }
  
  // Convert to map for JSON/sync
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'syid': syid, // Add category
      'synced': synced, // Add category
      'amount': amount,
      'type': typeIndex,
      'date': date.toIso8601String(),
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'reminderSent': reminderSent,
      'reserved_field': reserved_field,
      'reserved_field1': reserved_field1,
      'reserved_field2': reserved_field2,
      'reserved_field3': reserved_field3,
    };
  }
  
  // Create from map
  factory TransactionUdhari.fromMap(Map<String, dynamic> map) {
    return TransactionUdhari.create(
            syid: map['syid'] ?? 1,
      synced: map['synced'] ?? false,
      amount: map['amount'] ?? 0.0,
      type: TransactionType.values[map['type'] ?? 0],
      date: DateTime.parse(map['date']),
      description: map['description'] ?? '',
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      reminderSent: map['reminderSent'] ?? false,
    );
  }

}



@Entity()
class udhariCustomer {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  String ucuniid = '';
  String name = '';
  String phone = '';
  String? adreess = '';
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  // List<TransactionUdhari> transactions = [];

  @Backlink('customer')
  final transactions = ToMany<TransactionUdhari>();

  udhariCustomer({required this.ucuniid,required this.name, required this.syid, this.synced = false, required this.phone,this.adreess,this.reserved_field,this.reserved_field1,this.reserved_field2,this.reserved_field3,});

  /// Adds a transaction to this udhariCustomer
  void addTransaction({
    required double amount,
    required TransactionType type,
    required DateTime date,
    syid,
    synced = false,
    String description = '',
  }) {
    final transaction = TransactionUdhari.create(
      syid:syid,
      synced:synced,
      amount: amount,
      type: type,
      date: date,
      description: description,
    );
    transactions.add(transaction);
  }

  /// Calculates the current balance
  double get balance {
    double total = 0.0;
    for (final t in transactions) {
      total += t.type == TransactionType.gave ? t.amount : -t.amount;
    }
    return total;
  }

  /// Factory constructor from map (optional)
  factory udhariCustomer.fromMap(Map<String, dynamic> map, List<TransactionUdhari> transactions) {
    return udhariCustomer(
            syid: map['syid'] ?? 1,
      synced: map['synced'] ?? false,
      ucuniid : map['ucuniid'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      adreess: map['adreess'] as String,
    );
  }

}
