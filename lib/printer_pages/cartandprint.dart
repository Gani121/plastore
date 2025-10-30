import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'cat_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_flutter/tabler_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;


// The constructor no longer needs the 'stuffs' parameter
class PrinterPreviewWidget extends StatefulWidget {
  const PrinterPreviewWidget({Key? key}) : super(key: key);

  @override
  _PrinterPreviewWidgetState createState() => _PrinterPreviewWidgetState();
}

class _PrinterPreviewWidgetState extends State<PrinterPreviewWidget> {
  bool _isPrinting = false;
  String _printStatus = "Ready";
  BluetoothDevice? _connectedDevice;
  final GlobalKey _previewKey = GlobalKey();
  final String upi_id = '8380888360@pthdfc';
  final String _targetPrinterAddress = 'AF:03:20:77:46:F1';
  late List<Map<String, dynamic>> _testCart;

  // --- BLUETOOTH SCANNING LOGIC (remains the same) ---
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _testCart = buildReceiptList();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      print(" in the printpreview $_scanSubscription ");
      if (mounted) {
        setState(() {
          _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
          
          print(" in the _showPreviewAndPrint $_scanResults ");
        });
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
Future<void> _saveImage(ui.Image image) async {
  try {
    // 1. Get the directory for storing files
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception("Could not find external storage directory.");
    }
    
    // 2. Create a unique file name
    final fileName = 'kitty_print_${DateTime.now().millisecondsSinceEpoch}.png';
    final filePath = '${directory.path}/$fileName';

    // 3. Get the raw RGBA bytes from the ui.Image
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception("Could not get byte data from image.");
    }
    final buffer = byteData.buffer.asUint8List();

    // 4. Create an image object from the raw data using the 'image' package
    final img.Image imageFromRawData = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: buffer.buffer,
      numChannels: 4, // Specify the format of the raw data
    );

    // 5. Encode the image as a PNG. This creates the bytes for a VALID PNG file.
    final Uint8List pngBytes = img.encodePng(imageFromRawData);

    // 6. Save the valid PNG bytes to the file
    final file = File(filePath);
    await file.writeAsBytes(pngBytes);
    
    print('✅ Image saved successfully at: $filePath');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved to: $fileName')),
      );
    }
    
  } catch (e) {
    print('❌ Error saving image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    }
  }
}


List<Map<String, dynamic>> buildReceiptList(
) {

    List<Map<String, dynamic>> receiptLayout = [
    {'isLogo': true},
    {'isHeader': true, 'name': 'Chaap Center'},
    {'isDivider': true},
    {'isTotal': true, 'total': 810.0},
    {'isQrCode': true, 'upiId': '8380888360@pthdfc'},
  ];

  List<Map<String, dynamic>> cartItems = [
    {'name': 'Veggie Chaap', 'qty': 2, 'price': 120.0},
    {'name': 'Malai Chaap', 'qty': 1, 'price': 150.0},
    {'name': 'Amritsari Chaap', 'qty': 3, 'price': 180.0}
  ];

  // 1. Create a copy of the layout to avoid changing the original list.
  final combinedList = List<Map<String, dynamic>>.from(receiptLayout);

  // 2. Find the index of the divider in the new list.
  final insertionIndex =
      combinedList.indexWhere((item) => item['isDivider'] == true);

  // 3. If the divider is found, insert all cart items at that position.
  if (insertionIndex != -1) {
    combinedList.insertAll(insertionIndex, cartItems);
  } else {
    // Fallback: If no divider is found, you could add items at the end
    // or handle it as an error, depending on your app's needs.
    print("Warning: 'isDivider' not found in receipt layout.");
  }

  // 4. Return the newly created and combined list.
  return combinedList;
}

// --- PRINTING LOGIC (fixed for 2-inch thermal printer) ---
Future<void> _captureAndPrint() async {
  setState(() {
    _isPrinting = true;
    _printStatus = "Capturing preview...";
  });

  try {
    RenderRepaintBoundary boundary = _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    _saveImage(image);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    
    if (byteData == null) throw Exception("Could not capture preview.");

    _printStatus = "Searching for printer...";
    setState(() {});

    // final device = await _showDeviceSelectionDialog();
          // --- START: AUTOMATIC PRINTER DISCOVERY LOGIC ---
      _printStatus = "Searching for printer...";
      setState(() {});

      BluetoothDevice? device;

      // 1. Check among already connected system devices for speed
      // var connectedDevices = await FlutterBluePlus.connectedSystemDevices; //.connectedSystemDevices;
      // for (var d in connectedDevices) {
      //     debugPrint("d remoteId ${d.remoteId} ");
      //     if (d.remoteId.toString() == _targetPrinterAddress) {
      //         device = d;
      //         print("✅ Printer found among connected devices.");
      //         break;
      //     }
      // }

      // 2. If not found, start scanning to find the printer
      if (device == null) {
          print("Printer not connected. Starting scan...");
          await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

          // Listen to scan results
          await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
            print("✅ Printer found via scan.$results");
              for (ScanResult r in results) {
                print("✅ Printer found via scan. $r");
                  if (r.device.remoteId.toString() == _targetPrinterAddress) {
                      device = r.device;
                      print("✅ Printer found via scan.");
                      break; // Exit inner loop
                  }
              }
              if (device != null) {
                  break; // Exit stream listener
              }
          }
          await FlutterBluePlus.stopScan();
      }

      if (device == null) {
        throw Exception("Printer not found.\nPlease ensure it is turned on and in range.");
      }
      // --- END: AUTOMATIC PRINTER DISCOVERY LOGIC ---
    _connectedDevice = device;

    _printStatus = "Connecting to ${device.platformName}...";
    setState(() {});
    await device.connect(timeout: const Duration(seconds: 15));
    
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == CAT_PRINT_SRV);
    final tx = service.characteristics.firstWhere((c) => c.uuid == CAT_PRINT_TX_CHAR);

    final printer = CatPrinter(tx);
    final prefs = await SharedPreferences.getInstance();
    
    final speed = prefs.getInt('speed') ?? 32;
    final energy = prefs.getInt('energy') ?? 35000;
    final finishFeed = 50;

    await printer.prepare(speed, energy);

    _printStatus = "Processing and sending data...";
    setState(() {});
    
    
    print('Original image: ${image.width}x${image.height}');
    print('RGBA bytes length: ${byteData.lengthInBytes}');
    print('Expected printer width: 384 pixels');

    // Process image for 2-inch thermal printer (384 pixels wide)
    final int printerWidth = 384;
    final Uint8List processedBitmap = _processImageForPrinter(
      byteData.buffer.asUint8List(),
      image.width,
      image.height,
      printerWidth
    );

    print('Processed bitmap length: ${processedBitmap.length}');
    print('Expected length: ${image.height * (image.width ~/ 8)}');

    final pitch = printerWidth ~/ 8; // 384 / 8 = 48 bytes per line
        // Define chunk size and delay. YOU CAN TUNE THESE VALUES.
    const chunkSize = 16; // Send data in 16-byte chunks
    const delay = Duration(milliseconds: 20); // A more robust delay
    int blankLines = 0;
        // Process each line of the bitmap
        // --- START: MODIFIED LOOP FOR 2-PIXEL GAP ---
    for (int y = 0; y < processedBitmap.length ~/ pitch; y++) {
      final start = y * pitch;
      final end = start + pitch;
      
      if (end > processedBitmap.length) break;
      
      final line = processedBitmap.sublist(start, end);
      
      if (line.every((byte) => byte == 0)) {
        blankLines += 1; // It's a blank line, just count it
      } else {
        // This is a line with content.
        // If the previous line(s) were blank, we are starting a new block.
        if (blankLines > 0) {
          // --- CHANGE 1: INSERT A FIXED 2-PIXEL GAP ---
          // Instead of feeding by blankLines, feed by a fixed small amount.
          await printer.feed(2);  //to increase the gap of line
          blankLines = 0; // Reset the counter
        }

                // --- KEY CHANGE ---
        // Send the entire line at once, removing the inner chunking loop.
        await printer.draw(line);
        
        // Add a tiny delay BETWEEN lines to prevent overwhelming the printer.
        // This should be too short to notice.
        await Future.delayed(const Duration(milliseconds: 1));

        
        // const chunkSize = 16;
        // const delay = Duration(milliseconds: 1);
        // for (int i = 0; i < line.length; i += chunkSize) {
        //   final chunkEnd = (i + chunkSize > line.length) ? line.length : i + chunkSize;
        //   final chunk = line.sublist(i, chunkEnd);
        //   await printer.draw(chunk);
        //   await Future.delayed(delay);
        // }
      }
    }


     await printer.finish(finishFeed);
    
    _printStatus = "Print job complete!";
    setState(() {});

  } catch (e) {
    _printStatus = "Error: ${e.toString()}";
    setState(() {});
    print("Printing error: $e");
  } finally {
    await Future.delayed(const Duration(seconds: 2));
    _connectedDevice?.disconnect();
    setState(() => _isPrinting = false);
  }
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



  // --- UI BUILDING LOGIC ---
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The Preview Area
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.grey[200],
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: _previewKey,
                child: Container(
                  color: Colors.white,
                  width: 384, // Standard 58mm thermal paper width in pixels
                  constraints: BoxConstraints(maxWidth: 384),
                  child: Column(
                    // --- UI CHANGE ---
                    // Build the preview from the _testCart instead of widget.stuffs
                    children: _testCart.map((item) => _buildPreviewContent(item)).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The Print Button and Status
        if (_isPrinting)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(_printStatus, textAlign: TextAlign.center),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(TablerIcons.printer),
              label: const Text("Print Test Cart"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _captureAndPrint,
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewContent(Map<String, dynamic> item) {
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontFamily: 'RobotoMono',
      letterSpacing: -1,
    );

    if (item['isHeader'] == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          item['name'],
          textAlign: TextAlign.center,
          style: textStyle.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (item['isTotal'] == true) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Align( // Use Align to correctly align total to the right
          alignment: Alignment.centerRight,
          child: Text(
            "Total: Rs. ${item['total']}",
            textAlign: TextAlign.right,
            style: textStyle.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (item['isDivider'] == true) {
      return const Divider(
        color: Colors.black,
        thickness: 1,
        height: 20,
        indent: 8,
        endIndent: 8,
      );
    }

    if (item['isLogo'] == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Image.asset(
          'assets/images/chaap_center_logo.png', // Path to your logo asset
          width: 400, // Adjust width as needed for your printer
          height: 70, // Adjust height as needed
          fit: BoxFit.contain,
        ),
      );
    }

    if (item['isQrCode'] == true) {
      final String upiId = item['upiId'];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: QrImageView(
          data: upiId,
          version: QrVersions.auto,
          size: 200.0, // Size of the QR code
          gapless: true,
          // The embeddedImage can be used to add a logo in the center of the QR code if desired
          // embeddedImage: AssetImage('assets/your_upi_logo.png'),
          // embeddedImageStyle: QrEmbeddedImageStyle(
          //   size: Size(40, 40),
          // ),
        ),
      );
    }

    // Default item row (unchanged)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(item['name'], style: textStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${item['qty']} x ${item['price']}",
              textAlign: TextAlign.right,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }








}



