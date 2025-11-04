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
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '/objectbox.g.dart';
import 'package:intl/intl.dart';
import '../billnogenerator/BillCounter.dart';
import 'cartprovier/ObjectBoxService.dart';
import '../models/menu_item.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import './printer_pages/cat_protocol.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';



  enum PrintQuality {
    light,
    normal, 
    dark,
    maximum
  }

  enum SoundPattern {
  shortBeep,    // Quick confirmation
  longBeep,     // Attention required
  doubleBeep,   // Success
  tripleBeep,   // Error/alert
  continuous,   // Continuous beep
}


class BillPrinter {
  bl.BluetoothDevice? _connectedDevice;
  Generator? _generator;
  Function()? onTransactionAdded;
  List<bl.ScanResult> _scanResults = [];
  StreamSubscription<List<bl.ScanResult>>? _scanSubscription;
  static const String SERVICE_UUID1 = "0000ff00-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_UUID = "0000ff02-0000-1000-8000-00805f9b34fb";
  static const String SERVICE_UUID = "49535343-8841-43f4-a8d4-ecbe34729bb3";
  List<int> bytes = [];
  final int printerWidth = 384;



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
          bytes.clear();
          final stopwatch = Stopwatch()..start();
          final cart = cart1;
          final prefs = await SharedPreferences.getInstance();
          final int billNo = (transactionData?['billNo'] == null) ? getNextBillNo(context) : transactionData?['billNo'];
          debugPrint("check printer is connected total $total mode $mode payment_mode $payment_mode  $transactionData billNo $billNo");
          
          final device = await _getSavedPrinter();
          if (device != null) {
            
            bool isConnected = await _isConnected();
            debugPrint("check printer is connected ${isConnected} $transactionData");
            if (!isConnected) {
              bytes.clear();
              await _connectToPrinter(device);
              final store = Provider.of<ObjectBoxService>(context, listen: false).store;
              final box = store.box<Transaction>();
              debugPrint(" mode ${isConnected}  payment_mode $payment_mode");
              int pageback1 = 0;
              // if (mode == "settle1") pageback1 = 2;
              if ((kot ?? 0) > 0) pageback1 = 1;
              
              
              switch (mode) {
                case "kot":
                  await sendKotToPrinter(context: context,cart:cart,tableNumber: kot,kotNumber: 1,);
                  return true;
                case "onlyPrint":
                  await sendDataToPrinter(context: context, cart1:cart, total:total, billNo: billNo,tableNumber: kot,transactionData:transactionData);
                  return true;
                case "onlySettle":
                  await _disconnect();
                  final ttid = prefs.getInt("tt$kot");
                  int id;
                  if(ttid != null){
                    id = ttid;
                    await updateTransactionToObjectBox(
                      context: context,
                      cart: cart,
                      total: total,
                      tableNo: kot ?? 1,
                      pageback: pageback1,
                      payment_mode: payment_mode,
                      status: mode,
                      id: ttid.toString(),
                      transactionData:transactionData,
                    );
                    // int gotId = int.parse(ttid.toString());
                    sendTransactionToServer(box, ttid);
                  }else {
                    id  = await saveTransactionToObjectBox(
                      context: context,
                      cart: cart,
                      total: total,
                      tableNo: kot ?? 1,
                      pageback: pageback1,
                      payment_mode: payment_mode,
                      status: mode,
                      transactionData:transactionData
                    );
                  }
                  
                  final key = "table${kot}";
                  prefs.remove(key);
                  debugPrint("saveTransactionToObjectBox with id - $id  table $key ");
                  sendTransactionToServer(box, id);
                  prefs.remove("tt$kot",);
                  return true;
              }

              if(payment_mode == "KOT"){
                await sendKotToPrinter(context: context,cart:cart,tableNumber: kot,kotNumber: 1,);
              }else{
                await sendDataToPrinter(context: context, cart1:cart, total:total, billNo: billNo,tableNumber: kot,transactionData:transactionData);
              }
              
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
                if (kot != null){
                  prefs.setInt("tt$kot", id);
                }
              }

              stopwatch.stop();
              debugPrint("send print function Processing time: ${stopwatch.elapsedMilliseconds}ms and ${stopwatch.elapsedMilliseconds/1000} s");
              }
            else {
              await _disconnect(); 
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

  // Bluetooth connection methods
  Future<bool> _connectToPrinter(bl.BluetoothDevice device) async {
    try {
      // Connect to the device
      try{
        await device.connect();
      }catch (e) {
        await device.connect(timeout: Duration(seconds: 10));
      }
      
      // Discover services
      // List<bl.BluetoothService> services = await device.discoverServices();
      // debugPrint("✅ Found ${services.length} services");
      
      // for (int i = 0; i < services.length; i++) {
      //   bl.BluetoothService service = services[i];
      //   // debugPrint("--- Service $service ---");
      //   // debugPrint("--- Service ${i + 1} ---");
      //   // debugPrint("Service UUID: ${service.uuid}");
      //   // debugPrint("Service UUID (full): ${service.uuid.toString()}");
        
      //   for (int j = 0; j < service.characteristics.length; j++) {
      //     bl.BluetoothCharacteristic characteristic = service.characteristics[j];
      //     debugPrint("  Characteristic ${j + 1}:");
      //     debugPrint("    UUID: ${characteristic.uuid}");
      //     debugPrint("    Properties: ${characteristic.properties}");
      //     debugPrint("    Read: ${characteristic.properties.read}");
      //     debugPrint("    Write: ${characteristic.properties.write}");
      //     debugPrint("    WriteWithoutResponse: ${characteristic.properties.writeWithoutResponse}");
      //     debugPrint("    Notify: ${characteristic.properties.notify}");
      //     debugPrint("    Indicate: ${characteristic.properties.indicate}");
      //   }
      //   debugPrint(""); // Empty line for readability
      // }
      // Initialize generator
      final prefs = await SharedPreferences.getInstance();
      String paperSize = prefs.getString('paperSize') ?? '2';
      debugPrint("--- paperSize $paperSize ---");
      _generator = Generator((paperSize == "2") ? PaperSize.mm58 : (paperSize == "3") ? PaperSize.mm72 : PaperSize.mm80, await CapabilityProfile.load());
      _connectedDevice = device;
      
      debugPrint("✅ Connected to printer: ${device.platformName}");
      return true;
    } catch (e) {
      debugPrint("❌ Error connecting to printer: $e");
      return false;
    }
  }

  Future<bool> _isConnected() async {
    return _connectedDevice != null && _connectedDevice!.isConnected;
  }

  Future<void> _disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _connectedDevice = null;
    _generator = null;
  }

  Future<void> _sendToPrinter({Uint8List? imageBytes}) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception("Printer not connected");
    }
    final prefs = await SharedPreferences.getInstance();
    final bool miniPrinter = prefs.getBool('miniPrinter') ?? false;
    
    // Discover services
    List<bl.BluetoothService> services = await _connectedDevice!.discoverServices();
    // Find the printer service and characteristic
    bl.BluetoothCharacteristic? printerCharacteristic;


    if( !miniPrinter){

      for (bl.BluetoothService service in services) {
        for (bl.BluetoothCharacteristic characteristic in service.characteristics) {
          // Use the characteristic from Service 3 that has write capabilities
          
          if (characteristic.uuid.toString() == SERVICE_UUID) {
            printerCharacteristic = characteristic;
            // debugPrint("✅ Found printer characteristic: ${characteristic.uuid}");
            break;
          } 
          
        }
        if (printerCharacteristic != null) break;
      }
   
      if (printerCharacteristic == null) {
        throw Exception("Printer characteristic not found");
      }
      // Split data into chunks to avoid exceeding maximum length
      const int maxChunkSize = 230; // Use 200 to be safe (printer reported max 237)
      // debugPrint("📦 Sending ${bytes.length} bytes in chunks of $maxChunkSize");
      
      for (int i = 0; i < bytes.length; i += maxChunkSize) {
        int end = (i + maxChunkSize < bytes.length) ? i + maxChunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);
        
        // debugPrint("🔄 Sending chunk ${(i ~/ maxChunkSize) + 1}: ${chunk.length} bytes");
        
        try {
          // Try writeWithoutResponse first (faster for thermal printers)
          await printerCharacteristic.write(chunk, withoutResponse: true);
          // debugPrint("✅ Chunk ${(i ~/ maxChunkSize) + 1} sent successfully");
          
          // Small delay between chunks to prevent overwhelming the printer
          await Future.delayed(Duration(milliseconds: 5));
          
        } catch (e) {
          debugPrint("❌ Error sending chunk ${(i ~/ maxChunkSize) + 1}: $e");
          // Try with response if withoutResponse fails
          try {
            await printerCharacteristic.write(chunk, withoutResponse: false);
            debugPrint("✅ Chunk ${(i ~/ maxChunkSize) + 1} sent with response");
          } catch (e2) {
            debugPrint("❌ Failed to send chunk ${(i ~/ maxChunkSize) + 1} with response: $e2");
            throw Exception("Failed to send data to printer");
          }
        }
      }

    } else {
      final img.Image? originalImage = img.decodeImage(imageBytes!); //bytes ti image

      if (originalImage == null) {
        debugPrint("Error: Failed to decode PNG image.");
        return;
      }

      final service = services.firstWhere((s) => s.uuid == CAT_PRINT_SRV);
      printerCharacteristic = service.characteristics.firstWhere((c) => c.uuid == CAT_PRINT_TX_CHAR);
      final printer = CatPrinter(printerCharacteristic);
      final prefs = await SharedPreferences.getInstance();
      final speed = prefs.getInt('speed') ?? 32;
      final energy = prefs.getInt('energy') ?? 35000;
      final finishFeed = 50;
      await printer.prepare(speed, energy);

      final Uint8List processedBitmap = _processImageForPrinter(
        originalImage.buffer.asUint8List(),
        originalImage.width,
        originalImage.height,
        printerWidth
      );

      final pitch = printerWidth ~/ 8; // 384 / 8 = 48 bytes per line
      int blankLines = 0;
      for (int y = 0; y < processedBitmap.length ~/ pitch; y++) {
        final start = y * pitch;
        final end = start + pitch;
        if (end > processedBitmap.length) break;
        final line = processedBitmap.sublist(start, end);
        if (line.every((byte) => byte == 0)) {
          blankLines += 1; // It's a blank line, just count it
        } else {
          if (blankLines > 0) {
            await printer.feed(2);  //to increase the gap of line
            blankLines = 0; // Reset the counter
          }
          await printer.draw(line);
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
      await printer.finish(finishFeed);
      return;
    }

    debugPrint("🎉 All data sent successfully to printer!");
  }

  Uint8List _processImageForPrinter(
  Uint8List rgbaBytes, 
  int originalWidth, 
  int originalHeight, 
  int targetWidth
) {
  final originalImage = img.Image.fromBytes(
    width: originalWidth,
    height: originalHeight,
    bytes: rgbaBytes.buffer,
    format: img.Format.uint8,
    order: img.ChannelOrder.rgba,
  );

  final resizedImage = img.copyResize(
    originalImage,
    width: targetWidth,
    interpolation: img.Interpolation.average,
  );

  final pitch = resizedImage.width ~/ 8;
  final result = Uint8List(resizedImage.height * pitch);
  int resultIndex = 0;

  for (int y = 0; y < resizedImage.height; y++) {
    for (int x_byte = 0; x_byte < pitch; x_byte++) {
      int packedByte = 0;
      for (int x_bit = 0; x_bit < 8; x_bit++) {
        final x = x_byte * 8 + x_bit;
        
        final pixel = resizedImage.getPixel(x, y);
        final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
        
        if (luminance < 128) {
          // --- THIS IS THE KEY CHANGE ---
          // Reverses the bit order to match many common thermal printers.
          packedByte |= (1 << x_bit); 
        }
      }
      result[resultIndex++] = packedByte;
    }
  }
  
  return result;
}















  Future<List<int>> _setPrintQuality( PrintQuality quality) async {
    try {
      
      
      bytes += _generator!.reset();
      
      switch (quality) {
        case PrintQuality.light:
          // Light printing (fast, less contrast)
          bytes += _generator!.rawBytes([0x1B, 0x37, 0x14, 0xC8, 0x96]); // Low heating
          bytes += _generator!.rawBytes([0x1B, 0x45, 0x00]); // Emphasis off
          break;
          
        case PrintQuality.normal:
          // Normal printing (balanced)
          bytes += _generator!.rawBytes([0x1B, 0x37, 0x1E, 0x64, 0xC8]); // Medium heating
          bytes += _generator!.rawBytes([0x1B, 0x45, 0x00]); // Emphasis off
          break;
          
        case PrintQuality.dark:
          // Dark printing (good contrast)
          bytes += _generator!.rawBytes([0x1B, 0x37, 0x28, 0x50, 0xFA]); // High heating
          bytes += _generator!.rawBytes([0x1B, 0x45, 0x01]); // Emphasis on
          bytes += _generator!.rawBytes([0x1D, 0x45, 0x01]); // High density
          break;
          
        case PrintQuality.maximum:
        debugPrint("🎛️ Setting print quality: $quality");
          // Maximum darkness (slowest, best for images)
          bytes += _generator!.rawBytes([0x1B, 0x37, 0x32, 0x32, 0xFA]); // Max heating
          bytes += _generator!.rawBytes([0x1B, 0x45, 0x01]); // Emphasis on
          bytes += _generator!.rawBytes([0x1D, 0x45, 0x02]); // Maximum density
          // bytes += _generator!.rawBytes([0x1B, 0x2A, 0x21]); // High energy
          // Slow down print speed for better heating
          bytes += _generator!.rawBytes([0x1B, 0x1D, 0x03]); // Reduced speed
          break;
      }
      
      debugPrint("✅ Print quality set to: $quality");
      return bytes;
      
    } catch (e) {
      debugPrint("❌ Error setting print quality: $e");
      return bytes;
    }
  }

  // Rest of your methods remain the same...
  int getNextBillNo(BuildContext context) {
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final billCounterBox = store.box<BillCounter>();
    final existingCounters = billCounterBox.getAll();
    debugPrint("next bill number ${existingCounters}");
    int billNo = (existingCounters.isEmpty) ? 1 : existingCounters.first.lastBillNo;
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

  Future<void> getavailabeldevice() async {
    final Set<bl.BluetoothDevice> discoveredDevices = {};
    print("Starting BLE scan for 5 seconds...");

    final scanSubscription = bl.FlutterBluePlus.scanResults.listen((results) {
      for (bl.ScanResult r in results) {
        discoveredDevices.add(r.device);
      }
    });

    await bl.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    scanSubscription.cancel();

    List<String> deviceList = discoveredDevices.map((device) {
      final deviceName = device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';
      final deviceAddress = device.remoteId.toString();
      return '$deviceName - [$deviceAddress]';
    }).toList();

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
    } else {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.request().isGranted) {
    } else {
      await Permission.bluetoothConnect.request();
    }
  }

  Future<void> sendDataToPrinter({
    required BuildContext context,
    required List<Map<String, dynamic>> cart1,
    required int total,
    required int billNo,
    required Map<String, dynamic>? transactionData,
    required int? tableNumber,
  }) async {
    debugPrint("recived cart to send to printer total $total and cart $cart1 billNo $billNo transactionData $transactionData");
    List<Map<String, dynamic>> cart = cart1.map((item) => Map<String, dynamic>.from(item)).toList();
    
    final prefs = await SharedPreferences.getInstance();
    
    // 🏪 Business info
    String businessName = prefs.getString('businessName') ?? 'Hotel Test';
    String contactPhone = prefs.getString('contactPhone') ?? '';
    String contactEmail = prefs.getString('contactEmail') ?? '';
    String businessAddress = prefs.getString('businessAddress') ?? '';
    bool marathi = prefs.getBool('marathi') ?? false;
    bool customerName = prefs.getBool('customerName') ?? false;
    String gst = prefs.getString('gst') ?? '';
    String? upiId = prefs.getString('upi');

    // ⚙ Printer user settings
    bool printQr = prefs.getBool('printQR') ?? true;
    String _qrSize = prefs.getString('qrSize') ?? "5";
    int logoWidth = prefs.getInt('logoWidth') ?? 200;
    String footer =  prefs.getString('footerText')?? "** Thank You **";
    bool printName = prefs.getBool('printName') ?? true;
    String paperSize = prefs.getString('paperSize') ?? '2';
    bool _printQRlogo = prefs.getBool('printQRlogo') ?? true;
    
    int headerFontSizePref = prefs.getInt('headerFontSize') ?? 2;
    int itemFontSizePref = (prefs.getDouble('fontSize') ?? 1).toInt();

    // Get print quality from settings or use maximum
    PrintQuality quality = PrintQuality.maximum;
    SoundPattern sound = SoundPattern.tripleBeep;
    final String dateTime = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
    
    // Convert font sizes to ESC/POS sizes
    PosTextSize getTextSize(int size) {
      switch (size) {
        case 1: return PosTextSize.size1;
        case 2: return PosTextSize.size2;
        case 3: return PosTextSize.size3;
        case 4: return PosTextSize.size4;
        case 5: return PosTextSize.size5;
        case 6: return PosTextSize.size6;
        case 7: return PosTextSize.size7;
        case 8: return PosTextSize.size8;
        default: return PosTextSize.size1;
      }
    }
    QRSize getQRSize(int size) {
      switch (size) {
        case 1: return QRSize.size1;
        case 2: return QRSize.size2;
        case 3: return QRSize.size3;
        case 4: return QRSize.size4;
        case 5: return QRSize.size5;
        case 6: return QRSize.size6;
        case 7: return QRSize.size7;
        case 8: return QRSize.size8;
        default: return QRSize.size5;
      }
    }

    if (_generator == null) {
      throw Exception("Printer not initialized");
    }

    try {
      // Logo
      await _setPrintQuality(quality);
      if (marathi){
        Uint8List? imageBytes = await generateReceiptImage(
                                        cart1: cart,
                                        total: total,
                                        billNo: billNo,
                                        transactionData: transactionData,
                                        tableno:tableNumber,
                                      );
        if (imageBytes != null) {
          // showDialog(
          //   context: context,
          //   builder: (_) => AlertDialog(
          //     content: Image.memory(imageBytes),
          //   ),
          // );
          
          // Example: Save to file (requires path_provider package)
          // final directory = await getDownloadsDirectory();
          // final path = '${directory!.path}/receipt_$billNo.png';
          // final file = File(path);
          // await file.writeAsBytes(imageBytes);
          // debugPrint("Receipt image saved to: $path");

          img.Image? original = img.decodeImage(imageBytes);
          if (original != null) {
            // Resize to fit printer width
            // final resized = img.copyResize(original, width: 300, maintainAspect: true);
            
            // Convert to grayscale for better thermal printing
            final grayscale = img.grayscale(original);
            bytes += _generator!.imageRaster(grayscale);
            // bytes += _generator!.feed(2);
            // bytes += _generator!.cut();
          }

          await _sendToPrinter(imageBytes:imageBytes);

          debugPrint("before clear total $total and cart $cart");
          // cart.clear();
          await _disconnect(); 
          return;
        }
      } else{

        final prefs = await SharedPreferences.getInstance();
        final imagePath = prefs.getString('imagePath');
        final _printlogo = prefs.getBool('printLogo') ?? true;
        if (imagePath != null && File(imagePath).existsSync() && _printlogo ) {
          final file = File(imagePath);
          final imageBytes = await file.readAsBytes();
          img.Image? original = img.decodeImage(imageBytes);
          if (original != null) {
            // Resize to fit printer width // Convert to grayscale for better thermal printing
            final resized = img.copyResize(original, width: logoWidth, maintainAspect: true);
            final grayscale = img.grayscale(resized);
            // final grayscale = img.monochrome(resized);
            bytes += _generator!.imageRaster(grayscale);
            // bytes += _generator!.feed(1);
          }
        } else {
          debugPrint("⚠️ No logo found in SharedPreferences");
        }
        // bytes += _generator!.reverseFeed(2);
        if(printName){
          // debugPrint("⚠️ No logo found in SharedPreferences --$businessName---");
          // Business header
          bytes += _generator!.text(
            businessName,
            styles: PosStyles(
              align: PosAlign.center,
              bold: true,
              fontType: PosFontType.fontB,
              height: getTextSize(headerFontSizePref), // Set height to minimum
              width: getTextSize(headerFontSizePref), // Set height to minimum
            ),
          );
        }

        if (contactPhone.isNotEmpty) {
          bytes += _generator!.text(
            "Ph: $contactPhone",
            styles: PosStyles(
              align: PosAlign.center,
              fontType: PosFontType.fontA,
              height: PosTextSize.size1, // Set height to minimum
            ),
          );
        }
        
        if (contactEmail.isNotEmpty) {
          bytes += _generator!.text(
            contactEmail,
            styles: PosStyles(
              align: PosAlign.center,
              fontType: PosFontType.fontA,
              height: PosTextSize.size1, // Set height to minimum
            ),
          );
        }
        
        if (businessAddress.isNotEmpty) {
          bytes += _generator!.text(
            businessAddress,
            styles: PosStyles(
              align: PosAlign.center,
              fontType: PosFontType.fontA,
              height: PosTextSize.size1, // Set height to minimum
            ),
          );
        }
        
        if (gst.isNotEmpty) {
          bytes += _generator!.text(
            "GST: $gst",
            styles: PosStyles(
              align: PosAlign.center,
              fontType: PosFontType.fontA,
              height: PosTextSize.size1, // Set height to minimum
            ),
          );
        }

        // Bill number
        String billtable = (tableNumber != null) ?  "Bill No: $billNo / Table No-: $tableNumber" :  "Bill No: $billNo" ;
        bytes += _generator!.text(
          billtable,
          styles: PosStyles(
            bold: true,
            fontType: PosFontType.fontA,
            height: PosTextSize.size1, // Set height to minimum
          ),
        );

        
        bytes += _generator!.text(
          "Time:- $dateTime",
          styles: PosStyles(
          fontType: PosFontType.fontA,
          ),
        );



        if (customerName ) {
          debugPrint("⚠️ check printer is connected tota --$transactionData---");
          bytes += _generator!.hr();
          bytes += _generator!.text(
            "TO Customer:- ",
            styles: PosStyles(
              // align: PosAlign.center,
              fontType: PosFontType.fontA,
              height: PosTextSize.size1, // Set height to minimum
            ),
          );

          bytes += _generator!.text(
            "Name: ${transactionData?['customerName'] ?? " "}",
            styles: PosStyles(
              // align: PosAlign.center,
              bold: true,
              fontType: PosFontType.fontA,
              height: PosTextSize.size1, // Set height to minimum
              width: PosTextSize.size1,
            ),
          );

          bytes += _generator!.text(
            "Mobile NO: ${transactionData?['mobileNo'] ?? " "}",
            styles: PosStyles(
              // align: PosAlign.center,
              fontType: PosFontType.fontA,
              height: PosTextSize.size1, // Set height to minimum
            ),
          );

          bytes += _generator!.hr();
        }


        // bytes += _generator!.feed(1);
        // Item header
        bytes += _generator!.row([
          PosColumn(
            text: 'Item',
            width: 6,
            styles: PosStyles(bold: true, fontType: PosFontType.fontA, height: PosTextSize.size1),
          ),
          PosColumn(
            text: 'Qty',
            width: 2,
            styles: PosStyles(align: PosAlign.right, bold: true, fontType: PosFontType.fontA, height: PosTextSize.size1),
          ),
          PosColumn(
            text: 'Rate',
            width: 2,
            styles: PosStyles(align: PosAlign.right, bold: true, fontType: PosFontType.fontA, height: PosTextSize.size1),
          ),
          PosColumn(
            text: 'Sum',
            width: 2,
            styles: PosStyles(align: PosAlign.right, bold: false, fontType: PosFontType.fontA, height: PosTextSize.size1),
          ),
        ]);

        bytes += _generator!.hr();
        // bytes += _generator!.feed(1);

        // Cart items
        for (var item in cart) {
          String name = item['name'] ?? 'Item';
          int qty = item['qty'] ?? 0;
          final dynamic rawPrice = item['sellPrice'];
          final int rate = rawPrice is num
              ? rawPrice.toInt()
              : int.tryParse(rawPrice.toString().replaceAll(',', '')) ??
                    double.tryParse(rawPrice.toString())?.toInt() ??
                    0;
          
          // debugPrint("rate  $rate and $cart");
          int itemTotal = qty * rate;

          // Handle long item names by wrappingitem['qty']
          // const int maxNameWidth = 25;
          // List<String> wrapped = _wrapText(name, maxNameWidth);
          
          bytes += _generator!.row([
            PosColumn(
              text: name,
              width: 7,
              styles: PosStyles(fontType: PosFontType.fontA, bold: true, height: getTextSize(itemFontSizePref)),
            ),
            PosColumn(
              text: qty.toString(),
              width: 1,
              styles: PosStyles(align: PosAlign.right,bold: true,  fontType: PosFontType.fontA, height: getTextSize(itemFontSizePref)),
            ),
            PosColumn(
              text: rate.toString(),
              width: 2,
              styles: PosStyles(align: PosAlign.right,bold: true,  fontType: PosFontType.fontA, height: getTextSize(itemFontSizePref)),
            ),
            PosColumn(
              text: itemTotal.toString(),
              width: 2,
              styles: PosStyles(align: PosAlign.right,bold: true,  fontType: PosFontType.fontA, height: getTextSize(itemFontSizePref)),
            ),
          ]);
        }

        bytes += _generator!.hr();

        // Transaction data (discount, service charge)
        if (transactionData != null) {
          if (transactionData['discount'] != null && transactionData['discount'] > 0) {
            // bytes += _generator!.feed(1); // Commented out to reduce gap
            bytes += _generator!.row([
              PosColumn(
                text: 'Discount:',
                width: 6,
                styles: PosStyles(fontType: PosFontType.fontA, height: PosTextSize.size1),
              ),
              PosColumn(
                text: '${transactionData['discount']}',
                width: 6,
                styles: PosStyles(align: PosAlign.right, fontType: PosFontType.fontA, height: PosTextSize.size1),
              ),
            ]);
          }

          if (transactionData['serviceCharge'] != null && transactionData['serviceCharge'] > 0) {
            // bytes += _generator!.feed(1); // Commented out to reduce gap
            bytes += _generator!.row([
              PosColumn(
                text: 'Service Charge:',
                width: 6,
                styles: PosStyles(fontType: PosFontType.fontA, height: PosTextSize.size1),
              ),
              PosColumn(
                text: '${transactionData['serviceCharge']}',
                width: 6,
                styles: PosStyles(align: PosAlign.right, fontType: PosFontType.fontA, height: PosTextSize.size1),
              ),
            ]);
          }
        }

        // Total
        // bytes += _generator!.feed(1); // Commented out to reduce gap
        bytes += _generator!.row([
          PosColumn(
            text: 'TOTAL:',
            width: 5,
            styles: PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2, fontType: PosFontType.fontB),
          ),
          PosColumn(
            text: 'Rs.$total',
            width: 7,
            styles: PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2, fontType: PosFontType.fontB),
          ),
        ]);

        // bytes += _generator!.feed(1); // Commented out to reduce gap

        // QR Code
        if (printQr && upiId != null && upiId.isNotEmpty) {
          if(_printQRlogo){
            final qrlogo = await generateQRImage(total:total);
            if (qrlogo != null){
              img.Image? original = img.decodeImage(qrlogo);
              if (original != null){
                bytes += _generator!.imageRaster(original); 
              }
            }

          } else {
            // await _printQrCode(businessName, total);
            final String encodedBusinessName = Uri.encodeComponent(businessName);

            // Now use the encoded name in the qrData string
            String qrData = "upi://pay?pa=$upiId&pn=$encodedBusinessName&am=$total.00&cu=INR";
            bytes += _generator!.qrcode( qrData, size : getQRSize(int.tryParse(_qrSize) ?? 5) );        //.qrCode(qrData, size: QRSize.Size4);
            bytes += _generator!.feed(1);
          }
        } 

        // Thank you message
        bytes += _generator!.text(
          footer,
          styles: PosStyles(
            align: PosAlign.center,
            bold: true,
            width: PosTextSize.size1,//getTextSize(itemFontSizePref),
            fontType: PosFontType.fontA,
            height: PosTextSize.size1, // Set height to minimum
          ),
        );

        bytes += _generator!.feed(2);
        // bytes += _generator!.cut();

        // debugPrint("before clear total ${bytes.length} and cart $bytes");
        // Send to printer
        // bytes += _generator!.beep();
        await _sendToPrinter();

        // debugPrint("before clear total $total and cart $cart");
        cart.clear();
        await _disconnect(); 
        
        // debugPrint("✅ Receipt sent to printer successfully");
      }

    } catch (e) {
      debugPrint("❌ Error printing receipt: $e");
      rethrow;
    }
  }
























  /// Prints a Kitchen Order Ticket (KOT)
  Future<void> sendKotToPrinter({
    required BuildContext context,
    required List<Map<String, dynamic>> cart,
    int? tableNumber = 1,
    int? kotNumber = 1,
  }) async {
    if (_generator == null) {
      throw Exception("Printer not initialized");
      
    }
    final prefs = await SharedPreferences.getInstance();
    bool marathi = prefs.getBool('marathi') ?? false;
    PrintQuality quality = PrintQuality.maximum;
    final String dateTime = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

    List<Map<String, dynamic>> kotCart = cart.map((item) => Map<String, dynamic>.from(item)).toList();

    try {
      await _setPrintQuality(quality);
      if (marathi){
        Uint8List? imageBytes = await generateKOTImage(cart1: cart,tableNumber:tableNumber,kotNumber:kotNumber,);
        if (imageBytes != null) {
          // showDialog(
          //   context: context,
          //   builder: (_) => AlertDialog(
          //     content: Image.memory(imageBytes),
          //   ),
          // );
          // Example: Save to file (requires path_provider package)
          final directory = await getDownloadsDirectory();
          final path = '${directory!.path}/receipt_1.png';
          final file = File(path);
          await file.writeAsBytes(imageBytes);
          debugPrint("Receipt image saved to: $path");

          img.Image? original = img.decodeImage(imageBytes);
          if (original != null) {
            
            // Convert to grayscale for better thermal printing
            final grayscale = img.grayscale(original);
            bytes += _generator!.imageRaster(grayscale);
            // bytes += _generator!.feed(2);
            // bytes += _generator!.cut();
          }

          await _sendToPrinter(imageBytes:imageBytes);

          // kotCart.clear();
          // cart.clear();
          await _disconnect(); 
          return;
        }
      } else { 
        // if(printName){
        //   debugPrint("⚠️ No logo found in SharedPreferences --$businessName---");
        //   // Business header
        //   bytes += _generator!.text(
        //     businessName,
        //     styles: PosStyles(
        //       align: PosAlign.center,
        //       bold: true,
        //       fontType: PosFontType.fontA,
        //       width: PosTextSize.size3,
        //       height:  PosTextSize.size3, // Set height to minimum
        //     ),
        //   );
        // }
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

        bytes += _generator!.text(
            "KOT No: $kotNumber / Table No: $tableNumber",
            styles: PosStyles(
              bold: true,
              align: PosAlign.center,
              fontType: PosFontType.fontA,
            ),
          );

        // bytes += _generator!.text(
        //   "Table No: $tableNumber",
        //   styles: PosStyles(
        //     align: PosAlign.center,
        //     bold: true,
        //     height: PosTextSize.size2,
        //     width: PosTextSize.size2,
        //     fontType: PosFontType.fontB,
        //   ),
        // );

        bytes += _generator!.text(
          "KOT Time:- $dateTime",
          styles: PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontA,
          ),
        );
        
        // if (kotNumber != null) {
        //   bytes += _generator!.text(
        //     "KOT No: $kotNumber",
        //     styles: PosStyles(
        //       align: PosAlign.center,
        //       fontType: PosFontType.fontA,
        //     ),
        //   );
        // }
        
        // bytes += _generator!.feed(1);
        
        // Item header
        bytes += _generator!.row([
          PosColumn(
            text: 'Item',
            width: 8,
            styles: PosStyles(bold: true, fontType: PosFontType.fontA),
          ),
          PosColumn(
            text: 'Note  Qty',
            width: 4,
            styles: PosStyles(align: PosAlign.right, bold: true, fontType: PosFontType.fontA),
          ),
        ]);

        bytes += _generator!.hr();
        // bytes += _generator!.feed(1);

        // Item List
        for (var item in kotCart) {
          String name = item['name'] ?? 'Item';
          int qty = item['qty'] ?? 0;
          String note = item['note'] ?? ' ';
          
          // const int maxNameWidth = 20;
          // List<String> wrapped = _wrapText(name, maxNameWidth);
          
          // for (int i = 0; i < wrapped.length; i++) {
          //   if (i == 0) {
              bytes += _generator!.row([
                PosColumn(
                  text: name,
                  width: 7,
                  styles: PosStyles(fontType: PosFontType.fontA,bold: true),
                ),
                PosColumn(
                  text: note,
                  width: 4,
                  styles: PosStyles(align: PosAlign.center,fontType: PosFontType.fontA,bold: true),
                ),
                PosColumn(
                  text: "$qty",
                  width: 1,
                  styles: PosStyles(align: PosAlign.right, fontType: PosFontType.fontA,bold: true),
                ),
              ]);
          //     } else {
          //       bytes += _generator!.text(
          //         "  ${wrapped[i]}",
          //         styles: PosStyles(fontType: PosFontType.fontA),
          //       );
          //     }
          //   }
          //   // bytes += _generator!.feed(1);
        }

        bytes += _generator!.hr();
        bytes += _generator!.feed(2);
        // bytes += _generator!.cut();

        await _sendToPrinter();
        kotCart.clear();
        await _disconnect(); 
        
        debugPrint("✅ KOT for Table #$tableNumber sent to printer.");
      }

    } catch (e) {
      debugPrint("❌ Error printing KOT: $e");
      rethrow;
    }
  }


  List<String> _wrapText(String text, int width) {
    List<String> lines = [];
    List<String> words = text.split(' ');
    String currentLine = '';
    debugPrint("currentLine $text  $width");

    for (String word in words) {
      if ((currentLine + ' ' + word).length <= width) {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word;
      }
      debugPrint("currentLine $currentLine");
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    debugPrint("currentLine $lines");
    return lines;
  }

  Future<bl.BluetoothDevice?> _getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    String? address = prefs.getString('saved_printer_address');
    debugPrint("Looking for saved printer with address: $address");
    
    if (address == null) {
      debugPrint("❌ No saved printer address found");
      return null;
    }

    try {
      // Method 1: Check bonded devices first (already paired)
      List<bl.BluetoothDevice> bondedDevices = await bl.FlutterBluePlus.bondedDevices;
      debugPrint("Found ${bondedDevices.length} bonded devices");
      
      for (var device in bondedDevices) {
        debugPrint("Bonded: ${device.platformName} - ${device.remoteId}");
        if (device.remoteId.toString() == address) {
          debugPrint("✅ Found saved printer in bonded devices!");
          return device;
        }
      }

      // Method 2: If not bonded, create a device from address and connect
      debugPrint("🔄 Printer not bonded, creating device from address...");
      
      // Create device from address
      bl.BluetoothDevice device = bl.BluetoothDevice(remoteId: bl.DeviceIdentifier(address));
      
      debugPrint("✅ Created device from address: ${device.remoteId}");
      return device;
      
    } catch (e) {
      debugPrint("❌ Error in _getSavedPrinter: $e");
      return null;
    }
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
    
      if(pageback != null && pageback > 0){
        for(int i =0 ;i < pageback ;i++){
          debugPrint("save pageback1 $pageback");
          Navigator.of(context).pop();
        }
      }else{
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
      debugPrint(" up pageback1 $pageback");
      if(pageback != null && pageback > 0){
        for(int i =0 ;i < pageback ;i++){
          debugPrint(" up pageback1 $pageback");
          Navigator.of(context).pop();
        }
      }else{
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      
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




















Future<double> _drawText(
  ui.Canvas canvas,
  String text, {
  required double y,
  required double width,
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  TextAlign align = TextAlign.left,
}) async {
  final paraBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: align,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontFamily: 'Roboto', // Or your app's font
  ))
    ..pushStyle(ui.TextStyle(color: Colors.black))
    ..addText(text);

  final para = paraBuilder.build();
  para.layout(ui.ParagraphConstraints(width: width));

  canvas.drawParagraph(para, ui.Offset(0, y));
  return para.height;
}

/// Helper to draw left-aligned and right-aligned text on the same line.
Future<double> _drawLeftRight(
  ui.Canvas canvas,
  String leftText,
  String rightText, {
  required double y,
  required double width,
  required double fontSize,
  FontWeight leftFontWeight = FontWeight.normal,
  FontWeight rightFontWeight = FontWeight.normal,
}) async {
  // --- Draw Left Text ---
  final leftParaBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.left,
    fontSize: fontSize,
    fontWeight: leftFontWeight,
  ))
    ..pushStyle(ui.TextStyle(color: Colors.black))
    ..addText(leftText);
  
  final leftPara = leftParaBuilder.build();
  // Constrain left text to ~60% of width to avoid overlap
  final leftWidth = width * 0.6;
  leftPara.layout(ui.ParagraphConstraints(width: leftWidth));
  canvas.drawParagraph(leftPara, ui.Offset(0, y));

  // --- Draw Right Text ---
  final rightParaBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.right,
    fontSize: fontSize,
    fontWeight: rightFontWeight,
  ))
    ..pushStyle(ui.TextStyle(color: Colors.black))
    ..addText(rightText);

  final rightPara = rightParaBuilder.build();
  // Right text can use the full width, as it's right-aligned
  rightPara.layout(ui.ParagraphConstraints(width: width));
  canvas.drawParagraph(rightPara, ui.Offset(0, y));

  // Return the height of the taller of the two paragraphs
  return max(leftPara.height, rightPara.height);
}

/// Draws a dashed line
Future<double> _drawDashedLine(ui.Canvas canvas, double y, double width, double fontSize) {
  // You can also draw this with canvas.drawLine and a dashed path effect,
  // but for thermal printers, text dashes are more authentic.
  return _drawText(
    canvas,
    '---------------------------------------------------------------', // Adjust count for your width
    y: y,
    width: width,
    fontSize: fontSize,
    align: TextAlign.center,
  );
}


Future<double> _drawLogo(ui.Canvas canvas, double y, double width) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    int logoWidth = prefs.getInt('logoWidth') ?? 200;
    final imagePath = prefs.getString('imagePath');
    final _printlogo = prefs.getBool('printLogo') ?? true;

    // --- DIAGNOSTIC PRINT ---
    // Let's check what path is being used.
    debugPrint("Attempting to load logo from path: $imagePath");

    if (imagePath != null && File(imagePath).existsSync() && _printlogo) {
      
      // --- File was found, proceed ---
      debugPrint("Logo file found. Decoding...");

      final file = File(imagePath);
      final imageBytes = await file.readAsBytes();
      
      img.Image? original = img.decodeImage(imageBytes);

      // Handle failed decode
      if (original == null) {
        // --- ADDED ERROR PRINT ---
        debugPrint("Error: Could not decode logo image. Is it a valid PNG/JPG?");
        return 0.0;
      }
      
      // Resize to fit printer width
      final resized = img.copyResize(original, width: logoWidth, maintainAspect: true);
      final grayscale = img.grayscale(resized);
      final Uint8List resizedBytes = img.encodePng(grayscale); // Grayscale is optional
      
      final codec = await ui.instantiateImageCodec(resizedBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Scale image to fit canvas width if it's too large
      double imageWidth = image.width.toDouble();
      double imageHeight = image.height.toDouble();
      if (imageWidth > width) {
        final ratio = width / imageWidth;
        imageWidth = width;
        imageHeight = imageHeight * ratio;
      }

      // Center the logo
      final xOffset = (width - imageWidth) / 2;
      final rect = ui.Rect.fromLTWH(xOffset, y, imageWidth, imageHeight);
      
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint(),
      );
    
      // --- 1. FIXED THIS PRINT ---
      // This was showing an "Error" message before, now it shows success.
      debugPrint("Logo drawn successfully. Height: ${imageHeight + 10.0}");
      return imageHeight + 10.0; // Return height + padding

    } else {
      // --- 2. ADDED THIS PRINT ---
      // This is the most likely reason your logo isn't showing.
      debugPrint("Logo not drawn. Reason: File path was null or file does not exist at path.");
      return 0.0;
    }
  } catch (e) {
    debugPrint("Error drawing logo: $e");
    return 0.0;
  }
}

Future<ui.Image?> _loadLogoImage() async {
  try {
    const String upiLogoPath = 'assets/images/round_logo.png';
    final ByteData data = await rootBundle.load(upiLogoPath);
    final Uint8List bytes = data.buffer.asUint8List();
    
    // Decode using image package
    final original = img.decodeImage(bytes);
    if (original != null) {
      final grayscale = img.grayscale(original);
      
      // Convert back to ui.Image
      final Uint8List grayscaleBytes = Uint8List.fromList(img.encodePng(grayscale));
      final ui.Codec codec = await ui.instantiateImageCodec(grayscaleBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    }
    return null;
  } catch (e) {
    print('Failed to load logo: $e');
    return null;
  }
}

  double getQrPixelSize(qrSize) {
    switch (qrSize) {
      case "1": return 115;
      case "2": return 130;
      case "3": return 150;
      case "5": return 180;
      case "7": return 200;
      default: return 150;
    }
  }

Future<double> _drawQrCode(
  ui.Canvas canvas,
  String businessName,
  int total,
  double qrPixelSize,
  double y,
  double width,
  String upiId,
) async {

  // --- THIS IS THE FIX ---
    // Encode the business name to handle special characters
    final String encodedBusinessName = Uri.encodeComponent(businessName);
    final prefs = await SharedPreferences.getInstance();
    bool _printQRlogo = prefs.getBool('printQRlogo') ?? true;

    // Now use the encoded name in the qrData string
    String qrData = "upi://pay?pa=$upiId&pn=$encodedBusinessName&am=$total.00&cu=INR";
    // -------------------------
    try {

      QrPainter qrPainter;
      double logoWidth = (150 == qrPixelSize) ? 40 : 40 - ( (80 / (qrPixelSize)) *10);
      double logoHeight = (150 == qrPixelSize) ? 35 : 35 - ( (70 / (qrPixelSize)) *10);

      if (_printQRlogo) {
        debugPrint("logoWidth: $logoWidth logoHeight :$logoHeight");
        qrPainter = QrPainter(
          data: qrData,
          version: QrVersions.auto,
          gapless: true,
          embeddedImage: await _loadLogoImage() , 
          embeddedImageStyle: QrEmbeddedImageStyle(
            size: Size(logoWidth, logoHeight), // ✅ removed const
          ),
        );
      } else {
        qrPainter = QrPainter(
          data: qrData,
          version: QrVersions.auto,
          gapless: true,
        );
      }

    // Convert QrPainter to ui.Image
    ui.Image qrImage = await qrPainter.toImage(qrPixelSize);
    // final qrImage = await qrPainter;
    
    // Center it
    final xOffset = (width - qrImage.width) / 2.0;
    canvas.drawImage(qrImage, ui.Offset(xOffset, y), Paint());
    
    return qrImage.height.toDouble(); // + padding
  } catch (e) {
    debugPrint("Error drawing QR code: $e");
    return 0.0;
  }
}

Future<Uint8List?> generateQRImage({required int total,}) async {
  
  final prefs = await SharedPreferences.getInstance();
  

  String businessName = prefs.getString('businessName') ?? 'Hotel Test';
  bool printQr = prefs.getBool('printQR') ?? false;
  String _qrSize = prefs.getString('qrSize') ?? "5";
  double qrSize = getQrPixelSize(_qrSize);
  String? upiId = prefs.getString('upi');
  String paperSize = prefs.getString('paperSize') ?? '2';
  final double receiptWidth = (paperSize == "2") ? 384.0 :(paperSize == "3") ? 512.0 : 576.0 ;

  
  
  // --- 3. Setup Canvas ---
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  // Start with a large canvas, we'll crop it later
  final ui.Rect canvasRect = ui.Rect.fromLTWH(0, 0, receiptWidth, 20000); 
  final ui.Canvas canvas = ui.Canvas(recorder, canvasRect);

  // White background
  canvas.drawRect(canvasRect, Paint()..color = Colors.white);
  
  double yOffset = 10.0; // Start with a 10px top margin

  // --- 4. Draw Receipt (Translate bluetooth calls to canvas calls) ---
  
  try {

    // QR Code
    if (printQr && upiId != null && upiId.isNotEmpty) {
      // **ADAPT THIS** to match your _printQrCode logic
      yOffset += await _drawQrCode(canvas, businessName, total, qrSize, yOffset, receiptWidth, upiId);
      yOffset += 10.0;
    }
    
    
    // Stop recording
    final ui.Picture picture = recorder.endRecording();
    
    // Crop the image to the final height
    final ui.Image finalImage = await picture.toImage(
      receiptWidth.toInt(),
      yOffset.toInt(), // Crop to the height we actually used
    );
    
    // Encode to PNG
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    
    return byteData.buffer.asUint8List();

  } catch (e) {
    debugPrint("Error generating receipt image: $e");
    return null;
  }
}


Future<Uint8List?> generateReceiptImage({
  required List<Map<String, dynamic>> cart1,
  required int total,
  required int billNo,
  required Map<String, dynamic>? transactionData,
  int? tableno,
}) async {
  
  // --- 1. Configuration (MUST TWEAK THESE) ---
  

  
  // Map your printer's font sizes (1, 2, 3) to pixel font sizes
  final Map<int, double> fontSizes = {
    1: 18.0, // Small (items)
    2: 24.0, // Medium (total)
    3: 30.0, // Large (header)
  };
  
  // --- 2. Get All Data (Copied from your function) ---
  
  List<Map<String, dynamic>> cart = cart1.map((item) => Map<String, dynamic>.from(item)).toList();
  final prefs = await SharedPreferences.getInstance();


  // 🏪 Business info
  String businessName = prefs.getString('businessName') ?? 'Hotel Test';
  String contactPhone = prefs.getString('contactPhone') ?? '';
  String contactEmail = prefs.getString('contactEmail') ?? '';
  String businessAddress = prefs.getString('businessAddress') ?? '';
  String gst = prefs.getString('gst') ?? '';
  
  // ⚙ Printer user settings
  bool printQr = prefs.getBool('printQR') ?? false;
  String _qrSize = prefs.getString('qrSize') ?? "5";
  double qrSize = getQrPixelSize(_qrSize);
  bool printName = prefs.getBool('printName') ?? true;
  String footer =  prefs.getString('footerText') ?? "** Thank You **";
  String? upiId = prefs.getString('upi');
  bool customerName = prefs.getBool('customerName') ?? false;
  String paperSize = prefs.getString('paperSize') ?? '2';
  // Width in pixels. 58mm printers are ~384px. 80mm are ~576px.
    //   if (value == PaperSize.mm58.value) {
    //   return 384;
    // } else if (value == PaperSize.mm72.value) {
    //   return 512;
    // } else {
    //   return 576;
    // }
  final double receiptWidth = (paperSize == "2") ? 384.0 :(paperSize == "3") ? 512.0 : 576.0 ;

  debugPrint("Receipt image savedfooter customerName $customerName $footer printName $printName businessName$businessName contactPhone$contactPhone contactEmail$contactEmail businessAddress$businessAddress");
  
  // Font sizes from prefs
  double fHeader = 37;//fontSizes[headerFontSize] ?? 30.0;
  double fItem = 21;//fontSizes[itemFontSize] ?? 18.0;
  double fTotal = 30;//fontSizes[2] ?? 24.0; // Total/Discount size is '2' in your code
  final String dateTime = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
  
  // --- 3. Setup Canvas ---
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  // Start with a large canvas, we'll crop it later
  final ui.Rect canvasRect = ui.Rect.fromLTWH(0, 0, receiptWidth, 20000); 
  final ui.Canvas canvas = ui.Canvas(recorder, canvasRect);

  // White background
  canvas.drawRect(canvasRect, Paint()..color = Colors.white);
  
  double yOffset = 10.0; // Start with a 10px top margin

  // --- 4. Draw Receipt (Translate bluetooth calls to canvas calls) ---
  
  try {
    // Logo
    // **ADAPT THIS** to match your _printLogo logic
    yOffset += await _drawLogo(canvas, yOffset, receiptWidth);
    yOffset += 5; // New line

    // Business Info
    if (printName){
      yOffset += await _drawText(canvas, businessName, y: yOffset, width: receiptWidth, fontSize: fHeader, fontWeight: FontWeight.bold, align: TextAlign.center);
    }
    if (contactPhone.isNotEmpty) {
      yOffset += await _drawText(canvas, "Ph: $contactPhone", y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);
    }
    if (contactEmail.isNotEmpty) {
      yOffset += await _drawText(canvas, contactEmail, y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);
    }
    if (businessAddress.isNotEmpty) {
      yOffset += await _drawText(canvas, businessAddress, y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);
    }
    if (gst.isNotEmpty) {
      yOffset += await _drawText(canvas, "GST: $gst", y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);
    }
    // if (tableno != null) {
    //   yOffset += await _drawText(canvas, "", y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);
    // }
    
    yOffset += await _drawText(canvas, "Time:- $dateTime", y: yOffset, width: receiptWidth, fontWeight: FontWeight.bold, fontSize: fItem,);

    String billtable = (tableno != null) ?  "Bill No: $billNo / Table No-: $tableno" :  "Bill No: $billNo" ;
    yOffset += 5; // New line
    yOffset += await _drawText(canvas, billtable, y: yOffset, width: receiptWidth,fontWeight: FontWeight.bold, fontSize: fItem,);
    yOffset += 5;


    if (customerName ) {
      debugPrint("⚠️ check printer is connected tota --$transactionData---");
      yOffset += await _drawDashedLine(canvas, yOffset, receiptWidth, fItem);
      yOffset += 10; // New line
      
      yOffset += await _drawText(canvas, "TO Customer:- ", y: yOffset, width: receiptWidth,fontWeight: FontWeight.bold, fontSize: fItem, ); //align: TextAlign.center
      yOffset += 5;
      yOffset += await _drawText(canvas, "Name: ${transactionData?['customerName'] ?? " "}", y: yOffset, width: receiptWidth,fontWeight: FontWeight.bold, fontSize : fItem * 1.3, );
      yOffset += 2;
      yOffset += await _drawText(canvas, "Mobile NO: ${transactionData?['mobileNo'] ?? " "}", y: yOffset, width: receiptWidth,fontWeight: FontWeight.bold, fontSize: fItem ,);
      yOffset += 5; // New line
        // Line
      yOffset += await _drawDashedLine(canvas, yOffset, receiptWidth, fItem);
      yOffset += 5; // New line
      
    }

    // Header
    yOffset += await _drawLeftRight(canvas, "Item", "Qty  Rate  Total", y: yOffset, width: receiptWidth, fontSize: fItem, leftFontWeight: FontWeight.bold, rightFontWeight: FontWeight.bold);
    
    // Line
    yOffset += await _drawDashedLine(canvas, yOffset, receiptWidth, fItem);
    yOffset += 5; // New line

    // Cart Items
    for (var item in cart) {
      String name = item['name'] ?? 'Item';
      int qty = item['qty'] ?? 0;
      final dynamic rawPrice = item['sellPrice'];
      final int rate = rawPrice is num
          ? rawPrice.toInt()
          : int.tryParse(rawPrice.toString().replaceAll(',', '')) ??
                double.tryParse(rawPrice.toString())?.toInt() ??
                0;
      int total = qty * rate;
      String rightText =
          "${qty.toString().padLeft(2)}  ${rate.toString().padLeft(4)}  ${total.toString().padLeft(5)}";

      // The _drawLeftRight helper handles wrapping, so we don't need your _wrapText loop
      yOffset += await _drawLeftRight(canvas, name, rightText, y: yOffset, width: receiptWidth, fontSize: fItem,leftFontWeight: FontWeight.bold, rightFontWeight: FontWeight.bold);
      yOffset += 4; // Small padding between items
    }
    
    // Line
    yOffset += await _drawDashedLine(canvas, yOffset, receiptWidth, fItem);
    
    // Totals
    if (transactionData != null) {
      if (transactionData['discount'] != null && transactionData['discount'] > 0) {
        yOffset += 5; // New line
        yOffset += await _drawLeftRight(canvas, "Discount:", "${transactionData['discount']}", y: yOffset, width: receiptWidth, fontSize: fTotal * 0.7, rightFontWeight: FontWeight.bold);
      }
      if (transactionData['serviceCharge'] != null && transactionData['serviceCharge'] > 0) {
        yOffset += 5; // New line
        yOffset += await _drawLeftRight(canvas, "Service Charge:", "${transactionData['serviceCharge']}", y: yOffset, width: receiptWidth, fontSize: fTotal *0.7, rightFontWeight: FontWeight.bold);
      }
    }
    
    yOffset += 10; // New line
    yOffset += await _drawLeftRight(canvas, "Total:", "Rs.$total", y: yOffset, width: receiptWidth, fontSize: fTotal, leftFontWeight: FontWeight.bold, rightFontWeight: FontWeight.bold);
    yOffset += 15; // New line

    // QR Code
    if (printQr && upiId != null && upiId.isNotEmpty) {
      // **ADAPT THIS** to match your _printQrCode logic
      yOffset += await _drawQrCode(canvas, businessName, total, qrSize, yOffset, receiptWidth, upiId);
      yOffset += 10;
    }
    
    // Footer
    yOffset += await _drawText(canvas, footer, y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);
    yOffset += 70; // Extra padding at the bottom
    
    // --- 5. Finalize and Encode Image ---
    
    // Stop recording
    final ui.Picture picture = recorder.endRecording();
    
    // Crop the image to the final height
    final ui.Image finalImage = await picture.toImage(
      receiptWidth.toInt(),
      yOffset.toInt(), // Crop to the height we actually used
    );
    
    // Encode to PNG
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    
    return byteData.buffer.asUint8List();

  } catch (e) {
    debugPrint("Error generating receipt image: $e");
    return null;
  }
}

Future<Uint8List?> generateKOTImage({
  required List<Map<String, dynamic>> cart1,
  int? tableNumber,
  int? kotNumber = 1,
}) async {
  
  // --- 1. Configuration (MUST TWEAK THESE) ---
  
  // Width in pixels. 58mm printers are ~384px. 80mm are ~576px.

  // const double receiptWidth = 384.0;
  
  // Map your printer's font sizes (1, 2, 3) to pixel font sizes
  final Map<int, double> fontSizes = {
    1: 18.0, // Small (items)
    2: 24.0, // Medium (total)
    3: 30.0, // Large (header)
  };
  
  // --- 2. Get All Data (Copied from your function) ---
  
  List<Map<String, dynamic>> cart = cart1.map((item) => Map<String, dynamic>.from(item)).toList();
  final prefs = await SharedPreferences.getInstance();
  
  double getQrPixelSize(qrSize) {
    switch (qrSize) {
      case "3": return 150;
      case "5": return 180;
      case "7": return 200;
      default: return 150;
    }
  }

  // 🏪 Business info
  String businessName = prefs.getString('businessName') ?? 'Hotel Test';
    
  String paperSize = prefs.getString('paperSize') ?? '2';
  // Width in pixels. 58mm printers are ~384px. 80mm are ~576px.
  final double receiptWidth = (paperSize == "2") ? 384.0 :(paperSize == "3") ? 512.0 : 576.0 ;

  
  String contactPhone = prefs.getString('contactPhone') ?? '';
  String contactEmail = prefs.getString('contactEmail') ?? '';
  String businessAddress = prefs.getString('businessAddress') ?? '';
  String gst = prefs.getString('gst') ?? '';
  
  // ⚙ Printer user settings
  bool printQr = prefs.getBool('printQR') ?? false;
  String _qrSize = prefs.getString('qrSize') ?? "5";
  double qrSize = getQrPixelSize(_qrSize);
  bool printName = prefs.getBool('printName') ?? true;
  String footer =  prefs.getString('footerText')?? "** Thank You **";
  String? upiId = prefs.getString('upi');
  
  // int headerFontSize = prefs.getInt('headerFontSize') ?? 3;
  // int itemFontSize = (prefs.getDouble('fontSize') ?? 1).toInt();
  
  // Font sizes from prefs
  double fHeader = 37;//fontSizes[headerFontSize] ?? 30.0;
  double fItem = 21;//fontSizes[itemFontSize] ?? 18.0;
  double fTotal = 29;//fontSizes[2] ?? 24.0; // Total/Discount size is '2' in your code
  
  
  // --- 3. Setup Canvas ---
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  // Start with a large canvas, we'll crop it later
  final ui.Rect canvasRect = ui.Rect.fromLTWH(0, 0, receiptWidth, 20000); 
  final ui.Canvas canvas = ui.Canvas(recorder, canvasRect);

  // White background
  canvas.drawRect(canvasRect, Paint()..color = Colors.white);
  
  double yOffset = 10.0; // Start with a 10px top margin
  final String dateTime = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());

  // --- 4. Draw Receipt (Translate bluetooth calls to canvas calls) ---
  
  try {
    // Logo
    // // **ADAPT THIS** to match your _printLogo logic
    // yOffset += await _drawLogo(canvas, yOffset, receiptWidth);
    // yOffset += 5; // New line

    // Business Info
      // yOffset += await _drawText(canvas, businessName, y: yOffset, width: receiptWidth, fontSize: fHeader, fontWeight: FontWeight.bold, align: TextAlign.center);

      yOffset += await _drawText(canvas, " KOT ", y: yOffset, width: receiptWidth, fontSize: fHeader, fontWeight: FontWeight.bold, align: TextAlign.center);

      yOffset += await _drawText(canvas, "kot no.- $kotNumber / table no:- $tableNumber", y: yOffset, width: receiptWidth, fontSize: fItem, fontWeight: FontWeight.bold, align: TextAlign.center);

      // yOffset += await _drawText(canvas, , y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);

      yOffset += await _drawText(canvas, "KOT time:- $dateTime", y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);

    
    // yOffset += 10; // New line
    // yOffset += await _drawText(canvas, "Bill No: ${billNo ?? 0}", y: yOffset, width: receiptWidth,fontWeight: FontWeight.bold, fontSize: fItem, align: TextAlign.center);
    // yOffset += 5;

    // Header
    yOffset += await _drawLeftRight(canvas, "Item", "Note   Qty", y: yOffset, width: receiptWidth, fontSize: fTotal, leftFontWeight: FontWeight.bold, rightFontWeight: FontWeight.bold);
    
    // Line
    yOffset += await _drawDashedLine(canvas, yOffset, receiptWidth, fItem);
    yOffset += 5; // New line

    // Cart Items
    for (var item in cart) {
      String name = item['name'] ?? 'Item';
      int qty = item['qty'] ?? 0;
      String note = item['note'] ?? " ";
      debugPrint("jhk bkxb $item");
      // final dynamic rawPrice = item['sellPrice'];
      // final int rate = rawPrice is num
      //     ? rawPrice.toInt()
      //     : int.tryParse(rawPrice.toString().replaceAll(',', '')) ??
      //           double.tryParse(rawPrice.toString())?.toInt() ??
      //           0;
      // int total = qty * rate;
      String rightText = "${note.padLeft(1)} ${qty.toString().padLeft(2)}";

      // The _drawLeftRight helper handles wrapping, so we don't need your _wrapText loop
      yOffset += await _drawLeftRight(canvas, " $name", rightText, y: yOffset, width: receiptWidth, fontSize: fTotal,leftFontWeight: FontWeight.bold, rightFontWeight: FontWeight.bold);
      yOffset += 4; // Small padding between items
    }
    
    // Line
    yOffset += await _drawDashedLine(canvas, yOffset, receiptWidth, fItem);
    yOffset += 60;
    
    // Totals
    // if (transactionData != null) {
    //   if (transactionData['discount'] != null && transactionData['discount'] > 0) {
    //     yOffset += 5; // New line
    //     yOffset += await _drawLeftRight(canvas, "Discount:", "${transactionData['discount']}", y: yOffset, width: receiptWidth, fontSize: fTotal, rightFontWeight: FontWeight.bold);
    //   }
    //   if (transactionData['serviceCharge'] != null && transactionData['serviceCharge'] > 0) {
    //     yOffset += 5; // New line
    //     yOffset += await _drawLeftRight(canvas, "Service Charge:", "${transactionData['serviceCharge']}", y: yOffset, width: receiptWidth, fontSize: fTotal, rightFontWeight: FontWeight.bold);
    //   }
    // }
    
    // yOffset += 10; // New line
    // yOffset += await _drawLeftRight(canvas, "Total:", "Rs.$total", y: yOffset, width: receiptWidth, fontSize: fTotal, leftFontWeight: FontWeight.bold, rightFontWeight: FontWeight.bold);
    // yOffset += 15; // New line

    // QR Code
    // if (printQr && upiId != null && upiId.isNotEmpty) {
    //   // **ADAPT THIS** to match your _printQrCode logic
    //   yOffset += await _drawQrCode(canvas, businessName, total, qrSize, yOffset, receiptWidth, upiId);
    //   yOffset += 10;
    // }
    
    // Footer
    // yOffset += await _drawText(canvas, footer, y: yOffset, width: receiptWidth, fontSize: fItem, align: TextAlign.center);
    // yOffset += 30; // Extra padding at the bottom
    
    // --- 5. Finalize and Encode Image ---
    
    // Stop recording
    final ui.Picture picture = recorder.endRecording();
    
    // Crop the image to the final height
    final ui.Image finalImage = await picture.toImage(
      receiptWidth.toInt(),
      yOffset.toInt(), // Crop to the height we actually used
    );
    
    // Encode to PNG
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    
    return byteData.buffer.asUint8List();

  } catch (e) {
    debugPrint("Error generating receipt image: $e");
    return null;
  }
}



}
