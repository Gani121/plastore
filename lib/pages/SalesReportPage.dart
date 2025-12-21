import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ExpensesPage.dart';
import '../objectbox.g.dart';
import '../database_Module/expensDB.dart';
import '../utilities.dart';
import '../database_Module/menu_item.dart';
import '../bill_printer.dart';


class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  List<Transaction> _transactions = [];

  double todayTotal = 0;
  double weekTotal = 0;
  double monthTotal = 0;
  double cashTotal = 0;
  double cardTotal = 0;
  double upiTotal = 0;
  double otherTotal = 0; // Add this line
  double todayExpenses = 0;
  double expensesToday = 0.0;
  double expensesDateRange = 0.0;
  Map<DateTime, double> daywiseExpensesMap = {};
  List<String> expensesList = [];
  Map<String, int> itemQtyMap = {};
  Map<String, double> itemPriceMap = {};
  Map<String, int> citemQtyMap = {};
  Map<String, double> citemPriceMap = {};
  // New state variables for order type summary
  Map<String, int> orderTypeCountMap = {};
  Map<String, double> orderTypeTotalMap = {};
  Map<String, int> adjustStock = {};
  Map<String, int> unavailabelstock = {};


  // Date range filter
  DateTime? fromDate;
  DateTime? toDate;
  late Store store = Provider.of<ObjectBoxService>(context, listen: false).store;
  String giveamount = "0";
  bool _showMoreOptions = false;
  String takeamount = "0";

  @override
  void initState() {
    super.initState();
    fromDate = getDateWithFourAMOffset();
    toDate = getDateWithFourAMOffset();
    Future.delayed(const Duration(milliseconds: 200), _loadTransactions);
  }

  DateTime getDateWithFourAMOffset() {
    final now = DateTime.now();
    final fourAMToday = DateTime(now.year, now.month, now.day, 4);
    return now.isBefore(fourAMToday)
        ? DateTime(now.year, now.month, now.day - 1)
        : DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        fromDate = picked;
      });
      _loadTransactions();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        toDate = picked;
      });
      _loadTransactions();
    }
  }

  Future<Map<String, int>> _loadMenu() async {

    try {
      final store = Provider.of<ObjectBoxService>(context, listen: false).store;
      final menuItemBox = store.box<MenuItem>();
      final itemsAll = menuItemBox.getAll();
      final items = itemsAll.map((item) => item.toMap()).toList();
      Map<String, int> adjustStock1 = {};

      for (var tx in items) {
        if (tx['adjustStock'] != null && tx['adjustStock'] > 0) {
          print_log("_loadMenu $tx ${tx['adjustStock']}");
          final raw = tx['adjustStock'];
          final value = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
          adjustStock1["${tx['name']}"] = value;
        }
      }
      return adjustStock1;
    } catch (e, st) {
      print_log_red('Error in _loadMenu: $e\n$st');
      return <String, int>{};
    }
  }
    Future<Map<String, int>> _loadUnavailabelstock() async {

    try {
      final store = Provider.of<ObjectBoxService>(context, listen: false).store;
      final menuItemBox = store.box<MenuItem>();
      final itemsAll = menuItemBox.getAll();
      final items = itemsAll.map((item) => item.toMap()).toList();
      Map<String, int> adjustStock1 = {};

      for (var tx in items) {
        if (tx['adjustStock'] != null && tx['adjustStock'] <= 0) {
          print_log("_loadMenu $tx ${tx['adjustStock']}");
          final raw = tx['adjustStock'];
          final value = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
          adjustStock1["${tx['name']}"] = value;
        }
      }
      return adjustStock1;
    } catch (e, st) {
      print_log_red('Error in _loadMenu: $e\n$st');
      return <String, int>{};
    }
  }

  Future<void> _loadTransactions() async {
    giveamount = await getDatafromPrefs("You_will_give");
    takeamount = await getDatafromPrefs("You_will_get");
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final box = store.box<Transaction>();
    final transactions = box.getAll();

    DateTime now = DateTime.now();
    DateTime today;
    if (fromDate == toDate) {
      if (fromDate != null) {
        today = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      } else {
        today = DateTime(now.year, now.month, now.day);
      }
    } else {
      today = DateTime(now.year, now.month, now.day);
    }

    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

    double tTotal = 0, wTotal = 0, mTotal = 0;
    double cTotal = 0, crTotal = 0, uTotal = 0;
    Map<String, int> qtyMap = {};
    Map<String, double> priceMap = {};
    Map<String, int> cqtyMap = {};
    Map<String, double> cpriceMap = {};
    // New maps for order type aggregation
    Map<String, int> tempOrderTypeCount = {};
    Map<String, double> tempOrderTypeTotal = {};


    DateTime from = fromDate != null
        ? DateTime(fromDate!.year, fromDate!.month, fromDate!.day)
        : DateTime(2000);
    DateTime to = toDate != null
        ? DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59)
        : DateTime.now();

    // 🔹 Get expenses data from SharedPreferences
    double expensesTodayTotal = 0.0;
    double expensesDateRangeTotal = 0.0;
    Map<DateTime, double> daywiseExpenses = {};

    try {
      // Get today's expenses total
      final todayNormalized = DateTime(now.year, now.month, now.day);
      
      final box = store.box<expences>();
      final expensesJson = box.getAll();
      final daywiseData = await ExpensesService.getDaywiseExpenses(expensesJson);

      expensesTodayTotal = daywiseData[todayNormalized] ?? 0.0;

      // Get date range expenses total
      Map<String,dynamic> expenceMap = await ExpensesService.getDateRangeTotal(from,to,expensesJson);
      expensesDateRangeTotal = expenceMap['total'] ?? 0.0;
      expensesList = List<String>.from(jsonDecode(expenceMap['expenses'] ?? []));
      debugPrint("expensesList $expensesList");

      // Get all daywise expenses for display
      daywiseExpenses = daywiseData;
    } catch (e) {
      debugPrint('Error loading expenses data: $e');
    }

    for (var tx in transactions) {
      if (tx.time.isBefore(from) || tx.time.isAfter(to)) continue;

      if (tx.time.isAfter(from) && tx.time.isBefore(to)) tTotal += tx.total;
      if (tx.time.isAfter(startOfWeek)) wTotal += tx.total;
      if (tx.time.isAfter(startOfMonth)) mTotal += tx.total;

      switch (tx.payment_mode.toUpperCase()) {
        case "CASH":
          cTotal += tx.total;
          break;
        case "CARD":
          crTotal += tx.total;
          break;
        case "UPI":
          uTotal += tx.total;
          break;
        case "OTHER": // Handle split payments
          cTotal += tx.cashamount?.toDouble() ?? 0.0;
          uTotal += tx.upiamount?.toDouble() ?? 0.0;
          break;
        default:
          // Handle any other payment methods that are not settled
          otherTotal += tx.total;
          debugPrint('Uncategorized payment mode: ${tx.payment_mode} - Amount: ${tx.total}');
          break;
      }

      // Aggregate by orderType
      final orderType = tx.orderType?.isNotEmpty == true ? tx.orderType! : 'Other';
      tempOrderTypeCount[orderType] = (tempOrderTypeCount[orderType] ?? 0) + 1;
      tempOrderTypeTotal[orderType] = (tempOrderTypeTotal[orderType] ?? 0) + tx.total;

      for (var item in tx.decodedCart) {
        // print_log( "items in the salse report page $item");
        final name = item['name'].toString();
        final qty = int.tryParse(item['qty'].toString()) ?? 0;
        final price = double.tryParse(item['sellPrice'].toString()) ?? 0.0;
        final item_category = item['portion'].toString();

        qtyMap[name] = (qtyMap[name] ?? 0) + qty;
        priceMap[name] = (priceMap[name] ?? 0) + (price * qty);
        cqtyMap[item_category] = (cqtyMap[item_category] ?? 0) + qty;
        cpriceMap[item_category] = (cpriceMap[item_category] ?? 0) + (price * qty);
      }
    }

    // 🔹 Read today's expenses from SharedPreferences (if you still need this)
    final prefs = await SharedPreferences.getInstance();
    final storedExpenses = prefs.getDouble('Todayexpenses') ?? 0.0;

    Map<String, int> _adjustStock2 = await _loadMenu();
    Map<String, int> _unavailabelstock = await _loadUnavailabelstock();


    setState(() {
      _transactions = transactions.reversed.toList();
      todayTotal = tTotal;
      weekTotal = wTotal;
      monthTotal = mTotal;
      cashTotal = cTotal;
      cardTotal = crTotal;
      upiTotal = uTotal;
      itemQtyMap = qtyMap;
      itemPriceMap = priceMap;
      citemQtyMap = cqtyMap;
      citemPriceMap = cpriceMap;
      todayExpenses = storedExpenses;

      // 🔹 Set the new expenses data
      expensesToday = expensesTodayTotal;
      expensesDateRange = expensesDateRangeTotal;
      orderTypeCountMap = tempOrderTypeCount;
      orderTypeTotalMap = tempOrderTypeTotal;
      daywiseExpensesMap = daywiseExpenses;
      adjustStock = _adjustStock2;
      unavailabelstock = _unavailabelstock;
    });
  }


  List<MapEntry<String, int>> getTopItemsByQty() {
    final entries = itemQtyMap.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.toList();
  }

  List<MapEntry<String, double>> getTopItemsByPrice() {
    final entries = itemPriceMap.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.toList();
  }

  List<MapEntry<String, int>> ordertype_tran_total() {
    final entries = itemQtyMap.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.toList();
  }

  Future<void> _shareReport() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    final DateTime today = DateTime.now();

    // Check if today is selected (both from and to dates are today)
    final bool isTodaySelected =
        fromDate != null &&
        toDate != null &&
        fromDate!.day == today.day &&
        fromDate!.month == today.month &&
        fromDate!.year == today.year &&
        toDate!.day == today.day &&
        toDate!.month == today.month &&
        toDate!.year == today.year;

    // Date range is selected if both dates are provided AND it's not today
    final bool isDateRangeSelected =
        fromDate != null && toDate != null && !isTodaySelected;

    final double displayExpenses = isDateRangeSelected
        ? expensesDateRange
        : expensesToday;
    final String expensesLabel = isDateRangeSelected
        ? "Date Range Expenses"
        : "Today's Expenses";

    final reportBuffer = StringBuffer();
    reportBuffer.writeln("📊 Sales Report");
    reportBuffer.writeln("Generated on: $formattedDate");

    reportBuffer.writeln(
      "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate!)}"
      " → ${DateFormat('dd MMM yyyy').format(toDate!)}",
    );

    reportBuffer.writeln("=======================");
    reportBuffer.writeln(
      isDateRangeSelected
          ? "Selected Range Sales: ₹ ${todayTotal.toStringAsFixed(2)}"
          : "Today's Sales: ₹ ${todayTotal.toStringAsFixed(2)}",
    );
    reportBuffer.writeln("This Week: ₹ ${weekTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("This Month: ₹ ${monthTotal.toStringAsFixed(2)}");

    reportBuffer.writeln("");
    reportBuffer.writeln("By Payment Mode:");
    reportBuffer.writeln("💵 Cash: ₹ ${cashTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("💳 Card: ₹ ${cardTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("📱 UPI: ₹ ${upiTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("📱 Not Settled:₹ ${otherTotal.toStringAsFixed(2)}");

    reportBuffer.writeln("");
    final String giveamount = await getDatafromPrefs("You_will_give");
    final String takeamount = await getDatafromPrefs("You_will_get");
    reportBuffer.writeln("Udhari Get and Give:");
    reportBuffer.writeln("You_will_give $giveamount:");
    reportBuffer.writeln("You_will_get ${takeamount}");

    reportBuffer.writeln("");
    reportBuffer.writeln("💰 $expensesLabel:");
    reportBuffer.writeln("₹ ${displayExpenses.toStringAsFixed(2)}");
    
    reportBuffer.writeln("");
    // Show today's expenses as reference when date range is selected
    if (isDateRangeSelected && expensesToday > 0) {
      reportBuffer.writeln("Today's expenses:- ₹${expensesToday.toStringAsFixed(2)}",);
    }

    reportBuffer.writeln("");
    reportBuffer.writeln("💼 Net Total (Sales - Expenses):");
    reportBuffer.writeln("₹ ${(todayTotal).toStringAsFixed(2)}",);

    reportBuffer.writeln("");
    if (expensesList.isNotEmpty) {
      reportBuffer.writeln("Today's Expenses List:",);
      for (String ex in expensesList) {
        Map<String, dynamic> expence = jsonDecode(ex);
        String Sdate = expence['date'];
        DateTime _date = DateTime.parse(Sdate);
        reportBuffer.writeln("${expence['title']} - ${expence['category']} - ${formatDate(_date)} - ₹ ${expence['amount']}");
      }
    }

    await Share.share(
      reportBuffer.toString(),
      subject: 'Sales Report - $formattedDate',
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Share Report',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              BillPrinter().printSalesReportSummary(
                context: context,
                fromDate: fromDate,
                toDate: toDate,
                todayTotal: todayTotal,
                weekTotal: weekTotal,
                monthTotal: monthTotal,
                cashTotal: cashTotal,
                cardTotal: cardTotal,
                upiTotal: upiTotal,
                otherTotal: otherTotal,
                giveamount: giveamount,
                takeamount: takeamount,
                expensesDateRange: expensesDateRange,
                expensesToday: expensesToday,
                isDateRangeSelected: isDateRangeSelected,
              );
            },
            tooltip: 'Print Summary Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔹 Updated Date filter section
            _buildDateFilterSection(),
            _buildSectionTitle("Sales Summary"),
            _buildSummaryCard(),
            _buildOrderTypeSummaryCard(), // New card for order type summary
            _buildSectionTitle("Expenses Summary"),
            _buildTransactionList(),
            _buildportionWiseSummaryCard(),
            _buildadjustStockSummaryCard(),
            _builditemWiseSummaryCard(),
            _buildUnavailabelstockSummaryCard(),
            if (!_showMoreOptions)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showMoreOptions = true;
                    });
                  },
                  child: const Text('More Options'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeSummaryCard() {
    if (orderTypeTotalMap.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort the entries by total amount in descending order
    final sortedEntries = orderTypeTotalMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales by Order Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printOrderTypeSalesReport(
                    context: context,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    orderTypeTotalMap: orderTypeTotalMap,
                    orderTypeCountMap: orderTypeCountMap,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final orderType = entry.key;
              final totalAmount = entry.value;
              final count = orderTypeCountMap[orderType] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$orderType ($count Orders)',
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      '${totalAmount}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _builditemWiseSummaryCard() {
    if (itemPriceMap.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort the entries by total amount in descending order
    final sortedEntries = itemPriceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales by Item-Wise',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printItemWiseSalesReport(
                    context: context,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    itemPriceMap: itemPriceMap,
                    itemQtyMap: itemQtyMap,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final orderType = entry.key;
              final totalAmount = entry.value;
              final count = itemQtyMap[orderType] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$orderType (QTY:- $count)',
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      '₹ ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildportionWiseSummaryCard() {
    if (citemPriceMap.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort the entries by total amount in descending order
    final sortedEntries = citemPriceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales by portion-Wise',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printPortionWiseSalesReport(
                    context: context,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    portionPriceMap: citemPriceMap,
                    portionQtyMap: citemQtyMap,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final orderType = entry.key;
              final totalAmount = entry.value;
              final count = citemQtyMap[orderType] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$orderType (QTY:- $count)',
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      '₹ ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildadjustStockSummaryCard() {
    if (adjustStock.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort the entries by total amount in descending order
    final sortedEntries = adjustStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Stocks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printStockReport(
                    context: context,
                    stockMap: adjustStock,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final orderType = entry.key;
              final totalAmount = entry.value;
              // final count = citemQtyMap[orderType] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$orderType',
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      '${totalAmount.toStringAsFixed(0)}  -Qty',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailabelstockSummaryCard() {
    // Conditionally render based on _showMoreOptions
    if (!_showMoreOptions) {
      return const SizedBox.shrink();
    }
    if (unavailabelstock.isEmpty && _showMoreOptions) {
      return const SizedBox.shrink();
    }

    // Sort the entries by total amount in descending order
    final sortedEntries = unavailabelstock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Unavailable Stocks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printStockReport(
                    context: context,
                    stockMap: unavailabelstock,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final itemName = entry.key;
              final stockCount = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(itemName, style: const TextStyle(fontSize: 15)),
                    Text('$stockCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }


  Widget _buildTransactionList() {
  if (expensesList.isEmpty) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text(
        "No transactions found",
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    itemCount: expensesList.length,
    itemBuilder: (context, index) {
      try {
        // Parse the expense JSON string to Map
        final expenseMap = jsonDecode(expensesList[index]);
        final expense = Expense.fromMap(expenseMap);
        
        return _buildExpenseCard(expense);
      } catch (e) {
        debugPrint("Error parsing expense: $e");
        return Container(); // Return empty container on error
      }
    },
  );
}

Widget _buildExpenseCard(Expense expense) {
  debugPrint("expensesList _buildExpenseCard $expense");
  return Card(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    elevation: 2,
    child: ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getCategoryIcon(expense.category),
          color: Colors.white,
          size: 24,
        ),
      ),
      title: Text(
        expense.title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4),
          Text(
            expense.category,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 2),
          Text(
            formatDate(expense.date), // Formatted date
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      trailing: Text(
        "₹${expense.amount.toStringAsFixed(2)}",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.green[700],
        ),
      ),
    ),
  );
}


IconData _getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant;
    case 'utilities':
      return Icons.bolt;
    case 'transport':
      return Icons.directions_car;
    case 'shopping':
      return Icons.shopping_bag;
    case 'entertainment':
      return Icons.movie;
    case 'healthcare':
      return Icons.medical_services;
    default:
      return Icons.money;
  }
}

  // In your build method, update the date filter section:
  Widget _buildDateFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromDate,
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    fromDate != null
                        ? "From: ${DateFormat('dd MMM yyyy').format(fromDate!)}"
                        : "Select From Date",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade800,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickToDate,
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    toDate != null
                        ? "To: ${DateFormat('dd MMM yyyy').format(toDate!)}"
                        : "Select To Date",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),

          // Reset Date Range Button
          if (isDateRangeSelected)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    fromDate = getDateWithFourAMOffset();
                    toDate = getDateWithFourAMOffset();
                  });
                  _loadTransactions();
                },
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Reset to Today'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade50,
                  foregroundColor: Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final DateTime today = DateTime.now();

    // Check if today is selected (both from and to dates are today)
    final bool isTodaySelected =
        fromDate != null &&
        toDate != null &&
        fromDate!.day == today.day &&
        fromDate!.month == today.month &&
        fromDate!.year == today.year &&
        toDate!.day == today.day &&
        toDate!.month == today.month &&
        toDate!.year == today.year;

    // Date range is selected if both dates are provided AND it's not today
    final bool isDateRangeSelected =
        fromDate != null && toDate != null && !isTodaySelected;

    debugPrint("isDateRangeSelected $isDateRangeSelected");
    
    final double displayExpenses = isDateRangeSelected
                                    ? expensesDateRange
                                    : expensesToday;
    final String expensesLabel = isDateRangeSelected
                                  ? "Date Range Expenses"
                                  : "Today's Expenses";

    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.green.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range Info (if selected and not today)
          if (isDateRangeSelected)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "📅 Selected Date Range:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  "${DateFormat('dd MMM yyyy').format(fromDate!)} → ${DateFormat('dd MMM yyyy').format(toDate!)}",
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade600),
                ),
                SizedBox(height: 8),
              ],
            ),

          // Sales Totals
          Text(
            isDateRangeSelected
                ? "Selected Range Sales: ₹ ${todayTotal.toStringAsFixed(2)}"
                : "Today's Sales: ₹ ${todayTotal.toStringAsFixed(2)}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "This Week: ₹ ${weekTotal.toStringAsFixed(2)}",
            style: TextStyle(fontSize: 16),
          ),
          Text(
            "This Month: ₹ ${monthTotal.toStringAsFixed(2)}",
            style: TextStyle(fontSize: 16),
          ),
          Divider(),

          // Payment Modes
          Text("By Payment Mode:",style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
          Text("💵 Cash: ₹ ${cashTotal.toStringAsFixed(2)}"),
          Text("💳 Card: ₹ ${cardTotal.toStringAsFixed(2)}"),
          Text("📱 UPI: ₹ ${upiTotal.toStringAsFixed(2)}"),
          Text("📱 Not Settled: ₹ ${otherTotal.toStringAsFixed(2)}"),
          Divider(),
          // Payment Modes
          Text("Udhari Get and Give:",style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),
          Text("You_will_give: ₹ ${giveamount}"),
          Text("You_will_get: ₹ ${takeamount}"),
          Divider(),



          // Expenses Section
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "💰 $expensesLabel:- ₹ ${displayExpenses.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red.shade800,
                  ),
                ),
                SizedBox(height: 4),

                // Show today's expenses as reference when date range is selected
                if (isDateRangeSelected && expensesToday > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "(Today's expenses: ₹ ${expensesToday.toStringAsFixed(2)})",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Combined Total (Sales - Expenses)
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Net Total:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  "₹ ${(todayTotal).toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get isDateRangeSelected {
    return fromDate != null &&
        toDate != null &&
        (fromDate!.day != toDate!.day ||
            fromDate!.month != toDate!.month ||
            fromDate!.year != toDate!.year);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              BillPrinter().printSalesReportSummary(
                context: context,
                fromDate: fromDate,
                toDate: toDate,
                todayTotal: todayTotal,
                weekTotal: weekTotal,
                monthTotal: monthTotal,
                cashTotal: cashTotal,
                cardTotal: cardTotal,
                upiTotal: upiTotal,
                otherTotal: otherTotal,
                giveamount: giveamount,
                takeamount: takeamount,
                expensesDateRange: expensesDateRange,
                expensesToday: expensesToday,
                isDateRangeSelected: isDateRangeSelected,
              );
            },
            tooltip: 'Print Summary Report',
          ),
        ],
      ),
    );
  }


}
