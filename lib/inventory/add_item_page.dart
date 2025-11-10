import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/menu_item.dart';
import 'package:objectbox/objectbox.dart';
import '../objectbox.g.dart'; // This will be generated
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

final ImagePicker picker = ImagePicker();

class AddItemPage extends StatefulWidget {
  final Store? store; // 👈 made nullable
  final MenuItem? item; // 👈 optional edit

  const AddItemPage({super.key, this.store, this.item});

  @override
  _AddItemPageState createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final Box<MenuItem> _menuItemBox;

  File? _image;
  final picker = ImagePicker();
  String? _imagePath;

  // Controllers for main fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController sellPriceController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController purchasePriceController = TextEditingController();

  // Controllers for parking fields
  final TextEditingController acSellPrice1Controller = TextEditingController();
  final TextEditingController acSellPrice1ControllerHalf = TextEditingController();
  final TextEditingController nonAcSellPrice1Controller =TextEditingController();
  final TextEditingController nonAcSellPrice1ControllerHalf =TextEditingController();
  final TextEditingController onlineDeliveryPriceController =TextEditingController();
  final TextEditingController onlineDeliveryPriceControllerHalf =TextEditingController();
  final TextEditingController onlineSellPriceController =TextEditingController();
  final TextEditingController onlineSellPriceControllerHalf =TextEditingController();

  final TextEditingController halfPriceController = TextEditingController();
  final TextEditingController fullPriceController = TextEditingController();

  // Controllers for product details
  final TextEditingController hsnCodeController = TextEditingController();
  final TextEditingController itemCodeController = TextEditingController();
  final TextEditingController barCodeController = TextEditingController();
  final TextEditingController barCode2Controller = TextEditingController();

  // Controllers for tax gst
  final TextEditingController availableController = TextEditingController();
  final TextEditingController adjustStockController = TextEditingController();
  final TextEditingController gstRateController = TextEditingController();

  // In your widget's state class
  final TextEditingController _gstRateController = TextEditingController();
  final TextEditingController _cessRateController = TextEditingController();
  final TextEditingController _withTaxController = TextEditingController(
    text: 'false',
  ); // Default to "WITHOUT TAX"

  // State for expandable sections
  bool _showProductDetails = false;
  bool _showInventoryDetails = false;
  bool _showProductDisplay = false;
  bool _showGstTax = false;

  String? selectedCategory;
  String sellPriceType = '₹';

  List<String> categories = [];

  @override
  void initState() {
    super.initState();

    if (widget.store != null) {
      _menuItemBox = widget.store!.box<MenuItem>();
    } else {
      // Handle the null case (log, show error/snackbar, etc.)
      // For now, we’ll just print a warning
      print("⚠️ Store is null! _menuItemBox not initialized.");
    }
    _loadCategories();
    // Initialize with default values
    _gstRateController.text = '0.0'; // Default GST rate
    _cessRateController.text = '0.0'; // Default CESS rate

    if (widget.item != null) {
      final item = widget.item!;
      nameController.text = item.name;
      sellPriceController.text = item.sellPrice;
      sellPriceType = item.sellPriceType;
      selectedCategory = item.category;
      mrpController.text = item.mrp.toString();
      purchasePriceController.text = item.purchasePrice.toString();
      acSellPrice1Controller.text = item.acSellPrice.toString();
      acSellPrice1ControllerHalf.text = item.acSellPriceHalf.toString() ?? '0';
      nonAcSellPrice1Controller.text = item.nonAcSellPrice.toString();
      nonAcSellPrice1ControllerHalf.text = item.nonAcSellPriceHalf.toString() ?? '0';
      onlineDeliveryPriceController.text = item.onlineDeliveryPrice.toString();
      onlineDeliveryPriceControllerHalf.text = item.onlineDeliveryPriceHalf.toString() ?? '0';
      onlineSellPriceController.text = item.onlineSellPrice.toString();
      onlineSellPriceControllerHalf.text = item.onlineSellPriceHalf.toString() ?? '0';
      hsnCodeController.text = item.hsnCode.toString();
      itemCodeController.text = item.itemCode.toString();
      barCodeController.text = item.barCode.toString();
      barCode2Controller.text = item.barCode2.toString();
      availableController.text = item.available.toString();
      adjustStockController.text = item.adjustStock.toString();
      gstRateController.text = item.gstRate.toString();
      _cessRateController.text = item.cessRate.toString();
      _withTaxController.text = item.withTax.toString();
      halfPriceController.text = item.h_price.toString();
      fullPriceController.text = item.f_price.toString();
      // _imagePath = item.imagePath;
      // if (_imagePath != null) {
      //   _image = File(_imagePath!);
      // }

      _imagePath = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/${item.name}.jpeg";
      File imageFile = File(_imagePath ?? "");
      bool hasImage = imageFile.existsSync();
          // Check if the file exists
      if (!hasImage) {
        _imagePath = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/${item.name}.jpg";
        File imageFile = File(_imagePath ?? "");
        hasImage = imageFile.existsSync();
      }

      print("_imagePath $_imagePath");

     // _imagePath = item.imagePath;
      if (_imagePath != null && File(_imagePath!).existsSync()) {
        _image = File(_imagePath!);
      } else {
        _image = null; // No image available
      }
    }
  }

  @override
  void dispose() {
    _gstRateController.dispose();
    _cessRateController.dispose();
    _withTaxController.dispose();
    super.dispose();
  }

  // copy file and store in app path
  // Future<void> _pickImage() async {
  //   final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  //   if (pickedFile != null) {
  //     final appDir = await getApplicationDocumentsDirectory();
  //     final fileName = pickedFile.name;
  //     final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

  //     setState(() {
  //       _image = savedImage;
  //       _imagePath = savedImage.path;
  //     });
  //   }
  // }

  // Uint8List transparentImageBytes = Uint8List.fromList([
  //   0x89,
  //   0x50,
  //   0x4E,
  //   0x47,
  //   0x0D,
  //   0x0A,
  //   0x1A,
  //   0x0A,
  //   0x00,
  //   0x00,
  //   0x00,
  //   0x0D,
  //   0x49,
  //   0x48,
  //   0x44,
  //   0x52,
  //   0x00,
  //   0x00,
  //   0x00,
  //   0x01,
  //   0x00,
  //   0x00,
  //   0x00,
  //   0x01,
  //   0x08,
  //   0x06,
  //   0x00,
  //   0x00,
  //   0x00,
  //   0x1F,
  //   0x15,
  //   0xC4,
  //   0x89,
  //   0x00,
  //   0x00,
  //   0x00,
  //   0x0A,
  //   0x49,
  //   0x44,
  //   0x41,
  //   0x54,
  //   0x78,
  //   0x9C,
  //   0x63,
  //   0xF8,
  //   0xCF,
  //   0xC0,
  //   0x00,
  //   0x00,
  //   0x03,
  //   0x01,
  //   0x01,
  //   0x00,
  //   0x18,
  //   0xDD,
  //   0x8D,
  //   0xB3,
  //   0x00,
  //   0x00,
  //   0x00,
  //   0x00,
  //   0x49,
  //   0x45,
  //   0x4E,
  //   0x44,
  //   0xAE,
  //   0x42,
  //   0x60,
  //   0x82,
  // ]);

  // ImageProvider getSafeImageProvider(String? path) {
  //   if (path != null && path.isNotEmpty && File(path).existsSync()) {
  //     return FileImage(File(path));
  //   }
  //   // Return transparent placeholder
  //   return MemoryImage(transparentImageBytes);
  // }

  // Future<void> _pickImage() async {
  //   final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  //   if (pickedFile != null) {
  //     setState(() {
  //       _image = File(pickedFile.path);
  //       _imagePath = pickedFile.path;
  //     });
  //   }
  // }

  Future<void> _pickImage([MenuItem? item]) async {
    // ✅ Check name before opening gallery
    String itemName = item?.name ?? nameController.text.trim();

    if (itemName.isEmpty) {
      // Show a dialog/snackbar to tell user to enter name first
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Please enter the item name before selecting an image",
          ),
        ),
      );
      return; // stop execution
    }

    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final tempImage = File(pickedFile.path);

      final extDir = await getExternalStorageDirectory();

      final saveDir = Directory("${extDir!.path}/pictures/menu_images");
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // Use safe item name
      //String safeName = itemName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      String fileName = "$itemName.jpg";

      final savedPath = "${saveDir.path}/$fileName";

      final savedImage = await tempImage.copy(savedPath);

      setState(() {
        _image = savedImage;
        _imagePath = savedImage.path;

        if (item != null) {
          item.imagePath = savedImage.path;
        }
      });

      print("✅ Image saved at: ${savedImage.path}");
    }
  }

  // Future<void> _pickImage(MenuItem item) async {
  //   final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  //   if (pickedFile != null) {
  //     final tempImage = File(pickedFile.path);

  //     // Get external storage directory for this app
  //     final extDir = await getExternalStorageDirectory();

  //     // Create custom folder path: pictures/menu_images
  //     final saveDir = Directory("${extDir!.path}/pictures/menu_images");
  //     if (!await saveDir.exists()) {
  //       await saveDir.create(recursive: true);
  //     }

  //     // File name = item name
  //     String safeName = item.name;
  //     String fileName = "${safeName}.jpeg";

  //     // Final path
  //     final savedPath = "${saveDir.path}/$fileName";

  //     // Copy image to permanent location
  //     final savedImage = await tempImage.copy(savedPath);

  //     setState(() {
  //       _image = savedImage;
  //       _imagePath = savedImage.path;
  //       item.imagePath = savedImage.path;
  //     });

  //     print("✅ Image saved at: ${savedImage.path}");
  //   }
  // }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      final isEditing = widget.item != null;
      final menuItem = MenuItem(
        id: isEditing ? widget.item!.id : 0,
        name: nameController.text,
        sellPrice: sellPriceController.text,
        sellPriceType: sellPriceType,
        category: selectedCategory ?? '',
        mrp: mrpController.text,
        purchasePrice: purchasePriceController.text,
        acSellPrice: acSellPrice1Controller.text,
        acSellPriceHalf:acSellPrice1ControllerHalf.text,
        nonAcSellPrice: nonAcSellPrice1Controller.text,
        nonAcSellPriceHalf:nonAcSellPrice1ControllerHalf.text,
        onlineDeliveryPrice: onlineDeliveryPriceController.text,
        onlineDeliveryPriceHalf:onlineDeliveryPriceControllerHalf.text,
        onlineSellPrice: onlineSellPriceController.text,
        onlineSellPriceHalf:onlineSellPriceControllerHalf.text,
        hsnCode: hsnCodeController.text,
        itemCode: itemCodeController.text,
        barCode: barCodeController.text,
        barCode2: barCode2Controller.text,
        imagePath: _imagePath,
        available: int.tryParse(availableController.text) ?? 1,
        adjustStock: int.tryParse(adjustStockController.text) ?? 1,
        gstRate: double.tryParse(_gstRateController.text) ?? 0.0,
        cessRate: double.tryParse(_cessRateController.text) ?? 0.0,
        withTax: bool.tryParse(_withTaxController.text) ?? false,
        f_price: fullPriceController.text,
        h_price: halfPriceController.text,
      );

      final id = _menuItemBox.put(menuItem); // ✅ get actual ID from ObjectBox
      final updatedItem = _menuItemBox.get(
        id,
      ); // ✅ fetch saved version from disk

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Item Saved')));

      //print(updatedItem);

      Navigator.pop(
        context,
        updatedItem,
      ); // ✅ Return fresh object to calling page
    }
  }

  void _loadCategories() {
    final items = _menuItemBox.getAll();
    final uniqueCategories = <String>{};
    for (final item in items) {
      if (item.category.trim().isNotEmpty) {
        uniqueCategories.add(item.category.trim());
      }
    }
    setState(() {
      categories = uniqueCategories.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    return Scaffold(
      appBar: AppBar(
        title: 
        Text(isEditing ? "Edit Item" : "New Item" ,
          style: TextStyle(
          color: Colors.white,
          ),
        ),
        backgroundColor: Colors.purple.shade700,
        
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Upload Image
              GestureDetector(
                onTap: () {
                  if (widget.item == null) {
                    // Adding new item
                    _pickImage();
                  } else {
                    // Editing existing item
                    _pickImage(widget.item);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              color: Colors.grey,
                              size: 30,
                            ),
                            Text(
                              "Upload Item Image",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : Image.file(_image!, fit: BoxFit.fill),
                ),
              ),
              SizedBox(height: 16),

              // Product Name
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Product/Service Name *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.mic),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // Sell Price
              Row(
                children: [
                  // Expanded(
                  //   child: TextFormField(
                  //     controller: sellPriceController,
                  //     decoration: InputDecoration(
                  //       labelText: 'Sell Price *',
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     keyboardType: TextInputType.number,
                  //     validator: (value) {
                  //       if (value == null || value.isEmpty) {
                  //         return 'Please enter sell price';
                  //       }
                  //       return null;
                  //     },
                  //   ),
                  // ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: halfPriceController,
                      decoration: InputDecoration(
                        labelText: 'half Price *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter half price';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: fullPriceController,
                      decoration: InputDecoration(
                        labelText: 'Full Price *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter Full price';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Sell Price Type',
                        border: OutlineInputBorder(),
                      ),
                      // Ensure the value is valid, otherwise fallback to '₹'
                      value: ['₹', '%'].contains(sellPriceType)
                          ? sellPriceType
                          : '₹',
                      items: ['₹', '%'].map((e) {
                        return DropdownMenuItem(value: e, child: Text(e));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          sellPriceType = value ?? '₹';
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              // Category Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Item Category *',
                  border: OutlineInputBorder(),
                ),
                value: selectedCategory,
                items: [
                  ...categories.map(
                    (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                  ),
                  DropdownMenuItem<String>(
                    value: 'new_category',
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'Add New Category',
                          style: TextStyle(color: Colors.purple),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) async {
                  if (value == 'new_category') {
                    final newCategoryController = TextEditingController();
                    final newCategory = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Add New Category'),
                          content: TextField(
                            controller: newCategoryController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Category Name',
                              hintText: 'Enter new category name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (newCategoryController.text
                                    .trim()
                                    .isNotEmpty) {
                                  Navigator.pop(
                                    context,
                                    newCategoryController.text.trim(),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade700,
                              ),
                              child: Text('Add'),
                            ),
                          ],
                        );
                      },
                    );

                    if (newCategory != null && newCategory.isNotEmpty) {
                      if (!categories.contains(newCategory)) {
                        setState(() {
                          categories.add(newCategory);
                          selectedCategory = newCategory;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Category already exists!')),
                        );
                        setState(() {
                          selectedCategory = newCategory;
                        });
                      }
                    }
                  } else {
                    setState(() {
                      selectedCategory = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              // MRP + Purchase
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: mrpController,
                      decoration: InputDecoration(
                        labelText: 'MRP',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: purchasePriceController,
                      decoration: InputDecoration(
                        labelText: 'Purchase Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              // AC Sell Price
              Row(
                children: [
                  Expanded(
                    child:TextFormField(
                      controller: acSellPrice1Controller,
                      decoration: InputDecoration(
                        labelText: 'AC Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: acSellPrice1ControllerHalf,
                      decoration: InputDecoration(
                        labelText: 'Half AC Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 10),

              // Non-AC Sell Price
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                controller: nonAcSellPrice1Controller,
                decoration: InputDecoration(
                  labelText: 'Non-AC Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                controller: nonAcSellPrice1ControllerHalf,
                decoration: InputDecoration(
                  labelText: 'Half Non-AC Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
                  ),
                ],
              ),
              
              SizedBox(height: 10),

              // Online Delivery Price
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                controller: onlineDeliveryPriceController,
                decoration: InputDecoration(
                  labelText: 'Online Delivery Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                controller: onlineDeliveryPriceControllerHalf,
                decoration: InputDecoration(
                  labelText: 'Half Online Delivery Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
                  ),
                ],
              ),
              
              SizedBox(height: 10),

              // Online Sell Price
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                controller: onlineSellPriceController,
                decoration: InputDecoration(
                  labelText: 'Online Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                controller: onlineSellPriceControllerHalf,
                decoration: InputDecoration(
                  labelText: 'Half Online Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),

              // GST AND TAX Section
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showGstTax = !_showGstTax;
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(48),
                  side: BorderSide(color: Colors.purple.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "GST AND TAX (OPTIONAL)",
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                    Icon(
                      _showGstTax ? Icons.expand_less : Icons.expand_more,
                      color: Colors.purple.shade700,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              if (_showGstTax) ...[
                SizedBox(height: 10),
                TextFormField(
                  controller: _gstRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "GST %",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Prices With/Without Tax?",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text("WITH TAX"),
                        selected: _withTaxController.text == 'true',
                        onSelected: (selected) {
                          setState(() {
                            _withTaxController.text = 'true';
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text("WITHOUT TAX"),
                        selected: _withTaxController.text == 'false',
                        onSelected: (selected) {
                          setState(() {
                            _withTaxController.text = 'false';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _cessRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "CESS %",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent),
                  ),
                ),
                SizedBox(height: 10),
              ],

              // PRODUCT DETAILS Section
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showProductDetails = !_showProductDetails;
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(48),
                  side: BorderSide(color: Colors.purple.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "PRODUCT DETAILS (OPTIONAL)",
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                    Icon(
                      _showProductDetails
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.purple.shade700,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              if (_showProductDetails) ...[
                SizedBox(height: 10),
                TextFormField(
                  controller: hsnCodeController,
                  decoration: InputDecoration(
                    labelText: 'HSN/SAC Code',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: itemCodeController,
                  decoration: InputDecoration(
                    labelText: 'Item Code/SKU',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: barCodeController,
                  decoration: InputDecoration(
                    labelText: 'Bar Code',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: barCode2Controller,
                  decoration: InputDecoration(
                    labelText: 'Bar Code 2',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
              ],

              // INVENTORY DETAILS Section
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showInventoryDetails = !_showInventoryDetails;
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(48),
                  side: BorderSide(color: Colors.purple.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "INVENTORY DETAILS (OPTIONAL)",
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                    Icon(
                      _showInventoryDetails
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.purple.shade700,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),

              // PRODUCT DISPLAY Section
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showProductDisplay = !_showProductDisplay;
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(48),
                  side: BorderSide(color: Colors.purple.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "PRODUCT DISPLAY (OPTIONAL)",
                      style: TextStyle(color: Colors.purple.shade700),
                    ),
                    Icon(
                      _showProductDisplay
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.purple.shade700,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // SAVE Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text("SAVE", style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
