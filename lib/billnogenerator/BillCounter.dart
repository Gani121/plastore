import 'package:objectbox/objectbox.dart';

@Entity()
class BillCounter {
  @Id()
  int id = 0;

  int lastBillNo;

  BillCounter({this.lastBillNo = 0});
}
