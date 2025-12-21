import 'package:objectbox/objectbox.dart';


//flutter pub run build_runner watch
//flutter pub run build_runner build
@Entity()
class Parties {
  @Id()
  int id = 0;
  @Property(type: PropertyType.date)
  DateTime createTime = DateTime.now();
  String customername; //
  String? suppliername; //
  String mobilenumber;
  String? category; //
  String? adreess;
  String? gstno;
  String? billingterm; //
  String billingtype; //
  @Property(type: PropertyType.date)
  DateTime? bod; //
  String? mailid; //
  // bool? sendwhatsapp; //
  // bool? istable; //
  // bool isStarred;
  String? visitingday;
  bool isCompleted;
  @Property(type: PropertyType.date) // Store as a millisecond timestamp
  DateTime? completionDate;
  String? reserved_field;
  String? reserved_field1;
  String? reserved_field2;
  String? reserved_field3;
  String? reserved_field4;
  String? reserved_field5;

  Parties({
    required this.customername,
    this.suppliername,
    required this.mobilenumber,
    this.category,
    this.adreess,
    this.gstno,
    this.billingterm,
    required this.billingtype,
    this.bod,
    this.mailid,
    // this.sendwhatsapp,
    // this.istable,
    // this.isStarred = false,
    this.visitingday,
    this.isCompleted = false, // Default to false
    this.completionDate,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });

  // factory Parties.fromJson() {
  //   return Parties(
  //     id: id,
  //     createTime: createTime,
  //     customername: customername,
  //     suppliername:suppliername,
  //     mobilenumber:mobilenumber,
  //     category:category,
  //     adreess:adreess,
  //     gstno: gstno,
  //     billingterm:billingterm,
  //     billingtype:billingtype,
  //     bod:bod,
  //     mailid:mailid,
  //     sendwhatsapp:sendwhatsapp,
  //     istable:istable,
  //     reserved_field:reserved_field,
  //     reserved_field1:reserved_field1,
  //     reserved_field2:reserved_field2,
  //     reserved_field3:reserved_field3,
  //     reserved_field4:reserved_field4,
  //     reserved_field5:reserved_field5,
  //   );
  // }

  Map<String, dynamic> toJson() => {
      'id': id,
      'createTime': createTime,
      'customername': customername,
      'suppliername':suppliername,
      'mobilenumber':mobilenumber,
      'category':category,
      'adreess':adreess,
      'gstno': gstno,
      'billingterm':billingterm,
      'billingtype':billingtype,
      'bod':bod,
      'mailid':mailid,
      // 'sendwhatsapp':sendwhatsapp,
      // 'istable':istable,
      'reserved_field':reserved_field,
      'reserved_field1':reserved_field1,
      'reserved_field2':reserved_field2,
      'reserved_field3':reserved_field3,
      'reserved_field4':reserved_field4,
      'reserved_field5':reserved_field5,
      };

        // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createTime': createTime,
      'customername': customername,
      'suppliername':suppliername,
      'mobilenumber':mobilenumber,
      'category':category,
      'adreess':adreess,
      'gstno': gstno,
      'billingterm':billingterm,
      'billingtype':billingtype,
      'bod':bod,
      'mailid':mailid,
      // 'sendwhatsapp':sendwhatsapp,
      // 'istable':istable,
      'reserved_field':reserved_field,
      'reserved_field1':reserved_field1,
      'reserved_field2':reserved_field2,
      'reserved_field3':reserved_field3,
      'reserved_field4':reserved_field4,
      'reserved_field5':reserved_field5,
    };
  }


}