// lib/widgets/expense_statistics.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:test1/pages/expense_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test1/database_Module/expensDB.dart';
import 'package:flutter/material.dart';
import '../objectbox.g.dart';

class ExpenseProvider extends ChangeNotifier {
  late ExpenseService _expenseService;
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isLoading = false;
  String _currentFilter = 'All';
  String _searchQuery = '';

  // Initialize with store
  void init(Store store) {
    _expenseService = ExpenseService(store);
    loadExpenses();
  }

  // Getters
  List<Expense> get expenses => _filteredExpenses.isEmpty ? _expenses : _filteredExpenses;
  bool get isLoading => _isLoading;
  String get currentFilter => _currentFilter;
  int get totalCount => _expenses.length;
  
  double get totalAmount => _expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get totalPending => _expenseService.getTotalPendingAmount();

  // Load all expenses
  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      _expenses = _expenseService.getAllExpenses();
      _applyFilter();
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add expense
  Future<void> addExpense(Expense expense) async {
    await _expenseService.saveExpense(expense);
    await loadExpenses();
  }

  // Update expense
  Future<void> updateExpense(Expense expense) async {
    await _expenseService.updateExpense(expense);
    await loadExpenses();
  }

  // Delete expense
  Future<void> deleteExpense(String id) async {
    await _expenseService.deleteExpense(id);
    await loadExpenses();
  }

  // Filter by category
  void filterByCategory(String category) {
    _currentFilter = category;
    _applyFilter();
  }

  // Filter by payment method
  void filterByPaymentMethod(String method) {
    _currentFilter = method;
    _applyFilter();
  }

  // Search
  void search(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilter();
  }

  // Apply all filters
  void _applyFilter() {
    if (_currentFilter == 'All' && _searchQuery.isEmpty) {
      _filteredExpenses = [];
    } else {
      _filteredExpenses = _expenses.where((expense) {
        bool matchesFilter = _currentFilter == 'All' ||
            expense.category == _currentFilter ||
            expense.paymentMethod == _currentFilter;

        bool matchesSearch = _searchQuery.isEmpty ||
            expense.title.toLowerCase().contains(_searchQuery) ||
            (expense.supplierName?.toLowerCase().contains(_searchQuery) ?? false) ||
            expense.category.toLowerCase().contains(_searchQuery);

        return matchesFilter && matchesSearch;
      }).toList();
    }
    notifyListeners();
  }

  // Clear filters
  void clearFilters() {
    _currentFilter = 'All';
    _searchQuery = '';
    _filteredExpenses = [];
    notifyListeners();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    return _expenseService.getStatistics();
  }

  // Export to CSV
  Future<String> exportToCSV() async {
    return await _expenseService.exportToCSV();
  }
}