import 'package:objectbox/objectbox.dart';

enum TransactionType { gave, got }

@Entity()
class TransactionUdhari {
  @Id()
  int id = 0;

  double amount = 0.0;

  // Store enum as int
  @Property(type: PropertyType.byte)
  int typeIndex = 0;

  @Property(type: PropertyType.date)
  DateTime date = DateTime.now();

  String description = '';

  final customer = ToOne<udhariCustomer>();

  // ObjectBox needs a default constructor
  TransactionUdhari();

  // Named constructor for convenience
  TransactionUdhari.create({
    required this.amount,
    required TransactionType type,
    required this.date,
    this.description = '',
  }) : typeIndex = type.index;

  // Getter to access enum
  TransactionType get type => TransactionType.values[typeIndex];

  // Setter to update enum
  set type(TransactionType newType) => typeIndex = newType.index;
}



@Entity()
class udhariCustomer {
  @Id()
  int id = 0;
  String name = '';
  String phone = '';
  // List<TransactionUdhari> transactions = [];

  @Backlink('customer')
  final transactions = ToMany<TransactionUdhari>();

  udhariCustomer({required this.name, required this.phone,});

  /// Adds a transaction to this udhariCustomer
  void addTransaction({
    required double amount,
    required TransactionType type,
    required DateTime date,
    String description = '',
  }) {
    final transaction = TransactionUdhari.create(
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
      name: map['name'] as String,
      phone: map['phone'] as String,
    );
  }

}
