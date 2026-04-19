// lib/purchase_order/add_edit_purchase_order_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:test1/database_Module/supplier_database.dart';
import 'package:test1/database_Module/cunsuption.dart';
import 'package:test1/database_Module/menu_item.dart';
import 'package:test1/database_Module/purchase_order_database.dart';
import 'package:test1/utilities.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../objectbox.g.dart';
import 'purchase_order_model.dart';
import 'purchase_order_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:test1/theme_setting/theme_provider.dart';

class AddEditPurchaseOrderPage extends StatefulWidget {
  final PurchaseOrder? order;

  const AddEditPurchaseOrderPage({super.key, this.order});

  @override
  State<AddEditPurchaseOrderPage> createState() => _AddEditPurchaseOrderPageState();
}

class _AddEditPurchaseOrderPageState extends State<AddEditPurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  late Store _store;
  
  // Controllers
  final TextEditingController _orderNumberController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _supplierMobileController = TextEditingController();
  final TextEditingController _supplierAddressController = TextEditingController();
  final TextEditingController _supplierGstController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _paymentTermsController = TextEditingController();
  
  // Item controllers (for add item dialog)
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemQtyController = TextEditingController();
  final TextEditingController _itemUnitPriceController = TextEditingController();
  final TextEditingController _itemDiscountController = TextEditingController();
  final TextEditingController _itemTaxController = TextEditingController();
    final TextEditingController _unitController = TextEditingController();
  final TextEditingController _itemDescController = TextEditingController();
  
  // Variables
  late DateTime _orderDate;
  DateTime? _expectedDate;
  DateTime? _dueDate;
  PurchaseOrderStatus _status = PurchaseOrderStatus.draft;
  
  // Items list
  final List<PurchaseOrderItem> _items = [];
  
  // Totals
  double _subtotal = 0;
  double _taxAmount = 0;
  double _discountAmount = 0;
  double _shippingAmount = 0;
  double _total = 0;
  // Add these variables in your state class
  double _totalDiscountAmount = 0;
  double _totalTaxAmount = 0;
  
  // Data lists
  List<Supplier> _suppliers = [];
  List<MenuItem> _menuItems = [];
  List<InventoryItem> _inventoryItems = [];
  
  // Images
  File? _signatureImage;
  String? _signaturePath;
  final ImagePicker _picker = ImagePicker();
  
  // Loading state
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isEditing => widget.order != null;

  @override
  void initState() {
    super.initState();
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _orderDate = widget.order?.orderDate ?? DateTime.now();
    _expectedDate = widget.order?.expectedDeliveryDate;
    _dueDate = widget.order?.dueDate;
    _status = widget.order?.status ?? PurchaseOrderStatus.draft;
    
    _loadInitialData();
    
    if (isEditing) {
      _populateForm();
    } else {
      _generateOrderNumber();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadSuppliers(),
        _loadMenuItems(),
        _loadInventoryItems(),
      ]);
    } catch (e) {
      print_log('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSuppliers() async {
    final box = _store.box<Supplier>();
    _suppliers = box.getAll();
    print_log("_suppliers $_suppliers");
  }

  Future<void> _loadMenuItems() async {
    final box = _store.box<MenuItem>();
    _menuItems = box.getAll();
    print_log("_menuItems $_menuItems");
  }

  Future<void> _loadInventoryItems() async {
    final box = _store.box<InventoryItem>();
    _inventoryItems = box.getAll();
    print_log("_inventoryItems $_inventoryItems");
  }

  // List<String> get _allItemNames {
  //   final menuNames = _menuItems.map((e) => e.name).toList();
  //   final inventoryNames = _inventoryItems.map((e) => e.name).toList();

  //   return [...menuNames, ...inventoryNames];
  // }

  void _populateForm() {
    final order = widget.order!;
    _orderNumberController.text = order.orderNumber;
    _supplierNameController.text = order.supplierName;
    _supplierMobileController.text = order.supplierMobile ?? '';
    _supplierAddressController.text = order.supplierAddress ?? '';
    _supplierGstController.text = order.supplierGst ?? '';
    _notesController.text = order.notes ?? '';
    _termsController.text = order.termsAndConditions ?? '';
    _paymentTermsController.text = order.paymentTerms ?? '';
    _items.addAll(order.items);
    _subtotal = order.subtotal;
    _taxAmount = order.taxAmount;
    _discountAmount = order.discountAmount;
    _shippingAmount = order.shippingAmount;
    _total = order.totalAmount;
    _signaturePath = order.signaturePath;
    if (_signaturePath != null && File(_signaturePath!).existsSync()) {
      _signatureImage = File(_signaturePath!);
    }
  }

  Future<void> _generateOrderNumber() async {
    final prefs = await SharedPreferences.getInstance();
    int counter = prefs.getInt('po_counter') ?? 1000;
    counter++;
    await prefs.setInt('po_counter', counter);
    _orderNumberController.text = 'PO-${DateFormat('yyyyMM').format(DateTime.now())}-$counter';
  }

// Update the _calculateTotals method
void _calculateTotals() {
  _subtotal = _items.fold(0, (sum, item) => sum + item.subtotal);
  _totalDiscountAmount = _items.fold(0, (sum, item) => sum + item.discountAmount);
  _totalTaxAmount = _items.fold(0, (sum, item) => sum + item.taxAmount);
  
  // Calculate totals
  _subtotal = _items.fold(0, (sum, item) => sum + item.subtotal);
  _total = _subtotal - _totalDiscountAmount + _totalTaxAmount + _shippingAmount;
  
  setState(() {});
}

  Future<void> _selectSupplier(Supplier supplier) async {
    setState(() {
      _supplierNameController.text = supplier.supplierName;
      _supplierMobileController.text = supplier.mobileNumber ?? '';
      _supplierAddressController.text = supplier.address ?? '';
      _supplierGstController.text = supplier.gstNumber ?? '';
    });
  }



  List<ItemSuggestion> get _allItemSuggestions {
    final menuItems = _menuItems.map((e) => ItemSuggestion(
          name: e.name,
          price: double.tryParse(e.f_price ?? "0.0") ?? 0,
          gstRate: e.gstRate ?? 0.0,
          unit: 'Nos',
          source: "Menu",
        ));
    
    final inventoryItems = _inventoryItems.map((e) => ItemSuggestion(
          name: e.name,
          price: 0,
          gstRate: 0,
          unit: e.unit,
          source: "Inventory",
        ));

    return [...menuItems, ...inventoryItems];
  }

void _showAddItemDialog() {
  _itemNameController.clear();
  _itemQtyController.clear();
  _itemUnitPriceController.clear();
  _itemDiscountController.clear();
  _itemTaxController.clear();
  _itemDescController.clear();
  _unitController.clear();

  String _selectedUnit = "Nos";
  bool _isManualEntry = false;
  final TextEditingController _searchController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        // Calculate preview values
        double qty = 0;
        double price = 0;
        double discount = 0;
        double tax = 0;
        
        try {
          qty = double.tryParse(_itemQtyController.text) ?? 0;
          price = double.tryParse(_itemUnitPriceController.text) ?? 0;
          discount = double.tryParse(_itemDiscountController.text) ?? 0;
          tax = double.tryParse(_itemTaxController.text) ?? 0;
        } catch (e) {}
        
        final subtotal = qty * price;
        final discountAmount = subtotal * discount / 100;
        final taxAmount = subtotal * tax / 100;
        final total = subtotal - discountAmount + taxAmount;
        
        return AlertDialog(
          title: const Text('Add Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'autocomplete', label: Text('Search')),
                    ButtonSegment(value: 'manual', label: Text('Manual')),
                  ],
                  selected: {_isManualEntry ? 'manual' : 'autocomplete'},
                  onSelectionChanged: (Set<String> selection) {
                    setDialogState(() {
                      _isManualEntry = selection.first == 'manual';
                      _itemNameController.clear();
                      _itemUnitPriceController.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // ITEM NAME / SEARCH SECTION
                if (!_isManualEntry)
                  RawAutocomplete<ItemSuggestion>(
                    optionsBuilder: (TextEditingValue value) {
                      if (value.text.isEmpty) return const Iterable<ItemSuggestion>.empty();
                      return _allItemSuggestions.where((item) =>
                          item.name.toLowerCase().contains(value.text.toLowerCase()));
                    },
                    displayStringForOption: (option) => option.name,
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Search Item Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            width: 300,
                            height: 200,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option.name),
                                  subtitle: Text("Price: ₹${option.price.toStringAsFixed(2)} | GST: ${option.gstRate}%"),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (item) {
                      setDialogState(() {
                        _itemNameController.text = item.name;
                        _itemUnitPriceController.text = item.price.toString();
                        _itemTaxController.text = item.gstRate.toString();
                        _selectedUnit = item.unit;
                        _unitController.text = item.unit;
                      });
                    },
                  )
                else
                  TextFormField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),

                const SizedBox(height: 12),

                // UNIT PRICE
                TextFormField(
                  controller: _itemUnitPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price *',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => setDialogState(() {}),
                ),

                const SizedBox(height: 12),

                // QUANTITY AND UNIT
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemQtyController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setDialogState(() {}),
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
                        onChanged: (v) {
                          setDialogState(() {
                            _selectedUnit = v!;
                            _unitController.text = v;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // DISCOUNT AND TAX
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemDiscountController,
                        decoration: const InputDecoration(
                          labelText: 'Discount %',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _itemTaxController,
                        decoration: const InputDecoration(
                          labelText: 'GST %',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setDialogState(() {}),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // PRICE PREVIEW SECTION
                if (qty > 0 && price > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Price Preview',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildPreviewRow('Subtotal', subtotal),
                        if (discount > 0)
                          _buildPreviewRow('Discount (${discount.toStringAsFixed(0)}%)', -discountAmount, 
                            color: Colors.red),
                        if (tax > 0)
                          _buildPreviewRow('GST (${tax.toStringAsFixed(0)}%)', taxAmount,
                            color: Colors.orange),
                        const Divider(),
                        _buildPreviewRow('Total', total, isBold: true, color: Colors.teal),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _itemDescController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_itemNameController.text.isNotEmpty &&
                    _itemQtyController.text.isNotEmpty &&
                    _itemUnitPriceController.text.isNotEmpty) {
                  
                  final qty = double.parse(_itemQtyController.text);
                  final price = double.parse(_itemUnitPriceController.text);
                  final discountPercent = double.tryParse(_itemDiscountController.text) ?? 0;
                  final taxPercent = double.tryParse(_itemTaxController.text) ?? 0;
                  
                  final subtotal = qty * price;
                  final discountAmount = subtotal * discountPercent / 100;
                  final taxAmount = subtotal * taxPercent / 100;
                  final total = subtotal - discountAmount + taxAmount;

                  final item = PurchaseOrderItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _itemNameController.text,
                    description: _itemDescController.text,
                    quantity: qty,
                    unit: _unitController.text.isNotEmpty ? _unitController.text : _selectedUnit,
                    unitPrice: price,
                    discount: discountPercent,
                    discountAmount: discountAmount,
                    tax: taxPercent,
                    taxAmount: taxAmount,
                    subtotal: subtotal,
                    total: total,
                  );

                  setState(() {
                    _items.add(item);
                    _calculateTotals();
                  });

                  Navigator.pop(context);
                }
              },
              child: const Text('Add Item'),
            ),
          ],
        );
      },
    ),
  );
}


Widget _buildPreviewRow(String label, double amount, {bool isBold = false, Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 14 : 12,
          ),
        ),
        Text(
          '₹ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
            fontSize: isBold ? 14 : 12,
          ),
        ),
      ],
    ),
  );
}




  void _showMenuItemsDialog(StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Menu Item'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              final item = _menuItems[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(item.name),
                subtitle: Text('Price: Rs.${item.sellPrice}'),
                onTap: () {
                  setDialogState(() {
                    _itemNameController.text = item.name;
                    _itemUnitPriceController.text = item.sellPrice;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showInventoryItemsDialog(StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Inventory Item'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _inventoryItems.length,
            itemBuilder: (context, index) {
              final item = _inventoryItems[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(item.name),
                subtitle: Text('Stock: ${item.stockQuantity} ${item.unit}'),
                onTap: () {
                  setDialogState(() {
                    _itemNameController.text = item.name;
                    _itemUnitPriceController.text = '0'; // You may need a purchase price field
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

Future<void> _saveOrder() async {
  if (!_formKey.currentState!.validate()) return;
  if (_items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add at least one item')),
    );
    return;
  }
  
  final _syid = ganarateID();
  setState(() => _isSaving = true);

  try {
    final order = PurchaseOrder(
      syid: isEditing ? widget.order!.syid : _syid,
      synced: false,
      id: isEditing ? widget.order!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      orderNumber: _orderNumberController.text,
      orderDate: _orderDate,
      expectedDeliveryDate: _expectedDate,
      supplierId: '', // You may want to store supplier ID
      supplierName: _supplierNameController.text,
      supplierMobile: _supplierMobileController.text.isNotEmpty ? _supplierMobileController.text : null,
      supplierAddress: _supplierAddressController.text.isNotEmpty ? _supplierAddressController.text : null,
      supplierGst: _supplierGstController.text.isNotEmpty ? _supplierGstController.text : null,
      items: List.from(_items),
      subtotal: _subtotal,
      taxAmount: _taxAmount,
      discountAmount: _discountAmount,
      shippingAmount: _shippingAmount,
      totalAmount: _total,
      status: _status,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      termsAndConditions: _termsController.text.isNotEmpty ? _termsController.text : null,
      paymentTerms: _paymentTermsController.text.isNotEmpty ? _paymentTermsController.text : null,
      dueDate: _dueDate,
      createdAt: widget.order?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'current_user',
      signaturePath: _signaturePath,
    );

    final box = _store.box<PurchaseOrderEntity>();
    
    if (isEditing) {
      // Update existing order - Query by syid (your custom ID)
      final query = box.query(PurchaseOrderEntity_.syid.equals(widget.order!.syid)).build();
      final existingEntity = query.findFirst();
      query.close();
      
      if (existingEntity != null) {
        // Update the existing entity by modifying its properties directly
        existingEntity.orderData = jsonEncode(order.toMap());
        existingEntity.signaturePath = _signaturePath;
        existingEntity.orderNumber = order.orderNumber;
        existingEntity.supplierName = order.supplierName;
        existingEntity.statusIndex = order.status.index;
        existingEntity.orderDate = order.orderDate;
        existingEntity.synced = false; // Mark as not synced if you have sync functionality
        
        // Put the entity back - this will UPDATE because the object has an @Id
        await box.put(existingEntity);
        
        print_log('Updated order: ${order.orderNumber} with ID: ${existingEntity.id}');
      } else {
        // If not found, create new (fallback)
        final entity = PurchaseOrderEntity(
          syid: _syid,
          orderData: jsonEncode(order.toMap()),
          signaturePath: _signaturePath,
          orderNumber: order.orderNumber,
          supplierName: order.supplierName,
          statusIndex: order.status.index,
          orderDate: order.orderDate,
        );
        
        await box.put(entity);
        
        print_log('Created new order (fallback): ${order.orderNumber}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderNumber} updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Create new order
      final entity = PurchaseOrderEntity(
        syid: _syid,
        orderData: jsonEncode(order.toMap()),
        signaturePath: _signaturePath,
        orderNumber: order.orderNumber,
        supplierName: order.supplierName,
        statusIndex: order.status.index,
        orderDate: order.orderDate,
      );
      
      await box.put(entity);
      
      print_log('Created new order: ${order.orderNumber}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderNumber} saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  } catch (e) {
    print_log('Error saving order: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

  Future<String?> saveImageInternalStorage(String sourcePath, String folderName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // Create subfolder (e.g., /signatures)
      final targetDir = Directory(p.join(appDir.path, folderName));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final fileName = p.basename(sourcePath);    // e.g. image.jpg
      final savedPath = p.join(targetDir.path, fileName);

      final savedFile = await File(sourcePath).copy(savedPath);

      return savedFile.path;
    } catch (e) {
      print_log('Error saving image: $e');
      return null;
    }
  }

  Future<void> _takeSignature() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
    );
    if (image != null) {
      final path = await saveImageInternalStorage(image.path, 'signatures');
      if (path != null) {
        setState(() {
          _signatureImage = File(path);
          _signaturePath = path;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Purchase Order' : 'New Purchase Order'),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (isEditing)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'share') {
                  _shareOrder(widget.order!);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Share PDF'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _orderNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Order Number',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.numbers),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _orderDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _orderDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Order Date',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(DateFormat('dd/MM/yyyy').format(_orderDate)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<PurchaseOrderStatus>(
                                  value: _status,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                    // prefixIcon: Icon(Icons.badge),
                                  ),
                                  items: PurchaseOrderStatus.values.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _getStatusColor(status),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_getStatusText(status)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _status = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _expectedDate ?? DateTime.now().add(const Duration(days: 7)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _expectedDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Expected Delivery',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.local_shipping),
                                    ),
                                    child: Text(
                                      _expectedDate != null
                                          ? DateFormat('dd/MM/yyyy').format(_expectedDate!)
                                          : 'Not set',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Supplier Section
                    const Text(
                      'Supplier Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    RawAutocomplete<Supplier>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return Iterable.empty();
                        // Also update your external controller as the user types manually
                        _supplierNameController.text = textEditingValue.text; 
                        
                        return _suppliers.where((s) => 
                          s.supplierName.toLowerCase().contains(textEditingValue.text.toLowerCase())
                        );
                      },
                      displayStringForOption: (s) => s.supplierName,
                      onSelected: (Supplier selection) {
                        // 1. Update your external controller manually here
                        setState(() {
                          _supplierNameController.text = selection.supplierName;
                        });
                        // 2. Call your original select logic
                        _selectSupplier(selection);
                      },
                      fieldViewBuilder: (context, tc, fn, onSubmitted) {
                        // If your controller already has a value (e.g., editing), sync it to the autocomplete
                        if (_supplierNameController.text.isNotEmpty && tc.text.isEmpty) {
                          tc.text = _supplierNameController.text;
                        }

                        return TextFormField(
                          controller: tc, 
                          focusNode: fn,
                          onChanged: (value) {
                            // Update your controller when the user types manually
                            _supplierNameController.text = value;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Supplier Name *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: Container(
                              width: 300,
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.separated(
                                padding: EdgeInsets.zero, // Add this to remove default padding
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final supplier = options.elementAt(i);
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.teal.shade100,
                                      child: Text(supplier.supplierName[0].toUpperCase()),
                                    ),
                                    title: Text(supplier.supplierName),
                                    subtitle: Text(supplier.mobileNumber ?? 'No mobile'),
                                    onTap: () => onSelected(supplier),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    
                    // Supplier Contact Details
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _supplierMobileController,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _supplierGstController,
                            decoration: const InputDecoration(
                              labelText: 'GST Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _supplierAddressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Items Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.primaryColor,
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
                          border: Border.all(color: Colors.grey.shade300),
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
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              setState(() {
                                _items.removeAt(index);
                                _calculateTotals();
                              });
                            },
                            // In the items list builder
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        if (item.description != null)
                                          Text(
                                            item.description!,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        Text(
                                          '${item.formattedQuantity} ${item.unit} × ${item.formattedUnitPrice}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        // Show discount and tax badges
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            if (item.discount > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${item.formattedDiscount} OFF',
                                                  style: TextStyle(fontSize: 10, color: Colors.red.shade800),
                                                ),
                                              ),
                                            if (item.tax > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'GST ${item.formattedTax}',
                                                  style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        item.formattedTotal,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                      if (item.discountAmount > 0)
                                        Text(
                                          'Saved: ₹${item.discountAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      if (item.taxAmount > 0)
                                        Text(
                                          'GST: ₹${item.taxAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange.shade600,
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

                    // Totals Section
                    // Update the totals section in your build method
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildTotalRow('Subtotal', _subtotal),
                          const SizedBox(height: 8),
                          if (_totalDiscountAmount > 0)
                            _buildTotalRow('Total Discount', -_totalDiscountAmount, color: Colors.red),
                          if (_totalTaxAmount > 0)
                            _buildTotalRow('Total GST', _totalTaxAmount, color: Colors.orange),
                          if (_shippingAmount > 0)
                            _buildTotalRow('Shipping', _shippingAmount),
                          const Divider(height: 16),
                          _buildTotalRow('Grand Total', _total, isBold: true, color: Colors.teal),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Payment Terms & Dates
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _paymentTermsController,
                            decoration: const InputDecoration(
                              labelText: 'Payment Terms',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.payment),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _dueDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Due Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.event),
                              ),
                              child: Text(
                                _dueDate != null
                                    ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                                    : 'Not set',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Terms & Notes
                    TextFormField(
                      controller: _termsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Terms & Conditions',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),

                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Signature
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Authorized Signature'),
                              const SizedBox(height: 8),
                              Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _signatureImage != null
                                    ? Image.file(_signatureImage!, fit: BoxFit.contain)
                                    : const Center(
                                        child: Text('No signature'),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _takeSignature,
                          icon: const Icon(Icons.camera_alt),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.teal.shade50,
                            foregroundColor: Colors.teal.shade800,
                          ),
                        ),
                      ],
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
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isEditing ? 'Update Order' : 'Save Order',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft: return Colors.grey;
      case PurchaseOrderStatus.sent: return Colors.blue;
      case PurchaseOrderStatus.confirmed: return Colors.green;
      case PurchaseOrderStatus.received: return Colors.purple;
      case PurchaseOrderStatus.cancelled: return Colors.red;
    }
  }

  String _getStatusText(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft: return 'Draft';
      case PurchaseOrderStatus.sent: return 'Sent';
      case PurchaseOrderStatus.confirmed: return 'Confirmed';
      case PurchaseOrderStatus.received: return 'Received';
      case PurchaseOrderStatus.cancelled: return 'Cancelled';
    }
  }

  Future<void> _shareOrder(PurchaseOrder order) async {
    try {
      // final pdfFile = await PurchaseOrderPDF.generate(order);
      // final tempDir = await getTemporaryDirectory();
      // final filePath = '${tempDir.path}/PO_${order.orderNumber}.pdf';
      // await pdfFile.saveTo(filePath);
      final pdf = await PurchaseOrderPDF.generate(order);
      final bytes = await pdf.save();

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/PO_${order.orderNumber}.pdf';

      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      await SharePlus.instance.share(
        ShareParams(
          text: 'Purchase Order: ${order.orderNumber}',
          subject: 'Purchase Order PDF',
          files: [XFile(filePath)],
        ),
      );
    } catch (e) {
      print_log('Error sharing: $e');
    }
  }

  @override
  void dispose() {
    _orderNumberController.dispose();
    _supplierNameController.dispose();
    _supplierMobileController.dispose();
    _supplierAddressController.dispose();
    _supplierGstController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _paymentTermsController.dispose();
    _itemNameController.dispose();
    _itemQtyController.dispose();
    _itemUnitPriceController.dispose();
    _itemDiscountController.dispose();
    _itemTaxController.dispose();
    _itemDescController.dispose();
    super.dispose();
  }
}

  class ItemSuggestion {
    final String name;
    final double price;
    final double gstRate;
    final String unit;
    final String source; // "Menu" or "Inventory"

    ItemSuggestion({
      required this.name,
      required this.price,
      required this.gstRate,
      required this.unit,
      required this.source,
    });
  }