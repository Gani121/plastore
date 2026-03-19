// lib/pages/add_edit_expense_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:test1/utilities.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/supplier_database.dart';
import '../database_Module/cunsuption.dart';
import '../database_Module/expensDB.dart';
import '../database_Module/menu_item.dart';
import '../objectbox.g.dart';

class AddEditExpensePage extends StatefulWidget {
  final Expense? expenseToEdit;

  const AddEditExpensePage({super.key, this.expenseToEdit});

  @override
  State<AddEditExpensePage> createState() => _AddEditExpensePageState();
}

class _AddEditExpensePageState extends State<AddEditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _recivedAmountController = TextEditingController();
  
  // Variables
  late DateTime _selectedDate;
  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'Cash';
  String _selectedUnit = 'unit';
  String _expenseType = 'Expense';
  
  // Image
  File? _selectedImage;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  
  // Data lists
  late Store _store;
  List<String> _categories = [
    'Food', 'Transport', 'Entertainment', 'Shopping', 
    'Utilities', 'Healthcare', 'Other',
  ];
  List<Supplier> _suppliers = [];
  List<String> _supplierNames = [];
  List<String> _expenseTitles = [];
  List<String> _inventoryItemNames = [];
  List<String> _menuItemNames = [];
  List<Expense> _expenses = [];

  // Focus nodes
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _supplierFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  bool get isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _selectedDate = DateTime.now();
    
    _loadInitialData();
    
    if (isEditing) {
      _populateFormWithExpense(widget.expenseToEdit!);
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadCategories(),
      _loadSuppliers(),
      _loadExpenseTitles(),
      _loadInventoryItems(),
      _loadMenuItems(),
      _loadExpenses(),
    ]);
    setState(() {});
  }

  Future<void> _loadCategories() async {
    // You can load from SharedPreferences if needed
  }

  Future<void> _loadSuppliers() async {
    try {
      final box = _store.box<Supplier>();
      final allSuppliers = box.getAll();
      _suppliers = allSuppliers;
      _supplierNames = allSuppliers.map((s) => s.supplierName).toList();
    } catch (e) {
      print_log_red('Error loading suppliers: $e');
    }
  }

  Future<void> _loadExpenseTitles() async {
    try {
      final box = _store.box<expences>();
      final allExpenses = box.getAll();
      final Set<String> titles = {};
      
      for (final entity in allExpenses) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
          final expense = Expense.fromMap(map);
          if (expense.title.isNotEmpty) {
            titles.add(expense.title);
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
      _expenseTitles = titles.toList()..sort();
    } catch (e) {
      print_log_red('Error loading expense titles: $e');
    }
  }

  Future<void> _loadInventoryItems() async {
    try {
      final box = _store.box<InventoryItem>();
      final items = box.getAll();
      _inventoryItemNames = items.map((item) => item.name).toList()..sort();
    } catch (e) {
      print_log_red('Error loading inventory items: $e');
    }
  }

  Future<void> _loadMenuItems() async {
    try {
      final box = _store.box<MenuItem>();
      final items = box.getAll();
      _menuItemNames = items.map((item) => item.name).toList()..sort();
    } catch (e) {
      print_log_red('Error loading menu items: $e');
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final box = _store.box<expences>();
      final expensesJson = box.getAll();
      for (final s in expensesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(s.expence));
          _expenses.add(Expense.fromMap(map));
        } catch (e) {
          print_log_red('Error parsing expense: $e');
        }
      }
    } catch (e) {
      print_log_red('Error loading expenses: $e');
    }
  }

  void _populateFormWithExpense(Expense expense) {
    _titleController.text = expense.title;
    _amountController.text = expense.amount.toString();
    _selectedDate = expense.date;
    _selectedCategory = expense.category;
    _imagePath = expense.photoPath;
    if (expense.photoPath != null && File(expense.photoPath!).existsSync()) {
      _selectedImage = File(expense.photoPath!);
    }
    
    _supplierController.text = expense.supplierName ?? '';
    if (expense.quantity != null) {
      _qtyController.text = expense.quantity.toString();
    }
    _selectedUnit = expense.unit ?? 'unit';
    _selectedPaymentMethod = expense.paymentMethod ?? 'Cash';
    if (expense.receivedAmount != null) {
      _recivedAmountController.text = expense.receivedAmount.toString();
    }
    _descriptionController.text = expense.description ?? '';
    _expenseType = expense.expenseType ?? 'Expense';
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    double? receivedAmount;
    if (_selectedPaymentMethod == 'Credit' && _recivedAmountController.text.isNotEmpty) {
      receivedAmount = double.tryParse(_recivedAmountController.text);
    }

    double quantity = _qtyController.text.isNotEmpty 
        ? double.tryParse(_qtyController.text) ?? 0 
        : 0;

    // Validate stock for consumption, sell, and wastage
    if ((_expenseType == 'Consumption' || _expenseType == 'Sell' || _expenseType == 'Wastage') && quantity > 0) {
      if (_titleController.text.isEmpty) {
        _showErrorSnackBar('Please select an item');
        return;
      }

      // Show confirmation for wastage
      if (_expenseType == 'Wastage') {
        bool? confirm = await _showWastageConfirmation(quantity);
        if (confirm != true) return;
      }
    }

    final expense = Expense(
      id: isEditing ? widget.expenseToEdit!.id : ganarateID().toString(),
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      category: _selectedCategory,
      photoPath: _imagePath,
      supplierName: _supplierController.text.isNotEmpty ? _supplierController.text.trim() : null,
      quantity: quantity > 0 ? quantity : null,
      unit: _selectedUnit != 'unit' ? _selectedUnit : null,
      paymentMethod: _selectedPaymentMethod,
      receivedAmount: receivedAmount,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : null,
      expenseType: _expenseType,
    );

    try {
      // Update stock based on expense type
      if (quantity > 0) {
        await _updateStock(expense);
      }

      // Return the expense to previous page
      Navigator.pop(context, expense);
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _updateStock(Expense expense) async {
    if (_expenseType == 'Consumption') {
      await _updateInventoryStock(expense.title, expense.quantity!, _expenseType);
    } else if (_expenseType == 'Wastage') {
      if (_inventoryItemNames.contains(expense.title)) {
        await _updateInventoryStock(expense.title, expense.quantity!, _expenseType);
      } else if (_menuItemNames.contains(expense.title)) {
        await _updateMenuItemStock(expense.title, expense.quantity!, _expenseType);
      }
    } else if (_expenseType == 'Sell') {
      await _updateMenuItemStock(expense.title, expense.quantity!, _expenseType);
    }
  }

  Future<void> _updateInventoryStock(String itemName, double quantity, String action) async {
    try {
      final box = _store.box<InventoryItem>();
      final query = box.query(InventoryItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();

      if (items.isNotEmpty) {
        final item = items.first;
        
        switch (action) {
          case 'Consumption':
            if (item.stockQuantity < quantity) {
              throw Exception('Insufficient stock! Available: ${item.stockQuantity} ${item.unit}');
            }
            item.stockQuantity -= quantity;
            break;
          case 'Wastage':
            if (item.stockQuantity < quantity) {
              throw Exception('Insufficient stock for wastage! Available: ${item.stockQuantity} ${item.unit}');
            }
            item.stockQuantity -= quantity;
            break;
        }
        
        await box.putAsync(item);
        print_log('Inventory updated: ${item.name} - New stock: ${item.stockQuantity} ${item.unit}');
      }
    } catch (e) {
      print_log_red('Error updating inventory: $e');
      rethrow;
    }
  }

  Future<void> _updateMenuItemStock(String itemName, double quantity, String action) async {
    try {
      final box = _store.box<MenuItem>();
      final query = box.query(MenuItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();

      if (items.isNotEmpty) {
        final item = items.first;
        
        switch (action) {
          case 'Sell':
            item.adjustStock = (item.adjustStock ?? 0) + quantity.toInt();
            break;
          case 'Wastage':
            item.adjustStock = (item.adjustStock ?? 0) - quantity.toInt();
            break;
        }
        
        await box.putAsync(item);
        print_log('Menu item updated: ${item.name} - New stock: ${item.adjustStock}');
      }
    } catch (e) {
      print_log_red('Error updating menu item: $e');
      rethrow;
    }
  }

  Future<bool?> _showWastageConfirmation(double quantity) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Wastage'),
        content: Text('Are you sure you want to mark $quantity $_selectedUnit of "${_titleController.text}" as wastage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image != null) {
      String? savedPath = await saveImageInternalStorageDirectory(image.path, 'expense_images');
      if (savedPath != null) {
        setState(() {
          _selectedImage = File(savedPath);
          _imagePath = savedPath;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image != null) {
      String? savedPath = await saveImageInternalStorageDirectory(image.path, 'expense_images');
      if (savedPath != null) {
        setState(() {
          _selectedImage = File(savedPath);
          _imagePath = savedPath;
        });
      }
    }
  }

  void _removePhoto() {
    setState(() {
      if (_imagePath != null) {
        removeFileFromExternalStorage(_imagePath!);
      }
      _selectedImage = null;
      _imagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add New Expense'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveExpense,
          ),
        ],
      ),
      body: 
      
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_selectedImage!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                    ),
                    if (_selectedImage != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                            onPressed: _removePhoto,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Photo Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue.shade800),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expense Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            DateFormat('dd MMMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expense Type Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('Expense', Colors.blue),
                  _buildTypeChip('Consumption', Colors.green),
                  _buildTypeChip('Sell', Colors.orange),
                  _buildTypeChip('Wastage', Colors.red),
                ],
              ),
              const SizedBox(height: 16),

              // Title/Item Name
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: _getTitleLabel(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(_getTitleIcon()),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Amount and Payment Method
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Payment',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.payment),
                      ),
                      items: ['Cash', 'Online', 'Card', 'Credit']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPaymentMethod = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Received Amount for Credit
              if (_selectedPaymentMethod == 'Credit') ...[
                TextFormField(
                  controller: _recivedAmountController,
                  decoration: InputDecoration(
                    labelText: 'Received Amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.credit_score),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
              ],

              // Quantity and Unit
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.production_quantity_limits),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.straighten),
                      ),
                      items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Supplier
              TextFormField(
                controller: _supplierController,
                decoration: InputDecoration(
                  labelText: 'Supplier',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v ?? _categories.first),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description / Notes',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEditing ? 'Update Expense' : 'Save Expense',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    
    
    );
  }

  Widget _buildTypeChip(String type, Color color) {
    return ChoiceChip(
      label: Text(type),
      selected: _expenseType == type,
      selectedColor: color.withOpacity(0.2),
      onSelected: (selected) {
        setState(() {
          _expenseType = type;
          _titleController.clear();
        });
      },
    );
  }

  String _getTitleLabel() {
    switch (_expenseType) {
      case 'Expense': return 'Expense Title';
      case 'Consumption': return 'Inventory Item';
      case 'Wastage': return 'Item Name';
      default: return 'Menu Item';
    }
  }

  IconData _getTitleIcon() {
    switch (_expenseType) {
      case 'Expense': return Icons.receipt;
      case 'Consumption': return Icons.inventory;
      case 'Wastage': return Icons.warning;
      default: return Icons.restaurant_menu;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _supplierController.dispose();
    _qtyController.dispose();
    _descriptionController.dispose();
    _recivedAmountController.dispose();
    _titleFocusNode.dispose();
    _amountFocusNode.dispose();
    _supplierFocusNode.dispose();
    _qtyFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }
}