import 'dart:io';
// import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:test1/database_Module/expensDB.dart';
import 'package:test1/database_Module/transaction.dart';
import 'package:test1/database_Module/menu_item.dart';
import 'package:test1/database_Module/cunsuption.dart';
import 'package:test1/utilities.dart';
import 'dart:convert';
import 'package:test1/objectbox.g.dart';

import './export_service.dart';



class ExportService {
  static const int MAX_PAGES = 20; // Limit total pages
  static const int MAX_TRANSACTIONS = 50; // Limit transactions shown
  static const int MAX_EXPENSES = 50; // Limit expenses shown
  static const int MAX_CONSUMPTIONS = 30; // Limit consumption items shown
  
  static Future<void> exportFullReport({
    required ExportPeriod period,
    required DateTime startDate,
    required DateTime endDate,
    required BuildContext context,
    required Store store,
  }) async {
    try {
      // Fetch all data from ObjectBox
      final transactionBox = store.box<Transaction>();
      final expensesBox = store.box<expences>();
      final consumptionBox = store.box<ItemConsumption>();
      final inventoryBox = store.box<InventoryItem>();
      final menuItemBox = store.box<MenuItem>();
      
      // Get all records
      final allTransactions = transactionBox.getAll();
      final allExpensesEntities = expensesBox.getAll();
      final allConsumptions = consumptionBox.getAll();
      final allInventory = inventoryBox.getAll();
      final allMenuItems = menuItemBox.getAll();
      
      // Parse expenses from JSON
      List<Expense> expenses = [];
      for (var entity in allExpensesEntities) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
          expenses.add(Expense.fromMap(map));
        } catch (e) {
          print('Error parsing expense: $e');
        }
      }
      
      // Filter by date range
      final filteredTransactions = allTransactions;
      
      final filteredExpenses = expenses;
      final filteredConsumptions = allConsumptions;
      
      // Limit data to prevent too many pages
      final limitedTransactions = filteredTransactions.take(MAX_TRANSACTIONS).toList();
      final limitedExpenses = filteredExpenses.take(MAX_EXPENSES).toList();
      final limitedConsumptions = filteredConsumptions.take(MAX_CONSUMPTIONS).toList();
      
      // Calculate totals (using full data for accurate totals)
      final totalSales = filteredTransactions.fold(0.0, (sum, t) => sum + (t.total ?? 0));
      final totalExpenses = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
      final totalConsumption = filteredConsumptions.fold(0.0, (sum, c) => sum + (c.quantityUsed ?? 0));
      final netProfit = totalSales - totalExpenses;
      
      // Group sales by payment method
      Map<String, double> salesByPayment = {};
      for (var tx in filteredTransactions) {
        String method = tx.payment_mode ?? 'Cash';
        salesByPayment[method] = (salesByPayment[method] ?? 0) + (tx.total ?? 0);
      }
      
      // Group expenses by category
      Map<String, double> expensesByCategory = {};
      for (var exp in filteredExpenses) {
        expensesByCategory[exp.category] = (expensesByCategory[exp.category] ?? 0) + exp.amount;
      }
      
      // Group consumption by item
      Map<String, double> consumptionByItem = {};
      for (var cons in filteredConsumptions) {
        consumptionByItem[cons.id.toString()] = (consumptionByItem[cons.toString()] ?? 0) + (cons.quantityUsed ?? 0);
      }
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Add main page with all content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            final List<pw.Widget> pages = [];
            
            // Page 1: Header and Summary
            pages.addAll([
              _buildHeader(period, startDate, endDate),
              pw.SizedBox(height: 20),
              _buildExecutiveSummary(totalSales, totalExpenses, totalConsumption, netProfit, filteredTransactions.length),
              pw.SizedBox(height: 30),
              _buildSalesSummary(salesByPayment, totalSales),
              pw.SizedBox(height: 20),
              _buildExpensesSummary(expensesByCategory, totalExpenses),
              pw.SizedBox(height: 20),
              _buildConsumptionSummary(consumptionByItem, totalConsumption),
              pw.SizedBox(height: 30),
            ]);
            
            // Page 2: Detailed Transactions (if any)
            if (limitedTransactions.isNotEmpty) {
              // pages.add(1);
              pages.add(_buildDetailedTransactions(limitedTransactions, filteredTransactions.length > MAX_TRANSACTIONS));
            }
            
            // Page 3: Detailed Expenses (if any)
            if (limitedExpenses.isNotEmpty) {
              // pages.add(3);
              pages.add(_buildDetailedExpenses(limitedExpenses, filteredExpenses.length > MAX_EXPENSES));
            }
            
            // Page 4: Inventory Status
            // pages.add(2);
            pages.add(_buildInventoryStatus(allInventory, allMenuItems));
            
            // Footer for each page
            pages.add(_buildFooter());
            
            return pages;
          },
        ),
      );
      
      // Save and share
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'business_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Business Report - ${period.displayName}',
      );
      
      Future.delayed(const Duration(seconds: 5), () {
        file.delete();
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('PDF export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  static pw.Widget _buildHeader(ExportPeriod period, DateTime startDate, DateTime endDate) {
    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Business Performance Report',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            period.displayName,
            style: pw.TextStyle(
              fontSize: 18,
              color: PdfColors.blue600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${DateFormat('dd MMMM yyyy').format(startDate)} - ${DateFormat('dd MMMM yyyy').format(endDate)}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
          pw.Divider(thickness: 2),
        ],
      ),
    );
  }
  
  static pw.Widget _buildExecutiveSummary(
    double totalSales,
    double totalExpenses,
    double totalConsumption,
    double netProfit,
    int transactionCount,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Executive Summary',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricCard('Total Sales', '₹${totalSales.toStringAsFixed(2)}', PdfColors.green),
              _buildMetricCard('Total Expenses', '₹${totalExpenses.toStringAsFixed(2)}', PdfColors.red),
              _buildMetricCard('Net Profit', '₹${netProfit.toStringAsFixed(2)}', 
                  netProfit >= 0 ? PdfColors.green : PdfColors.red),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricCard('Transactions', transactionCount.toString(), PdfColors.blue),
              _buildMetricCard('Consumption', '${totalConsumption.toStringAsFixed(0)} units', PdfColors.orange),
              _buildMetricCard('Profit Margin', 
                  totalSales > 0 ? '${((netProfit / totalSales) * 100).toStringAsFixed(1)}%' : '0%',
                  PdfColors.purple),
            ],
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildSalesSummary(Map<String, double> salesByPayment, double totalSales) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Sales Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Payment Method Breakdown', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...salesByPayment.entries.map((entry) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(entry.key),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    '₹${entry.value.toStringAsFixed(2)}',
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    height: 20,
                    margin: const pw.EdgeInsets.only(left: 8),
                    child: pw.ClipRRect(
                      // borderRadius: pw.BorderRadius.circular(4),
                      child: pw.Container(
                        width: totalSales > 0 ? (entry.value / totalSales) * 200 : 0,
                        color: _getPaymentColor(entry.key),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  static pw.Widget _buildExpensesSummary(Map<String, double> expensesByCategory, double totalExpenses) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Expenses Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Category Breakdown', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...expensesByCategory.entries.map((entry) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(entry.key),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    '₹${entry.value.toStringAsFixed(2)}',
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    height: 20,
                    margin: const pw.EdgeInsets.only(left: 8),
                    child: pw.ClipRRect(
                      // borderRadius: pw.BorderRadius.circular(4),
                      child: pw.Container(
                        width: totalExpenses > 0 ? (entry.value / totalExpenses) * 200 : 0,
                        color: _getCategoryColor(entry.key),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  static pw.Widget _buildConsumptionSummary(Map<String, double> consumptionByItem, double totalConsumption) {
    if (consumptionByItem.isEmpty) {
      return pw.Container();
    }
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Inventory Consumption Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Top Consumed Items', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...consumptionByItem.entries.take(10).map((entry) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Text(entry.key)),
                pw.Text('${entry.value.toStringAsFixed(0)} units'),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  static pw.Widget _buildDetailedTransactions(List<Transaction> transactions, bool hasMore) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Recent Transactions',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
        ),
        pw.SizedBox(height: 12),
        if (hasMore)
          pw.Text(
            'Showing ${transactions.length} of ${transactions.length}+ transactions',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Table No', 'Amount', 'Payment', 'Items'],
          data: transactions.map((tx) => [
            DateFormat('dd/MM/yy').format(tx.time),
            tx.tableNo?.toString() ?? '-',
            '₹${(tx.total ?? 0).toStringAsFixed(2)}',
            tx.payment_mode ?? 'Cash',
            '${tx.cartData?.length ?? 0} items',
          ]).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: PdfColors.green),
          cellAlignment: pw.Alignment.centerLeft,
          cellHeight: 25,
          cellStyle: pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }
  
  static pw.Widget _buildDetailedExpenses(List<Expense> expenses, bool hasMore) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Recent Expenses',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
        ),
        pw.SizedBox(height: 12),
        if (hasMore)
          pw.Text(
            'Showing ${expenses.length} of ${expenses.length}+ expenses',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Title', 'Amount', 'Category', 'Payment'],
          data: expenses.map((e) => [
            DateFormat('dd/MM/yy').format(e.date),
            e.title.length > 25 ? '${e.title.substring(0, 25)}...' : e.title,
            '₹${e.amount.toStringAsFixed(2)}',
            e.category,
            e.paymentMethod ?? 'Cash',
          ]).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: PdfColors.red),
          cellAlignment: pw.Alignment.centerLeft,
          cellHeight: 25,
          cellStyle: pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }
  
  static pw.Widget _buildInventoryStatus(List<InventoryItem> inventory, List<MenuItem> menuItems) {
    final lowStockInventory = inventory.where((item) => item.stockQuantity < 10).toList();
    final lowStockMenu = menuItems.where((item) => (item.available ?? 0) < 5).toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Inventory Status',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange800,
          ),
        ),
        pw.SizedBox(height: 12),
        
        if (lowStockInventory.isNotEmpty || lowStockMenu.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red300),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.red50,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '⚠️ Low Stock Alert',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                ),
                pw.SizedBox(height: 8),
                if (lowStockInventory.isNotEmpty) ...[
                  pw.Text('Inventory Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...lowStockInventory.take(10).map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(item.name)),
                        pw.Text('Stock: ${item.stockQuantity} ${item.unit}'),
                      ],
                    ),
                  )),
                ],
                if (lowStockMenu.isNotEmpty && lowStockInventory.isNotEmpty)
                  pw.SizedBox(height: 8),
                if (lowStockMenu.isNotEmpty) ...[
                  pw.Text('Menu Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...lowStockMenu.take(10).map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(item.name)),
                        pw.Text('Available: ${item.available ?? 0}'),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ] else ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green300),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.green50,
            ),
            child: pw.Text(
              '✓ All inventory items are well stocked',
              style: pw.TextStyle(color: PdfColors.green800),
            ),
          ),
        ],
      ],
    );
  }
  
  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This is a computer generated report',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page 1',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }
  
  static pw.Widget _buildMetricCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  static PdfColor _getPaymentColor(String paymentMethod) {
    switch (paymentMethod) {
      case 'Cash':
        return PdfColors.green;
      case 'Card':
        return PdfColors.blue;
      case 'Online':
        return PdfColors.purple;
      case 'Credit':
        return PdfColors.orange;
      default:
        return PdfColors.grey;
    }
  }
  
  static PdfColor _getCategoryColor(String category) {
    final colors = [
      PdfColors.blue,
      PdfColors.green,
      PdfColors.orange,
      PdfColors.purple,
      PdfColors.red,
      PdfColors.teal,
      PdfColors.pink,
    ];
    final hash = category.hashCode.abs();
    return colors[hash % colors.length];
  }
}

// Expense class (make sure this is defined)
class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? photoPath;
  final String? supplierName;
  final double? quantity;
  final String? unit;
  final String? paymentMethod;
  final double? receivedAmount;
  final String? description;
  final String? expenseType;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.photoPath,
    this.supplierName,
    this.quantity,
    this.unit,
    this.paymentMethod,
    this.receivedAmount,
    this.description,
    this.expenseType,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'] ?? 'Other',
      photoPath: map['photoPath'],
      supplierName: map['supplierName'],
      quantity: map['quantity']?.toDouble(),
      unit: map['unit'],
      paymentMethod: map['paymentMethod'],
      receivedAmount: map['receivedAmount']?.toDouble(),
      description: map['description'],
      expenseType: map['expenseType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'photoPath': photoPath,
      'supplierName': supplierName,
      'quantity': quantity,
      'unit': unit,
      'paymentMethod': paymentMethod,
      'receivedAmount': receivedAmount,
      'description': description,
      'expenseType': expenseType,
    };
  }
}

// ExportPeriod enum
enum ExportPeriod {
  today,
  week,
  month,
  year,
  custom,
}

extension ExportPeriodExtension on ExportPeriod {
  String get displayName {
    switch (this) {
      case ExportPeriod.today:
        return 'Today';
      case ExportPeriod.week:
        return 'This Week';
      case ExportPeriod.month:
        return 'This Month';
      case ExportPeriod.year:
        return 'This Year';
      case ExportPeriod.custom:
        return 'Custom Range';
    }
  }
  
  (DateTime, DateTime) getDateRange() {
    final now = DateTime.now();
    switch (this) {
      case ExportPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
      case ExportPeriod.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return (start, end);
      case ExportPeriod.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (start, end);
      case ExportPeriod.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return (start, end);
      case ExportPeriod.custom:
        return (now, now);
    }
  }
}