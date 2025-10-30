import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../objectbox.g.dart';
import '../billnogenerator/BillCounter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:test1/editBillPrint/CheckoutPage.dart';
import '../cartprovier/cart_provider.dart';
import 'package:provider/provider.dart';
import '../cartprovier/ObjectBoxService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../NewOrderPage.dart';
import 'package:test1/MenuItemPage.dart' as gk;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

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


