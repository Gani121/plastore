import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart'; // <-- needed for RenderRepaintBoundary

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final GlobalKey _receiptKey = GlobalKey();
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  @override
  void initState() {
    super.initState();
    _connectPrinter();
  }

  /// Connect automatically to first paired printer
  Future<void> _connectPrinter() async {
    List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
    if (devices.isNotEmpty) {
      await bluetooth.connect(devices.first); // Connect first paired printer
      debugPrint("Connected to: ${devices.first.name}");
    } else {
      debugPrint("No paired devices found!");
    }
  }

  /// Capture receipt as image
  Future<Uint8List?> _captureReceipt() async {
    try {
      RenderRepaintBoundary boundary =
          _receiptKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing receipt: $e");
      return null;
    }
  }

  /// Print captured image
  Future<void> _printReceipt() async {
    Uint8List? imgBytes = await _captureReceipt();
    if (imgBytes != null) {
      // Save temp file
      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/receipt.png");
      await file.writeAsBytes(imgBytes);

      // Print image
      bluetooth.isConnected.then((isConnected) {
        if (isConnected == true) {
          //bluetooth.printImage(file.path);
          bluetooth.print3Column("(Roll) Cheese", "RS 100x2 200", "", 1);
          bluetooth.print3Column("Butter Rumali Roti", "RS 50x1 50", "", 1);
          // bluetooth.print3Column("TOTAL", "", "250", 0);

          // bluetooth.printNewLine();
          bluetooth.printCustom("Thank You! Visit Again", 1, 1);
        } else {
          debugPrint("Printer not connected");
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Receipt Preview")),
      body: Column(
        children: [
          // Receipt UI (capturable widget)
          Expanded(
            child: RepaintBoundary(
              key: _receiptKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Hotel Logo
                    Image.asset("assets/splash.png", height: 80),

                    const SizedBox(height: 10),
                    const Text(
                      "Green Leaf Restaurant",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),

                    // Bill Details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [Text("Burger x2"), Text("₹200")],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [Text("Coke x1"), Text("₹50")],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Total",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "₹250",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // QR Code (e.g., payment link or order id)
                    QrImageView(
                      data: "upi://pay?pa=hotel@upi&pn=GreenLeaf&am=250",
                      version: QrVersions.auto,
                      size: 120,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Print Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _printReceipt,
              icon: const Icon(Icons.print),
              label: const Text("Print Receipt"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
