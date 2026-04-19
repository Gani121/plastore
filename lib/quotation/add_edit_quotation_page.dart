// lib/quotation/add_edit_quotation_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:test1/database_Module/party_database.dart';
import 'package:test1/database_Module/menu_item.dart';
import 'package:test1/utilities.dart';
import '../objectbox.g.dart';
import 'quotation_model.dart';
import 'package:test1/database_Module/quotation_database.dart';
import 'quotation_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:test1/theme_setting/theme_provider.dart';

class AddEditQuotationPage extends StatefulWidget {
  final Quotation? quotation;

  const AddEditQuotationPage({super.key, this.quotation});

  @override
  State<AddEditQuotationPage> createState() => _AddEditQuotationPageState();
}

class _AddEditQuotationPageState extends State<AddEditQuotationPage> with SingleTickerProviderStateMixin {
  late Store _store;
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  final TextEditingController _quotationNumberController = TextEditingController();
  final TextEditingController _partyNameController = TextEditingController();
  final TextEditingController _partyMobileController = TextEditingController();
  final TextEditingController _businessaddress = TextEditingController();
  final TextEditingController _partyEmailController = TextEditingController();
  final TextEditingController _partyAddressController = TextEditingController();
  final TextEditingController _partyGstController = TextEditingController();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _eventVenueController = TextEditingController();
  final TextEditingController _expectedGuestsController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _cancellationController = TextEditingController();
  final TextEditingController _paymentTermsController = TextEditingController();
  final TextEditingController _specialInstructionsController = TextEditingController();
  
  // Discount and charges controllers
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _serviceChargeController = TextEditingController();
  final TextEditingController _packagingChargeController = TextEditingController();
  final TextEditingController _deliveryChargeController = TextEditingController();

  // Dates
  late DateTime _quotationDate;
  DateTime? _validUntil;
  DateTime? _eventDate;

  // Status
  QuotationStatus _status = QuotationStatus.draft;

  // Lists
  List<Parties> _parties = [];
  List<MenuItem> _menuItems = [];
  List<PlateQuotation> _plates = [];
  List<BanquetQuotation> _banquetItems = [];
  List<AdditionalQuotationItem> _additionalItems = [];

  // For new plate
  final TextEditingController _newPlateNameController = TextEditingController();
  final TextEditingController _newPlatePriceController = TextEditingController();
  final TextEditingController _newPlateQuantityController = TextEditingController();
  final TextEditingController _newPlateDescriptionController = TextEditingController();
  PlateType _newPlateType = PlateType.vegetarian;
  List<PlateMenuItem> _newPlateItems = [];

  // For new banquet
  final TextEditingController _newBanquetNameController = TextEditingController();
  final TextEditingController _newBanquetPriceController = TextEditingController();
  final TextEditingController _newBanquetHoursController = TextEditingController();
  final TextEditingController _newBanquetDescriptionController = TextEditingController();
  final List<String> _newBanquetInclusions = [];

  // For new additional item
  final TextEditingController _newItemNameController = TextEditingController();
  final TextEditingController _newItemPriceController = TextEditingController();
  final TextEditingController _newItemQuantityController = TextEditingController();
  final TextEditingController _newItemUnitController = TextEditingController();
  final TextEditingController _newItemDescriptionController = TextEditingController();

  // Images
  File? _signatureImage;
  String? _signaturePath;
  final ImagePicker _picker = ImagePicker();

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;

  // Totals
  double _platesSubtotal = 0;
  double _banquetSubtotal = 0;
  double _additionalSubtotal = 0;
  double _discountAmount = 0;
  double _taxAmount = 0;
  double _totalAmount = 0;

  bool get isEditing => widget.quotation != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _quotationDate = widget.quotation?.quotationDate ?? DateTime.now();
    _validUntil = widget.quotation?.validUntil ?? DateTime.now().add(const Duration(days: 15));
    _eventDate = widget.quotation?.eventDate;
    _status = widget.quotation?.status ?? QuotationStatus.draft;

    _loadInitialData();

    if (isEditing) {
      _populateForm();
    } else {
      _generateQuotationNumber();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadParties(),
        _loadMenuItems(),
      ]);
    } catch (e) {
      print_log('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadParties() async {
    final box = _store.box<Parties>();
    _parties = box.getAll();
  }

  Future<void> _loadMenuItems() async {
    final box = _store.box<MenuItem>();
    _menuItems = box.getAll();
  }

  void _populateForm() {
    final q = widget.quotation!;
    _quotationNumberController.text = q.quotationNumber;
    _partyNameController.text = q.partyName;
    _partyMobileController.text = q.partyMobile ?? '';
    _businessaddress.text = q.businessAddress ?? '';
    _partyEmailController.text = q.partyEmail ?? '';
    _partyAddressController.text = q.partyAddress ?? '';
    _partyGstController.text = q.partyGst ?? '';
    _eventNameController.text = q.eventName ?? '';
    _eventVenueController.text = q.eventVenue ?? '';
    _expectedGuestsController.text = q.expectedGuests?.toString() ?? '';
    _termsController.text = q.termsAndConditions ?? '';
    _cancellationController.text = q.cancellationPolicy ?? '';
    _paymentTermsController.text = q.paymentTerms ?? '';
    _specialInstructionsController.text = q.specialInstructions ?? '';
    
    _plates = List.from(q.plates);
    _banquetItems = List.from(q.banquetItems);
    _additionalItems = List.from(q.additionalItems);
    
    _discountController.text = q.discountAmount.toString();
    _taxController.text = q.taxAmount.toString();
    _serviceChargeController.text = q.serviceCharge?.toString() ?? '';
    _packagingChargeController.text = q.packagingCharge?.toString() ?? '';
    _deliveryChargeController.text = q.deliveryCharge?.toString() ?? '';
    
    _signaturePath = q.signaturePath;
    if (_signaturePath != null && File(_signaturePath!).existsSync()) {
      _signatureImage = File(_signaturePath!);
    }

    _calculateTotals();
  }

  Future<void> _generateQuotationNumber() async {
    final prefs = await SharedPreferences.getInstance();
    int counter = prefs.getInt('quotation_counter') ?? 1000;
    counter++;
    await prefs.setInt('quotation_counter', counter);
    _quotationNumberController.text = 'Q-${DateFormat('yyyyMM').format(DateTime.now())}-$counter';
  }

  Future<void> _selectParty(Parties party) async {
    setState(() {
      _partyNameController.text = party.customername;
      _partyMobileController.text = party.mobilenumber ?? '';
      _partyAddressController.text = party.adreess ?? '';
      // You might want to add email and GST fields to your Parties model
    });
  }

  void _calculateTotals() {
    _platesSubtotal = _plates.fold(0, (sum, plate) => sum + plate.total);
    _banquetSubtotal = _banquetItems.fold(0, (sum, item) => sum + item.total);
    _additionalSubtotal = _additionalItems.fold(0, (sum, item) => sum + item.total);
    
    _discountAmount = double.tryParse(_discountController.text) ?? 0;
    _taxAmount = double.tryParse(_taxController.text) ?? 0;
    
    _totalAmount = _platesSubtotal + _banquetSubtotal + _additionalSubtotal - _discountAmount + _taxAmount;
    
    setState(() {});
  }

  void _showAddPlateDialog() {
    _newPlateNameController.clear();
    _newPlatePriceController.clear();
    _newPlateQuantityController.text = '1';
    _newPlateDescriptionController.clear();
    _newPlateType = PlateType.vegetarian;
    _newPlateItems = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Food Package'),
            content: SingleChildScrollView(
              child: Container(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Plate Type
                    DropdownButtonFormField<PlateType>(
                      value: _newPlateType,
                      decoration: const InputDecoration(
                        labelText: 'Package Type',
                        border: OutlineInputBorder(),
                      ),
                      items: PlateType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getPlateTypeColor(type),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_getPlateTypeName(type)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => _newPlateType = v!),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Package Name
                    TextFormField(
                      controller: _newPlateNameController,
                      decoration: const InputDecoration(
                        labelText: 'Package Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Price and Quantity
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _newPlatePriceController,
                            decoration: const InputDecoration(
                              labelText: 'Price per Plate *',
                              border: OutlineInputBorder(),
                              prefixText: 'Rs.  ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _newPlateQuantityController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Select from Menu Items
                    ElevatedButton.icon(
                      onPressed: () => _showMenuItemsForPlate(setDialogState),
                      icon: const Icon(Icons.restaurant_menu),
                      label: const Text('Add Items from Menu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        foregroundColor: Colors.orange.shade800,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Selected Items
                    if (_newPlateItems.isNotEmpty) ...[
                      const Divider(),
                      const Text(
                        'Selected Items:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._newPlateItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: item.included,
                              onChanged: (value) {
                                setDialogState(() {
                                  final index = _newPlateItems.indexWhere((i) => i.id == item.id);
                                  _newPlateItems[index] = PlateMenuItem(
                                    id: item.id,
                                    name: item.name,
                                    description: item.description,
                                    included: value ?? false,
                                  );
                                });
                              },
                            ),
                            Expanded(child: Text(item.name)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                setDialogState(() {
                                  _newPlateItems.removeWhere((i) => i.id == item.id);
                                });
                              },
                            ),
                          ],
                        ),
                      )),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // Description
                    TextFormField(
                      controller: _newPlateDescriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
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
                  if (_newPlateNameController.text.isNotEmpty &&
                      _newPlatePriceController.text.isNotEmpty &&
                      _newPlateQuantityController.text.isNotEmpty) {
                    
                    final price = double.parse(_newPlatePriceController.text);
                    final qty = double.parse(_newPlateQuantityController.text);
                    
                    final plate = PlateQuotation(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _newPlateNameController.text,
                      type: _newPlateType,
                      pricePerPlate: price,
                      quantity: qty.toInt(),
                      total: price * qty,
                      items: List.from(_newPlateItems),
                      description: _newPlateDescriptionController.text.isNotEmpty 
                          ? _newPlateDescriptionController.text 
                          : null,
                    );
                    
                    setState(() {
                      _plates.add(plate);
                      _calculateTotals();
                    });
                    
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add Package'),
              ),
            ],
          );
        },
      ),
    );
  }

void _showMenuItemsForPlate(StateSetter setDialogState) {
  List<PlateMenuItem> tempSelectedItems = List.from(_newPlateItems);
  String searchQuery = '';
  
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        // Filter menu items based on search
        final filteredItems = _menuItems.where((item) => 
          item.name.toLowerCase().contains(searchQuery.toLowerCase())
        ).toList();
        
        return AlertDialog(
          title: const Text('Select Menu Items'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search menu items...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Selected count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selected Items:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${tempSelectedItems.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Items list
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = tempSelectedItems.any((i) => i.id == item.id.toString());
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: CheckboxListTile(
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹ ${item.f_price}'),
                              if (item.category != null)
                                Text(
                                  item.category!,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                          value: isSelected,
                          activeColor: Colors.purple,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                tempSelectedItems.add(PlateMenuItem(
                                  id: item.id.toString(),
                                  name: item.name,
                                  description: item.category,
                                  included: true,
                                ));
                              } else {
                                tempSelectedItems.removeWhere((i) => i.id == item.id.toString());
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Cancel - don't save changes
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Save changes to parent dialog
                setDialogState(() {
                  _newPlateItems.clear();
                  _newPlateItems.addAll(tempSelectedItems);
                });
                Navigator.pop(context);
                
                // Optional: Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${tempSelectedItems.length} items selected'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white70,
                foregroundColor: Colors.black,
              ),
              child: const Text('Apply Selection'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showAddBanquetDialog() {
    _newBanquetNameController.clear();
    _newBanquetPriceController.clear();
    _newBanquetHoursController.text = '4';
    _newBanquetDescriptionController.clear();
    _newBanquetInclusions.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inclusionController = TextEditingController();
          
          return AlertDialog(
            title: const Text('Add Banquet Hall'),
            content: SingleChildScrollView(
              child: Container(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _newBanquetNameController,
                      decoration: const InputDecoration(
                        labelText: 'Hall Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _newBanquetPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Total Price *',
                              border: OutlineInputBorder(),
                              prefixText: 'Rs.  ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _newBanquetHoursController,
                            decoration: const InputDecoration(
                              labelText: 'Hours *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Inclusions
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: inclusionController,
                            decoration: const InputDecoration(
                              labelText: 'Add Inclusion',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () {
                            if (inclusionController.text.isNotEmpty) {
                              setDialogState(() {
                                _newBanquetInclusions.add(inclusionController.text);
                                inclusionController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Inclusion List
                    if (_newBanquetInclusions.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _newBanquetInclusions.map((inc) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(child: Text('• $inc')),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    setDialogState(() {
                                      _newBanquetInclusions.remove(inc);
                                    });
                                  },
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _newBanquetDescriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
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
                  if (_newBanquetNameController.text.isNotEmpty &&
                      _newBanquetPriceController.text.isNotEmpty &&
                      _newBanquetHoursController.text.isNotEmpty) {
                    
                    final price = double.parse(_newBanquetPriceController.text);
                    final hours = int.parse(_newBanquetHoursController.text);
                    
                    final banquet = BanquetQuotation(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _newBanquetNameController.text,
                      price: price,
                      hours: hours,
                      total: price,
                      description: _newBanquetDescriptionController.text.isNotEmpty 
                          ? _newBanquetDescriptionController.text 
                          : null,
                      inclusions: List.from(_newBanquetInclusions),
                    );
                    
                    setState(() {
                      _banquetItems.add(banquet);
                      _calculateTotals();
                    });
                    
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add Hall'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAdditionalItemDialog() {
    _newItemNameController.clear();
    _newItemPriceController.clear();
    _newItemQuantityController.text = '1';
    _newItemUnitController.clear();
    _newItemDescriptionController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Additional Item'),
        content: SingleChildScrollView(
          child: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _newItemNameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _newItemPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Price *',
                          border: OutlineInputBorder(),
                          prefixText: 'Rs.  ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _newItemQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _newItemUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit (e.g., piece, kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _newItemDescriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
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
              if (_newItemNameController.text.isNotEmpty &&
                  _newItemPriceController.text.isNotEmpty &&
                  _newItemQuantityController.text.isNotEmpty) {
                
                final price = double.parse(_newItemPriceController.text);
                final qty = double.parse(_newItemQuantityController.text);
                
                final item = AdditionalQuotationItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _newItemNameController.text,
                  price: price,
                  quantity: qty.toInt(),
                  total: price * qty,
                  unit: _newItemUnitController.text.isNotEmpty ? _newItemUnitController.text : null,
                  description: _newItemDescriptionController.text.isNotEmpty 
                      ? _newItemDescriptionController.text 
                      : null,
                );
                
                setState(() {
                  _additionalItems.add(item);
                  _calculateTotals();
                });
                
                Navigator.pop(context);
              }
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
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

Future<void> _saveQuotation() async {
  if (!_formKey.currentState!.validate()) return;
  if (_plates.isEmpty && _banquetItems.isEmpty && _additionalItems.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add at least one item')),
    );
    return;
  }
  final _syid = ganarateID();

  setState(() => _isSaving = true);

  try {
    final quotation = Quotation(
      syid: isEditing ? widget.quotation!.syid : _syid,
      synced: false,
      id: isEditing ? widget.quotation!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      quotationNumber: _quotationNumberController.text,
      quotationDate: _quotationDate,
      validUntil: _validUntil,
      partyId: '',
      businessAddress: _businessaddress.text,
      partyName: _partyNameController.text,
      partyMobile: _partyMobileController.text.isNotEmpty ? _partyMobileController.text : null,
      partyEmail: _partyEmailController.text.isNotEmpty ? _partyEmailController.text : null,
      partyAddress: _partyAddressController.text.isNotEmpty ? _partyAddressController.text : null,
      partyGst: _partyGstController.text.isNotEmpty ? _partyGstController.text : null,
      eventName: _eventNameController.text.isNotEmpty ? _eventNameController.text : null,
      eventDate: _eventDate,
      eventVenue: _eventVenueController.text.isNotEmpty ? _eventVenueController.text : null,
      expectedGuests: int.tryParse(_expectedGuestsController.text),
      plates: _plates,
      banquetItems: _banquetItems,
      additionalItems: _additionalItems,
      platesSubtotal: _platesSubtotal,
      banquetSubtotal: _banquetSubtotal,
      additionalSubtotal: _additionalSubtotal,
      discountAmount: _discountAmount,
      taxAmount: _taxAmount,
      totalAmount: _totalAmount,
      serviceCharge: double.tryParse(_serviceChargeController.text),
      packagingCharge: double.tryParse(_packagingChargeController.text),
      deliveryCharge: double.tryParse(_deliveryChargeController.text),
      status: _status,
      termsAndConditions: _termsController.text.isNotEmpty ? _termsController.text : null,
      cancellationPolicy: _cancellationController.text.isNotEmpty ? _cancellationController.text : null,
      paymentTerms: _paymentTermsController.text.isNotEmpty ? _paymentTermsController.text : null,
      specialInstructions: _specialInstructionsController.text.isNotEmpty ? _specialInstructionsController.text : null,
      createdAt: widget.quotation?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'current_user',
      signaturePath: _signaturePath,
    );

    final box = _store.box<QuotationEntity>();
    
    if (isEditing) {
      // Update existing quotation - IMPORTANT: Query by syid (your custom ID)
      final query = box.query(QuotationEntity_.syid.equals(widget.quotation!.syid)).build();
      final existingEntity = query.findFirst();
      query.close();
      
      if (existingEntity != null) {
        // Update the existing entity by modifying its properties directly
        existingEntity.quotationData = jsonEncode(quotation.toMap());
        existingEntity.signaturePath = _signaturePath;
        existingEntity.quotationNumber = quotation.quotationNumber;
        existingEntity.partyName = quotation.partyName;
        existingEntity.statusIndex = quotation.status.index;
        existingEntity.quotationDate = quotation.quotationDate;
        existingEntity.eventDate = quotation.eventDate;
        existingEntity.synced = false; // Mark as not synced if you have sync functionality
        
        // Put the entity back - this will UPDATE because the object has an @Id
        await box.put(existingEntity);
        
        print_log('Updated quotation: ${quotation.quotationNumber} with ID: ${existingEntity.id}');
      } else {
        // If not found, create new (fallback)
        final entity = QuotationEntity(
          syid: _syid,
          quotationData: jsonEncode(quotation.toMap()),
          signaturePath: _signaturePath,
          quotationNumber: quotation.quotationNumber,
          partyName: quotation.partyName,
          statusIndex: quotation.status.index,
          quotationDate: quotation.quotationDate,
          eventDate: quotation.eventDate,
        );

        await box.put(entity);
        
        print_log('Created new quotation: ${quotation.quotationNumber}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation ${quotation.quotationNumber} updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Create new quotation
      final entity = QuotationEntity(
        syid: _syid,
        quotationData: jsonEncode(quotation.toMap()),
        signaturePath: _signaturePath,
        quotationNumber: quotation.quotationNumber,
        partyName: quotation.partyName,
        statusIndex: quotation.status.index,
        quotationDate: quotation.quotationDate,
        eventDate: quotation.eventDate,
      );
      
      await box.put(entity);
      print_log('Created new quotation: ${quotation.quotationNumber}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation ${quotation.quotationNumber} saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  } catch (e) {
    print_log_red('Error saving quotation: $e');
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

  Future<void> _shareQuotation(Quotation quotation) async {
    try {
      final pdf = await QuotationPDF.generate(quotation);
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/Quotation_${quotation.quotationNumber}.pdf';

      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      await SharePlus.instance.share(
      ShareParams(
        text: 'Purchase Order: ${quotation.id}',
        subject: 'Purchase Order PDF',
        files: [XFile(filePath)],
      ),
    );
    } catch (e) {
      print_log('Error sharing: $e');
    }
  }

@override
Widget build(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context);
  return Scaffold(
    appBar: AppBar(
      title: Text(isEditing ? 'Edit Quotation' : 'New Quotation'),
      backgroundColor: themeProvider.primaryColor,
      foregroundColor: Colors.white,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(text: 'Party & Event'),
          Tab(text: 'Food Packages'),
          Tab(text: 'Banquet Hall'),
          Tab(text: 'Summary'),
        ],
      ),
      actions: [
        if (isEditing)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'share') {
                _shareQuotation(widget.quotation!);
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Party & Event Details
                _buildPartyEventTab(),
                
                // Tab 2: Food Packages
                _buildFoodPackagesTab(),
                
                // Tab 3: Banquet Hall
                _buildBanquetHallTab(),
                
                // Tab 4: Summary & Terms
                _buildSummaryTab(),
              ],
            ),
          ),
    floatingActionButton: ValueListenableBuilder(
      valueListenable: _tabController.animation!,
      builder: (context, value, child) {
        final currentIndex = _tabController.index;
        
        if (currentIndex == 1) {
          return FloatingActionButton.extended(
            onPressed: _showAddPlateDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Package', style: TextStyle(color: Colors.white)),
            backgroundColor: themeProvider.primaryColor,
          );
        } else if (currentIndex == 2) {
          return FloatingActionButton.extended(
            onPressed: _showAddBanquetDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Hall', style: TextStyle(color: Colors.white)),
            backgroundColor: themeProvider.primaryColor,
          );
        } else if (currentIndex == 3) {
          return FloatingActionButton.extended(
            onPressed: _showAddAdditionalItemDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Item', style: TextStyle(color: Colors.white)),
            backgroundColor: themeProvider.primaryColor,
          );
        } else {
          return const SizedBox.shrink(); // Hide FAB on first tab
        }
      },
    ),
  );
}

  Widget _buildPartyEventTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quotation Header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quotationNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Quotation Number',
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
                            initialDate: _quotationDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _quotationDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Quotation Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(_quotationDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 15)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _validUntil = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Valid Until',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.timer),
                          ),
                          child: Text(_validUntil != null 
                              ? DateFormat('dd/MM/yyyy').format(_validUntil!)
                              : 'Not set'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<QuotationStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                        items: QuotationStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Row(
                              children: [
                                Text(_getStatusText(status)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),


          // Party Selection
          const Text(
            'Business Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
              child: TextFormField(
                controller: _businessaddress,
                decoration: const InputDecoration(
                  labelText: 'Business Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_location),
                ),
              ),
            ),
            ],
          ),

          
          const SizedBox(height: 12),

          // Party Selection
          const Text(
            'Party Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          RawAutocomplete<Parties>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return Iterable.empty();
              return _parties.where((p) => p.customername
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()));
            },
            displayStringForOption: (p) => p.customername,
            onSelected: _selectParty,
            fieldViewBuilder: (context, tc, fn, onSubmitted) {
              return TextFormField(
                controller: _partyNameController,
                focusNode: fn,
                decoration: const InputDecoration(
                  labelText: 'Party Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
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
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final party = options.elementAt(i);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade100,
                            child: Text(party.customername[0].toUpperCase()),
                          ),
                          title: Text(party.customername),
                          subtitle: Text(party.mobilenumber ?? ''),
                          onTap: () => onSelected(party),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _partyMobileController,
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
                  controller: _partyEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _partyAddressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _partyGstController,
            decoration: const InputDecoration(
              labelText: 'GST Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),

          const SizedBox(height: 20),

          // Event Details
          const Text(
            'Event Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _eventNameController,
            decoration: const InputDecoration(
              labelText: 'Event Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _eventDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Event Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_eventDate != null 
                        ? DateFormat('dd/MM/yyyy').format(_eventDate!)
                        : 'Select date'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _expectedGuestsController,
                  decoration: const InputDecoration(
                    labelText: 'Expected Guests',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _eventVenueController,
            decoration: const InputDecoration(
              labelText: 'Venue',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodPackagesTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (_plates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No food packages added',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showAddPlateDialog,
              icon: const Icon(Icons.add, color: Colors.white,),
              label: const Text('Add Food Package'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plates.length,
      itemBuilder: (context, index) {
        final plate = _plates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getPlateTypeColor(plate.type),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plate.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${plate.typeName} • ${plate.quantity} plates',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPlateTypeColor(plate.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plate.formattedTotal,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getPlateTypeColor(plate.type),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        setState(() {
                          _plates.removeAt(index);
                          _calculateTotals();
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Items list
                if (plate.items.isNotEmpty) ...[
                  const Text(
                    'Items included:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: plate.items.map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.included ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: item.included ? Colors.green.shade800 : Colors.red.shade800,
                          decoration: item.included ? TextDecoration.none : TextDecoration.lineThrough,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
                
                if (plate.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Note: ${plate.description}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBanquetHallTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (_banquetItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_city, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No banquet halls added',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showAddBanquetDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Banquet Hall', style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _banquetItems.length,
      itemBuilder: (context, index) {
        final item = _banquetItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${item.hours} hours • ${item.hourlyRate}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.formattedTotal,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        setState(() {
                          _banquetItems.removeAt(index);
                          _calculateTotals();
                        });
                      },
                    ),
                  ],
                ),
                
                if (item.inclusions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Inclusions:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: item.inclusions.map((inc) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        inc,
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                      ),
                    )).toList(),
                  ),
                ],
                
                if (item.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.description!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items Summary
          const Text(
            'Items Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Plates summary
          if (_plates.isNotEmpty) ...[
            const Text(
              'Food Packages',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._plates.map((plate) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${plate.name} (${plate.quantity} plates)'),
                  ),
                  Text(
                    plate.formattedTotal,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
          ],

          // Banquet summary
          if (_banquetItems.isNotEmpty) ...[
            const Text(
              'Banquet Hall',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._banquetItems.map((item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${item.name} (${item.hours} hrs)'),
                  ),
                  Text(
                    item.formattedTotal,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
          ],

          // Additional items summary
          if (_additionalItems.isNotEmpty) ...[
            const Text(
              'Additional Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._additionalItems.map((item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${item.name} (${item.formattedQuantity})'),
                  ),
                  Text(
                    item.formattedTotal,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
          ],

          const Divider(),

          // Financial Summary
          const SizedBox(height: 16),
          const Text(
            'Financial Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Plates Subtotal', _platesSubtotal),
                _buildSummaryRow('Banquet Subtotal', _banquetSubtotal),
                _buildSummaryRow('Additional Subtotal', _additionalSubtotal),
                const Divider(),
                _buildSummaryRow('Subtotal', _platesSubtotal + _banquetSubtotal + _additionalSubtotal),
                
                const SizedBox(height: 12),
                
                // Discount
                TextFormField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                    labelText: 'Discount',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.discount),
                    prefixText: 'Rs.  ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _calculateTotals(),
                ),
                
                const SizedBox(height: 8),
                
                // Tax
                TextFormField(
                  controller: _taxController,
                  decoration: const InputDecoration(
                    labelText: 'Tax',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt),
                    prefixText: 'Rs.  ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _calculateTotals(),
                ),
                
                const SizedBox(height: 8),
                
                // Service Charge
                TextFormField(
                  controller: _serviceChargeController,
                  decoration: const InputDecoration(
                    labelText: 'Service Charge',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.miscellaneous_services),
                    prefixText: 'Rs.  ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _calculateTotals(),
                ),
                
                const SizedBox(height: 8),
                
                // Packaging Charge
                TextFormField(
                  controller: _packagingChargeController,
                  decoration: const InputDecoration(
                    labelText: 'Packaging Charge',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory),
                    prefixText: 'Rs.  ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _calculateTotals(),
                ),
                
                const SizedBox(height: 8),
                
                // Delivery Charge
                TextFormField(
                  controller: _deliveryChargeController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Charge',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping),
                    prefixText: 'Rs.  ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _calculateTotals(),
                ),
                
                const Divider(height: 24),
                
                // Total
                _buildSummaryRow('TOTAL', _totalAmount, isBold: true, color: Colors.purple),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Terms & Conditions
          const Text(
            'Terms & Conditions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _termsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Terms & Conditions',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _cancellationController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Cancellation Policy',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _paymentTermsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Payment Terms',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _specialInstructionsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Special Instructions',
              border: OutlineInputBorder(),
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
                  backgroundColor: Colors.purple.shade50,
                  foregroundColor: Colors.purple.shade800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveQuotation,
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
                      isEditing ? 'Update Quotation' : 'Save Quotation',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold , color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Rs.  ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft: return Colors.grey;
      case QuotationStatus.sent: return Colors.blue;
      case QuotationStatus.accepted: return Colors.green;
      case QuotationStatus.expired: return Colors.orange;
      case QuotationStatus.rejected: return Colors.red;
    }
  }

  String _getStatusText(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft: return 'Draft';
      case QuotationStatus.sent: return 'Sent';
      case QuotationStatus.accepted: return 'Accepted';
      case QuotationStatus.expired: return 'Expired';
      case QuotationStatus.rejected: return 'Rejected';
    }
  }

  Color _getPlateTypeColor(PlateType type) {
    switch (type) {
      case PlateType.vegetarian: return Colors.green;
      case PlateType.nonVegetarian: return Colors.red;
      case PlateType.jain: return Colors.orange;
      case PlateType.vegan: return Colors.teal;
    }
  }

  String _getPlateTypeName(PlateType type) {
    switch (type) {
      case PlateType.vegetarian: return 'Vegetarian';
      case PlateType.nonVegetarian: return 'Non-Vegetarian';
      case PlateType.jain: return 'Jain';
      case PlateType.vegan: return 'Vegan';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quotationNumberController.dispose();
    _partyNameController.dispose();
    _partyMobileController.dispose();
    _businessaddress.dispose();
    _partyEmailController.dispose();
    _partyAddressController.dispose();
    _partyGstController.dispose();
    _eventNameController.dispose();
    _eventVenueController.dispose();
    _expectedGuestsController.dispose();
    _termsController.dispose();
    _cancellationController.dispose();
    _paymentTermsController.dispose();
    _specialInstructionsController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _serviceChargeController.dispose();
    _packagingChargeController.dispose();
    _deliveryChargeController.dispose();
    _newPlateNameController.dispose();
    _newPlatePriceController.dispose();
    _newPlateQuantityController.dispose();
    _newPlateDescriptionController.dispose();
    _newBanquetNameController.dispose();
    _newBanquetPriceController.dispose();
    _newBanquetHoursController.dispose();
    _newBanquetDescriptionController.dispose();
    _newItemNameController.dispose();
    _newItemPriceController.dispose();
    _newItemQuantityController.dispose();
    _newItemUnitController.dispose();
    _newItemDescriptionController.dispose();
    super.dispose();
  }
}