import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test1/utilities.dart';

/// PrinterService - Complete implementation of all printer methods
class PrinterService {
  static const MethodChannel _channel = MethodChannel('com.orbipay.test8/printer');
  static const EventChannel _eventChannel = EventChannel('com.orbipay.test8/printer_events');
  
  // Connection type constants
  static const int CONN_TYPE_BT = 1;
  static const int CONN_TYPE_USB = 2;
  static const int CONN_TYPE_IP = 3;
  
  int _connType = CONN_TYPE_BT;
  int _glbPrinterWidth = 32;
  bool _isConnected = false;
  
  // Callbacks
  Function(String)? onConnectionStatus;
  Function(String)? onError;
  
  // ==================== CONNECTION METHODS ====================
  
  /// Get paired Bluetooth printers
  Future<List<String>> getPairedPrinters() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getPairedPrinters');
      return result.cast<String>().toList();
    } on PlatformException catch (e) {
      //debugPrint("Failed to get printers: '${e.message}'.");
      onError?.call(e.message ?? 'Failed to get printers');
      return [];
    }
  }

  /// Print image
  static Future<bool> printImage(Uint8List imageBytes) async {
    try {
      final success = await _channel.invokeMethod('printImage', {
        'imageBytes': imageBytes,
        'paperSize': 0, // 0 for 2-inch, 1 for 3-inch
      });
      return success ?? false;
    } on PlatformException catch (e) {
      //debugPrint("Failed to print image: '${e.message}'.");
      return false;
    }
  }
  
  /// Print text
  /// Send raw bytes to the printer
  static Future<bool> sendPrintRequest(List<int> bytes) async {
    try {
      final Uint8List dataToPrint = Uint8List.fromList(bytes);
      // Pass the Uint8List directly; it becomes a ByteArray in Kotlin
      final bool? success = await _channel.invokeMethod('print', {
        'bytes': dataToPrint,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print_log("Failed to print: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> Initialize_Printer() async {
    try {
      // Pass the Uint8List directly; it becomes a ByteArray in Kotlin
      await _channel.invokeMethod('Initialize_Printer');
      return true;
    } on PlatformException catch (e) {
      print_log("Failed to print: '${e.message}'.");
      return false;
    }
  }
  

  static Future<bool> connectToPrinterUsingMac(String macAddress) async {
    try {
      final result = await _channel.invokeMethod('connectToPrinterUsingMac', {
        'macAddress': macAddress,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      //debugPrint("Failed to connect using MAC: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> isconnected() async {
    try {
      final result = await _channel.invokeMethod('isPrinterConnected');
      return result ?? false;
    } on PlatformException catch (e) {
      //debugPrint("Failed to connect using MAC: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnectPrinter');
      return result ?? false;
    } on PlatformException catch (e) {
      //debugPrint("Failed to connect using MAC: '${e.message}'.");
      return false;
    }
  }








  /// Connect to printer using context menu style
  Future<bool> connectToPrinter(String printerName) async {
    try {
      final success = await _channel.invokeMethod('connectToPrinter', {
        'printerNameWithMac': printerName,
      });
      
      if (success) {
        _isConnected = true;
        onConnectionStatus?.call('Connected with $printerName');
        
        // Enable all print buttons
        _setPrintButtonsEnabled(true);
      }
      
      return success;
    } on PlatformException catch (e) {
      final message = e.message ?? '';
      if (message.contains('Service discovery failed')) {
        onError?.call('Not Connected\n$printerName is unreachable or off otherwise it is connected with other device');
      } else if (message.contains('Device or resource busy')) {
        onError?.call('The device is already connected');
      } else {
        onError?.call('Unable to connect');
      }
      return false;
    }
  }
  
  /// Show paired printers (like context menu)
  Future<void> showPairedPrinters(Function(String) onPrinterSelected) async {
    final printers = await getPairedPrinters();
    if (printers.isNotEmpty) {
      // You would typically show a dialog or bottom sheet here
      // For now, we'll just select the first printer
      if (printers.isNotEmpty) {
        onPrinterSelected(printers.first);
      }
    } else {
      onError?.call('No Paired Printers found');
    }
  }
  
  /// Set printer type (2-inch or 3-inch)
  Future<void> setPrinterType(int width) async {
    _glbPrinterWidth = width;
    if (width == 48) {
      onConnectionStatus?.call('48 Characters / Line or 3 Inch (80mm) Printer Selected!');
    }
  }
  
  /// Disconnect printer
  Future<bool> disconnectPrinter() async {
    try {
      final success = await _channel.invokeMethod('disconnectPrinter');
      if (success) {
        _isConnected = false;
        _setPrintButtonsEnabled(false);
      }
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to disconnect');
      return false;
    }
  }
  
  // ==================== PRINTING METHODS ====================
  
  /// Initialize printer
  Future<bool> initializePrinter() async {
    try {
      final success = await _channel.invokeMethod('initializePrinter');
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to initialize printer');
      return false;
    }
  }
  
  /// Print test page (replicates onTestPrinter)
  Future<bool> printTestPage() async {
    if (!_isConnected) {
      onError?.call('Printer not connected');
      return false;
    }
    
    try {
      // Initialize printer
      await initializePrinter();
      
      // Test all alignments and fonts
      await _channel.invokeMethod('printTestContent');
      
      // Print bill
      await _printBillBluetooth(_glbPrinterWidth);
      
      return true;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Print test failed');
      return false;
    }
  }
  
  /// Print bill (replicates onPrintBillBluetooth)
  Future<bool> _printBillBluetooth(int numChars) async {
    try {
      final success = await _channel.invokeMethod('printBill', {
        'numChars': numChars,
        'connType': _connType,
      });
      
      if (success) {
        // Disconnect based on connection type
        await _disconnectByType();
        _setPrintButtonsEnabled(false);
      }
      
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print bill');
      return false;
    }
  }
  
  /// Print barcode (replicates BarcodeBT)
  Future<bool> printBarcodeDemo() async {
    if (!_isConnected) {
      onError?.call('Printer not connected');
      return false;
    }
    
    try {
      final success = await _channel.invokeMethod('printBarcodeDemo');
      
      if (success) {
        await _disconnectByType();
        _setPrintButtonsEnabled(false);
      }
      
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print barcode');
      return false;
    }
  }
  
  /// Print image (replicates onPrintImage)
  Future<bool> printImageDemo() async {
    if (!_isConnected) {
      onError?.call('Printer not connected');
      return false;
    }
    
    try {
      final success = await _channel.invokeMethod('printImageDemo', {
        'printerWidth': _glbPrinterWidth,
        'connType': _connType,
      });
      
      if (success) {
        _setPrintButtonsEnabled(false);
      }
      
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print image');
      return false;
    }
  }
  
  /// Print QR code (replicates onPrintQRCodeRaster)
  Future<bool> printQRCodeDemo() async {
    if (!_isConnected) {
      onError?.call('Printer not connected');
      return false;
    }
    
    try {
      final success = await _channel.invokeMethod('printQRCodeDemo', {
        'printerWidth': _glbPrinterWidth,
      });
      
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print QR code');
      return false;
    }
  }
  
  /// Print all (replicates onPrint)
  Future<bool> printAllDemo() async {
    if (!_isConnected) {
      onError?.call('Printer not connected');
      return false;
    }
    
    try {
      final success = await _channel.invokeMethod('printAllDemo', {
        'printerWidth': _glbPrinterWidth,
        'connType': _connType,
      });
      
      if (success) {
        _setPrintButtonsEnabled(false);
      }
      
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print all');
      return false;
    }
  }
  
  // ==================== PRINTER CONTROL METHODS ====================
  
  /// Set text alignment
  static Future<bool> setTextAlignment(Alignment alignment) async {
    try {
      final success = await _channel.invokeMethod('setAlignment', {
        'alignment': alignment.value,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      //debugPrint("Failed to set alignment: '${e.message}'.");
      return false;
    }
  }

  /// Set character mode
  Future<bool> setCharMode(CharMode mode) async {
    try {
      final success = await _channel.invokeMethod('setCharMode', {
        'mode': mode.value,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set character mode');
      return false;
    }
  }
  
  /// Feed lines
  Future<bool> feedLines(int lines) async {
    try {
      final success = await _channel.invokeMethod('feedLines', {
        'lines': lines,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to feed lines');
      return false;
    }
  }
  
  /// Auto cut
  Future<bool> autoCut() async {
    try {
      final success = await _channel.invokeMethod('autoCut');
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to auto cut');
      return false;
    }
  }
  
  /// Print barcode with custom parameters
  Future<bool> printBarcodeCustom({
    required String data,
    required BarcodeType type,
    required BarcodeHeight height,
    required BarcodePosition position,
  }) async {
    try {
      final success = await _channel.invokeMethod('printBarcodeCustom', {
        'data': data,
        'type': type.index,
        'height': height.index,
        'position': position.index,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print barcode');
      return false;
    }
  }
  
  /// Print image with custom parameters
  Future<bool> printImageCustom(Uint8List imageBytes, int paperSize) async {
    try {
      final success = await _channel.invokeMethod('printImageCustom', {
        'imageBytes': imageBytes,
        'paperSize': paperSize,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print image');
      return false;
    }
  }
  
  /// Print column formatted text
  Future<bool> printColumnFormatted(String inputData, int size) async {
    try {
      final success = await _channel.invokeMethod('printColumnFormatted', {
        'inputData': inputData,
        'size': size,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print column formatted text');
      return false;
    }
  }
  
  /// Print text as image
  Future<bool> printTextAsImage(String text, double textSize, int alignment, int paperSize) async {
    try {
      final success = await _channel.invokeMethod('printTextAsImage', {
        'text': text,
        'textSize': textSize,
        'alignment': alignment,
        'paperSize': paperSize,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print text as image');
      return false;
    }
  }
  
  /// Print label
  Future<bool> printLabel(Uint8List labelImage, int labelWidth, int labelHeight, 
                         int xCoordinate, int yCoordinate, String unit, 
                         int scaling, int size) async {
    try {
      final success = await _channel.invokeMethod('printLabel', {
        'labelImage': labelImage,
        'labelWidth': labelWidth,
        'labelHeight': labelHeight,
        'xCoordinate': xCoordinate,
        'yCoordinate': yCoordinate,
        'unit': unit,
        'scaling': scaling,
        'size': size,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to print label');
      return false;
    }
  }
  
  /// Send byte array
  Future<bool> sendByteArray(List<int> bytes) async {
    try {
      final success = await _channel.invokeMethod('sendByteArray', {
        'bytes': Uint8List.fromList(bytes),
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to send byte array');
      return false;
    }
  }
  
  /// Send single byte
  Future<bool> sendByte(int byte) async {
    try {
      final success = await _channel.invokeMethod('sendByte', {
        'byte': byte,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to send byte');
      return false;
    }
  }
  
  /// Set line feed
  Future<bool> setLineFeed(int noOfFeeds) async {
    try {
      final success = await _channel.invokeMethod('setLineFeed', {
        'noOfFeeds': noOfFeeds,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set line feed');
      return false;
    }
  }
  
  /// Set carriage return
  Future<bool> setCarriageReturn() async {
    try {
      final success = await _channel.invokeMethod('setCarriageReturn');
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set carriage return');
      return false;
    }
  }
  
  /// Set character spacing
  Future<bool> setCharacterSpacing(int mode) async {
    try {
      final success = await _channel.invokeMethod('setCharacterSpacing', {
        'mode': mode,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set character spacing');
      return false;
    }
  }
  
  /// Set reverse printing
  Future<bool> setReversePrinting(int mode) async {
    try {
      final success = await _channel.invokeMethod('setReversePrinting', {
        'mode': mode,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set reverse printing');
      return false;
    }
  }
  
  /// Set text underline
  Future<bool> setTextUnderline(int mode) async {
    try {
      final success = await _channel.invokeMethod('setTextUnderline', {
        'mode': mode,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set text underline');
      return false;
    }
  }
  
  /// Set text emphasized
  Future<bool> setTextEmphasized(int mode) async {
    try {
      final success = await _channel.invokeMethod('setTextEmphasized', {
        'mode': mode,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set text emphasized');
      return false;
    }
  }
  
  /// Set character font
  Future<bool> setCharFont(CharFont font) async {
    try {
      final success = await _channel.invokeMethod('setCharFont', {
        'font': font.value,
      });
      return success;
    } on PlatformException catch (e) {
      onError?.call(e.message ?? 'Failed to set character font');
      return false;
    }
  }
  
  // ==================== HELPER METHODS ====================
  
  void _setPrintButtonsEnabled(bool enabled) {
    _isConnected = enabled;
  }
  
  Future<void> _disconnectByType() async {
    switch (_connType) {
      case CONN_TYPE_BT:
        await disconnectPrinter();
        break;
      case CONN_TYPE_USB:
        // USB disconnect would be handled differently
        break;
      case CONN_TYPE_IP:
        // TCP disconnect
        break;
    }
  }
  
  // Getters
  bool get isConnected => _isConnected;
  int get printerWidth => _glbPrinterWidth;
  int get connectionType => _connType;
  
  // Setters
  set connectionType(int type) {
    _connType = type;
  }
}

// ==================== ENUMS ====================

enum Alignment {
  left(0x00),
  center(0x01),
  right(0x02);

  final int value;
  const Alignment(this.value);
}

enum CharMode {
  normal(0x00),
  tahoma(0x01),
  calibri(0x02),
  verdana(0x03),
  doubleHeight(0x10),
  doubleWidth(0x20),
  underline(0x80),
  bold(0x08);

  final int value;
  const CharMode(this.value);
}

enum CharFont {
  normal(0x00),
  tahoma(0x01),
  calibri(0x02),
  verdana(0x03);

  final int value;
  const CharFont(this.value);
}

enum BarcodeType {
  UPCA,
  UPCE,
  EAN13,
  EAN8,
  CODE39
}

enum BarcodeHeight {
  HT_SMALL,
  HT_MEDIUM,
  HT_LARGE
}

enum BarcodePosition {
  POS_NONE,
  POS_ABOVE,
  POS_BELOW,
  POS_BOTH
}

enum ConnectionType {
  bluetooth,
  usb,
  wifi
}