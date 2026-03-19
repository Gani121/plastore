// lib/pages/purchase_invoice_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../database_Module/ObjectBoxService.dart';
import '../objectbox.g.dart';
import '../database_Module/purchase_invoice_DB.dart';
import '../utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/database_Module/supplier_database.dart';
import 'package:test1/database_Module/cunsuption.dart';
import 'package:test1/database_Module/expensDB.dart';
import 'package:test1/database_Module/menu_item.dart';
import 'package:test1/utilities.dart';
import 'package:test1/pages/PartyListPage.dart';
import 'package:test1/inventory/inventory_page.dart';
import 'package:http/http.dart' as http;

// Add these missing imports
import 'dart:math';

class PurchaseInvoicePage extends StatefulWidget {
  const PurchaseInvoicePage({super.key});

  @override
  State<PurchaseInvoicePage> createState() => _PurchaseInvoicePageState();
}

class _PurchaseInvoicePageState extends State<PurchaseInvoicePage> with SingleTickerProviderStateMixin {
  final List<PurchaseInvoice> _invoices = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<PurchaseItem> _items = [];
  late DateTime _selectedDate;
  late Store _store;
  File? _selectedImage;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  PaymentStatus _selectedStatus = PaymentStatus.pending;
  DateTime? _dueDate;

  // Expense related controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _recivedAmountController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  late TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _supplierMobileController = TextEditingController();
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier<bool>(false);
  
  String _selectedPaymentMethod = 'Cash';
  String _selectedUnit = 'unit';
  String _expenseType = 'Sell';
  String _selectedCategory = 'Food';

  // Focus nodes
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _supplierFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  List<String> _categories = [
    'Food', 'Transport', 'Entertainment', 'Shopping', 
    'Utilities', 'Healthcare', 'Other',
  ];

  List<Expense> _expenses = [];
  List<Supplier> _suppliers = [];
  List<String> _supplierNames = [];
  List<String> _expenseTitles = [];
  List<String> _inventoryItemNames = [];
  List<String> _menuItemNames = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dueDateController.text = _formatDate(DateTime.now().add(const Duration(days: 7)));
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _selectedDate = DateTime.now();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadInvoices(),
        _loadSuppliers(),
        _loadExpenseTitles(),
        _loadInventoryItems(),
        _loadMenuItems(),
        _loadExpenses(),
        _loadCategories(),
      ]);
    } catch (e) {
      print_log_red('Error loading initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }  
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  Future<void> _loadInvoices() async {
    try {
      final box = _store.box<PurchaseInvoiceEntity>();
      final entities = box.getAll();
      final List<PurchaseInvoice> loadedInvoices = [];

      for (final entity in entities) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(entity.invoiceData));
          loadedInvoices.add(PurchaseInvoice.fromMap(map));
        } catch (e) {
          print_log_red('Error parsing invoice: $e');
        }
      }

      loadedInvoices.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() {
        _invoices.clear();
        _invoices.addAll(loadedInvoices);
      });
    } catch (e) {
      print_log_red('Error loading invoices: $e');
    }
  }

  Future<void> _saveInvoice(PurchaseInvoice invoice) async {
    try {
      final box = _store.box<PurchaseInvoiceEntity>();
      final entity = PurchaseInvoiceEntity(
        syid: ganarateID(), 
        invoiceData: jsonEncode(invoice.toMap()),
      );
      await box.putAsync(entity);
      await _loadInvoices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${invoice.invoiceNumber} saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print_log_red('Error saving invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteInvoice(PurchaseInvoice invoice) async {
    try {
      final box = _store.box<PurchaseInvoiceEntity>();
      final entities = box.getAll();
      
      for (final entity in entities) {
        final map = jsonDecode(entity.invoiceData);
        if (map['id'].toString() == invoice.id) {
          box.remove(entity.id);
          if (invoice.photoPath != null) {
            await removeFileFromExternalStorage(invoice.photoPath!);
          }
          break;
        }
      }
      
      setState(() {
        _invoices.removeWhere((i) => i.id == invoice.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${invoice.invoiceNumber} deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print_log_red('Error deleting invoice: $e');
    }
  }

  double get _totalPurchases {
    return _invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
  }

  double _getPendingPayments() {
    return _invoices
        .where((inv) => inv.paymentStatus != PaymentStatus.paid)
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Invoices'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            onPressed: _showSummaryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                const SizedBox(height: 8),
                Expanded(child: _buildInvoiceList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInvoiceDialog,
        backgroundColor: Colors.green.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Total Purchases',
            '₹${_totalPurchases.toStringAsFixed(2)}',
            Icons.shopping_cart,
          ),
          _buildSummaryItem(
            'Pending',
            '₹${_getPendingPayments().toStringAsFixed(2)}',
            Icons.pending_actions,
            color: Colors.orange,
          ),
          _buildSummaryItem(
            'Invoices',
            _invoices.length.toString(),
            Icons.receipt,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.green.shade800, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.green.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildInvoiceList() {
    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No purchase invoices yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showAddInvoiceDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add First Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return _buildInvoiceCard(invoice);
      },
    );
  }

  Widget _buildInvoiceCard(PurchaseInvoice invoice) {
    Color statusColor;
    switch (invoice.paymentStatus) {
      case PaymentStatus.paid:
        statusColor = Colors.green;
        break;
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        break;
      case PaymentStatus.overdue:
        statusColor = Colors.red;
        break;
      case PaymentStatus.partial:
        statusColor = Colors.blue;
        break;
    }

    return Dismissible(
      key: Key(invoice.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Invoice'),
            content: Text('Delete invoice ${invoice.invoiceNumber}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteInvoice(invoice),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: GestureDetector(
            onTap: () {
              if (invoice.photoPath != null) {
                _showImage(invoice.photoPath!);
              }
            },
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.green.shade100,
              backgroundImage: invoice.photoPath != null && File(invoice.photoPath!).existsSync()
                  ? FileImage(File(invoice.photoPath!))
                  : null,
              child: invoice.photoPath == null
                  ? const Icon(Icons.receipt, color: Colors.green, size: 24)
                  : null,
            ),
          ),
          title: Text(
            invoice.invoiceNumber,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(invoice.supplierName),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(invoice.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.shopping_bag, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${invoice.items.length} items',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${invoice.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  invoice.paymentStatus.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          onTap: () => _showInvoiceDetails(invoice),
        ),
      ),
    );
  }

  // Date picker method
  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange, // Header color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dueDateController.text = _formatDate(picked);
      });
    }
  }

  // NEW FUNCTION: Show dialog to add an item to the invoice
  void _showAddItemDialog(StateSetter setModalState) {
    // Clear item form fields
    _titleController.clear();
    _amountController.clear();
    _qtyController.clear();
    _descriptionController.clear();
    _unitController.clear();
    _selectedUnit = 'unit';
    _expenseType = 'Sell';
    _selectedCategory = 'Food';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Item to Invoice'),
              content: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Type Selection
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text("Consumption")),
                              selected: _expenseType == 'Consumption',
                              selectedColor: Colors.green.shade100,
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  _expenseType = 'Consumption';
                                  _titleController.clear();
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text("Sell Item")),
                              selected: _expenseType == 'Sell',
                              selectedColor: Colors.orange.shade100,
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  _expenseType = 'Sell';
                                  _titleController.clear();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Item Name with Autocomplete
                      Text('Item Name *', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      RawAutocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          
                          List<String> suggestions = [];
                          if (_expenseType == 'Expense') {
                            suggestions = _expenseTitles;
                          } else if (_expenseType == 'Consumption') {
                            suggestions = _inventoryItemNames;
                          } else if (_expenseType == 'Sell') {
                            suggestions = _menuItemNames;
                          } else {
                            suggestions = [..._inventoryItemNames, ..._menuItemNames];
                          }
                          
                          return suggestions.where((item) => 
                            item.toLowerCase().contains(textEditingValue.text.toLowerCase())
                          ).take(10);
                        },
                        onSelected: (String selection) {
                          setDialogState(() {
                            _titleController.text = selection;
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Search ${_expenseType.toLowerCase()}...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              _titleController.text = value;
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: Container(
                                width: 300,
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Quantity and Unit
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _qtyController,
                              decoration: const InputDecoration(
                                labelText: 'Quantity *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                              ),
                              items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) => setDialogState(() => _selectedUnit = v!),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Unit Price and Total
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'Unit Price *',
                                border: OutlineInputBorder(),
                                prefixText: '₹ ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  Text(
                                    '₹ ${_calculateItemTotal().toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Category
                      DropdownButtonFormField<String>(
                        value: _categories.contains(_selectedCategory) ? _selectedCategory : _categories.first,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setDialogState(() => _selectedCategory = v!),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addItemToInvoice(setModalState);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                  ),
                  child: const Text('Add to Invoice'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // NEW FUNCTION: Calculate item total
  double _calculateItemTotal() {
    double qty = double.tryParse(_qtyController.text) ?? 0;
    double price = double.tryParse(_amountController.text) ?? 0;
    return qty * price;
  }

  // NEW FUNCTION: Add item to invoice
  void _addItemToInvoice(StateSetter setModalState) {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item name')),
      );
      return;
    }
    
    if (_qtyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter quantity')),
      );
      return;
    }
    
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter unit price')),
      );
      return;
    }
    
    double qty = double.tryParse(_qtyController.text) ?? 0;
    double unitPrice = double.tryParse(_amountController.text) ?? 0;
    
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0')),
      );
      return;
    }
    
    if (unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price must be greater than 0')),
      );
      return;
    }
    
    final item = PurchaseItem(
      name: _titleController.text.trim(),
      quantity: qty,
      unitPrice: unitPrice,
      totalPrice: qty * unitPrice,
      unit: _selectedUnit != 'unit' ? _selectedUnit : null,
      type: _expenseType,
    );
    
    setModalState(() {
      _items.add(item);
    });
    
    // Clear the form for next item
    _titleController.clear();
    _qtyController.clear();
    _amountController.clear();
    _descriptionController.clear();
    _selectedUnit = 'unit';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to invoice'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAddInvoiceDialog() {
    _clearForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.receipt, color: Colors.green.shade800),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'New Purchase Invoice',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo + Invoice Details Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Photo Section
                              _buildPhotoUploadSection(setModalState),
                              const SizedBox(width: 16),
                              
                              // Invoice Details
                              Expanded(
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _invoiceNumberController,
                                      decoration: _buildInputDecoration('Invoice No.', Icons.numbers),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedDate,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                        if (picked != null) {
                                          setModalState(() => _selectedDate = picked);
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: _buildInputDecoration('Bill Date', Icons.calendar_today),
                                        child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Supplier Name
                          TextFormField(
                            controller: _supplierController,
                            decoration: _buildInputDecoration('Supplier Name', Icons.business),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter supplier' : null,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Payment Method Section
                          Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Payment Method
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedPaymentMethod,
                                      decoration: _buildInputDecoration('Payment', Icons.payments),
                                      items: ['Cash', 'Online', 'Card', 'Credit']
                                          .map((m) => DropdownMenuItem(
                                                value: m, 
                                                child: Text(m, style: const TextStyle(fontSize: 12))
                                              ))
                                          .toList(),
                                      onChanged: (v) => setModalState(() => _selectedPaymentMethod = v!),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Show Received Amount below if Credit is selected
                              if (_selectedPaymentMethod == 'Credit') ...[
                                const SizedBox(height: 12),
                                
                                // Row for Received Amount and Due Date
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Received Amount Field
                                    Expanded(
                                      flex: 6,
                                      child: TextFormField(
                                        controller: _recivedAmountController,
                                        onTap: () {
                                          if (_recivedAmountController.text == '0') {
                                            _recivedAmountController.clear();
                                          }
                                        },
                                        decoration: _buildInputDecoration('Received Amount', Icons.payments),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 12),
                                    
                                    // Due Date Field
                                    Expanded(
                                      flex: 4,
                                      child: TextFormField(
                                        controller: _dueDateController,
                                        readOnly: true,
                                        onTap: () => _selectDueDate(context),
                                        decoration: InputDecoration(
                                          labelText: "Due Date",
                                          filled: true,
                                          fillColor: Colors.blue.shade50.withOpacity(0.3),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.blue.shade100),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade200),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Items Header with Add Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Items',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showAddItemDialog(setModalState),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade800,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Items List
                          if (_items.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.shopping_cart, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No items added',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap "Add Item" to add items',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Dismissible(
                                  key: Key('${item.name}_$index'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    color: Colors.red,
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (direction) {
                                    setModalState(() {
                                      _items.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade400,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${item.quantity} ${item.unit ?? ''} × ₹${item.unitPrice.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${item.totalPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.type ?? 'Expense',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          
                          const SizedBox(height: 20),
                          
                          // Notes
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: _buildInputDecoration('Notes (Optional)', Icons.note),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Total Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green.shade50, Colors.green.shade100],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade200.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Amount',
                                      style: TextStyle(fontSize: 14, color: Colors.black54),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_calculateTotal().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.receipt,
                                    color: Colors.green.shade800,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Discard'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: _isSavingNotifier,
                                  builder: (context, isLoading, child) {
                                    return ElevatedButton(
                                      onPressed: isLoading ? null : () => _saveInvoiceFromForm(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade800,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        disabledBackgroundColor: Colors.grey.shade400,
                                      ),
                                      child: isLoading
                                          ? const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text('Saving...'),
                                              ],
                                            )
                                          : const Text(
                                              'Save Invoice',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper for consistent styling
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.green.shade700),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.green.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }

  // Color helpers
  Color _getTypeColor() {
    switch (_expenseType) {
      case 'Expense':
        return Colors.blue;
      case 'Consumption':
        return Colors.green;
      case 'Wastage':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getTypeLabel() {
    switch (_expenseType) {
      case 'Expense':
        return 'EXPENSE';
      case 'Consumption':
        return 'CONSUMPTION';
      case 'Wastage':
        return 'WASTAGE';
      default:
        return 'SELL';
    }
  }

  String _getTitleLabel() {
    switch (_expenseType) {
      case 'Expense':
        return 'Expense Title';
      case 'Consumption':
        return 'Inventory Item';
      case 'Wastage':
        return 'Wastage Item';
      default:
        return 'Menu Item';
    }
  }

  String _getHintText() {
    switch (_expenseType) {
      case 'Expense':
        return 'Search expenses...';
      case 'Consumption':
        return 'Search inventory...';
      case 'Wastage':
        return 'Search items...';
      default:
        return 'Search menu...';
    }
  }

  IconData _getTitleIcon() {
    switch (_expenseType) {
      case 'Expense':
        return Icons.receipt;
      case 'Consumption':
        return Icons.inventory;
      case 'Wastage':
        return Icons.warning;
      default:
        return Icons.restaurant_menu;
    }
  }

  // Auto-fill fields based on selection
  void _autoFillBasedOnSelection(String selection, StateSetter setModalState) {
    final matchingExpenses = _expenses.where((e) => e.title == selection).toList();
    
    if (matchingExpenses.isNotEmpty) {
      final expense = matchingExpenses.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setModalState(() {
          _supplierController.text = expense.supplierName ?? "";
          _amountController.text = (expense.amount ?? 0).toString();
          _qtyController.text = (expense.quantity ?? 0).toString();
          _descriptionController.text = expense.description ?? "";
          _recivedAmountController.text = (expense.receivedAmount ?? 0).toString();
          _unitController.text = expense.unit ?? 'unit';
          _selectedPaymentMethod = expense.paymentMethod ?? 'Cash';
          _selectedUnit = expense.unit ?? 'unit';
          _selectedCategory = expense.category ?? 'Food';
        });
      });
    } else {
      if (_expenseType == 'Consumption' || _expenseType == 'Wastage') {
        _autoFillFromInventory(selection, setModalState);
      } else if (_expenseType == 'Expense') {
        // Already handled above
      } else {
        _autoFillFromMenu(selection, setModalState);
      }
    }
  }

  void _autoFillFromInventory(String selection, StateSetter setModalState) {
    try {
      final box = _store.box<InventoryItem>();
      final query = box.query(InventoryItem_.name.equals(selection)).build();
      final items = query.find();
      query.close();
      
      if (items.isNotEmpty) {
        final item = items.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setModalState(() {
            _selectedUnit = item.unit;
          });
        });
      }
    } catch (e) {
      print_log_red('Error auto-filling inventory: $e');
    }
  }

  void _autoFillFromMenu(String selection, StateSetter setModalState) {
    try {
      final box = _store.box<MenuItem>();
      final query = box.query(MenuItem_.name.equals(selection)).build();
      final items = query.find();
      query.close();
      
      if (items.isNotEmpty) {
        final item = items.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setModalState(() {
            _amountController.text = (item.f_price ?? 0).toString();
          });
        });
      }
    } catch (e) {
      print_log_red('Error auto-filling menu: $e');
    }
  }

  // Get details for existing expense
  Widget? _getExpenseDetails(String title) {
    final matchingExpenses = _expenses.where((e) => e.title == title).toList();
    if (matchingExpenses.isNotEmpty) {
      final expense = matchingExpenses.first;
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Last: ₹${expense.amount} • ${expense.category}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      );
    }
    return null;
  }

  // Build selected item info
  Widget _buildSelectedItemInfo() {
    if (_expenseType == 'Consumption' || (_expenseType == 'Wastage' && _inventoryItemNames.contains(_titleController.text))) {
      return FutureBuilder<InventoryItem?>(
        future: _getInventoryItemByName(_titleController.text),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final item = snapshot.data!;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Stock: ${item.stockQuantity} ${item.unit} • ${item.category ?? 'No Category'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    } else if (_expenseType == 'Expense') {
      final recentExpenses = _expenses.where((e) => e.title == _titleController.text).toList();
      if (recentExpenses.isNotEmpty) {
        final expense = recentExpenses.first;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous: ₹${expense.amount}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Category: ${expense.category}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    } else if (_expenseType == 'Sell' || (_expenseType == 'Wastage' && _menuItemNames.contains(_titleController.text))) {
      return FutureBuilder<MenuItem?>(
        future: _getMenuItemByName(_titleController.text),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final item = snapshot.data!;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.restaurant, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Stock: ${item.adjustStock ?? 0} • Price: ₹${item.h_price ?? 0} • ${item.category}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }
    return const SizedBox.shrink();
  }

  // Helper methods to get items by name
  Future<InventoryItem?> _getInventoryItemByName(String name) async {
    try {
      final box = _store.box<InventoryItem>();
      final query = box.query(InventoryItem_.name.equals(name)).build();
      final items = query.find();
      query.close();
      return items.isNotEmpty ? items.first : null;
    } catch (e) {
      print_log_red('Error finding inventory item: $e');
      return null;
    }
  }

  Future<MenuItem?> _getMenuItemByName(String name) async {
    try {
      final box = _store.box<MenuItem>();
      final query = box.query(MenuItem_.name.equals(name)).build();
      final items = query.find();
      query.close();
      return items.isNotEmpty ? items.first : null;
    } catch (e) {
      print_log_red('Error finding menu item: $e');
      return null;
    }
  }

  // Stock management methods
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
          case 'add':
            item.stockQuantity += quantity;
            break;
        }
        
        await box.putAsync(item);
        print_log('Inventory updated: ${item.name} - New stock: ${item.stockQuantity} ${item.unit}');
        
        if (item.stockQuantity < 10) {
          _showLowStockWarning(item);
        }
      } else {
        throw Exception('Item "$itemName" not found in inventory');
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
            item.adjustStock = (item.adjustStock ?? 0) - quantity.toInt();
            break;
          case 'Wastage':
            item.adjustStock = (item.adjustStock ?? 0) - quantity.toInt();
            break;
          case 'add':
            item.adjustStock = (item.adjustStock ?? 0) + quantity.toInt();
            break;
        }
        
        await box.putAsync(item);
        print_log('Menu item updated: ${item.name} - New stock: ${item.adjustStock}');
      } else {
        throw Exception('Item "$itemName" not found in menu');
      }
    } catch (e) {
      print_log_red('Error updating menu item: $e');
      rethrow;
    }
  }

  void _showLowStockWarning(dynamic item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ Low stock: ${item.name} (${item.stockQuantity ?? item.adjustStock ?? 0} ${item.unit ?? 'pcs'})',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // In the optionsViewBuilder of your autocomplete, enhance the item display
  Widget? _getInventoryItemDetails(String itemName) {
    try {
      final box = _store.box<InventoryItem>();
      final query = box.query(InventoryItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();
      
      if (items.isNotEmpty) {
        final item = items.first;
        final isLowStock = item.stockQuantity < 10;
        final stockColor = isLowStock ? Colors.red : Colors.green;
        
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: stockColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Stock: ${item.stockQuantity} ${item.unit} • ${item.category ?? 'No Category'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLowStock ? Colors.red : Colors.grey.shade600,
                    fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print_log_red('Error getting inventory details: $e');
    }
    return null;
  }

  Widget? _getMenuItemDetails(String itemName) {
    try {
      final box = _store.box<MenuItem>();
      final query = box.query(MenuItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();
      
      if (items.isNotEmpty) {
        final item = items.first;
        final available = item.adjustStock ?? 0;
        final isLowStock = available < 5;
        final stockColor = isLowStock ? Colors.red : Colors.green;
        
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: stockColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Stock: $available • ₹${item.sellPrice} • ${item.category}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLowStock ? Colors.red : Colors.grey.shade600,
                    fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print_log_red('Error getting menu details: $e');
    }
    return null;
  }

  // Helper method to get color based on item type
  Color _getTypeColorForItem(String itemName, String itemType) {
    if (_expenseType == 'Wastage') {
      if (itemType == 'Inventory') {
        return Colors.green;
      } else if (itemType == 'Menu Item') {
        return Colors.orange;
      }
    }
    return _getTypeColor();
  }

  // Helper method to get icon based on item type
  IconData _getIconForItemType(String itemType) {
    switch (itemType) {
      case 'Inventory':
        return Icons.inventory;
      case 'Menu Item':
        return Icons.restaurant_menu;
      default:
        return Icons.receipt;
    }
  }

  // Data loading methods
  Future<void> _loadSuppliers() async {
    try {
      final box = _store.box<Supplier>();
      final allSuppliers = box.getAll();
      setState(() {
        _suppliers = allSuppliers;
        _supplierNames = allSuppliers.map((s) => s.supplierName).toList();
      });
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
      
      setState(() {
        _expenseTitles = titles.toList()..sort();
      });
    } catch (e) {
      print_log_red('Error loading expense titles: $e');
    }
  }

  Future<void> _loadInventoryItems() async {
    try {
      final box = _store.box<InventoryItem>();
      final items = box.getAll();
      setState(() {
        _inventoryItemNames = items.map((item) => item.name).toList()..sort();
      });
    } catch (e) {
      print_log_red('Error loading inventory items: $e');
    }
  }

  Future<void> _loadMenuItems() async {
    try {
      final box = _store.box<MenuItem>();
      final items = box.getAll();
      setState(() {
        _menuItemNames = items.map((item) => item.name).toList()..sort();
      });
    } catch (e) {
      print_log_red('Error loading menu items: $e');
    }
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList('expense_categories');
    if (savedCategories != null && savedCategories.isNotEmpty) {
      setState(() {
        _categories = savedCategories;
        if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  // Future<void> _saveCategories() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setStringList('expense_categories', _categories);
  // }

  // ---------- Persistence ----------
  Future<void> _loadExpenses() async {
    try {
      _selectedDate = AppConstants.businessDate ?? DateTime.now();
      final box = _store.box<expences>();
      // final prefs = await SharedPreferences.getInstance();
      final loadedExpenses = <Expense>[];

      // Load from ObjectBox
      final expensesJson = box.getAll();
      for (final s in expensesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(s.expence));
          loadedExpenses.add(Expense.fromMap(map));
        } catch (e) {
          print_log_red('Skipping malformed expense entry: $e');
        }
      }

      loadedExpenses.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _expenses.clear();
        _expenses.addAll(loadedExpenses);
      });
    } catch (e) {
      print_log('Error loading expenses: $e');
    }
  }

  // SAVE OR UPDATE
  Future<void> syncExpenseToCloud(int id, Expense expense, String hotelName,Box<expences> box) async {
    final prefs = await SharedPreferences.getInstance();
    final apicall = await prefs.getString("adminPanel") ?? "no";
    bool demo = prefs.getBool('demo') ?? false;   
    
    if (apicall.toLowerCase().contains("no") || demo) {
      print_log("❌ in settel transection adminPanel not yes so Not send transection to the sever $apicall");
      return;
    }
    try {
      final payload = {
          'login_user': hotelName,
          'id': expense.id.toString(), // External ID
          'amount': expense.amount,
          'date': expense.date.toIso8601String(),
          'expense_data': expense.toMap(), // Full JSON blob
        };
      http.Response? response = await apiCalls("ex_save", hotelName, payload);
      if (response == null) {
        
        return;
      }

      if (response.statusCode == 200) {
        final Expensetoupdate =  box.get(id);
          if (Expensetoupdate != null) {
            // //debugPrint('Settling ${tx['tableNo']} with $selectedPayment',);
            Expensetoupdate.synced = true;
            box.put(Expensetoupdate);
            print_log("Cloud Sync Successful ${response.toString()}");
          }
      }
    } catch (e) {
      print_log_red("Sync Error: $e");
    }
  }

  // DELETE
  Future<void> deleteExpenseFromCloud(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final apicall = await prefs.getString("adminPanel") ?? "no";
    try {
      if (apicall.toLowerCase().contains("no")) {
        return;
      }
      final hotelName = await prefs.getString(AppConstants.usernameKey) ?? "";
      await apiCalls("ex_delete", hotelName, {}, id: id);
    } catch (e) {
      print_log_red("error in deleteExpenseFromCloud $e");
    }
  }

  void _saveExpense() async {
    if (_isSavingNotifier.value) return;
    if (!_formKey.currentState!.validate()) return;
    
    _isSavingNotifier.value = true;
    
    try {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an item'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (_expenseType == 'Wastage') {
          bool? confirm = await showDialog<bool>(
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
          
          if (confirm != true) return;
        }
      }

      // Create expense object
      final newExpense = Expense(
        id: ganarateID().toString(),
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

      // Update stock based on expense type
      if (quantity > 0) {
        if (_expenseType == 'Consumption') {
          await _updateInventoryStock(_titleController.text, quantity, _expenseType);
        } else if (_expenseType == 'Wastage') {
          if (_inventoryItemNames.contains(_titleController.text)) {
            await _updateInventoryStock(_titleController.text, quantity, _expenseType);
          } else if (_menuItemNames.contains(_titleController.text)) {
            await _updateMenuItemStock(_titleController.text, quantity, _expenseType);
          }
        } else if (_expenseType == 'Sell') {
          await _updateMenuItemStock(_titleController.text, quantity, _expenseType);
        }
      }

      // Add to items list for invoice
      final purchaseItem = PurchaseItem(
        name: newExpense.title,
        quantity: newExpense.quantity ?? 0,
        unitPrice: newExpense.amount / (newExpense.quantity ?? 1),
        totalPrice: newExpense.amount,
        unit: newExpense.unit,
        type: newExpense.expenseType,
      );
      
      _items.add(purchaseItem);
      
      // Clear form
      _clearExpenseForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${newExpense.title}" added to invoice'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isSavingNotifier.value = false;
    }
  }

  void _clearExpenseForm() {
    _titleController.clear();
    _amountController.clear();
    _qtyController.clear();
    _descriptionController.clear();
    _recivedAmountController.clear();
    _unitController.clear();
    _supplierController.clear();
    _selectedUnit = 'unit';
    _selectedPaymentMethod = 'Cash';
    _expenseType = 'Expense';
    _selectedCategory = 'Food';
  }

  void _showAddCategoryDialog(StateSetter setModalState) {
    final TextEditingController categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(hintText: 'Category Name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCategory = categoryController.text.trim();
              if (newCategory.isNotEmpty && !_categories.contains(newCategory)) {
                setState(() {
                  _categories.add(newCategory);
                  _selectedCategory = newCategory;
                });
                _saveCategories();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setModalState(() {
                    _selectedCategory = newCategory;
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
    
  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('expense_categories', _categories);
  }

  // Add update method
  void _updateExpense(String expenseId) {
    if (!_formKey.currentState!.validate()) return;

    double? receivedAmount;
    if (_selectedPaymentMethod == 'Credit' && _recivedAmountController.text.isNotEmpty) {
      receivedAmount = double.tryParse(_recivedAmountController.text);
    }

    final updatedExpense = Expense(
      id: expenseId,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      category: _selectedCategory,
      photoPath: _imagePath,
      supplierName: _supplierController.text.isNotEmpty ? _supplierController.text.trim() : null,
      quantity: _qtyController.text.isNotEmpty ? double.tryParse(_qtyController.text) : null,
      unit: _selectedUnit != 'unit' ? _selectedUnit : null,
      paymentMethod: _selectedPaymentMethod,
      receivedAmount: receivedAmount,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : null,
      expenseType: _expenseType,
    );

    // Update in list
    final index = _expenses.indexWhere((e) => e.id == expenseId);
    if (index != -1) {
      setState(() {
        _expenses[index] = updatedExpense;
      });
    }

    // Update in database
    _updateExpenseInDatabase(updatedExpense);
    
    _clearForm();
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${updatedExpense.title}" updated successfully!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Add method to update in database
  Future<void> _updateExpenseInDatabase(Expense expense) async {
    try {
      final box = _store.box<expences>();
      final allExpenses = box.getAll();
      
      for (final entity in allExpenses) {
        final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
        if (map['id'].toString() == expense.id) {
          entity.expence = jsonEncode(expense.toMap());
          await box.putAsync(entity);
          
          // Sync with cloud
          final prefs = await SharedPreferences.getInstance();
          final hotelName = await prefs.getString(AppConstants.usernameKey) ?? "";
          await syncExpenseToCloud(entity.id, expense, hotelName,box);
          
          print_log('Expense updated: ${expense.id}');
          break;
        }
      }
    } catch (e) {
      print_log_red('Error updating expense: $e');
    }
  }

  /// ---------- Add new expense ----------
  void _addNewExpense(Expense? expense) {
    _clearForm();
    _recivedAmountController.text = "0.0";
    if(expense != null){
        // Pre-fill the form with existing expense data
      _titleController.text = expense.title;
      _amountController.text = expense.amount.toString();
      _selectedDate = expense.date;
      _selectedCategory = expense.category;
      _imagePath = expense.photoPath;
      if (expense.photoPath != null && File(expense.photoPath!).existsSync()) {
        _selectedImage = File(expense.photoPath!);
      } else {
        _selectedImage = null;
      }
      
      // Pre-fill new fields
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
      _selectedUnit = 'unit';
      if(mounted){
        setState(() {
          
        });
      }
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        'Add New Expense',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // TOP SECTION: Image (Left) | Camera/Gallery & Date (Right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Photo Preview
                          // SizedBox(
                          //   width: 120,
                          //   height: 100,
                          //   child: _buildPhotoUploadSection(), 
                          // ),
                          // const SizedBox(width: 8),
                          
                          // Right: Controls & Date
                          Expanded(
                            child: Column(
                              children: [
                                // Date Picker Styled Input
                                // InkWell(
                                //   onTap: () async {
                                //     final picked = await showDatePicker(
                                //       context: context,
                                //       initialDate: _selectedDate,
                                //       firstDate: DateTime(2024),
                                //       lastDate: DateTime.now(),
                                //     );
                                //     if (picked != null) {
                                //       setModalState(() => _selectedDate = picked);
                                //       setState(() => _selectedDate = picked);
                                //     }
                                //   },
                                //   child: InputDecorator(
                                //     decoration: _buildInputDecoration('Expense Date', Icons.calendar_today),
                                //     child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                                //   ),
                                // ),
                                // const SizedBox(height: 12),
                                // You mentioned Camera/Gallery on right - 
                                // usually these are buttons inside your _buildPhotoUploadSection,
                                // but if you want them separate as buttons:
                                // Row(
                                //   children: [
                                //     Expanded(
                                //       child: ElevatedButton(
                                //         onPressed: () async {
                                //           await _takePhotoFromCamera();
                                //           setState(() {});
                                //         }, // Trigger Camera
                                //         style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800, elevation: 0),
                                //         child: const Icon(Icons.camera_alt),
                                //       ),
                                //     ),
                                //     const SizedBox(width: 8),
                                //     Expanded(
                                //       child: ElevatedButton(
                                //         onPressed: () async {
                                //           await _pickPhotoFromGallery();
                                //           setState(() {});
                                //         }, // Trigger Gallery
                                //         style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800, elevation: 0),
                                //         child: const Icon(Icons.photo_library),
                                //       ),
                                //     ),
                                //     if (_selectedImage != null)
                                //       Expanded(
                                //         child: ElevatedButton(
                                //           onPressed: () async {
                                //             _removePhoto();
                                //               setState(() {});
                                //           }, // Trigger Gallery
                                //           style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800, elevation: 0),
                                //           child: const Icon(Icons.remove),
                                //       ),
                                //     ),
                                //   ],
                                // )
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // 2. Selection Type: Consumption vs Expense
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text("Expense")),
                                  selected: _expenseType == 'Expense',
                                  selectedColor: Colors.blue.shade100,
                                  onSelected: (bool selected) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setModalState(() {
                                      _expenseType = 'Expense';
                                      _titleController.clear(); // Clear when switching types
                                    });
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text("Consumption")),
                                  selected: _expenseType == 'Consumption',
                                  selectedColor: Colors.green.shade100,
                                  onSelected: (bool selected) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setModalState(() {
                                      _expenseType = 'Consumption';
                                      _titleController.clear(); // Clear when switching types
                                    });
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text("Sell Item")),
                                  selected: _expenseType == 'Sell',
                                  selectedColor: Colors.orange.shade100,
                                  onSelected: (bool selected) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setModalState(() {
                                      _expenseType = 'Sell';
                                      _titleController.clear(); // Clear when switching types
                                    });
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text("Wastage")),
                                  selected: _expenseType == 'Wastage',
                                  selectedColor: Colors.red.shade100,
                                  onSelected: (bool selected) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setModalState(() {
                                      _expenseType = 'Wastage';
                                      _titleController.clear(); // Clear when switching types
                                    });
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Selection Titel 
                      Row(
                        children: [
                          Expanded(
                            child:  Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getTypeColor(),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getTypeLabel(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _getTitleLabel(),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                RawAutocomplete<String>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    
                                    // Get suggestions based on expense type
                                    List<String> suggestions = [];
                                    if (_expenseType == 'Expense') {
                                      suggestions = _expenseTitles;
                                    } else if (_expenseType == 'Consumption') {
                                      suggestions = _inventoryItemNames;
                                    } else if (_expenseType == 'Sell') {
                                      // For sell items (you can add another type)
                                      suggestions = _menuItemNames;
                                    } else{
                                      // For sell items (you can add another type)
                                      suggestions = [..._inventoryItemNames, ..._menuItemNames];
                                    }
                                    
                                    return suggestions.where((item) => item.toLowerCase().contains(textEditingValue.text.toLowerCase())).take(10);

                                  },
                                  onSelected: (String selection) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      setModalState(() {
                                        _titleController.text = selection;
                                        // _titleFocusNode.unfocus();
                                        _autoFillBasedOnSelection(selection, setModalState);
                                        // Focus on amount field after a short delay
                                        // Future.delayed(const Duration(milliseconds: 200), () {
                                        //   FocusScope.of(context).requestFocus(_amountFocusNode);
                                        // });
                                        
                                      });
                                    });
                                  },
                                  
                                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                    textEditingController.text = _titleController.text;
                                    });
                                    
                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      onChanged: (value) {
                                        _titleController.text = value;
                                      },
                                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                      onEditingComplete: () {
                                        // Hide keyboard and suggestions when editing is complete
                                        focusNode.unfocus();
                                      },
                                      decoration: InputDecoration(
                                        hintText: _getHintText(),
                                        prefixIcon: Icon(
                                          _getTitleIcon(),
                                          color: Colors.blue.shade700,
                                        ),
                                        suffixIcon: _titleController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () {
                                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                                    setModalState(() {
                                                      _titleController.clear();
                                                      textEditingController.clear();
                                                    });
                                                  });
                                                },
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: Colors.blue.shade50.withValues(alpha:0.3),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.blue.shade100),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade200),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    );

                                  },
                                  optionsViewBuilder: (BuildContext context, 
                                    AutocompleteOnSelected<String> onSelected, 
                                  Iterable<String> options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4.0,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: MediaQuery.of(context).size.width * 0.8,
                                        constraints: const BoxConstraints(maxHeight: 250),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withValues(alpha:0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListView.separated(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          shrinkWrap: true,
                                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = options.elementAt(index);
                                            
                                            // Determine the type of item for wastage
                                            String itemType = '';
                                            Widget? subtitle;
                                            
                                            if (_expenseType == 'Wastage') {
                                              // Check if it's an inventory item
                                              if (_inventoryItemNames.contains(option)) {
                                                itemType = 'Inventory';
                                                subtitle = _getInventoryItemDetails(option);
                                              } else if (_menuItemNames.contains(option)) {
                                                itemType = 'Menu Item';
                                                subtitle = _getMenuItemDetails(option);
                                              }
                                            } else {
                                              // For other types, use existing logic
                                              if (_expenseType == 'Consumption') {
                                                subtitle = _getInventoryItemDetails(option);
                                              } else if (_expenseType == 'Sell') {
                                                subtitle = _getMenuItemDetails(option);
                                              } else if (_expenseType == 'Expense') {
                                                subtitle = _getExpenseDetails(option);
                                              }
                                            }
                                            
                                            return ListTile(
                                              leading: CircleAvatar(
                                                radius: 16,
                                                backgroundColor: _getTypeColorForItem(option, itemType).withValues(alpha:0.2),
                                                child: Icon(
                                                  _getIconForItemType(itemType),
                                                  size: 16,
                                                  color: _getTypeColorForItem(option, itemType),
                                                ),
                                              ),
                                              title: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      option,
                                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                  if (itemType.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: _getTypeColorForItem(option, itemType).withValues(alpha:0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        itemType,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: _getTypeColorForItem(option, itemType),
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              subtitle: subtitle,
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                ),
                                
                                // Show additional info if an item is selected
                                if (_titleController.text.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildSelectedItemInfo(),
                                ],
                              ],
                            ),
                                          
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.add_business, color: Colors.green.shade700),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const InventoryPage()),
                                );
                                if (mounted) {
                                  setModalState(() {
                                    _loadInventoryItems();
                                  });
                                }
                              },
                              tooltip: 'View Inventory',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Amount & Payment Method Section
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start, // Keeps items aligned at top
                            children: [
                              // 1. Total Amount
                              Expanded(
                                flex: 2, // Give Amount slightly more room
                                child: TextFormField(
                                  controller: _amountController,
                                  decoration: _buildInputDecoration('Total Amount', Icons.account_balance_wallet),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // 2. Payment Method
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPaymentMethod,
                                  decoration: _buildInputDecoration('Payment', Icons.payments),
                                  items: ['Cash', 'Online', 'Card', 'Credit']
                                      .map((m) => DropdownMenuItem(
                                            value: m, 
                                            child: Text(m, style: const TextStyle(fontSize: 12)) // Slightly smaller font
                                          ))
                                      .toList(),
                                  onChanged: (v) => setModalState(() => _selectedPaymentMethod = v!),
                                ),
                              ),
                            ],
                          ),
                          
                          // 3. Show Received Amount below if Credit is selected
                          if (_selectedPaymentMethod == 'Credit') ...[
                          const SizedBox(height: 12),
                          
                          // Row for Received Amount and Due Date
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Received Amount Field
                              Expanded(
                                flex: 6,
                                child: TextFormField(
                                  controller: _recivedAmountController,
                                  onTap: () {
                                    if (_recivedAmountController.text == '0') {
                                      _recivedAmountController.clear();
                                    }
                                  },
                                  onChanged: (value) {
                                    setState(() {}); // Update UI for remaining amount
                                  },
                                  decoration: _buildInputDecoration('Received Amount', Icons.payments,),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Required';
                                    }
                                    if (double.tryParse(v) == null) {
                                      return 'Invalid amount';
                                    }
                                    return null;
                                  },
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Due Date Field
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: _dueDateController,
                                  readOnly: true,
                                  onTap: () => _selectDueDate(context),
                                  decoration: InputDecoration(
                                        labelText: "Due Date",
                                        filled: true,
                                        fillColor: Colors.blue.shade50.withOpacity(0.3),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.blue.shade100),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade200),
                                        ),
                                      ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Select due date' : null,
                                ),
                              ),
                            ],
                          ),
                          
                          // Remaining amount info
                          if (_recivedAmountController.text.isNotEmpty && 
                              double.tryParse(_recivedAmountController.text) != null &&
                              double.tryParse(_recivedAmountController.text) != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Remaining: ₹ ${((double.tryParse(_amountController.text)??0.0) - (double.tryParse(_recivedAmountController.text) ?? 0.0)).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Qty & unit Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _qtyController,
                              decoration: _buildInputDecoration('Quantity', Icons.production_quantity_limits),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              // Use the String variable here, NOT the controller
                              value: _selectedUnit, 
                              decoration: _buildInputDecoration('unit', Icons.straighten),
                              items: units
                                  .map((u) => DropdownMenuItem(
                                        value: u, 
                                        child: Text(u, style: const TextStyle(fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                setModalState(() {
                                  _selectedUnit = v!;
                                });
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // After the supplier autocomplete field, add a quick add button
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Supplier Input with Autocomplete
                                RawAutocomplete<String>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    // Filter supplier names based on input
                                    return _supplierNames.where(
                                      (supplier) => supplier.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                    ).take(10); // Limit to 10 suggestions
                                  },
                                  onSelected: (String selection) {
                                    // When a supplier is selected, find and set the full supplier
                                    final selectedSupplier = _suppliers.firstWhere(
                                      (s) => s.supplierName == selection,
                                      orElse: () => Supplier(syid:ganarateID(), supplierName: selection),
                                    );
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      setModalState(() {
                                        _supplierController.text = selection;
                                        _supplierMobileController.text = selectedSupplier.mobileNumber ?? '';
                                      });
                                      
                                    });
                                    
                                    // Optional: Show supplier details in a snackbar
                                    if (selectedSupplier.mobileNumber != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Supplier: ${selectedSupplier.supplierName}\nMobile: ${selectedSupplier.mobileNumber}'),
                                          duration: const Duration(seconds: 2),
                                          backgroundColor: Colors.blue,
                                        ),
                                      );
                                    }
                                  },
                                  fieldViewBuilder: (BuildContext context,TextEditingController textEditingController,FocusNode focusNode,VoidCallback onFieldSubmitted) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      textEditingController.text = _supplierController.text;
                                    });
                                    
                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      validator: (value) {
                                        if (_selectedPaymentMethod == 'Credit') {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Supplier is required for credit';
                                          }
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        // Update the main controller
                                        _supplierController.text = value;
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Select Supplier',
                                        prefixIcon: Icon(Icons.person_search, color: Colors.blue.shade700),
                                        suffixIcon: _supplierController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () {
                                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                                    setModalState(() {
                                                      _supplierController.clear();
                                                      textEditingController.clear();
                                                    });
                                                  });
                                                },
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: Colors.blue.shade50.withOpacity(0.3),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.blue.shade100),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade200),
                                        ),
                                      ),
                                    );
                                  },
                                  optionsViewBuilder: (BuildContext context, 
                                      AutocompleteOnSelected<String> onSelected, 
                                      Iterable<String> options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4.0,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: MediaQuery.of(context).size.width * 0.8,
                                          constraints: const BoxConstraints(maxHeight: 200),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ListView.separated(
                                            padding: EdgeInsets.zero,
                                            itemCount: options.length,
                                            shrinkWrap: true,
                                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                            itemBuilder: (BuildContext context, int index) {
                                              final option = options.elementAt(index);
                                              final supplier = _suppliers.firstWhere(
                                                (s) => s.supplierName == option,
                                                orElse: () => Supplier(syid:ganarateID(), supplierName: option),
                                              );
                                              
                                              return ListTile(
                                                leading: CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: Colors.blue.shade100,
                                                  child: Text(
                                                    option.isNotEmpty ? option[0].toUpperCase() : '?',
                                                    style: TextStyle(
                                                      color: Colors.blue.shade800,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  option,
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                ),
                                                subtitle: supplier.mobileNumber != null
                                                    ? Text(
                                                        supplier.mobileNumber!,
                                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                      )
                                                    : null,
                                                onTap: () {
                                                  onSelected(option);
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.add_business, color: Colors.green.shade700),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PartyListPage()),
                                );
                                if (mounted) {
                                  setModalState(() {
                                    _loadSuppliers();
                                  });
                                }
                              },
                              tooltip: 'View Suppliers',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      // Category with Add Button
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
                              decoration: _buildInputDecoration('Category', Icons.category),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) {
                                setModalState(() => _selectedCategory = v ?? _categories.first);
                                setState(() => _selectedCategory = v ?? _categories.first);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blue),
                            onPressed: () => _showAddCategoryDialog(setModalState),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        controller: _descriptionController, // Ensure this controller exists
                        maxLines: 2,
                        decoration: _buildInputDecoration('Description / Notes', Icons.description),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // In your button
                          Expanded(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isSavingNotifier,
                              builder: (context, isLoading, child) {
                                return ElevatedButton(
                                  onPressed: isLoading 
                                      ? null 
                                      : (expense != null ? () => _updateExpense(expense.id) : _saveExpense),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    disabledBackgroundColor: Colors.grey.shade400,
                                  ),
                                  child: Text(
                                    isLoading 
                                        ? 'Saving...' 
                                        : (expense != null ? 'Update Expense' : 'Save Expense'),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
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
      },
    );
  }

  Widget _buildTypeChip(String type, Color color, StateSetter setModalState) {
    return ChoiceChip(
      label: Text(type),
      selected: _expenseType == type,
      selectedColor: color.withOpacity(0.2),
      onSelected: (selected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setModalState(() {
            _expenseType = type;
            _titleController.clear();
          });
        });
      },
    );
  }

  Widget _buildPhotoUploadSection(StateSetter setModalState) {
    return GestureDetector(
      onTap: () => _showImagePickerOptions(setModalState),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: _selectedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: () {
                          setModalState(() {
                            if (_imagePath != null) {
                              removeFileFromExternalStorage(_imagePath!);
                            }
                            _selectedImage = null;
                            _imagePath = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload, size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 4),
                  Text(
                    'Add Photo',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
      ),
    );
  }

  void _showImagePickerOptions(StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                  maxWidth: 800,
                );
                // if (image != null) {
                //   final path = await saveImageInternalStorage(image.path, 'purchase_invoices');
                //   if (path != null && mounted) {
                //     setModalState(() {
                //       _selectedImage = File(path);
                //       _imagePath = path;
                //     });
                //   }
                // }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                  maxWidth: 800,
                );
                // if (image != null) {
                //   final path = await saveImageInternalStorage(image.path, 'purchase_invoices');
                //   if (path != null && mounted) {
                //     setModalState(() {
                //       _selectedImage = File(path);
                //       _imagePath = path;
                //     });
                //   }
                // }
              },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setModalState(() {
                    if (_imagePath != null) {
                      removeFileFromExternalStorage(_imagePath!);
                    }
                    _selectedImage = null;
                    _imagePath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _saveInvoiceFromForm(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }

    _isSavingNotifier.value = true;

    final invoice = PurchaseInvoice(
      id: ganarateID().toString(),
      invoiceNumber: _invoiceNumberController.text.trim(),
      supplierName: _supplierController.text.trim(),
      totalAmount: _calculateTotal(),
      date: _selectedDate,
      photoPath: _imagePath,
      items: List.from(_items),
      notes: _notesController.text.isNotEmpty ? _notesController.text.trim() : null,
      paymentStatus: _selectedStatus,
      dueDate: _dueDate,
    );

    _saveInvoice(invoice).then((_) {
      _isSavingNotifier.value = false;
      Navigator.pop(context);
    }).catchError((error) {
      _isSavingNotifier.value = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    });
  }

  double _calculateTotal() {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void _showInvoiceDetails(PurchaseInvoice invoice) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invoice Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                
                if (invoice.photoPath != null && File(invoice.photoPath!).existsSync())
                  Center(
                    child: GestureDetector(
                      onTap: () => _showImage(invoice.photoPath!),
                      child: Container(
                        width: 200,
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(invoice.photoPath!), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                
                _buildDetailRow('Invoice #:', invoice.invoiceNumber),
                _buildDetailRow('Supplier:', invoice.supplierName),
                _buildDetailRow('Date:', DateFormat('dd/MM/yyyy').format(invoice.date)),
                _buildDetailRow('Status:', invoice.paymentStatus.toString().split('.').last,
                  color: invoice.paymentStatus == PaymentStatus.paid 
                      ? Colors.green 
                      : invoice.paymentStatus == PaymentStatus.overdue 
                          ? Colors.red 
                          : Colors.orange,
                ),
                if (invoice.dueDate != null)
                  _buildDetailRow('Due Date:', DateFormat('dd/MM/yyyy').format(invoice.dueDate!)),
                
                const SizedBox(height: 15),
                const Text(
                  'Items:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...invoice.items.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.name} (${item.quantity} ${item.unit ?? ''})',
                        ),
                      ),
                      Text('₹${item.totalPrice.toStringAsFixed(2)}'),
                    ],
                  ),
                )),
                
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${invoice.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                
                if (invoice.notes != null) ...[
                  const SizedBox(height: 15),
                  const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(invoice.notes!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  void _showImage(String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSummaryDialog() {
    final pendingInvoices = _invoices.where((inv) => 
        inv.paymentStatus == PaymentStatus.pending).toList();
    final overdueInvoices = _invoices.where((inv) => 
        inv.paymentStatus == PaymentStatus.overdue).toList();
    final paidInvoices = _invoices.where((inv) => 
        inv.paymentStatus == PaymentStatus.paid).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Summary'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryStat('Total Invoices', _invoices.length.toString()),
              _buildSummaryStat('Total Amount', '₹${_totalPurchases.toStringAsFixed(2)}'),
              _buildSummaryStat('Paid', '₹${paidInvoices.fold(0.0, (s, i) => s + i.totalAmount).toStringAsFixed(2)}'),
              _buildSummaryStat('Pending', '₹${pendingInvoices.fold(0.0, (s, i) => s + i.totalAmount).toStringAsFixed(2)}'),
              _buildSummaryStat('Overdue', '₹${overdueInvoices.fold(0.0, (s, i) => s + i.totalAmount).toStringAsFixed(2)}'),
              const SizedBox(height: 10),
              const Text('Pending Invoices:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...pendingInvoices.take(5).map((inv) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(inv.invoiceNumber),
                      Text('₹${inv.totalAmount.toStringAsFixed(2)}'),
                    ],
                  ),
                )
              ),
              if (overdueInvoices.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Overdue Invoices:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ...overdueInvoices.take(5).map((inv) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(inv.invoiceNumber, style: const TextStyle(color: Colors.red)),
                        Text('₹${inv.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  )
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _clearForm() {
    _invoiceNumberController.clear();
    _supplierController.clear();
    _notesController.clear();
    _items.clear();
    _selectedDate = DateTime.now();
    _selectedStatus = PaymentStatus.pending;
    _dueDate = null;
    _selectedImage = null;
    _imagePath = null;
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _qtyController.dispose();
    _descriptionController.dispose();
    _recivedAmountController.dispose();
    _unitController.dispose();
    _dueDateController.dispose();
    _supplierMobileController.dispose();
    _titleFocusNode.dispose();
    _amountFocusNode.dispose();
    _supplierFocusNode.dispose();
    _qtyFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _isSavingNotifier.dispose();
    super.dispose();
  }
}