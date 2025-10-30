import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../cartprovier/ObjectBoxService.dart';
import '../models/transaction.dart'; // replace with actual import
import 'package:shared_preferences/shared_preferences.dart'; // <-- already imported? if not, add it at the top
import 'ExpensesPage.dart';

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
  double todayExpenses = 0;
  double expensesToday = 0.0;
  double expensesDateRange = 0.0;
  Map<DateTime, double> daywiseExpensesMap = {};

  Map<String, int> itemQtyMap = {};
  Map<String, double> itemPriceMap = {};

  // Date range filter
  DateTime? fromDate;
  DateTime? toDate;

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

  Future<void> _loadTransactions() async {
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
      final daywiseData = await ExpensesService.getDaywiseExpenses();
      expensesTodayTotal = daywiseData[todayNormalized] ?? 0.0;

      // Get date range expenses total
      expensesDateRangeTotal = await ExpensesService.getDateRangeTotal(
        from,
        to,
      );

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
      }

      for (var item in tx.decodedCart) {
        final name = item['name'].toString();
        final qty = int.tryParse(item['qty'].toString()) ?? 0;
        final price = double.tryParse(item['sellPrice'].toString()) ?? 0.0;

        qtyMap[name] = (qtyMap[name] ?? 0) + qty;
        priceMap[name] = (priceMap[name] ?? 0) + (price * qty);
      }
    }

    // 🔹 Read today's expenses from SharedPreferences (if you still need this)
    final prefs = await SharedPreferences.getInstance();
    final storedExpenses = prefs.getDouble('Todayexpenses') ?? 0.0;

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
      todayExpenses = storedExpenses;

      // 🔹 Set the new expenses data
      expensesToday = expensesTodayTotal;
      expensesDateRange = expensesDateRangeTotal;
      daywiseExpensesMap = daywiseExpenses;
    });
  }

  String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy – hh:mm a').format(date);
  }

  List<MapEntry<String, int>> getTopItemsByQty() {
    final entries = itemQtyMap.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  List<MapEntry<String, double>> getTopItemsByPrice() {
    final entries = itemPriceMap.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
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

    // // Include date range if selected
    // if (isDateRangeSelected) {
    //   reportBuffer.writeln(
    //     "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate!)}"
    //     " → ${DateFormat('dd MMM yyyy').format(toDate!)}",
    //   );
    // } else if (fromDate != null && toDate != null) {
    //   // Show today's date when today is selected
    //   reportBuffer.writeln(
    //     "Date: ${DateFormat('dd MMM yyyy').format(fromDate!)}",
    //   );
    // }

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
    reportBuffer.writeln("\nBy Payment Mode:");
    reportBuffer.writeln("💵 Cash: ₹ ${cashTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("💳 Card: ₹ ${cardTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("📱 UPI: ₹ ${upiTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("\n💰 $expensesLabel:");
    reportBuffer.writeln("₹ ${displayExpenses.toStringAsFixed(2)}");

    // Show today's expenses as reference when date range is selected
    if (isDateRangeSelected && expensesToday > 0) {
      reportBuffer.writeln(
        "(Today's expenses: ₹ ${expensesToday.toStringAsFixed(2)})",
      );
    }

    reportBuffer.writeln("\n💼 Net Total (Sales - Expenses):");
    reportBuffer.writeln(
      "₹ ${(todayTotal - displayExpenses).toStringAsFixed(2)}",
    );
    reportBuffer.writeln("\nTop Items by Qty:");
    for (var e in getTopItemsByQty()) {
      reportBuffer.writeln("• ${e.key}: Qty ${e.value}");
    }
    reportBuffer.writeln("\nTop Items by Price:");
    for (var e in getTopItemsByPrice()) {
      reportBuffer.writeln("• ${e.key}: ₹ ${e.value.toStringAsFixed(2)}");
    }

    await Share.share(
      reportBuffer.toString(),
      subject: 'Sales Report - $formattedDate',
    );
  }

  @override
  Widget build(BuildContext context) {
    final topQty = getTopItemsByQty();
    final topPrice = getTopItemsByPrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Share Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔹 Updated Date filter section
            _buildDateFilterSection(),
            _buildSummaryCard(),
            _buildSectionTitle("Top 5 Items by Quantity"),
            _buildItemList(topQty, isQty: true),
            _buildSectionTitle("Top 5 Items by Price"),
            _buildItemList(topPrice, isQty: false),
            _buildSectionTitle("Pie Chart - Top Items (₹)"),
            _buildPieChart(topPrice),
            _buildSectionTitle("Bar Chart - Top Items (Qty)"),
            _buildBarChart(topQty),
          ],
        ),
      ),
    );
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
          Text(
            "By Payment Mode:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text("💵 Cash: ₹ ${cashTotal.toStringAsFixed(2)}"),
          Text("💳 Card: ₹ ${cardTotal.toStringAsFixed(2)}"),
          Text("📱 UPI: ₹ ${upiTotal.toStringAsFixed(2)}"),
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
                  "💰 $expensesLabel:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "₹ ${displayExpenses.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),

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
                  "₹ ${(todayTotal - displayExpenses).toStringAsFixed(2)}",
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildItemList(List<MapEntry> items, {required bool isQty}) {
    return Column(
      children: items.map((entry) {
        return ListTile(
          title: Text(entry.key),
          trailing: Text(
            isQty
                ? 'Qty: ${entry.value}'
                : '₹ ${entry.value.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieChart(List<MapEntry<String, double>> data) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
    ];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: AspectRatio(
        aspectRatio: 1.3,
        child: PieChart(
          PieChartData(
            sections: List.generate(data.length, (i) {
              final value = data[i].value;
              return PieChartSectionData(
                value: value,
                title: data[i].key,
                color: colors[i % colors.length],
                radius: 60,
                titleStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<MapEntry<String, int>> data) {
    final colors = [
      Colors.teal,
      Colors.deepOrange,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Text(
                      data[index].key,
                      style: TextStyle(fontSize: 10),
                    );
                  }
                  return SizedBox.shrink();
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(data.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].value.toDouble(),
                  color: colors[i % colors.length],
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
