import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'cartprovier/cart_provider.dart';
import 'package:provider/provider.dart';
import 'models/transaction.dart';
import 'cartprovier/ObjectBoxService.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as bl;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '/objectbox.g.dart';
import 'package:intl/intl.dart';
import '../billnogenerator/BillCounter.dart';
import 'cartprovier/ObjectBoxService.dart';
import '../models/menu_item.dart';

class BillPrinter {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  Function()? onTransactionAdded;
  List<bl.ScanResult> _scanResults = [];
  StreamSubscription<List<bl.ScanResult>>? _scanSubscription;

  Future<bool> printCart({
      required BuildContext context,
      required List<Map<String, dynamic>> cart1,
      required int total,
      required String mode,
      required String payment_mode,
      int? kot,
      Map<String, dynamic>? transactionData,
    }) async {
      try {
        final stopwatch = Stopwatch()..start();
        final cart = cart1;
        final int billNo = (transactionData?['billNo'] == null) ? getNextBillNo(context) : transactionData?['billNo'];
        debugPrint("check printer is connected $transactionData billNo $billNo");
        final device = await _getSavedPrinter();
        if (device != null) {
          
          bool? isConnected = await bluetooth.isConnected;
          debugPrint("check printer is connected ${isConnected} $transactionData");
          if (isConnected != true) {

            await bluetooth.connect(device);
            final store = Provider.of<ObjectBoxService>(context, listen: false).store;
            final box = store.box<Transaction>();
            debugPrint(" mode ${isConnected}  payment_mode $payment_mode");
            switch (mode) {
              case "kot":
                sendKotToPrinter(context: context,cart:cart,tableNumber: kot,kotNumber: 1,);
                return true;
              case "onlyPrint":
              // sendReceiptImageToPrinter(context: context, cart:cart, total:total, billNo: billNo,transactionData:transactionData);
                sendDataToPrinter(context: context, cart1:cart, total:total, billNo: billNo,transactionData:transactionData);
                return true;
              case "onlySettle":
                bluetooth.disconnect();
                int id  = await saveTransactionToObjectBox(
                  context: context,
                  cart: cart,
                  total: total,
                  tableNo: kot ?? 1,
                  pageback: 1,
                  payment_mode: payment_mode,
                  status: mode,
                  transactionData:transactionData
                );
                final prefs = await SharedPreferences.getInstance();
                final key = "table${kot}";
                prefs.remove(key);
                debugPrint("saveTransactionToObjectBox with id - $id  table $key ");
                sendTransactionToServer(box, id);
                return true;
            }

            if(payment_mode == "KOT"){
              sendKotToPrinter(context: context,cart:cart,tableNumber: 1,kotNumber: 1,);
            }else{
              // sendReceiptImageToPrinter(context: context, cart:cart, total:total, billNo: billNo,transactionData:transactionData);
              sendDataToPrinter(context: context, cart1:cart, total:total, billNo: billNo,transactionData:transactionData);
            }
            
            int pageback1 =0;
            if (mode == "settle1") pageback1 = 2;
            if (mode == "print") pageback1 = 3;
            late final String id;
            
            if (payment_mode.contains("_")) {
              List pm = payment_mode.split("_");
              String paymentMode = pm[0];
              id = pm[1];
              debugPrint("updateTransactionToObjectBox ID is $id and mode $payment_mode");
              await updateTransactionToObjectBox(
                context: context,
                cart: cart,
                total: total,
                tableNo: 1,
                pageback: pageback1,
                payment_mode: paymentMode,
                status: mode,
                id: id,
                transactionData:transactionData,
              );
              int gotId = int.parse(id);
              sendTransactionToServer(box, gotId);
              
            } else {
              // Provide a default value or handle the case where id is not needed
              debugPrint(" print onl calle in else ");
              int id  = await saveTransactionToObjectBox(
                context: context,
                cart: cart,
                total: total,
                tableNo: 1,
                pageback: pageback1,
                payment_mode: payment_mode,
                status: mode,
                transactionData:transactionData,
              );

              debugPrint("saveTransactionToObjectBox with id - $id ");
              sendTransactionToServer(box, id);
            }

            stopwatch.stop();
            debugPrint("send print function Processing time: ${stopwatch.elapsedMilliseconds}ms and ${stopwatch.elapsedMilliseconds/1000} s");
            }
          else {
           bluetooth.disconnect(); 
          }
        }
      } catch (e) {
        print("❌ Error while printing: $e");
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Printer Is Not Connected, Please Restart the Printer"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      } 

      return true;

    }


  int getNextBillNo(BuildContext context) {
    // 2. Find the existing counter object. There should only be one.
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final billCounterBox = store.box<BillCounter>();
    final existingCounters = billCounterBox.getAll();
    debugPrint("next bill number ${existingCounters}");
    int billNo = (existingCounters.isEmpty) ? 1 : existingCounters.first.lastBillNo;
    // if (existingCounters.isEmpty) {
    //   // 3a. If no counter exists (first time), create one starting at 1.
    //   counter = BillCounter(lastBillNo: 1);
    // } else {
    //   // 3b. If a counter exists, get it and increment the number.
     
    //   counter.lastBillNo++;
    // }
    // 5. Return the latest bill number.
    
    // int billNo = (existingCounters.isEmpty) ? 1 : counter.lastBillNo;
    debugPrint("next bill number ${billNo}");
    return billNo;
  }

  /// Fetches the current bill counter, increments it, saves it, and returns the new bill number.
  void setNextBillNo(BuildContext context, int billNo) async {
    // 1. Access the ObjectBox store and box for BillCounter
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final billCounterBox = store.box<BillCounter>();

    // 2. Get the existing counter (there should be only one)
    BillCounter? existingCounter = billCounterBox.getAll().isNotEmpty
        ? billCounterBox.getAll().first
        : null;

    // 3. Increment the bill number
    final nextBillNo = billNo + 1;
    debugPrint("✅ Saving next Bill No to ObjectBox: $nextBillNo");

    // 4. If a counter exists, update it; otherwise, create a new one
    if (existingCounter != null) {
      existingCounter.lastBillNo = existingCounter.lastBillNo + 1;
      billCounterBox.put(existingCounter);
    } else {
      BillCounter newCounter = BillCounter(lastBillNo: nextBillNo);
      billCounterBox.put(newCounter);
    }

    debugPrint("✅ BillCounter saved successfully with billNo: $nextBillNo");
  }



  Future<void> getavailabeldevice() async{
    final Set<bl.BluetoothDevice> discoveredDevices = {};

    print("Starting BLE scan for 5 seconds...");

    // 2. Start scanning and listen to the results
    final scanSubscription = bl.FlutterBluePlus.scanResults.listen((results) {
      for (bl.ScanResult r in results) {
        discoveredDevices.add(r.device);
      }
    });

    // Start the scan
    await bl.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // The scan automatically stops after the timeout.
    // We can cancel our subscription to the stream.
    scanSubscription.cancel();

    // 3. Format the results into a list of strings
    List<String> deviceList = discoveredDevices.map((device) {
      final deviceName = device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';
      final deviceAddress = device.remoteId.toString();
      return '$deviceName - [$deviceAddress]';
    }).toList();

    // 4. Print the final list to the console
    print("\n--- Scan Complete ---");
    if (deviceList.isNotEmpty) {
      print("Found ${deviceList.length} unique devices:");
      print(deviceList);
    } else {
      print("No devices found.");
    }
    print("---------------------\n");
    }

  Future<void> requestBluetoothPermissions() async {
    if (await Permission.bluetoothScan.request().isGranted) {
      // Permission is granted
    } else {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.request().isGranted) {
      // Permission is granted
    }else{
      await Permission.bluetoothConnect.request();
    }
  }

  Future<void> sendDataToPrinter(
  {
    required BuildContext context,
    required List<Map<String, dynamic>> cart1,
    required int total,
    required int billNo,
    required Map<String, dynamic>? transactionData,
  }
  ) async{
    debugPrint("recived cart to send to printer total $total and cart $cart1 billNo $billNo transactionData $transactionData");
    List<Map<String, dynamic>> cart = cart1.map((item) => Map<String, dynamic>.from(item)).toList();
    
    final prefs = await SharedPreferences.getInstance();
    double getQrPixelSize(qrSize) {
      switch (qrSize) {
        case "Small":
          return 150;
        case "Medium":
          return 180;
        case "Large":
          return 200;
        default:
          return 150;
      }
    }
    
    // 🏪 Business info
    String businessName = prefs.getString('businessName') ?? 'Hotel Test';
    String contactPhone = prefs.getString('contactPhone') ?? '';
    String contactEmail = prefs.getString('contactEmail') ?? '';
    String businessAddress = prefs.getString('businessAddress') ?? '';
    String gst = prefs.getString('gst') ?? '';
    

    // ⚙ Printer user settings
    bool printQr = prefs.getBool('printQR') ?? false;

    debugPrint("qr printer value: $printQr");
    

    String qrSize0 = prefs.getString('qrSize') ?? "Medium";
    double qrSize = getQrPixelSize(qrSize0);
    int headerFontSize = prefs.getInt('headerFontSize') ?? 3;
    int itemFontSize = (prefs.getDouble('fontSize') ?? 1).toInt();

    //logo
    await _printLogo(); // debugPrint saved logo first

    //bluetooth.printNewLine();
    bluetooth.printCustom(businessName, headerFontSize, 1);
    if (contactPhone.isNotEmpty) {
      bluetooth.printCustom("Ph: $contactPhone", itemFontSize, 1);
    }
    
    if (contactEmail.isNotEmpty) {
      bluetooth.printCustom(contactEmail, itemFontSize, 1);
    }
    
    if (businessAddress.isNotEmpty) {
      bluetooth.printCustom(businessAddress, itemFontSize, 1);
    }
    
    if (gst.isNotEmpty) bluetooth.printCustom("GST: $gst", itemFontSize, 1);
    
    bluetooth.printNewLine();
    bluetooth.printCustom("Bill No: ${billNo ?? 0}", itemFontSize, 1);
    await bluetooth.printLeftRight("Item", "Qty  Rate  Total", itemFontSize);
    
    await bluetooth.write("--------------------------------");
    await bluetooth.printNewLine();
    
    for (var item in cart) {
      String name = item['name'] ?? 'Item';
      int qty = item['qty'] ?? 0;
              final dynamic rawPrice = item['sellPrice'];
      final int rate = rawPrice is num
          ? rawPrice.toInt()
          : int.tryParse(rawPrice.toString().replaceAll(',', '')) ??
                double.tryParse(rawPrice.toString())?.toInt() ??
                0;
      debugPrint("rate  $rate and $cart");
      int total = qty * rate;
      String rightText =
          "${qty.toString().padLeft(2)}  ${rate.toString().padLeft(4)}  ${total.toString().padLeft(5)}";

      // Max width for the left side (depends on printer, ~15 chars for 58mm)
      const int maxNameWidth = 15;
      List<String> wrapped = _wrapText(name, maxNameWidth);
      for (int i = 0; i < wrapped.length; i++) {
        if (i == 0) {
          // First line → show name + qty/rate/total
          await bluetooth.printLeftRight(wrapped[i], rightText, itemFontSize);
        } else {
          // Extra lines → only name (empty right side)
          await bluetooth.printLeftRight(wrapped[i], "", itemFontSize);
        }
      }
    }

    //bluetooth.printReceipt(cart1, 1000);
    await bluetooth.write("--------------------------------");
    if (transactionData != null) {
      if (transactionData['discount'] != null && transactionData['discount'] > 0) {
        bluetooth.printNewLine();
        bluetooth.printCustom("Discount: ${transactionData['discount']}", 2, 2);
      }

      if (transactionData['serviceCharge'] != null && transactionData['serviceCharge'] > 0) {
        bluetooth.printNewLine();
        bluetooth.printCustom("Service Charge: ${transactionData['serviceCharge']}", 2, 2);
      }
    }
    bluetooth.printNewLine();
    bluetooth.printCustom("Total: Rs.$total", 2, 2);
    bluetooth.printNewLine();
    // ⭐ RESET PRINTER MODE - send some text commands to reset
    bluetooth.printCustom("", 1, 1); // Empty text to reset mode
    await Future.delayed(Duration(milliseconds: 500));
    if (printQr) {
      await _printQrCode(businessName, total, qrSize);
    }

    bluetooth.printCustom("", 1, 1); // Empty text to reset mode
    await Future.delayed(Duration(milliseconds: 500));
    bluetooth.printCustom("Thank you!", itemFontSize, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
    bluetooth.disconnect();

    debugPrint("before clear total $total and cart $cart");
    cart.clear();
    
    debugPrint("✅ only print for Table sent to printer. printer is connected ${bluetooth.isConnected}");
    debugPrint("after clear total $total and cart $cart");

  }
Future<void> sendReceiptImageToPrinter({
  required BuildContext context,
  required List<Map<String, dynamic>> cart,
  required int total,
  required int billNo,
  required Map<String, dynamic>? transactionData,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // 🏪 Business Info
  String businessName = prefs.getString('businessName') ?? 'Hotel Test';
  String contactPhone = prefs.getString('contactPhone') ?? '';
  String contactEmail = prefs.getString('contactEmail') ?? '';
  String businessAddress = prefs.getString('businessAddress') ?? '';
  String gst = prefs.getString('gst') ?? '';

  // 🖋️ Text Styles
  final headerStyle = const TextStyle(
    color: Colors.black,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
  final normalStyle = const TextStyle(color: Colors.black, fontSize: 20);
  final smallStyle = const TextStyle(color: Colors.black, fontSize: 18);

  // 🖼️ Create Image Canvas
  const double width = 500; // ~58mm printer width (500px)
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..color = Colors.white;
  double y = 20;

  canvas.drawRect(Rect.fromLTWH(0, 0, width, 2000), paint);

  void drawText(String text, TextStyle style, {TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: ui.TextDirection.ltr, // ✅ fixed
    )..layout(maxWidth: width - 40);

    double x = 20;
    if (align == TextAlign.center) x = (width - tp.width) / 2;
    if (align == TextAlign.right) x = width - tp.width - 20;
    tp.paint(canvas, Offset(x, y));
    y += tp.height + 6;
  }

  // 🧾 Build receipt layout
  drawText(businessName, headerStyle);
  if (contactPhone.isNotEmpty) drawText("Ph: $contactPhone", normalStyle);
  if (contactEmail.isNotEmpty) drawText(contactEmail, normalStyle);
  if (businessAddress.isNotEmpty) drawText(businessAddress, smallStyle);
  if (gst.isNotEmpty) drawText("GST: $gst", smallStyle);
  y += 10;
  drawText("Bill No: $billNo", normalStyle, align: TextAlign.left);
  drawText("----------------------------------------------", smallStyle);

  drawText("Item".padRight(20) + "Qty  Rate  Total", smallStyle, align: TextAlign.left);
  drawText("----------------------------------------------", smallStyle);

  for (var item in cart) {
    String name = item['name'] ?? 'Item';
    int qty = item['qty'] ?? 0;
    final dynamic rawPrice = item['sellPrice'];
    final int rate = rawPrice is num
        ? rawPrice.toInt()
        : int.tryParse(rawPrice.toString().replaceAll(',', '')) ??
              double.tryParse(rawPrice.toString())?.toInt() ??
              0;

    int itemTotal = qty * rate;
    drawText(name, normalStyle, align: TextAlign.left);
    drawText("     ${qty.toString().padLeft(2)}   ${rate.toString().padLeft(4)}   ${itemTotal.toString().padLeft(5)}",
        smallStyle,
        align: TextAlign.left);
  }

  drawText("----------------------------------------------", smallStyle);

  if (transactionData != null) {
    if (transactionData['discount'] != null && transactionData['discount'] > 0) {
      drawText("Discount: ${transactionData['discount']}", normalStyle, align: TextAlign.left);
    }
    if (transactionData['serviceCharge'] != null && transactionData['serviceCharge'] > 0) {
      drawText("Service Charge: ${transactionData['serviceCharge']}", normalStyle, align: TextAlign.left);
    }
  }

  drawText("Total: Rs. $total", headerStyle, align: TextAlign.right);
  y += 15;
  drawText("Thank you!", normalStyle, align: TextAlign.center);

  // ✅ Finish recording
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), (y + 40).toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  // 💾 Save image to temp file
  final directory = await getTemporaryDirectory();
  final path = '${directory.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png';
  final file = File(path);
  await file.writeAsBytes(pngBytes);
  debugPrint("🖼️ Receipt image saved at: $path");

  // 🖨️ Send image file to printer
  bool? connected = await bluetooth.isConnected;
  if (connected == null || !connected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚠️ Printer not connected')),
    );
    return;
  }

  await bluetooth.printImage(path);
  await bluetooth.printNewLine();
  await bluetooth.paperCut();

  debugPrint("✅ Receipt image sent to printer successfully!");
}

  /// Prints a Kitchen Order Ticket (KOT) with only essential information for the kitchen.
  Future<void> sendKotToPrinter({
    required BuildContext context,
    required List<Map<String, dynamic>> cart,
    int? tableNumber = 1,
    int? kotNumber = 1,
  }) async {
    // Use a copy of the cart to avoid modifying the original list
    List<Map<String, dynamic>> kotCart = cart.map((item) => Map<String, dynamic>.from(item)).toList();
    
    // --- KOT Header ---
    // A larger font size for high visibility in the kitchen
    const int headerFontSize = 3; 
    const int itemFontSize = 1; // Make item font slightly larger for readability

    bluetooth.printCustom("KOT", headerFontSize, 1);
    bluetooth.printCustom("Table No: $tableNumber", 2, 1);

    // Add current date and time, which is crucial for the kitchen
    final String dateTime = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
    bluetooth.printCustom(dateTime, 1, 1);
    
    if (kotNumber != null) {
        bluetooth.printCustom("KOT No: $kotNumber", 1, 1);
    }
    
    bluetooth.printNewLine();
    await bluetooth.printLeftRight("Item", "Qty", itemFontSize);
    await bluetooth.write("--------------------------------");
    await bluetooth.printNewLine();

    // --- Item List ---
    // Loop through items and print only the name and quantity
    for (var item in kotCart) {
      String name = item['name'] ?? 'Item';
      int qty = item['qty'] ?? 0;
      
      // No prices or totals are needed for the KOT
      String rightText = qty.toString();

      // Use text wrapping for long item names
      const int maxNameWidth = 15; // Allow more space for item names
      List<String> wrapped = _wrapTextkot(name, maxNameWidth);
      for (int i = 0; i < wrapped.length; i++) {
        if (i == 0) {
          // First line shows the item name and quantity
          await bluetooth.printLeftRight(wrapped[i], rightText, itemFontSize);
        } else {
          // Subsequent lines of a long name are indented
          await bluetooth.printLeftRight("  ${wrapped[i]}", "", itemFontSize);
        }
      }
    }

    await bluetooth.write("--------------------------------");
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    
    // --- Finalize Print Job ---
    bluetooth.paperCut();
    bluetooth.disconnect();
    
    debugPrint("✅ KOT for Table #$tableNumber sent to printer. printer is connected ${bluetooth.isConnected}");
  }

  /// Helper function to wrap long text based on a max width.
  List<String> _wrapTextkot(String text, int maxWidth) {
    List<String> lines = [];
    List<String> words = text.split(' ');
    String currentLine = '';

    for (String word in words) {
      if ((currentLine + ' ' + word).length <= maxWidth) {
        currentLine += ' ' + word;
      } else {
        lines.add(currentLine.trim());
        currentLine = word;
      }
    }
    lines.add(currentLine.trim());
    return lines;
  }

  Future<int> saveTransactionToObjectBox({
    required BuildContext context,
    required List<Map<String, dynamic>> cart,
    required int total,
    int? tableNo,
    int? pageback,
    required String payment_mode,
    required String status,
    required Map<String, dynamic>? transactionData,
  }) async {
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final box = store.box<Transaction>();

    final prefs = await SharedPreferences.getInstance();
    final businessDateString = prefs.getString('businessDate') ?? DateTime.now().toString();
    final now = DateTime.now();
    debugPrint("✅ business date from prefs ${prefs.getString('businessDate')} $payment_mode $transactionData");
    final businessDatePart = DateTime.parse(businessDateString);
    // debugPrint("business date ${businessDatePart}");
    final fullDateTime = DateTime(
      businessDatePart.year,
      businessDatePart.month,
      businessDatePart.day,
      now.hour,
      now.minute,
      now.second,
    );
    // debugPrint("Final combined DateTime: $fullDateTime"); // Will show the correct date and current time
    // debugPrint("now time in hhmmss: $now");
    late int createdId = 0;

    final tx = Transaction(
      time: fullDateTime,
      tableNo: tableNo,
      total: total,
      cartData: jsonEncode(cart),
      payment_mode: payment_mode,
      status:status,
      serviceCharge: transactionData?['serviceCharge'] ?? 0.0, // 1.0
      discount: transactionData?['discount'] ?? 0.0, // 10.0
      discountPercent: transactionData?['discountpercent'] ?? 0.0, // 0.0
      billNo:  transactionData?['billNo'] ?? 0,
      customerName: transactionData?['customerName'] ?? '', // '28282'
      mobileNo: transactionData?['mobileNo'] ?? '' // '386838'
    );
    debugPrint("Transaction Data to be sent: $tx");
    if(status != 'print1')
    {
      createdId = box.put(tx);
      adjustStock(context, cart);
     setNextBillNo(context, transactionData?['billNo']);
      debugPrint("✅ Transaction saved to ObjectBox with ID: $createdId");
    }
    
    onTransactionAdded?.call();
    // debugPrint("🔁 Transaction added callback fired!");
    // To go back to the very first screen (the "home" screen)
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    return createdId;
  }


Future<void> adjustStock(BuildContext context, List<Map<String, dynamic>> cart1) async {
  // Clone the cart list to avoid modifying the original
  List<Map<String, dynamic>> cart = cart1.map((item) => Map<String, dynamic>.from(item)).toList();

  // Access ObjectBox store and MenuItem box
  final store = Provider.of<ObjectBoxService>(context, listen: false).store;
  final Box<MenuItem> menuItemBox = store.box<MenuItem>();

  // Fetch all items from the database
  final List<MenuItem> allItems = menuItemBox.getAll();

  // Loop through each item in the cart
  for (var cartItem in cart) {
    final int? cartItemId = cartItem['id'];
    final int qtyToReduce = cartItem['qty'] ?? 0;

    if (cartItemId == null || qtyToReduce <= 0) continue;

    // Find the matching MenuItem in ObjectBox
    final MenuItem? menuItem = allItems.firstWhere(
      (item) => item.id == cartItemId,
      // orElse: () => null,
    );

    if (menuItem != null) {
      // Adjust stock safely (prevent going below 0)
      int currentStock = menuItem.adjustStock ?? 0;
      int newStock = (currentStock - qtyToReduce).clamp(0, double.infinity).toInt();

      // Update the item
      menuItem.adjustStock = newStock;

      // Save back to ObjectBox
      menuItemBox.put(menuItem);
    }
  }

  debugPrint("✅ Stock adjusted successfully for ${cart.length} items.");
}



  Future<bool> isDeviceConnected() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.bluetooth) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet)) {
      // Now, check for actual internet access
      debugPrint(" connectivityResult ${connectivityResult}");
      return await InternetConnection().hasInternetAccess;
    }
    return false;
  }

  Future<void> updateTransactionToObjectBox({
    required BuildContext context,
    required List<Map<String, dynamic>> cart,
    required int total,
    int? tableNo,
    int? pageback,
    required String payment_mode,
    required String status,
    required String id, // This is the string ID of the transaction to update
    Map<String, dynamic>? transactionData,
  }) async {
    debugPrint("🔁 in _updateTransactionToObjectBox");
    final int transactionId = int.parse(id);
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final box = store.box<Transaction>();
    final prefs = await SharedPreferences.getInstance();
    final businessDateString = prefs.getString('BusinessDate') ?? DateTime.now().toString();
    final now = DateTime.now();
    final businessDatePart = DateTime.parse(businessDateString);
    final fullDateTime = DateTime(
      businessDatePart.year,
      businessDatePart.month,
      businessDatePart.day,
      now.hour,
      now.minute,
      now.second,
    );

    // 1. Find the existing transaction by its ID
    final existingTx = box.get(transactionId);
    debugPrint("🔁 Transaction to update $existingTx ");

    // 2. Check if the transaction was actually found
    if (existingTx != null) {
      if (status == 'print1') {
        debugPrint("⏩ Skipping update for print1 status");
        return; // Exit the function early if no update is needed
      }

      debugPrint("in bill debugPrint update transactionData $transactionData $tableNo and $total and ${cart.length} and $payment_mode and $status");
      // 3. Modify only the properties of the existing transaction
      existingTx.time = fullDateTime;
      existingTx.total = total;
      existingTx.cartData = jsonEncode(cart);
      existingTx.payment_mode = payment_mode;
      existingTx.status = status;
      existingTx.synced = false; // Mark as unsynced after modification
      existingTx.serviceCharge = transactionData?['serviceCharge'] ?? 0.0; // 1.0
      existingTx.discount = transactionData?['discount'] ?? 0.0; // 10.0
      existingTx.customerName = transactionData?['customerName'] ?? ''; // '28282'
      existingTx.mobileNo = transactionData?['mobileNo'] ?? ''; // '386838'

      // 4. Put the modified object back into the box
      box.put(existingTx);
      debugPrint("✅ Transaction updated in ObjectBox: $existingTx");

      onTransactionAdded?.call(); // Fire the callback
      debugPrint("🔁 Transaction updated callback fired!");

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();
      
      // Navigate back
      // To go back to the very first screen (the "home" screen)
      Navigator.of(context).popUntil((route) => route.isFirst);
      
    } else {
      // 5. Handle the case where no transaction with that ID was found
      debugPrint("❌ Error: Transaction with ID $transactionId not found. Cannot update.");
      // Optionally show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Could not find the transaction to update.")),
      );
    }
  }

  /// Attempt to send a transaction to the server
  Future<bool> sendTransactionToServer(Box<Transaction> box,int id,) async {
    try {

      final existingTx = box.get(id);
      final prefs = await SharedPreferences.getInstance();
      // final isConnected = await isDeviceConnected();
      final isConnected = prefs.getBool('isOnline');
      debugPrint("❌ isConnected $isConnected not found");
      if (isConnected != true) { return false;}
      debugPrint("✅ sendTransactionToServer: ${existingTx}  and ${existingTx?.payment_mode}");
      if (existingTx == null) {
        debugPrint("❌ Transaction with ID $id not found");
        return false;
      }

      
      String businessName = prefs.getString('businessName') ?? 'Hotel Test';
      String login_user = prefs.getString('username') ?? 'Hotel Test';
      String cart_String = existingTx.cartData.toString().replaceAll('"', "'");
      final payload = {
        "transactions_id": id,
        "hotelName": login_user,
        "tableNo": existingTx.tableNo,
        "total": existingTx.total,
        "cartData": cart_String,
        "payment_mode": existingTx.payment_mode,
        "time": existingTx.time.toIso8601String(),
        "login_user":login_user,
      };

      debugPrint("payload $payload ");

      final response = await http
          .post(
            Uri.parse("https://api2.nextorbitals.in/api/save_transaction.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        existingTx.synced = true;
        // debugPrint("✅ sendTransactionToServer: ${existingTx} and ${existingTx.synced}");
        box.put(existingTx);
        debugPrint("✅ sendTransactionToServer: ${response.body}");
        return true;
      } else {
        debugPrint("❌ sendTransactionToServer failed: ${response.statusCode} and body ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error sending transaction: $e");
    }

    return false;
  }


  void listenForNetworkChanges(BuildContext context) {
    print("network state changed");
    final objectBoxService = Provider.of<ObjectBoxService>(
      context,
      listen: false,
    );
    final store = objectBoxService.store;
    final box = store.box<Transaction>();

    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("you are online, wite to async transections"),
          ),
        );

        // await _syncPendingTransactions(context);
      }
    });
  }

  Future<void> syncPendingTransactions(BuildContext context) async {
    try {

      final objectBoxService = Provider.of<ObjectBoxService>(context,listen: false,);
      final store = objectBoxService.store;
      final box = store.box<Transaction>();
      final unsyncedIds = box.getAll().where((tx) => !(tx.synced)).map((tx) => tx.id).toList();
      debugPrint("Unsynced transaction IDs: $unsyncedIds");
      // final isOnline = await isDeviceOnline();
      // final isOnline = await isDeviceConnected();
      final prefs = await SharedPreferences.getInstance();
      final isOnline = prefs.getBool('isOnline') ?? true;
      debugPrint("isOnline: $isOnline unsyncedIds.isNotEmpty: ${unsyncedIds.isNotEmpty} both: ${isOnline && unsyncedIds.isNotEmpty}");
      if(isOnline && unsyncedIds.isNotEmpty){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("you are online, ⏳ wait to async ${unsyncedIds.length} transaction " ),
            duration: Duration(seconds: 1),
          ),
        );
      }
      else{
        return;
      }

      int successfulSyncs = 0;
      for (int i in unsyncedIds) {
        try {
          // Wait for 1 second before sending (except for the first one)
          if (i > 0) {
            await Future.delayed(Duration(milliseconds: 100));
          }
          final success = await sendTransactionToServer(box, i);
          if (success) {
            successfulSyncs++;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⏳ wait sending transaction ${successfulSyncs}/${unsyncedIds.length}" ),
                duration: Duration(milliseconds: 50),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("❌ Error sending transaction $i" ),
                duration: Duration(milliseconds: 50),
              ),
            );
          }
        } catch (e) {
          debugPrint("❌ Got Exception Transaction failed ${unsyncedIds.length} $e ");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Got Exception Transaction failed ${unsyncedIds.length} $e "),
              duration: Duration(milliseconds: 50),
            ),
          );
          break;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sending Transaction Completed ${successfulSyncs}/${unsyncedIds.length}" ),
          duration: Duration(seconds: 4),
          backgroundColor: Colors.teal,
        ),
      );

    } catch (e) {
      print("❌ Error in sync process: $e");
    }
  }

  // helper function
  List<String> _wrapText(String text, int width) {
    List<String> lines = [];
    while (text.length > width) {
      lines.add(text.substring(0, width));
      text = text.substring(width);
    }
    if (text.isNotEmpty) lines.add(text);
    return lines;
  }

  Future<void> _printLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString('imagePath');

      if (imagePath != null && File(imagePath).existsSync()) {
        final file = File(imagePath);
        final bytes = await file.readAsBytes();

        // Decode the image
        img.Image? original = img.decodeImage(bytes);
        if (original != null) {
          // Resize to fit 52mm paper (usually 384px width for 58mm printer, 52mm ~ 350px)
          final resized = img.copyResize(original, width: 350);

          // Save resized temp file
          final resizedPath = '${file.parent.path}/resized_logo.png';
          final resizedFile = File(resizedPath)
            ..writeAsBytesSync(img.encodePng(resized));

          // debugPrint resized logo
          bluetooth.printImage(resizedFile.path);
          bluetooth.printNewLine();

          // ⭐ RESET PRINTER MODE - send some text commands to reset
          bluetooth.printCustom("", 1, 1); // Empty text to reset mode
          await Future.delayed(Duration(milliseconds: 400));
        }
      } else {
        debugPrint("⚠️ No logo found in SharedPreferences");
      }
    } catch (e) {
      debugPrint("❌ Error printing logo: $e");
    }
  }

  Future<BluetoothDevice?> _getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    String? address = prefs.getString('saved_printer_address');
    if (address == null) return null;

    List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
    try {
      return devices.firstWhere((d) => d.address == address);
    } catch (e) {
      return null; // Return null if no match found
    }
  }

  // Optional: Call this at app start (e.g., in main or splash)
  Future<void> autoConnectIfSaved() async {
    final device = await _getSavedPrinter();
    if (device == null) return;

    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected != true) {
        await bluetooth.connect(device);
        debugPrint("✅ Auto-connected to saved printer.");
      }
    } catch (e) {
      debugPrint("❌ Auto-connect failed: $e");
    }
  }

  // Optional: Save printer on setup page
  static Future<void> savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_printer_address', device.address ?? '');
    debugPrint("✅ Saved printer: ${device.name}");
  }

  Future<void> _printQrCode(
    String businessName,
    int total,
    double qrSize,
  ) async {
    // 🔹 Read UPI ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String upiId = prefs.getString('upi') ?? '';

    if (upiId.isEmpty) {
      debugPrint("❌ No UPI ID saved in settings.");
      return; // Exit if UPI not found
    }

    // 🔹 Create UPI payment link
    String qrData = "upi://pay?pa=$upiId&pn=$businessName&am=$total&cu=INR";

    // 🔹 Validate and generate QR code
    final qrValidationResult = QrValidator.validate(
      data: qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );

    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode;
      final painter = QrPainter.withQr(
        qr: qrCode!,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );

      // 🔹 Save QR image temporarily
      final tempDir = await getTemporaryDirectory();
      String qrPath = '${tempDir.path}/qr.png';
      final picData = await painter.toImageData(
        qrSize,
        format: ui.ImageByteFormat.png,
      );
      final file = File(qrPath);
      await file.writeAsBytes(picData!.buffer.asUint8List());

      // 🔹 debugPrint QR
      bluetooth.printNewLine();
      bluetooth.printImage(qrPath);
      bluetooth.printNewLine();
    }
  }

}
