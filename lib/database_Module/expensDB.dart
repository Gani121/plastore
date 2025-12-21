// lib/tabledata.dart
import 'package:objectbox/objectbox.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';


@Entity()
class expences {
  @Id()
  int id = 0;
  @Property(type: PropertyType.date)
  DateTime createTime = DateTime.now();

  String expence;
  String? reserved_field = '';
  String? reserved_field1 = '';
  String? reserved_field2 = '';
  String? reserved_field3 = '';
  String? reserved_field4 = '';
  String? reserved_field5 = '';


  expences({
    required this.expence,
    this.reserved_field,
    this.reserved_field1,
    this.reserved_field2,
    this.reserved_field3,
    this.reserved_field4,
    this.reserved_field5,
  });
}

