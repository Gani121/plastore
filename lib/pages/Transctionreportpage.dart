import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

const String apiUrl = 'https://api2.nextorbitals.in/api/save_transaction.php';

class Transctionreportpage extends StatefulWidget {
  final List<String> allowedHotels;

  const Transctionreportpage({Key? key, required this.allowedHotels})
    : super(key: key);

  @override
  State<Transctionreportpage> createState() => _TransctionreportpageState();
}

class _TransctionreportpageState extends State<Transctionreportpage> {
  List<String> allowedHotels = [];
  String? selectedHotel;

  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  List<dynamic> transactions = [];
  bool isLoading = false;

  double totalSales = 0;
  double cashSales = 0;
  double cardSales = 0;
  double upiSales = 0;

  @override
  void initState() {
    super.initState();
    // Use the hotels passed from the widget
    if (widget.allowedHotels.isNotEmpty) {
      selectedHotel = widget.allowedHotels[0];
    }
  }

  Future<void> pickDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> fetchTransactions() async {
    if (selectedHotel == null || selectedHotel!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select hotel')));
      return;
    }

    if (startController.text.isNotEmpty && endController.text.isNotEmpty) {
      DateTime start =
          DateTime.tryParse(startController.text) ?? DateTime(2000);
      DateTime end = DateTime.tryParse(endController.text) ?? DateTime.now();
      if (start.isAfter(end)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start date cannot be after End date')),
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
      transactions = [];
      totalSales = cashSales = cardSales = upiSales = 0;
    });

    try {
      final uri = Uri.parse(apiUrl).replace(
        queryParameters: {
          'hotel_name': selectedHotel!,
          if (startController.text.isNotEmpty) 'start': startController.text,
          if (endController.text.isNotEmpty) 'end': endController.text,
        },
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> fetched = data['data'];

          double tSales = 0, cSales = 0, crSales = 0, uSales = 0;
          for (var tx in fetched) {
            double amt = double.tryParse(tx['total_amount'].toString()) ?? 0;
            tSales += amt;
            String payment = tx['payment_mode'].toString().toUpperCase();
            if (payment == 'CASH') cSales += amt;
            if (payment == 'CARD') crSales += amt;
            if (payment == 'UPI') uSales += amt;
          }

          setState(() {
            transactions = fetched;
            totalSales = tSales;
            cashSales = cSales;
            cardSales = crSales;
            upiSales = uSales;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget buildTransactionItem(Map<String, dynamic> tx) {
    List<dynamic> cartItems = [];
    try {
      String jsonStr = tx['cart_data'].replaceAll("'", '"');
      cartItems = json.decode(jsonStr);
    } catch (e) {
      cartItems = [];
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(
          'Hotel: ${tx['hotel_name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction Time: ${tx['transaction_time']}'),
            Text('Total: ₹${tx['total_amount']} (${tx['payment_mode']})'),
            if (cartItems.isNotEmpty) const Text('Items:'),
            ...cartItems.map(
              (item) => Text(
                '- ${item['name']} x${item['qty']}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> shareReport() async {
    if (transactions.isEmpty) return;
    StringBuffer buffer = StringBuffer();
    buffer.writeln('📊 Transaction Report');
    buffer.writeln('Hotel: $selectedHotel');
    buffer.writeln('Date: ${startController.text} → ${endController.text}');
    buffer.writeln('----------------------------------');

    for (var tx in transactions) {
      buffer.writeln('Hotel: ${tx['hotel_name']}');
      buffer.writeln('Time: ${tx['transaction_time']}');
      buffer.writeln('Total: ₹${tx['total_amount']} (${tx['payment_mode']})');
      try {
        String jsonStr = tx['cart_data'].replaceAll("'", '"');
        List<dynamic> cart = json.decode(jsonStr);
        for (var item in cart)
          buffer.writeln('  - ${item['name']} x${item['qty']}');
      } catch (_) {}
      buffer.writeln('----------------------------------');
    }

    buffer.writeln('💰 Total Sales: ₹${totalSales.toStringAsFixed(2)}');
    buffer.writeln('💵 Cash: ₹${cashSales.toStringAsFixed(2)}');
    buffer.writeln('💳 Card: ₹${cardSales.toStringAsFixed(2)}');
    buffer.writeln('📱 UPI: ₹${upiSales.toStringAsFixed(2)}');

    await Share.share(buffer.toString(), subject: 'Transaction Report');
  }

  Future<void> exportCSV() async {
    if (transactions.isEmpty) return;

    List<List<String>> csvData = [
      ['Hotel', 'Transaction Time', 'Total', 'Payment Mode', 'Items'],
    ];

    for (var tx in transactions) {
      List<String> items = [];
      try {
        String jsonStr = tx['cart_data'].replaceAll("'", '"');
        List<dynamic> cart = json.decode(jsonStr);
        for (var item in cart) items.add('${item['name']} x${item['qty']}');
      } catch (_) {}
      csvData.add([
        tx['hotel_name'].toString(),
        tx['transaction_time'].toString(),
        tx['total_amount'].toString(),
        tx['payment_mode'].toString(),
        items.join('; '),
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);

    String? dirPath;
    if (Platform.isAndroid) {
      Directory downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);

      Directory reportDir = Directory(
        '${downloadsDir.path}/Orbipay Sales Report',
      );
      if (!reportDir.existsSync()) reportDir.createSync(recursive: true);
      dirPath = reportDir.path;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }

    final path =
        '$dirPath/transaction_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csv);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('CSV saved at: $path')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Report'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: shareReport,
            tooltip: 'Share Text',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: exportCSV,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedHotel,
                  items: widget.allowedHotels
                      .map(
                        (hotel) =>
                            DropdownMenuItem(value: hotel, child: Text(hotel)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedHotel = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Select Hotel *',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => pickDate(startController),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => pickDate(endController),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: fetchTransactions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Sales: ₹${totalSales.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('💵 Cash: ₹${cashSales.toStringAsFixed(2)}'),
                  Text('💳 Card: ₹${cardSales.toStringAsFixed(2)}'),
                  Text('📱 UPI: ₹${upiSales.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                ? const Center(child: Text('No transactions found.'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) =>
                        buildTransactionItem(transactions[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
