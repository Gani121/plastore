// lib/tabledata.dart
import 'package:objectbox/objectbox.dart';


@Entity()
class tableCart {
  @Id()
  int id = 0;
    int syid;
  bool synced;
  int tableNo;
  String tCart;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';


  tableCart({
    required this.tableNo,
    required this.tCart,
        required this.syid,
    this.synced = false,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });
}

