// lib/services/expense_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:test1/utilities.dart';
import 'package:test1/database_Module/expensDB.dart';
import '../objectbox.g.dart';
import 'package:intl/intl.dart';


class ExpenseService {
  final Store store;
  late Box<expences> _box;

  ExpenseService(this.store) {
    _box = store.box<expences>();
  }

  // Save expense
  Future<int> saveExpense(Expense expense) async {
    try {
      final expenseEntity = expences(
        syid:ganarateID(), expence: jsonEncode(expense.toMap()),
      );
      final id = await _box.putAsync(expenseEntity);
      print_log('Expense saved with ID: $id');
      return id;
    } catch (e) {
      print_log_red('Error saving expense: $e');
      rethrow;
    }
  }

  // Get all expenses
  List<Expense> getAllExpenses() {
    try {
      final entities = _box.getAll();
      final expenses = <Expense>[];

      for (final entity in entities) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
          expenses.add(Expense.fromMap(map));
        } catch (e) {
          print_log_red('Error parsing expense: $e');
        }
      }

      // Sort by date, newest first
      expenses.sort((a, b) => b.date.compareTo(a.date));
      return expenses;
    } catch (e) {
      print_log_red('Error getting expenses: $e');
      return [];
    }
  }

  // Get expense by ID
  Expense? getExpenseById(String expenseId) {
    try {
      final entities = _box.getAll();
      for (final entity in entities) {
        final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
        if (map['id'].toString() == expenseId) {
          return Expense.fromMap(map);
        }
      }
      return null;
    } catch (e) {
      print_log_red('Error finding expense: $e');
      return null;
    }
  }

  // Delete expense
  Future<bool> deleteExpense(String expenseId) async {
    try {
      final entities = _box.getAll();
      for (final entity in entities) {
        final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
        if (map['id'].toString() == expenseId) {
          // Delete photo if exists
          if (map['photoPath'] != null) {
            await removeFileFromExternalStorage(map['photoPath']);
          }
          return _box.remove(entity.id);
        }
      }
      return false;
    } catch (e) {
      print_log_red('Error deleting expense: $e');
      return false;
    }
  }

  // Update expense
  Future<bool> updateExpense(Expense expense) async {
    try {
      final entities = _box.getAll();
      for (final entity in entities) {
        final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
        if (map['id'].toString() == expense.id) {
          entity.expence = jsonEncode(expense.toMap());
          await _box.putAsync(entity);
          return true;
        }
      }
      return false;
    } catch (e) {
      print_log_red('Error updating expense: $e');
      return false;
    }
  }

  // Get expenses by date range
  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    final allExpenses = getAllExpenses();
    return allExpenses.where((expense) {
      return expense.date.isAfter(start.subtract(const Duration(days: 1))) &&
             expense.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // Get expenses by category
  List<Expense> getExpensesByCategory(String category) {
    final allExpenses = getAllExpenses();
    return allExpenses.where((expense) => expense.category == category).toList();
  }

  // Get expenses by payment method
  List<Expense> getExpensesByPaymentMethod(String method) {
    final allExpenses = getAllExpenses();
    return allExpenses.where((expense) => expense.paymentMethod == method).toList();
  }

  // Get credit expenses (pending payments)
  List<Expense> getCreditExpenses() {
    final allExpenses = getAllExpenses();
    return allExpenses.where((expense) => 
        expense.paymentMethod == 'Credit' && 
        expense.dueAmount != null && 
        expense.dueAmount! > 0
    ).toList();
  }

  // Calculate total by date range
  double getTotalByDateRange(DateTime start, DateTime end) {
    final expenses = getExpensesByDateRange(start, end);
    return expenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  // Calculate total pending amount
  double getTotalPendingAmount() {
    final creditExpenses = getCreditExpenses();
    return creditExpenses.fold(0.0, (sum, e) => sum + (e.dueAmount ?? 0));
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    final allExpenses = getAllExpenses();
    final now = DateTime.now();
    final thisMonth = now.month;
    final thisYear = now.year;

    double monthlyTotal = 0;
    double yearlyTotal = 0;
    final Map<String, double> categoryWise = {};
    final Map<String, double> paymentMethodWise = {};

    for (final expense in allExpenses) {
      // Monthly total
      if (expense.date.month == thisMonth && expense.date.year == thisYear) {
        monthlyTotal += expense.amount;
      }

      // Yearly total
      if (expense.date.year == thisYear) {
        yearlyTotal += expense.amount;
      }

      // Category wise
      categoryWise[expense.category] = 
          (categoryWise[expense.category] ?? 0) + expense.amount;

      // Payment method wise
      final method = expense.paymentMethod ?? 'Other';
      paymentMethodWise[method] = 
          (paymentMethodWise[method] ?? 0) + expense.amount;
    }

    return {
      'total': allExpenses.fold(0.0, (sum, e) => sum + e.amount),
      'monthly': monthlyTotal,
      'yearly': yearlyTotal,
      'count': allExpenses.length,
      'categoryWise': categoryWise,
      'paymentMethodWise': paymentMethodWise,
      'pendingAmount': getTotalPendingAmount(),
      'creditCount': getCreditExpenses().length,
    };
  }

  // Export to CSV
  Future<String> exportToCSV() async {
    final expenses = getAllExpenses();
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('ID,Title,Amount,Date,Category,Supplier,Quantity,Unit,Payment Method,Received Amount,Description,Expense Type');
    
    // Data rows
    for (final e in expenses) {
      buffer.writeln(
        '${e.id},'
        '"${e.title}",'
        '${e.amount},'
        '${DateFormat('yyyy-MM-dd').format(e.date)},'
        '"${e.category}",'
        '"${e.supplierName ?? ''}",'
        '${e.quantity ?? ''},'
        '"${e.unit ?? ''}",'
        '"${e.paymentMethod ?? ''}",'
        '${e.receivedAmount ?? ''},'
        '"${e.description ?? ''}",'
        '"${e.expenseType ?? ''}"'
      );
    }

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/expenses_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());
    
    return file.path;
  }
}