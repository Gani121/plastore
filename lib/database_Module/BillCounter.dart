import 'package:objectbox/objectbox.dart';

@Entity()
class BillCounter {
  @Id()
  int id = 0;

  int lastBillNo;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';

  BillCounter({this.lastBillNo = 0,this.reserved_field,this.reserved_field1,this.reserved_field2,this.reserved_field3,this.reserved_field4,this.reserved_field5,});
}
