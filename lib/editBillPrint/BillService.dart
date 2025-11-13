import 'package:flutter/material.dart';
import '../objectbox.g.dart';
import '../billnogenerator/BillCounter.dart';


class BillService {
  
  static int getNextBillNo(Store store) {
    final billCounterBox = store.box<BillCounter>();
    final existingCounters = billCounterBox.getAll();

    int billNo = (existingCounters.isEmpty)
        ? 1
        : existingCounters.first.lastBillNo;

    debugPrint("Next bill number: $billNo");
    return billNo;
  }
}


