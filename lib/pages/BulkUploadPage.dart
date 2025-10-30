import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

import '../models/menu_item.dart';
import 'package:test1/cartprovier/ObjectBoxService.dart';
import 'package:provider/provider.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class BulkUploadPage extends StatefulWidget {
  const BulkUploadPage({super.key});

  @override
  _BulkUploadPageState createState() => _BulkUploadPageState();
}

class _BulkUploadPageState extends State<BulkUploadPage> {
  List<Map<String, dynamic>> parsedItems = [];
  String? error;

  Future<void> pickFileAndParse() async {
    setState(() {
      parsedItems = [];
      error = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);

    if (rows.isEmpty) {
      setState(() => error = "Empty CSV file.");
      return;
    }

    final headers = rows.first.map((e) => e.toString()).toList();
    final dataRows = rows.sublist(1);

    for (var row in dataRows) {
      if (row.length < 4) continue;

      final rowMap = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        rowMap[headers[i]] = row[i];
      }

      // Validate required fields
      if (rowMap['name'] == null ||
          rowMap['sellPrice'] == null ||
          rowMap['sellPriceType'] == null ||
          rowMap['category'] == null) {
        continue;
      }

      parsedItems.add(rowMap);
    }

    setState(() {});
  }

  Future<void> _exportSampleCSV() async {
    // Request storage permission
    if (await Permission.storage.request().isGranted) {
      final headers = [
        "name",
        "sellPrice",
        "sellPriceType",
        "category",
        "mrp",
        "purchasePrice",
        "acSellPrice",
        "nonAcSellPrice",
        "onlineDeliveryPrice",
        "onlineSellPrice",
        "hsnCode",
        "itemCode",
        "barCode",
        "barCode2",
        "imagePath",
        "available",
        "adjustStock",
        "gstRate",
        "withTax",
        "cessRate",
      ];

      final rows = [
        headers,
        [
          "Paneer Masala",
          "120",
          "FIXED",
          "Main Course",
          "140",
          "100",
          "115",
          "110",
          "125",
          "130",
          "0401",
          "ITM001",
          "1234567",
          "2345678",
          "img1.jpg",
          "100",
          "0",
          "5",
          "true",
          "0",
        ],
        [
          "Butter Naan",
          "30",
          "FIXED",
          "Breads",
          "35",
          "20",
          "30",
          "28",
          "32",
          "33",
          "1905",
          "ITM002",
          "9876543",
          "8765432",
          "img2.jpg",
          "200",
          "0",
          "5",
          "false",
          "0",
        ],
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final directory = await getExternalStorageDirectory();

      final file = File("${directory!.path}/sample_menu_items.csv");
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sample CSV exported to ${file.path}")),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Storage permission denied")));
    }
  }

  void saveToDatabase() {
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final box = store.box<MenuItem>();

    for (var row in parsedItems) {
      final item = MenuItem(
        name: row['name'].toString(),
        sellPrice: row['sellPrice'].toString(),
        sellPriceType: row['sellPriceType'].toString(),
        category: row['category'].toString(),
        mrp: row['mrp']?.toString(),
        purchasePrice: row['purchasePrice']?.toString(),
        acSellPrice: row['acSellPrice']?.toString(),
        nonAcSellPrice: row['nonAcSellPrice']?.toString(),
        onlineDeliveryPrice: row['onlineDeliveryPrice']?.toString(),
        onlineSellPrice: row['onlineSellPrice']?.toString(),
        hsnCode: row['hsnCode']?.toString(),
        itemCode: row['itemCode']?.toString(),
        barCode: row['barCode']?.toString(),
        barCode2: row['barCode2']?.toString(),
        imagePath: row['imagePath']?.toString(),
        available: int.tryParse(row['available']?.toString() ?? ''),
        adjustStock: int.tryParse(row['adjustStock']?.toString() ?? ''),
        gstRate: double.tryParse(row['gstRate']?.toString() ?? ''),
        withTax: row['withTax']?.toString().toLowerCase() == 'true',
        cessRate: double.tryParse(row['cessRate']?.toString() ?? ''),
      );

      box.put(item); // save to ObjectBox
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${parsedItems.length} items uploaded')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bulk Item Upload")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickFileAndParse,
              icon: Icon(Icons.upload_file),
              label: Text("Upload CSV File"),
            ),
            ElevatedButton(
              onPressed: _exportSampleCSV,
              child: Text("Download Sample CSV"),
            ),
            if (error != null)
              Text(error!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            if (parsedItems.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    Text("Parsed Items: ${parsedItems.length}"),
                    Expanded(
                      child: ListView.builder(
                        itemCount: parsedItems.length,
                        itemBuilder: (_, i) {
                          final item = parsedItems[i];
                          return ListTile(
                            title: Text(item['name']),
                            subtitle: Text(
                              "₹ ${item['sellPrice']} | ${item['category']}",
                            ),
                          );
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: saveToDatabase,
                      child: Text("Save All Items"),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
