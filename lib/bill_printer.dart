import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:test1/utilities.dart';
import 'dart:io';
import 'cartprovier/cart_provider.dart';
import 'package:provider/provider.dart';
import 'database_Module/transaction.dart';
import 'database_Module/ObjectBoxService.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as thermal;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '/objectbox.g.dart';
import 'package:intl/intl.dart';
import 'database_Module/BillCounter.dart';
import 'database_Module/menu_item.dart';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'database_Module/tableCart.dart';

enum PrintQuality { light, normal, dark, maximum }

enum SoundPattern { shortBeep, longBeep, doubleBeep, tripleBeep, continuous }

class BillPrinter {
  thermal.BlueThermalPrinter printer = thermal.BlueThermalPrinter.instance;
  thermal.BluetoothDevice? _connectedDevice;
  Generator? _generator;
  Function()? onTransactionAdded;
  late List<int> bytes = [];
  final int printerWidth = 384;
  late bool KOT_Print = false;
  late Store store;

  Future<bool> printCart({
    required BuildContext context,
    required List<Map<String, dynamic>> cart1,
    required int total,
    required String mode,
    required String payment_mode,
    List<Map<String, dynamic>>? oldcart1,
    int? tableNo,
    Map<String, dynamic>? transactionData,
  }) async {
    try {
      store = Provider.of<ObjectBoxService>(context, listen: false).store;
      bytes = [];
      final stopwatch = Stopwatch()..start();
      final cart = (oldcart1 != null) ? oldcart1 : cart1;
      final _tableno = tableNo ?? 0;
      final prefs = await SharedPreferences.getInstance();
      final int billNo = (transactionData?['billNo'] == null)
          ? getNextBillNo(context)
          : transactionData?['billNo'];

      debugPrint(
        "check printer is connected total $total mode $mode payment_mode $payment_mode  $transactionData billNo $billNo",
      );

      KOT_Print =
          mode.toLowerCase().contains("kot") ||
          payment_mode.toLowerCase().contains("kot");

      final device = await _getSavedPrinter(
        KOTmode: KOT_Print,
        context: context,
      );
      bool settle_button_enabled =
          prefs.getBool("settle_button_enabled") ?? false;

      if (device != null || settle_button_enabled) {
        bool isConnected = await _isConnected();
        debugPrint(
          "check printer is connected ${isConnected} $transactionData",
        );

        if (!isConnected || settle_button_enabled) {
          bytes = [];

          final store = Provider.of<ObjectBoxService>(
            context,
            listen: false,
          ).store;
          final box = store.box<Transaction>();
          print_log(
            "settle_button_enabled mode ${isConnected}  payment_mode $payment_mode settle_button_enabled $settle_button_enabled",
          );
          int pageback1 = 0;
          // if (mode == "settle1") pageback1 = 2;
          if (_tableno > 0) pageback1 = 1;

          if (settle_button_enabled) {
            await settel_update(
              context: context,
              prefs: prefs,
              box: box,
              cart: cart,
              oldcart1: oldcart1,
              total: total,
              tableNo: _tableno,
              pageback: pageback1,
              payment_mode: payment_mode,
              mode: mode,
              transactionData: transactionData,
            );
            return true;
          } else {
            bool isconnected = await _connectToPrinter(device!);
            if (!isconnected) {
              return false;
            }
          }

          switch (mode.toLowerCase()) {
            case "only_kot":
              await sendKotToPrinter(
                context: context,
                cart: cart,
                tableNumber: _tableno,
                kotNumber: transactionData?['billNo'],
                transactionData: transactionData,
              );
              return true;
            case "onlyprint":
              await sendDataToPrinter(
                context: context,
                cart1: cart,
                total: total,
                billNo: billNo,
                tableNumber: _tableno,
                transactionData: transactionData,
              );
              return true;
            case "onlysettle":
              await _disconnect();

              final ttid = prefs.getInt("tt$tableNo");
              final isnonzero = areAllQuantitiesZero(cart);
              print_log("qty check  ${isnonzero} > 0");
              if (isnonzero) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Please ckeck the cart"),
                    duration: Duration(seconds: 1),
                  ),
                );
                return false;
              }
              int id;
              if (ttid != null) {
                id = ttid;
                await updateTransactionToObjectBox(
                  context: context,
                  cart: cart,
                  total: total,
                  tableNo: _tableno,
                  pageback: pageback1,
                  payment_mode: payment_mode,
                  status: mode,
                  id: ttid.toString(),
                  transactionData: transactionData,
                );
                // int gotId = int.parse(ttid.toString());
                sendTransactionToServer(box, ttid);
              } else {
                id = await saveTransactionToObjectBox(
                  context: context,
                  cart: cart,
                  total: total,
                  tableNo: _tableno,
                  pageback: pageback1,
                  payment_mode: payment_mode,
                  status: mode,
                  transactionData: transactionData,
                );
              }

              final key = "table${tableNo}";
              final message = 'clear table cart data $key';
              debugPrint('\x1B[31m $message \x1B[0m');
              // prefs.remove(key);
              deletetablecart(_tableno);
              debugPrint(
                "saveTransactionToObjectBox with id - $id  table $key ",
              );
              sendTransactionToServer(box, id);
              prefs.remove("tt$tableNo");
              return true;
          }

          if (payment_mode.toLowerCase().contains("kot")) {
            await sendKotToPrinter(
              context: context,
              cart: cart,
              tableNumber: _tableno,
              kotNumber: transactionData?['billNo'],
              transactionData: transactionData,
            );
          } else {
            await sendDataToPrinter(
              context: context,
              cart1: cart,
              total: total,
              billNo: billNo,
              tableNumber: _tableno,
              transactionData: transactionData,
            );
          }

          late final String id;
          final isnonzero = areAllQuantitiesZero(cart);
          print_log("qty check  ${isnonzero} > 0");
          if (isnonzero) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Please ckeck the cart"),
                duration: Duration(seconds: 1),
              ),
            );
            return false;
          }
          if (payment_mode.contains("_")) {
            List pm = payment_mode.split("_");
            String paymentMode = pm[0];
            id = pm[1];
            debugPrint(
              "updateTransactionToObjectBox ID is $id and mode $payment_mode",
            );
            await updateTransactionToObjectBox(
              context: context,
              cart: cart,
              total: total,
              tableNo: _tableno,
              pageback: pageback1,
              payment_mode: paymentMode,
              status: mode,
              id: id,
              transactionData: transactionData,
            );
            int gotId = int.parse(id);
            sendTransactionToServer(box, gotId);
          } else {
            int id = await saveTransactionToObjectBox(
              context: context,
              cart: cart,
              total: total,
              tableNo: _tableno,
              pageback: pageback1,
              payment_mode: payment_mode,
              status: mode,
              transactionData: transactionData,
            );

            debugPrint("saveTransactionToObjectBox with id - $id ");
            sendTransactionToServer(box, id);
            if (_tableno > 0) {
              prefs.setInt("tt$tableNo", id);
            }
          }

          stopwatch.stop();
          debugPrint(
            "send print function Processing time: ${stopwatch.elapsedMilliseconds}ms and ${stopwatch.elapsedMilliseconds / 1000} s",
          );
        } else {
          await _disconnect();
        }
      }
    } catch (e) {
      print_log_red("❌ Error while printing: $e");
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Printer Is Not Connected, Please Restart the Printer"),
          duration: Duration(seconds: 5),
        ),
      );
    }

    return true;
  }

  // Bluetooth connection methods with blue_thermal_printer
  Future<bool> _connectToPrinter(
    thermal.BluetoothDevice device, {
    BuildContext? context,
  }) async {
    try {
      // Connect using blue_thermal_printer
      await printer.connect(device);

      // Initialize generator
      final prefs = await SharedPreferences.getInstance();
      String paperSize = prefs.getString('paperSize') ?? '2';
      debugPrint("--- paperSize $paperSize ---");

      // Load capability profile
      final profile = await CapabilityProfile.load();

      // Set paper size based on preference
      PaperSize size;
      switch (paperSize) {
        case "2":
          size = PaperSize.mm58;
          break;
        case "3":
          size = PaperSize.mm72;
          break;
        case "4":
          size = PaperSize.mm80;
          break;
        default:
          size = PaperSize.mm58;
      }

      _generator = Generator(size, profile);
      _connectedDevice = device;

      debugPrint("✅ Connected to printer: ${device.name}");
      return true;
    } catch (e) {
      debugPrint("❌ Error connecting to printer: $e");
      return false;
    }
  }

  Future<bool> _isConnected({BuildContext? context}) async {
    final connected = await printer.isConnected;
    return connected == true;
  }

  Future<void> _disconnect({BuildContext? context}) async {
    await printer.disconnect();
    _connectedDevice = null;
    _generator = null;
  }

  Future<void> _sendToPrinter({
    Uint8List? imageBytes,
    BuildContext? context,
  }) async {
    final isConnected = await _isConnected();
    if (!isConnected) {
      throw Exception("Printer not connected");
    }

    final prefs = await SharedPreferences.getInstance();
    final bool miniPrinter = prefs.getBool('miniPrinter') ?? false;
    final bool miniPrinterKOT = prefs.getBool('miniPrinterKOT') ?? false;

    if (bytes.isNotEmpty) {
      // Convert bytes to Uint8List
      final data = Uint8List.fromList(bytes);

      // Send the data to printer
      await printer.writeBytes(data);

      // Wait for printer to process
      await Future.delayed(Duration(milliseconds: 100));
    }

    bytes = [];
    debugPrint("🎉 All data sent successfully to printer!");
  }

  int getNextBillNo(BuildContext context) {
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final billCounterBox = store.box<BillCounter>();
    final existingCounters = billCounterBox.getAll();
    debugPrint("next bill number ${existingCounters}");
    int billNo = (existingCounters.isEmpty)
        ? 1
        : existingCounters.first.lastBillNo;
    debugPrint("next bill number ${billNo}");
    return billNo;
  }

  void setNextBillNo(BuildContext context, int billNo) async {
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final billCounterBox = store.box<BillCounter>();

    BillCounter? existingCounter = billCounterBox.getAll().isNotEmpty
        ? billCounterBox.getAll().first
        : null;

    final nextBillNo = billNo + 1;
    debugPrint("✅ Saving next Bill No to ObjectBox: $nextBillNo");

    if (existingCounter != null) {
      existingCounter.lastBillNo = existingCounter.lastBillNo + 1;
      billCounterBox.put(existingCounter);
    } else {
      BillCounter newCounter = BillCounter(lastBillNo: nextBillNo);
      billCounterBox.put(newCounter);
    }

    debugPrint("✅ BillCounter saved successfully with billNo: $nextBillNo");
  }

  Future<void> sendDataToPrinter({
    required BuildContext context,
    required List<Map<String, dynamic>> cart1,
    required int total,
    required int billNo,
    required Map<String, dynamic>? transactionData,
    required int? tableNumber,
  }) async {
    try {
      debugPrint("🖨 Printing bill $billNo total $total");

      List<Map<String, dynamic>> cart = cart1
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final prefs = await SharedPreferences.getInstance();

      // ---------------- BUSINESS INFO ----------------
      String businessName = prefs.getString('businessName') ?? '';
      String contactPhone = prefs.getString('contactPhone') ?? '';
      String contactEmail = prefs.getString('contactEmail') ?? '';
      String businessAddress = prefs.getString('businessAddress') ?? '';
      String gst = prefs.getString('gst') ?? '';
      String? upiId = prefs.getString('upi');

      bool printLogo = prefs.getBool('printLogo') ?? true;
      bool printQr = prefs.getBool('printQR') ?? true;
      bool printName = prefs.getBool('printName') ?? true;
      bool customerName = prefs.getBool('customerName') ?? false;

      String footer = prefs.getString('footerText') ?? '** THANK YOU **';

      int headerFontSize = (prefs.getInt('headerFontSize') ?? 2).clamp(1, 3);

      int itemFontSize = (prefs.getDouble('fontSize') ?? 1).round().clamp(1, 3);

      final String dateTime = DateFormat(
        'dd-MMM-yyyy hh:mm a',
      ).format(DateTime.now());

      if (_generator == null) {
        throw Exception("Printer generator not initialized");
      }

      // ---------------- RESET & DARK PRINT ----------------
      bytes = [];
      bytes += _generator!.reset();

      // 🔥 DARK PRINT DENSITY (IMPORTANT)
      bytes += [0x1D, 0x7C, 0x0A];

      bytes += _generator!.clearStyle();

      // ---------------- LOGO ----------------
      if (printLogo) {
        await _printHotelLogo(prefs);
        await _sendToPrinter();
        bytes = [];
        bytes += _generator!.reset();
        bytes += [0x1D, 0x7C, 0x0A];
        bytes += _generator!.clearStyle();
      }

      // ---------------- HEADER ----------------
      List<String> _splitTextToLines(String text, int maxWidth) {
        List<String> lines = [];
        List<String> words = text.split(' ');
        String currentLine = '';

        for (String word in words) {
          // Check if current line is empty
          if (currentLine.isEmpty) {
            currentLine = word;
          }
          // Check if adding this word would exceed maxWidth
          else if ((currentLine.length + 1 + word.length) > maxWidth) {
            // Add current line to result and start new line with current word
            lines.add(currentLine);
            currentLine = word;
          }
          // Word fits in current line
          else {
            currentLine = '$currentLine $word';
          }
        }

        // Add the last line
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }

        return lines;
      }

      if (printName && businessName.isNotEmpty) {
        int maxLineWidth = 25; //

        List<String> nameLines = _splitTextToLines(businessName, maxLineWidth);

        for (String line in nameLines) {
          bytes += _generator!.text(
            line,
            styles: PosStyles(
              align: PosAlign.center,
              bold: true,
              fontType: PosFontType.fontA,
              height: _textSizeFromInt(headerFontSize),
              width: _textSizeFromInt(headerFontSize),
            ),
          );
        }
      }
      if (contactPhone.isNotEmpty) {
        bytes += _generator!.text(
          'Ph: $contactPhone',
          styles: PosStyles(align: PosAlign.center),
        );
      }

      if (contactEmail.isNotEmpty) {
        bytes += _generator!.text(
          contactEmail,
          styles: PosStyles(align: PosAlign.center),
        );
      }

      if (businessAddress.isNotEmpty) {
        bytes += _generator!.text(
          businessAddress,
          styles: PosStyles(align: PosAlign.center),
        );
      }

      if (gst.isNotEmpty) {
        bytes += _generator!.text(
          'GST: $gst',
          styles: PosStyles(align: PosAlign.center),
        );
      }

      bytes += _generator!.hr();

      // ---------------- BILL INFO ----------------
      bytes += _generator!.text(
        tableNumber != null
            ? 'Bill No: $billNo  |  Table: $tableNumber'
            : 'Bill No: $billNo',
        styles: PosStyles(bold: true, align: PosAlign.center),
      );

      bytes += _generator!.text(
        'Time: $dateTime',
        styles: PosStyles(align: PosAlign.center),
      );

      bytes += _generator!.hr();

      // ---------------- CUSTOMER INFO ----------------
      if (customerName && transactionData != null) {
        if ((transactionData['customerName'] ?? '').toString().isNotEmpty) {
          bytes += _generator!.text(
            'Customer: ${transactionData['customerName']}',
            styles: PosStyles(bold: true),
          );
        }

        if ((transactionData['mobileNo'] ?? '').toString().isNotEmpty) {
          bytes += _generator!.text('Mobile: ${transactionData['mobileNo']}');
        }

        if ((transactionData['reserved'] ?? '').toString().isNotEmpty) {
          bytes += _generator!.text('Address: ${transactionData['reserved']}');
        }

        bytes += _generator!.hr();
      }

      // ---------------- ITEM HEADER ----------------
      bytes += _generator!.row([
        PosColumn(text: 'Item', width: 6, styles: PosStyles(bold: true)),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'Rate',
          width: 2,
          styles: PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'Amt',
          width: 2,
          styles: PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      bytes += _generator!.hr();

      // ---------------- CART ITEMS ----------------
      for (var item in cart) {
        String name = item['name'] ?? '';
        int qty = item['qty'] ?? 0;

        int rate = (item['sellPrice'] is num)
            ? (item['sellPrice'] as num).toInt()
            : int.tryParse(item['sellPrice'].toString()) ?? 0;

        int amt = qty * rate;

        bytes += _generator!.row([
          PosColumn(
            text: name,
            width: 6,
            styles: PosStyles(
              bold: true,
              fontType: PosFontType.fontA,
              height: _textSizeFromInt(itemFontSize),
            ),
          ),
          PosColumn(
            text: qty.toString(),
            width: 2,
            styles: PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: rate.toString(),
            width: 2,
            styles: PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: amt.toString(),
            width: 2,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      // ---------------- TOTAL ----------------
      bytes += _generator!.hr();
      bytes += _generator!.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: PosStyles(
            bold: true,
            fontType: PosFontType.fontA,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
        PosColumn(
          text: 'Rs. $total',
          width: 6,
          styles: PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      ]);

      bytes += _generator!.hr();

      // ---------------- QR PAYMENT ----------------
      if (printQr && upiId != null && upiId.isNotEmpty) {
        bytes += _generator!.text(
          'Scan to Pay',
          styles: PosStyles(align: PosAlign.center, bold: true),
        );

        bytes += _generator!.qrcode(
          'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$total&cu=INR',
          size: QRSize.size6,
        );
      }

      // ---------------- FOOTER ----------------
      bytes += _generator!.text(
        footer,
        styles: PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += _generator!.feed(3);
      //bytes += _generator!.cut();

      debugPrint("✅ Print bytes: ${bytes.length}");
      await _sendToPrinter();
      await _disconnect();
    } catch (e) {
      print_log_red("❌ Print error: $e");
    }
  }

  // ==============================================
  // HELPER METHOD TO SPLIT LONG ITEM NAMES
  // ==============================================
  List<String> _splitItemName(String name, {int maxLineLength = 16}) {
    List<String> lines = [];

    if (name.length <= maxLineLength) {
      // If name is short enough, return as single line
      lines.add(name);
      return lines;
    }

    // Split by words first
    List<String> words = name.split(' ');
    String currentLine = '';

    for (String word in words) {
      // Check if adding this word would exceed the max line length
      if ((currentLine + ' ' + word).length <= maxLineLength) {
        // Add word to current line
        if (currentLine.isEmpty) {
          currentLine = word;
        } else {
          currentLine += ' ' + word;
        }
      } else {
        // Save current line and start new line
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }

        // If word itself is longer than maxLineLength, split the word
        if (word.length > maxLineLength) {
          // Split long word into chunks
          for (int i = 0; i < word.length; i += maxLineLength) {
            int end = i + maxLineLength;
            if (end > word.length) end = word.length;
            lines.add(word.substring(i, end));
          }
          currentLine = '';
        } else {
          currentLine = word;
        }
      }
    }

    // Add the last line if not empty
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    // Ensure we don't have too many lines (limit to 3 lines maximum)
    if (lines.length > 2) {
      lines = lines.sublist(0, 2);
      // Truncate the last line if needed
      if (lines[2].length > maxLineLength) {
        lines[2] = lines[2].substring(0, maxLineLength - 2) + '...';
      }
    }

    return lines;
  }

  // ==============================================
  // HELPER METHOD TO PRINT HOTEL LOGO
  // ==============================================
  Future<void> _printHotelLogo(SharedPreferences prefs) async {
    try {
      final imagePath = prefs.getString('imagePath');
      final printLogo = prefs.getBool('printLogo') ?? true;
      int logoWidth = prefs.getInt('logoWidth') ?? 200;

      if (imagePath != null && File(imagePath).existsSync() && printLogo) {
        final file = File(imagePath);

        if (!await file.exists()) {
          debugPrint("❌ Logo file not found at: $imagePath");
          return;
        }

        final imageBytes = await file.readAsBytes();
        final img.Image? original = img.decodeImage(imageBytes);

        if (original == null) {
          debugPrint("❌ Failed to decode image at: $imagePath");
          return;
        }

        // Resize the image
        final resized = img.copyResize(
          original,
          width: logoWidth,
          maintainAspect: true,
        );

        // Convert to grayscale for better thermal printing
        final grayscale = img.grayscale(resized);

        // Add the image to the bytes buffer
        bytes += _generator!.image(grayscale, align: PosAlign.center);

        debugPrint("✅ Logo added to print buffer successfully.");
      }
    } catch (e, stack) {
      debugPrint("❌ Error adding logo: $e");
      debugPrint("Stack trace: $stack");
    }
  }

  PosTextSize _textSizeFromInt(int size) {
    switch (size) {
      case 1:
        return PosTextSize.size1;
      case 2:
        return PosTextSize.size2;
      case 3:
        return PosTextSize.size3;
      case 4:
        return PosTextSize.size4;
      case 5:
        return PosTextSize.size5;
      case 6:
        return PosTextSize.size6;
      case 7:
        return PosTextSize.size7;
      case 8:
        return PosTextSize.size8;
      default:
        return PosTextSize.size1;
    }
  }

  Future<bool> settel_update({
    required BuildContext context,
    required SharedPreferences prefs,
    required Box<Transaction> box,
    required List<Map<String, dynamic>> cart,
    List<Map<String, dynamic>>? oldcart1,
    required int total,
    required int tableNo,
    int? pageback,
    required String payment_mode,
    required String mode,
    required Map<String, dynamic>? transactionData,
  }) async {
    if (tableNo > 0) {
      final ttid = prefs.getInt("tt$tableNo");
      final isnonzero = areAllQuantitiesZero(cart);
      print_log("qty check  ${isnonzero} > 0");
      if (isnonzero) {
        screen_massage(context, "Please ckeck the cart");
        return false;
      }
      int id;
      if (ttid != null) {
        id = ttid;
        await updateTransactionToObjectBox(
          context: context,
          cart: cart,
          total: total,
          tableNo: tableNo,
          pageback: pageback,
          payment_mode: payment_mode,
          status: mode,
          id: ttid.toString(),
          transactionData: transactionData,
        );
        sendTransactionToServer(box, ttid);
      } else {
        id = await saveTransactionToObjectBox(
          context: context,
          cart: cart,
          total: total,
          tableNo: tableNo,
          pageback: pageback,
          payment_mode: payment_mode,
          status: mode,
          transactionData: transactionData,
        );
      }

      final key = "table${tableNo}";
      final message = 'clear table cart data $key';
      debugPrint('\x1B[31m $message \x1B[0m');
      deletetablecart(tableNo);
      debugPrint("saveTransactionToObjectBox with id - $id  table $key ");
      sendTransactionToServer(box, id);
      prefs.remove("tt$tableNo");
      return true;
    } else {
      late final String id;
      final final_cart = (oldcart1 != null) ? oldcart1 : cart;
      final isnonzero = areAllQuantitiesZero(final_cart);
      print_log("qty check  ${isnonzero} > 0");
      if (isnonzero) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please ckeck the cart"),
            duration: Duration(seconds: 1),
          ),
        );
        return false;
      }
      if (payment_mode.contains("_")) {
        List pm = payment_mode.split("_");
        String paymentMode = pm[0];
        id = pm[1];
        debugPrint(
          "updateTransactionToObjectBox ID is $id and mode $payment_mode",
        );
        await updateTransactionToObjectBox(
          context: context,
          cart: cart,
          total: total,
          tableNo: tableNo,
          pageback: pageback,
          payment_mode: paymentMode,
          status: mode,
          id: id,
          transactionData: transactionData,
        );
        int gotId = int.parse(id);
        sendTransactionToServer(box, gotId);
      } else {
        int id = await saveTransactionToObjectBox(
          context: context,
          cart: cart,
          total: total,
          tableNo: tableNo,
          pageback: pageback,
          payment_mode: payment_mode,
          status: mode,
          transactionData: transactionData,
        );

        debugPrint("saveTransactionToObjectBox with id - $id ");
        sendTransactionToServer(box, id);
        if (tableNo > 0) {
          prefs.setInt("tt$tableNo", id);
        }
      }
      return true;
    }
  }

  Future<void> sendKotToPrinter({
    required BuildContext context,
    required List<Map<String, dynamic>> cart,
    int? tableNumber = 0,
    int? kotNumber = 1,
    required Map<String, dynamic>? transactionData,
  }) async {
    if (_generator == null) {
      throw Exception("Printer not initialized");
    }

    final prefs = await SharedPreferences.getInstance();
    final String dateTime = DateFormat(
      'dd-MMM-yyyy hh:mm a',
    ).format(DateTime.now());

    List<Map<String, dynamic>> kotCart = cart
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    try {
      // Reset printer and clear styles
      bytes += _generator!.reset();
      bytes += _generator!.clearStyle();
      bytes += _generator!.feed(1);

      // KOT Header
      bytes += _generator!.text(
        "KOT",
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          fontType: PosFontType.fontB,
        ),
      );

      String kotInfo = (tableNumber == 0 || tableNumber == null)
          ? "Bill No: ${transactionData?['billNo']} / Order Type: ${transactionData?['orderType']}"
          : "KOT No: $kotNumber / Table No: $tableNumber";

      bytes += _generator!.text(
        kotInfo,
        styles: PosStyles(
          bold: true,
          align: PosAlign.center,
          fontType: PosFontType.fontA,
        ),
      );

      bytes += _generator!.text(
        "Time: $dateTime",
        styles: PosStyles(align: PosAlign.center, fontType: PosFontType.fontA),
      );

      bytes += _generator!.hr();
      bytes += _generator!.feed(1);

      // Item header
      bytes += _generator!.row([
        PosColumn(
          text: 'Item',
          width: 8,
          styles: PosStyles(bold: true, fontType: PosFontType.fontA),
        ),
        PosColumn(
          text: 'Qty',
          width: 4,
          styles: PosStyles(
            align: PosAlign.right,
            bold: true,
            fontType: PosFontType.fontA,
          ),
        ),
      ]);

      bytes += _generator!.hr();

      // Item List
      for (var item in kotCart) {
        String name = item['name'] ?? 'Item';
        int qty = item['qty'] ?? 0;
        String note = item['note'] ?? '';

        // Handle long item names
        if (name.length > 20) {
          bytes += _generator!.text(
            name.substring(0, 20),
            styles: PosStyles(fontType: PosFontType.fontA, bold: true),
          );
          if (name.length > 40) {
            bytes += _generator!.text(
              name.substring(20, 40),
              styles: PosStyles(fontType: PosFontType.fontA, bold: true),
            );
          } else if (name.length > 20) {
            bytes += _generator!.text(
              name.substring(20),
              styles: PosStyles(fontType: PosFontType.fontA, bold: true),
            );
          }
        } else {
          bytes += _generator!.row([
            PosColumn(
              text: name,
              width: 8,
              styles: PosStyles(fontType: PosFontType.fontA, bold: true),
            ),
            PosColumn(
              text: "$qty",
              width: 4,
              styles: PosStyles(
                align: PosAlign.right,
                fontType: PosFontType.fontA,
                bold: true,
              ),
            ),
          ]);
        }

        // Add note if exists
        if (note.isNotEmpty) {
          bytes += _generator!.text(
            "Note: $note",
            styles: PosStyles(fontType: PosFontType.fontA),
          );
        }

        bytes += _generator!.text(
          "------------------------",
          styles: PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontA,
          ),
        );
      }

      //bytes += _generator!.hr();
      bytes += _generator!.feed(3);
      //bytes += _generator!.cut();

      await _sendToPrinter();
      await _disconnect();

      debugPrint("✅ KOT for Table #$tableNumber sent to printer.");
    } catch (e) {
      debugPrint("❌ Error printing KOT: $e");
      screen_massage(context, "❌ Error printing KOT: $e");
      rethrow;
    }
  }

  // Get saved printer using blue_thermal_printer
  Future<thermal.BluetoothDevice?> _getSavedPrinter({
    required bool KOTmode,
    required BuildContext context,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String? address;

    if (KOTmode) {
      address = prefs.getString('saved_KOT_printer_address');
    } else {
      address = prefs.getString('saved_printer_address');
    }

    debugPrint("Looking for saved printer with address: $address");

    if (address == null) {
      screen_massage(context, "Printer Is Not Selected");
      return null;
    }

    try {
      // Get bonded devices using blue_thermal_printer
      List<thermal.BluetoothDevice> bondedDevices = await printer
          .getBondedDevices();
      debugPrint("Found ${bondedDevices.length} bonded devices");

      for (var device in bondedDevices) {
        debugPrint("Bonded: ${device.name} - ${device.address}");
        if (device.address == address) {
          debugPrint("✅ Found saved printer in bonded devices!");
          return device;
        }
      }

      debugPrint("❌ Printer not found in bonded devices");
      return null;
    } catch (e) {
      debugPrint("❌ Error in _getSavedPrinter: $e");
      screen_massage(context, "❌ Error in _getSavedPrinter: $e");
      return null;
    }
  }

  // Rest of your existing methods (saveTransactionToObjectBox, updateTransactionToObjectBox, etc.)
  // These remain the same as in your original code...

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
    final businessDateString =
        prefs.getString('businessDate') ?? DateTime.now().toString();
    final now = DateTime.now();
    int cash_amount =
        (double.tryParse(transactionData?['cashamount']?.toString() ?? '0.0') ??
                0.0)
            .toInt();
    int upi_amount =
        (double.tryParse(transactionData?['upiamount']?.toString() ?? '0.0') ??
                0.0)
            .toInt();

    debugPrint(
      "✅ business date from prefs ${prefs.getString('businessDate')} $payment_mode $cash_amount $upi_amount $transactionData",
    );

    final businessDatePart = DateTime.parse(businessDateString);
    final fullDateTime = DateTime(
      businessDatePart.year,
      businessDatePart.month,
      businessDatePart.day,
      now.hour,
      now.minute,
      now.second,
    );

    late int createdId = 0;

    final tx = Transaction(
      time: fullDateTime,
      tableNo: tableNo,
      total: total,
      cartData: jsonEncode(cart),
      payment_mode: payment_mode,
      status: status,
      serviceCharge: transactionData?['serviceCharge'] ?? 0.0,
      discount: transactionData?['discount'] ?? 0.0,
      discountPercent: transactionData?['discountpercent'] ?? 0.0,
      billNo: transactionData?['billNo'] ?? 0,
      customerName: transactionData?['customerName'] ?? '',
      mobileNo: transactionData?['mobileNo'] ?? '',
      reserved: transactionData?['reserved'] ?? '',
      orderType: transactionData?['orderType'] ?? '',
      cashamount: cash_amount,
      upiamount: upi_amount,
    );

    debugPrint("Transaction Data to be sent: $tx");
    createdId = box.put(tx);
    setNextBillNo(context, transactionData?['billNo']);

    if (status.toLowerCase().contains("settle")) {
      try {
        adjustStock(context, cart);
        debugPrint("✅ Transaction saved to ObjectBox with ID: $createdId");
      } catch (e) {
        print_log_red("Transaction not saved to ObjectBox with ID: $e");
        screen_massage(
          context,
          "Transaction not saved to ObjectBox with ID: $e",
        );
      }
    }

    onTransactionAdded?.call();

    if (pageback != null && pageback > 0) {
      for (int i = 0; i < pageback; i++) {
        debugPrint("save pageback1 $pageback");
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    return createdId;
  }

  Future<void> updateTransactionToObjectBox({
    required BuildContext context,
    required List<Map<String, dynamic>> cart,
    required int total,
    int? tableNo,
    int? pageback,
    required String payment_mode,
    required String status,
    required String id,
    Map<String, dynamic>? transactionData,
  }) async {
    debugPrint("🔁 in _updateTransactionToObjectBox");
    final int transactionId = int.parse(id);
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final box = store.box<Transaction>();
    final prefs = await SharedPreferences.getInstance();
    final businessDateString =
        prefs.getString('BusinessDate') ?? DateTime.now().toString();
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

    final existingTx = box.get(transactionId);
    debugPrint("🔁 Transaction to update $existingTx ");

    if (existingTx != null) {
      if (status == 'print1') {
        debugPrint("⏩ Skipping update for print1 status");
        return;
      }

      debugPrint(
        "in bill debugPrint update transactionData $transactionData $tableNo and $total and ${cart.length} and $payment_mode and $status",
      );

      existingTx.time = fullDateTime;
      existingTx.total = total;
      existingTx.cartData = jsonEncode(cart);
      existingTx.payment_mode = payment_mode;
      existingTx.status = status;
      existingTx.synced = false;
      existingTx.serviceCharge = transactionData?['serviceCharge'] ?? 0.0;
      existingTx.discount = transactionData?['discount'] ?? 0.0;
      existingTx.customerName = transactionData?['customerName'] ?? '';
      existingTx.mobileNo = transactionData?['mobileNo'] ?? '';
      existingTx.reserved = transactionData?['reserved'] ?? '';
      existingTx.orderType = transactionData?['orderType'] ?? '';
      existingTx.cashamount =
          (double.tryParse(
                    transactionData?['cashamount']?.toString() ?? '0.0',
                  ) ??
                  0.0)
              .toInt();
      existingTx.upiamount =
          (double.tryParse(
                    transactionData?['upiamount']?.toString() ?? '0.0',
                  ) ??
                  0.0)
              .toInt();

      box.put(existingTx);

      if (status.toLowerCase().contains("settle")) {
        adjustStock(context, cart);
      }

      debugPrint("✅ Transaction updated in ObjectBox: $existingTx");

      onTransactionAdded?.call();

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();

      debugPrint(" up pageback1 $pageback");
      if (pageback != null && pageback > 0) {
        for (int i = 0; i < pageback; i++) {
          debugPrint(" up pageback1 $pageback");
          Navigator.of(context).pop();
        }
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      debugPrint(
        "❌ Error: Transaction with ID $transactionId not found. Cannot update.",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: Could not find the transaction to update."),
        ),
      );
    }
  }

  Future<bool> sendTransactionToServer(Box<Transaction> box, int id) async {
    try {
      final existingTx = box.get(id);
      final prefs = await SharedPreferences.getInstance();
      final isConnected = prefs.getBool('isOnline');

      debugPrint("❌ isConnected $isConnected not found");
      if (isConnected != true) {
        return false;
      }

      debugPrint(
        "✅ sendTransactionToServer: ${existingTx}  and ${existingTx?.payment_mode}",
      );

      if (existingTx == null) {
        debugPrint("❌ Transaction with ID $id not found");
        return false;
      }

      String businessName = prefs.getString('businessName') ?? '';
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
        "login_user": login_user,
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
        box.put(existingTx);
        debugPrint("✅ sendTransactionToServer: ${response.body}");
        return true;
      } else {
        debugPrint(
          "❌ sendTransactionToServer failed: ${response.statusCode} and body ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("❌ Error sending transaction: $e");
    }

    return false;
  }

  void deletetablecart(int tableNo) async {
    final box = store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
    tableCart? existingTableCart = query.findFirst();
    query.close();
    debugPrint(
      "✅ Updated cart for table #$tableNo in ObjectBox. existingTableCart $existingTableCart",
    );

    if (existingTableCart != null) {
      box.remove(existingTableCart.id);
      debugPrint("🗑️ Removed empty cart for table #$tableNo from ObjectBox.");
    }
  }

  Future<void> adjustStock(
    BuildContext context,
    List<Map<String, dynamic>> cart1,
  ) async {
    List<Map<String, dynamic>> cart = cart1
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final Box<MenuItem> menuItemBox = store.box<MenuItem>();
    final List<MenuItem> allItems = menuItemBox.getAll();

    print_log("menuItem adjustStock $cart ");

    for (var cartItem in cart) {
      final String? cartItemId = cartItem['name'];
      final int qtyToReduce = cartItem['qty'] ?? 0;
      print_log(
        "menuItem adjustStock ${(cartItemId == null || qtyToReduce <= 0)} ",
      );

      if (cartItemId == null || qtyToReduce <= 0) continue;

      final MenuItem? menuItem = allItems.firstWhere(
        (item) => item.name == cartItemId,
      );

      print_log("menuItem adjustStock $menuItem ");

      if (menuItem != null) {
        int currentStock = menuItem.adjustStock ?? 0;
        int newStock = (currentStock - qtyToReduce)
            .clamp(0, double.infinity)
            .toInt();

        print_log("menuItem adjustStock $menuItem $currentStock $newStock");
        menuItem.adjustStock = newStock;
        menuItemBox.put(menuItem);
      }
    }

    debugPrint("✅ Stock adjusted successfully for ${cart.length} items.");
  }

  // Print sales Report
  Future<void> printSalesReportSummary({
    required BuildContext context,
    required DateTime? fromDate,
    required DateTime? toDate,
    required double todayTotal,
    required double weekTotal,
    required double monthTotal,
    required double cashTotal,
    required double cardTotal,
    required double upiTotal,
    required double otherTotal,
    required String giveamount,
    required String takeamount,
    required double expensesDateRange,
    required double expensesToday,
    required bool isDateRangeSelected,
  }) async {
    try {
      store = Provider.of<ObjectBoxService>(context, listen: false).store;
      bytes = [];
      final stopwatch = Stopwatch()..start();

      final device = await _getSavedPrinter(KOTmode: false, context: context);
      if (device == null) return;

      bool isConnected = await _isConnected();
      if (!isConnected) {
        await _connectToPrinter(device);
      }

      if (_generator == null) {
        throw Exception("Printer not initialized");
      }

      final prefs = await SharedPreferences.getInstance();
      String businessName = prefs.getString('businessName') ?? 'Hotel Test';
      final String dateTime = DateFormat(
        'dd-MMM-yyyy hh:mm a',
      ).format(DateTime.now());

      bytes += _generator!.reset();
      bytes += _generator!.clearStyle();

      // --- Header ---
      bytes += _generator!.text(
        businessName,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += _generator!.text(
        'Sales Summary Report',
        styles: PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += _generator!.text(
        'Generated: $dateTime',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      // --- Date Range ---
      bytes += _generator!.text(
        "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate!)} to ${DateFormat('dd MMM yyyy').format(toDate!)}",
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      // --- Sales Totals ---
      bytes += _generator!.row([
        PosColumn(
          text: isDateRangeSelected ? 'Range Sales:' : "Today's Sales:",
          width: 6,
        ),
        PosColumn(
          text: 'Rs. ${todayTotal.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += _generator!.row([
        PosColumn(text: 'This Week:', width: 6),
        PosColumn(
          text: 'Rs. ${weekTotal.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.row([
        PosColumn(text: 'This Month:', width: 6),
        PosColumn(
          text: 'Rs. ${monthTotal.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.hr();

      // --- Payment Modes ---
      bytes += _generator!.text(
        'By Payment Mode:',
        styles: PosStyles(bold: true),
      );
      bytes += _generator!.row([
        PosColumn(text: 'Cash:', width: 6),
        PosColumn(
          text: 'Rs. ${cashTotal.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.row([
        PosColumn(text: 'Card:', width: 6),
        PosColumn(
          text: 'Rs. ${cardTotal.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.row([
        PosColumn(text: 'UPI:', width: 6),
        PosColumn(
          text: 'Rs. ${upiTotal.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.row([
        PosColumn(text: 'Not Settled:', width: 6),
        PosColumn(
          text: 'Rs. ${otherTotal.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.hr();

      // --- Udhari ---
      bytes += _generator!.text(
        'Udhari (Credit):',
        styles: PosStyles(bold: true),
      );
      bytes += _generator!.row([
        PosColumn(text: 'You will give:', width: 6),
        PosColumn(
          text: 'Rs. $giveamount',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.row([
        PosColumn(text: 'You will get:', width: 6),
        PosColumn(
          text: 'Rs. $takeamount',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += _generator!.hr();

      // --- Expenses & Net Total ---
      final double displayExpenses = isDateRangeSelected
          ? expensesDateRange
          : expensesToday;
      final String expensesLabel = isDateRangeSelected
          ? "Range Expenses:"
          : "Today's Expenses:";
      bytes += _generator!.row([
        PosColumn(text: expensesLabel, width: 6, styles: PosStyles(bold: true)),
        PosColumn(
          text: 'Rs. ${displayExpenses.toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += _generator!.hr();
      bytes += _generator!.row([
        PosColumn(
          text: 'Net Total:',
          width: 6,
          styles: PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
        PosColumn(
          text: 'Rs. ${(todayTotal).toStringAsFixed(2)}',
          width: 6,
          styles: PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      ]);

      bytes += _generator!.hr();
      bytes += _generator!.feed(1);
      await _sendToPrinter();
      await _disconnect();
      debugPrint(
        "✅ Sales Summary Report sent to printer. Processing time: ${stopwatch.elapsedMilliseconds}ms",
      );
    } catch (e) {
      print_log_red("❌ Error while printing sales summary: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error printing report: $e"),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> printItemWiseSalesReport({
    required BuildContext context,
    required DateTime fromDate,
    required DateTime toDate,
    required Map<String, double> itemPriceMap,
    required Map<String, int> itemQtyMap,
  }) async {
    try {
      store = Provider.of<ObjectBoxService>(context, listen: false).store;
      bytes = [];
      final stopwatch = Stopwatch()..start();

      final device = await _getSavedPrinter(KOTmode: false, context: context);
      if (device == null) return;

      bool isConnected = await _isConnected();
      if (!isConnected) {
        await _connectToPrinter(device);
      }

      if (_generator == null) {
        throw Exception("Printer not initialized");
      }

      final prefs = await SharedPreferences.getInstance();
      String businessName = prefs.getString('businessName') ?? 'Hotel Test';
      final String dateTime = DateFormat(
        'dd-MMM-yyyy hh:mm a',
      ).format(DateTime.now());

      bytes += _generator!.reset();
      bytes += _generator!.clearStyle();

      // --- Header ---
      bytes += _generator!.text(
        businessName,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += _generator!.text(
        'Item-Wise Sales Report',
        styles: PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += _generator!.text(
        'Generated: $dateTime',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      // --- Date Range ---
      bytes += _generator!.text(
        "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate)} to ${DateFormat('dd MMM yyyy').format(toDate)}",
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      // --- Table Header ---
      bytes += _generator!.row([
        PosColumn(text: 'Item', width: 6, styles: PosStyles(bold: true)),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: PosStyles(align: PosAlign.center, bold: true),
        ),
        PosColumn(
          text: 'Total',
          width: 4,
          styles: PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += _generator!.hr();

      // --- Table Body ---
      final sortedEntries = itemPriceMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var entry in sortedEntries) {
        final itemName = entry.key;
        final totalAmount = entry.value;
        final qty = itemQtyMap[itemName] ?? 0;

        bytes += _generator!.row([
          PosColumn(text: itemName, width: 6),
          PosColumn(
            text: qty.toString(),
            width: 2,
            styles: PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: 'Rs. ${totalAmount.toStringAsFixed(2)}',
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += _generator!.hr();
      bytes += _generator!.feed(1);
      await _sendToPrinter();
      await _disconnect();
      debugPrint(
        "✅ Item-Wise Sales Report sent to printer. Processing time: ${stopwatch.elapsedMilliseconds}ms",
      );
    } catch (e) {
      print_log_red("❌ Error while printing item-wise sales report: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error printing report: $e")));
    }
  }

  Future<void> printPortionWiseSalesReport({
    required BuildContext context,
    required DateTime fromDate,
    required DateTime toDate,
    required Map<String, double> portionPriceMap,
    required Map<String, int> portionQtyMap,
  }) async {
    try {
      store = Provider.of<ObjectBoxService>(context, listen: false).store;
      bytes = [];

      final device = await _getSavedPrinter(KOTmode: false, context: context);
      if (device == null) return;

      bool isConnected = await _isConnected();
      if (!isConnected) {
        await _connectToPrinter(device);
      }

      if (_generator == null) {
        throw Exception("Printer not initialized");
      }

      final prefs = await SharedPreferences.getInstance();
      String businessName = prefs.getString('businessName') ?? 'Hotel Test';
      final String dateTime = DateFormat(
        'dd-MMM-yyyy hh:mm a',
      ).format(DateTime.now());

      bytes += _generator!.reset();
      bytes += _generator!.clearStyle();

      bytes += _generator!.text(
        businessName,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += _generator!.text(
        'Portion-Wise Sales Report',
        styles: PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += _generator!.text(
        'Generated: $dateTime',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      bytes += _generator!.text(
        "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate)} to ${DateFormat('dd MMM yyyy').format(toDate)}",
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      bytes += _generator!.row([
        PosColumn(text: 'Portion', width: 6, styles: PosStyles(bold: true)),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: PosStyles(align: PosAlign.center, bold: true),
        ),
        PosColumn(
          text: 'Total',
          width: 4,
          styles: PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += _generator!.hr();

      final sortedEntries = portionPriceMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var entry in sortedEntries) {
        final portionName = entry.key;
        final totalAmount = entry.value;
        final qty = portionQtyMap[portionName] ?? 0;

        bytes += _generator!.row([
          PosColumn(text: portionName, width: 6),
          PosColumn(
            text: qty.toString(),
            width: 2,
            styles: PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: 'Rs. ${totalAmount.toStringAsFixed(2)}',
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += _generator!.hr();
      bytes += _generator!.feed(1);
      await _sendToPrinter();
      await _disconnect();
      debugPrint("✅ Portion-Wise Sales Report sent to printer");
    } catch (e) {
      print_log_red("❌ Error while printing portion-wise sales report: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error printing report: $e")));
    }
  }

  Future<void> printOrderTypeSalesReport({
    required BuildContext context,
    required DateTime fromDate,
    required DateTime toDate,
    required Map<String, double> orderTypeTotalMap,
    required Map<String, int> orderTypeCountMap,
  }) async {
    try {
      store = Provider.of<ObjectBoxService>(context, listen: false).store;
      bytes = [];

      final device = await _getSavedPrinter(KOTmode: false, context: context);
      if (device == null) return;

      bool isConnected = await _isConnected();
      if (!isConnected) {
        await _connectToPrinter(device);
      }

      if (_generator == null) {
        throw Exception("Printer not initialized");
      }

      final prefs = await SharedPreferences.getInstance();
      String businessName = prefs.getString('businessName') ?? 'Hotel Test';
      final String dateTime = DateFormat(
        'dd-MMM-yyyy hh:mm a',
      ).format(DateTime.now());

      bytes += _generator!.reset();
      bytes += _generator!.clearStyle();

      bytes += _generator!.text(
        businessName,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += _generator!.text(
        'Order Type Sales Report',
        styles: PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += _generator!.text(
        'Generated: $dateTime',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      bytes += _generator!.text(
        "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate)} to ${DateFormat('dd MMM yyyy').format(toDate)}",
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      bytes += _generator!.row([
        PosColumn(text: 'Order Type', width: 5, styles: PosStyles(bold: true)),
        PosColumn(
          text: 'Count',
          width: 3,
          styles: PosStyles(align: PosAlign.center, bold: true),
        ),
        PosColumn(
          text: 'Total',
          width: 4,
          styles: PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += _generator!.hr();

      final sortedEntries = orderTypeTotalMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var entry in sortedEntries) {
        final orderType = entry.key;
        final totalAmount = entry.value;
        final count = orderTypeCountMap[orderType] ?? 0;

        bytes += _generator!.row([
          PosColumn(text: orderType, width: 5),
          PosColumn(
            text: count.toString(),
            width: 3,
            styles: PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: 'Rs. ${totalAmount.toStringAsFixed(2)}',
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += _generator!.hr();
      bytes += _generator!.feed(1);
      await _sendToPrinter();
      await _disconnect();
      debugPrint("✅ Order Type Sales Report sent to printer");
    } catch (e) {
      print_log_red("❌ Error while printing order type sales report: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error printing report: $e")));
    }
  }

  Future<void> printStockReport({
    required BuildContext context,
    required Map<String, int> stockMap,
  }) async {
    try {
      store = Provider.of<ObjectBoxService>(context, listen: false).store;
      bytes = [];

      final device = await _getSavedPrinter(KOTmode: false, context: context);
      if (device == null) return;

      bool isConnected = await _isConnected();
      if (!isConnected) {
        await _connectToPrinter(device);
      }

      if (_generator == null) {
        throw Exception("Printer not initialized");
      }

      final prefs = await SharedPreferences.getInstance();
      String businessName = prefs.getString('businessName') ?? 'Hotel Test';
      final String dateTime = DateFormat(
        'dd-MMM-yyyy hh:mm a',
      ).format(DateTime.now());

      bytes += _generator!.reset();
      bytes += _generator!.clearStyle();

      bytes += _generator!.text(
        businessName,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += _generator!.text(
        'Available Stock Report',
        styles: PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += _generator!.text(
        'Generated: $dateTime',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += _generator!.hr();

      bytes += _generator!.row([
        PosColumn(text: 'Item', width: 8, styles: PosStyles(bold: true)),
        PosColumn(
          text: 'Stock',
          width: 4,
          styles: PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += _generator!.hr();

      final sortedEntries = stockMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var entry in sortedEntries) {
        final itemName = entry.key;
        final stock = entry.value;

        bytes += _generator!.row([
          PosColumn(text: itemName, width: 8),
          PosColumn(
            text: stock.toString(),
            width: 4,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += _generator!.hr();
      bytes += _generator!.feed(1);
      await _sendToPrinter();
      await _disconnect();
      debugPrint("✅ Stock Report sent to printer");
    } catch (e) {
      print_log_red("❌ Error while printing stock report: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error printing report: $e")));
    }
  }

  Future<void> syncPendingTransactions(BuildContext context) async {
    try {
      final objectBoxService = Provider.of<ObjectBoxService>(
        context,
        listen: false,
      );
      final store = objectBoxService.store;
      final box = store.box<Transaction>();
      final unsyncedIds = box
          .getAll()
          .where((tx) => !(tx.synced))
          .map((tx) => tx.id)
          .toList();
      debugPrint("Unsynced transaction IDs: $unsyncedIds");
      // final isOnline = await isDeviceOnline();
      // final isOnline = await isDeviceConnected();
      final prefs = await SharedPreferences.getInstance();
      final isOnline = prefs.getBool('isOnline') ?? true;
      debugPrint(
        "isOnline: $isOnline unsyncedIds.isNotEmpty: ${unsyncedIds.isNotEmpty} both: ${isOnline && unsyncedIds.isNotEmpty}",
      );
      if (isOnline && unsyncedIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "you are online, ⏳ wait to async ${unsyncedIds.length} transaction ",
            ),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
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
                content: Text(
                  "⏳ wait sending transaction ${successfulSyncs}/${unsyncedIds.length}",
                ),
                duration: Duration(milliseconds: 40),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("❌ Error sending transaction $i"),
                duration: Duration(milliseconds: 40),
              ),
            );
          }
        } catch (e) {
          debugPrint(
            "❌ Got Exception Transaction failed ${unsyncedIds.length} $e ",
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "❌ Got Exception Transaction failed ${unsyncedIds.length} $e ",
              ),
              duration: Duration(milliseconds: 40),
            ),
          );
          break;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Sending Transaction Completed ${successfulSyncs}/${unsyncedIds.length}",
          ),
          duration: Duration(seconds: 4),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      print("❌ Error in sync process: $e");
    }
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

  Future<Uint8List?> generateReceiptImageToShare({
    required List<Map<String, dynamic>> cart1,
    required int total,
    required int billNo,
    required Map<String, dynamic> transactionData,
    required tableno,
  }) async {}
}
