// lib/tabledata.dart
import 'package:objectbox/objectbox.dart';
import 'menu_item.dart';

@Entity()
class Active_Table_view {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  @Unique()
  int number;

  double total = 0.0;
  String paymentMethod = 'Cash';
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';

  @Backlink()
  final ToMany<OrderItem> orders = ToMany<OrderItem>();

  Active_Table_view({
    required this.number,
        required this.syid,
    this.synced = false,
    this.total = 0.0,
    this.paymentMethod = 'Cash',
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });
}




@Entity()
class CartItem {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  int quantity;
  
  // Store menu item details directly for cart display
  String name;
  double price;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';

  // Reference to the original menu item
  final ToOne<Active_Table_view> menuItem = ToOne<Active_Table_view>();

  CartItem({
    required this.name,
    required this.price,
        required this.syid,
    this.synced = false,
    this.quantity = 1,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });
  
  double get totalPrice => price * quantity;
}

@Entity()
class OrderItem {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  String name;
  int quantity;
  double price;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';

  final ToOne<Active_Table_view> table = ToOne<Active_Table_view>();

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
        required this.syid,
    this.synced = false,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });

  double get totalPrice => price * quantity;
}