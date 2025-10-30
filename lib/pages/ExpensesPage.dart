import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final List<Expense> _expenses = [];
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';
  File? _selectedImage; // used while adding a new expense
  String? _imagePath; // path used while adding a new expense
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Food',
    'Transport',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Healthcare',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();

    // _loadExpenses().then((_) {
    //   _printAllExpensesFromPrefs(); // Print after loading
    // });
  }

  // ---------- Persistence ----------
  Future<void> _loadExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = prefs.getStringList('expenses') ?? [];

      setState(() {
        _expenses.clear();
        for (final s in expensesJson) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(s));
            _expenses.add(Expense.fromMap(map));
          } catch (e) {
            // ignore malformed entry
            debugPrint('Skipping malformed expense entry: $e');
          }
        }
        // update shared total notifier
        ExpensesService.updateTotal(_totalExpenses);
      });
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    }
  }

  Future<void> _saveExpensesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = _expenses.map((e) => jsonEncode(e.toMap())).toList();
      await prefs.setStringList('expenses', expensesJson);

      // update shared total
      await ExpensesService.updateTotal(_totalExpenses);

      final daywise = _getDaywiseExpenses();
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);
      final todayTotal = daywise[todayNormalized] ?? 0.0;
      debugPrint('Today\'s total: ₹$todayTotal');

      await prefs.setDouble('Todayexpenses', todayTotal);
    } catch (e) {
      debugPrint('Error saving expenses: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving data: $e')));
      }
    }
  }

  // ---------- Totals & stats ----------
  double get _totalExpenses {
    return _expenses.fold(0.0, (sum, exp) => sum + exp.amount);
  }

  double _getTodayExpenses() {
    final today = DateTime.now();
    final total = _expenses
        .where(
          (expense) =>
              expense.date.day == today.day &&
              expense.date.month == today.month &&
              expense.date.year == today.year,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
    // Persist today's total if needed
    _saveTotalExpensesToPrefs(total);
    return total;
  }

  Future<void> _saveTotalExpensesToPrefs(double total) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('totalExpenses', total);
      await ExpensesService.updateTotal(total);
    } catch (e) {
      debugPrint('Error saving total: $e');
    }
  }

  double _getWeekExpenses() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _expenses
        .where((expense) => expense.date.isAfter(weekAgo))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _getMonthExpenses() {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    return _expenses
        .where((expense) => expense.date.isAfter(monthAgo))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // ---------- UI Builders ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildExpensesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewExpense,
        backgroundColor: Colors.blue.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Total Expenses',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_totalExpenses.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'Today',
                '₹${_getTodayExpenses().toStringAsFixed(2)}',
              ),
              _buildStatCard(
                'This Week',
                '₹${_getWeekExpenses().toStringAsFixed(2)}',
              ),
              _buildStatCard(
                'This Month',
                '₹${_getMonthExpenses().toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return const Center(child: Text('No expenses yet'));
    }
    return ListView.builder(
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return _buildExpenseItem(expense);
      },
    );
  }

  Widget _buildExpenseItem(Expense expense) {
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async =>
          await _showDeleteConfirmation(expense),
      onDismissed: (direction) => _deleteExpense(expense),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: GestureDetector(
            onTap: () {
              if (expense.photoPath != null) {
                _showAttachedPhoto(expense.photoPath!);
              } else {
                _showAddPhotoDialog(expense);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor(expense.category),
                shape: BoxShape.circle,
              ),
              child: expense.photoPath != null
                  ? const Icon(
                      Icons.photo_camera,
                      color: Colors.white,
                      size: 20,
                    )
                  : Icon(
                      _getCategoryIcon(expense.category),
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
          title: Text(
            expense.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${expense.category} • ${DateFormat('MMM dd, yyyy').format(expense.date)}',
          ),
          trailing: Text(
            '₹${expense.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: expense.amount > 50 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Actions: add / edit / delete ----------
  void _deleteExpense(Expense expense) {
    final removed = expense;
    setState(() => _expenses.removeWhere((e) => e.id == expense.id));
    _saveExpensesToPrefs();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${expense.title}" deleted successfully!'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            setState(() => _expenses.add(removed));
            _saveExpensesToPrefs();
          },
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(Expense expense) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Expense'),
              content: Text(
                'Are you sure you want to delete "${expense.title}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // ---------- Photo viewing & editing ----------
  void _showAttachedPhoto(String photoPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(photoPath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 50,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddPhotoDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Photo'),
          content: const Text(
            'This expense doesn\'t have a photo attached. Would you like to add one?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _editExpensePhoto(expense);
              },
              child: const Text('Add Photo'),
            ),
          ],
        );
      },
    );
  }

  void _editExpensePhoto(Expense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index == -1) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Photo to "${expense.title}"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (expense.photoPath != null)
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.file(
                    File(expense.photoPath!),
                    fit: BoxFit.cover,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _takePhotoFromCamera(expense);
                    },
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade800,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _pickPhotoFromGallery(expense);
                    },
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                    ),
                  ),
                  if (expense.photoPath != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _removeExpensePhoto(expense);
                      },
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade800,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhotoFromCamera([Expense? expense]) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image == null) return;

    if (expense != null) {
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        setState(
          () => _expenses[idx] = _expenses[idx].copyWith(photoPath: image.path),
        );
        await _saveExpensesToPrefs();
      }
    } else {
      setState(() {
        _selectedImage = File(image.path);
        _imagePath = image.path;
      });
    }
  }

  Future<void> _pickPhotoFromGallery([Expense? expense]) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image == null) return;

    if (expense != null) {
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        setState(
          () => _expenses[idx] = _expenses[idx].copyWith(photoPath: image.path),
        );
        await _saveExpensesToPrefs();
      }
    } else {
      setState(() {
        _selectedImage = File(image.path);
        _imagePath = image.path;
      });
    }
  }

  void _removeExpensePhoto(Expense expense) {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      setState(() => _expenses[idx] = _expenses[idx].copyWith(photoPath: null));
      _saveExpensesToPrefs();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo removed')));
    }
  }

  // void _printAllExpensesFromPrefs() async {

  // }

  // ---------- Daywise Expenses Total ----------
  Map<DateTime, double> _getDaywiseExpenses() {
    final Map<DateTime, double> daywiseTotals = {};

    for (final expense in _expenses) {
      // Normalize the date to remove time component
      final dateOnly = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );

      daywiseTotals.update(
        dateOnly,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    // Sort by date (most recent first)
    final sortedEntries = daywiseTotals.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Map.fromEntries(sortedEntries);
  }

  /// ---------- Add new expense ----------
  void _addNewExpense() {
    _clearForm(); // ensure form is empty
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add New Expense',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPhotoUploadSection(),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Expense Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Please enter a title'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter an amount';
                      if (double.tryParse(value) == null)
                        return 'Please enter a valid number';
                      if ((double.tryParse(value) ?? 0.0) <= 0)
                        return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCategory = v ?? 'Food'),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Select Date'),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null)
                        setState(() => _selectedDate = pickedDate);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearForm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: _saveExpense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoUploadSection() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _selectedImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                )
              : Icon(Icons.receipt, size: 40, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                await _takePhotoFromCamera();
                setState(() {});
              },
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade800,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await _pickPhotoFromGallery();
                setState(() {});
              },
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade800,
              ),
            ),
            if (_selectedImage != null)
              ElevatedButton.icon(
                onPressed: () {
                  _removePhoto();
                  setState(() {});
                },
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade800,
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      category: _selectedCategory,
      photoPath: _imagePath,
    );

    setState(() => _expenses.add(newExpense));
    _saveExpensesToPrefs();
    Navigator.pop(context);
    _clearForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${newExpense.title}" added successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearForm() {
    _titleController.clear();
    _amountController.clear();
    _selectedDate = DateTime.now();
    _selectedCategory = 'Food';
    _selectedImage = null;
    _imagePath = null;
  }

  void _removePhoto() {
    setState(() {
      _selectedImage = null;
      _imagePath = null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Entertainment':
        return Colors.purple;
      case 'Shopping':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_bus;
      case 'Entertainment':
        return Icons.movie;
      case 'Shopping':
        return Icons.shopping_bag;
      default:
        return Icons.money;
    }
  }
}

// ---------- Expense model ----------
class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? photoPath;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'photoPath': photoPath,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'].toString(),
      title: map['title']?.toString() ?? '',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      category: map['category']?.toString() ?? 'Other',
      photoPath: map['photoPath']?.toString(),
    );
  }

  // convenience copyWith for updating photoPath
  Expense copyWith({
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? photoPath,
  }) {
    return Expense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}

// ---------- ExpensesService ----------
class ExpensesService {
  static final ValueNotifier<double> totalExpensesNotifier =
      ValueNotifier<double>(0.0);

  static Future<void> updateTotal(double newTotal) async {
    totalExpensesNotifier.value = newTotal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalExpenses', newTotal);
  }

  static Future<double> getTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('totalExpenses') ?? 0.0;
  }

  // Add this method to your _ExpensesPageState class

  // static final ExpensesService _instance = ExpensesService._internal();
  // factory ExpensesService() => _instance;
  // ExpensesService._internal();

  // Method to get date range total from any page
  static Future<double> getDateRangeTotal(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = prefs.getStringList('expenses') ?? [];

      // Normalize dates to include entire days
      final normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );

      double total = 0.0;

      for (final expenseJson in expensesJson) {
        try {

          final map = Map<String, dynamic>.from(jsonDecode(expenseJson));
          final expense = Expense.fromMap(map);

          // Check if expense falls within the date range
          // debugPrint("expense ${expense.date} $normalizedStart $normalizedEnd ${expense.date.isAfter(normalizedStart)} ${expense.date.isBefore(normalizedEnd)}");
          if (expense.date.isAfter(normalizedStart) && expense.date.isBefore(normalizedEnd)) {
            total += expense.amount;
          } 
        } catch (e) {
          debugPrint('Error parsing expense: $e');
        }
      }

      return total;
    } catch (e) {
      debugPrint('Error getting date range total: $e');
      return 0.0;
    }
  }

  // Method to get daywise expenses from any page
  static Future<Map<DateTime, double>> getDaywiseExpenses() async {
    final Map<DateTime, double> daywiseTotals = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      final expensesJson = prefs.getStringList('expenses') ?? [];

      for (final expenseJson in expensesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(expenseJson));
          final expense = Expense.fromMap(map);

          // Normalize the date to remove time component
          final dateOnly = DateTime(
            expense.date.year,
            expense.date.month,
            expense.date.day,
          );

          daywiseTotals.update(
            dateOnly,
            (value) => value + expense.amount,
            ifAbsent: () => expense.amount,
          );
        } catch (e) {
          debugPrint('Error parsing expense: $e');
        }
      }

      // Sort by date (most recent first)
      final sortedEntries = daywiseTotals.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));

      return Map.fromEntries(sortedEntries);
    } catch (e) {
      debugPrint('Error getting daywise expenses: $e');
      return {};
    }
  }
}
