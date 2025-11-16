import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './editBillPrint/editBill.dart';
import 'bill_printer.dart';
import './objectbox.g.dart';
import '../models/menu_item.dart';
import 'cartprovier/cart_provider.dart';
import 'package:provider/provider.dart';
import 'cartprovier/ObjectBoxService.dart';
import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'dart:io';
import './cartprovier/cartProvider.dart';

final printer = BillPrinter();
int imageHeight = 92;
double boxHeight = 0.4;
double boxText = 16;
bool isHoldEnabled = false;
List<String> categories = [];
String? selectedCategory = "ALL";
bool _isVoiceSelected = false;
Box<MenuItem>? menuItemBox;
CartProvider? cartProvider;
late List<MenuItem> _items;
late List<MenuItem> items_all;
late List<Map<String, dynamic>> items = [];
late List<Map<String, dynamic>> filteredItems = []; // Mutable filtered list
Map<String, List<Map<String, dynamic>>> groupedItems = {};

class CartItemRow extends StatefulWidget {
  final String itemName;
  final double price;
  final int quantity;
  final Function(int) onQuantityChanged;
  final Function() onDelete;

  CartItemRow({
    Key? key,
    required this.itemName,
    required this.price,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<CartItemRow> {
  late int _quantity;
  late FocusNode _focusNode;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _quantity = widget.quantity;
    _controller = TextEditingController(text: _quantity.toString());
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Run after Flutter finishes focusing/caret placement
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemTotal = widget.price * _quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Item name and price
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.itemName,
                  textScaler: TextScaler.linear(1.0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${(widget.price).toStringAsFixed(0)}", //₹
                  textScaler: TextScaler.linear(1.0),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          // Inline editable quantity
          Expanded(
            flex: 1,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              enableInteractiveSelection: true,
              autofocus: false,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
              ),
              onTap: () {
                // Also force-select on tap (next frame beats internal caret logic)
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  _controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controller.text.length,
                  );
                });
              },
              onSubmitted: (value) {
                final qty = int.tryParse(value) ?? 1;
                setState(() {
                  _quantity = qty > 0 ? qty : 1;
                  _controller.text = _quantity.toString();
                });
                widget.onQuantityChanged(_quantity);
              },
            ),
          ),

          // Total price and delete button
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "₹$itemTotal",
                  textScaler: TextScaler.linear(1.0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewOrderPage extends StatefulWidget {
  final List<Map<String, dynamic>>? cart1; // Make it nullable with ?
  final int? tableno;
  final String? mode;
  final String? billingType;
  final int? hideadd;
  
  const NewOrderPage({
    this.cart1, // Set default value to null
    this.tableno,
    this.mode,
    this.billingType,
    this.hideadd,
    super.key,
  });

  @override
  _NewOrderPageState createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String selected = "CASH"; // default selected
  final ValueNotifier<double> subtotalNotifier = ValueNotifier<double>(0);
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? selectedDevice;
  bool isGridView = true; // Add this as a state variable
  String selectedStyle = "List Style Half Full"; // default fallback
  Set<int> selectedIndexes = {};
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isPrinting = false;
  String? billingType;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    final stopwatch = Stopwatch()..start();
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    menuItemBox = store.box<MenuItem>();
    items_all = menuItemBox!.getAll();
    _extractCategories(items_all);
    loadSelectedStyle();
    
    debugPrint("selectedCategory $selectedCategory $billingType");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Future.delayed(Duration(milliseconds: 15), () => _loadItems(items_all));
      
      _loadItems(items_all);
      cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider?.addListener(_handleCartChange);
      Future.delayed(const Duration(milliseconds: 300), () {
        _loadItems_cart(items_all, widget.cart1); // update selected items
        _filterItems(category: selectedCategory); // ✅ filter by selected category
      });
      // Future.delayed(Duration(milliseconds: 15), () => _filterItems(category:selectedCategory));//update selected items
      stopwatch.stop();
      debugPrint('✅ Total loading time: ${stopwatch.elapsedMilliseconds}ms');
    });
  }

  @override
  bool get wantKeepAlive => true;


  void _filterItems({String? searchQuery, String? category}) {
    final query = (searchQuery ?? '').toLowerCase();
    final selected = category ?? selectedCategory;

    List<Map<String, dynamic>> filtered = [];

    for (var item in items) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final matchesSearch = query.isEmpty || name.contains(query);
      final matchesCategory =
          selected == "ALL" || selected == null
              ? true
              : selected == "FAVORITES"
                  ? (item['favorites'] == true)
                  : item['category'] == selected;

      if (matchesSearch && matchesCategory) {
        filtered.add(item);
      }
    }

    setState(() {
      filteredItems = filtered;
    });
  }

  void _loadItems(List<MenuItem> items11) {
    if (widget.cart1 != null){
      _loadCartData();
    }
    setState(() {
      _items = items11;
      items = _items.map((item) => item.toMap()).toList();
      filteredItems = List.from(items); // start with all items
    });

  }

  void _loadItems_cart(List<MenuItem> itemsm,List<Map<String, dynamic>>? cart1) async {
    // final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    // final itemsm = store.box<MenuItem>().getAll();
    if(cart1 != null){
      debugPrint("updating UI with $cart1");
      // No changes to the mapping logic
      _items = itemsm.map((item) {
        var newItem = item.copyWith(selected: false, qty: 0, h_qty: 0);
        
        if (cart1 != null && cart1.isNotEmpty) {
          for (final cartItem in cart1) {
            if (cartItem['id'] == item.id) {
              // debugPrint("newItem $newItem");
              if (cartItem['portion'].toLowerCase() == 'full') {
                newItem = newItem.copyWith(
                  qty: cartItem['qty'] ?? 0,
                  selected: (cartItem['qty']?? 0) > 0
                );
              } else if ((cartItem['portion']).toLowerCase() == 'half') {
                newItem = newItem.copyWith(
                  h_qty: cartItem['qty'] ?? 0,
                  selected: (cartItem['qty'] ?? 0) > 0
                );
                // debugPrint("newItem $newItem");
              }
            }
          }
        }
        // debugPrint("newItem $newItem");
        return newItem;
      }).toList();
      
      items = _items.map((item) => item.toMap()).toList();
      debugPrint("loded cart in the items is $items");
      setState(() { filteredItems = List.from(items); });
    }
  }

  void _loadCartData() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    debugPrint("set cart to the provider to the in neworderpage ${cartProvider.cart.isEmpty} ${cartProvider.cart}");
    if (cartProvider.cart.isEmpty){
      debugPrint("set cart to the provider to the in neworderpage ${cartProvider.cart.isEmpty} ${cartProvider.cart}");
      cartProvider.setCart(widget.cart1 ?? []);
    }
  }

  void toggleFavorite(Map<String, dynamic> item,) {
    final itemId = item['id'] as int;
    if (itemId == 0) return;
    final menuItem = menuItemBox?.get(itemId);

    if (menuItem != null) {
      setState(() {
        bool isFavorite = item['favorites'] ?? false;
        item['favorites'] = !isFavorite;
        menuItem.favorites = item['favorites'];
        menuItemBox?.put(menuItem);
      });
    }
  }



  Widget buildGridView(String selectedStyle) {
    if (filteredItems.isEmpty) {
      return const Center(
        child: Text(
          'No items found',
          textScaler: TextScaler.linear(1.0),
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // ✅ Group the filtered items by category only once
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in filteredItems) {
      final category = item["category"];
      grouped.putIfAbsent(category, () => []).add(item);
    }

    // ✅ Determine which categories to show
    final List<String> categoriesToShow;
    if (selectedCategory == "FAVORITES") {
      categoriesToShow = grouped.keys.toList();
    } else if (selectedCategory != null && selectedCategory != "ALL") {
      categoriesToShow = [selectedCategory!];
    } else {
      categoriesToShow = grouped.keys.toList();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: categoriesToShow.length,
      itemBuilder: (context, catIndex) {
        final category = categoriesToShow[catIndex];
        final itemsToShow = grouped[category] ?? [];

        if (itemsToShow.isEmpty) return const SizedBox.shrink();

        return Column(
          key: _categoryKeys.putIfAbsent(category, () => GlobalKey()),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Category Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                category,
                textScaler: TextScaler.linear(1.0),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // ✅ Grid of items for this category
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              itemCount: itemsToShow.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 6,
                childAspectRatio: (selectedStyle == "Restaurant With Image Style")? boxHeight : boxHeight*1.4 ,
              ),
              itemBuilder: (context, index) {
                final item = itemsToShow[index];
                return buildItemCardWithImage(item,selectedStyle);
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(color: Colors.blue.shade400, thickness: 1.5),
            ),
          ],
        );
      },
    );
  }

  Widget buildGridView_half_full() {
    if (filteredItems.isEmpty) {
      return const Center(
        child: Text(
          'No items found',
          textScaler: TextScaler.linear(1.0),
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // ✅ Group the filtered items by category only once
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in filteredItems) {
      final category = item["category"];
      grouped.putIfAbsent(category, () => []).add(item);
    }

    // ✅ Determine which categories to show
    final List<String> categoriesToShow;
    if (selectedCategory == "FAVORITES") {
      categoriesToShow = grouped.keys.toList();
    } else if (selectedCategory != null && selectedCategory != "ALL") {
      categoriesToShow = [selectedCategory!];
    } else {
      categoriesToShow = grouped.keys.toList();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: categoriesToShow.length,
      itemBuilder: (context, catIndex) {
        final category = categoriesToShow[catIndex];
        final itemsToShow = grouped[category] ?? [];

        if (itemsToShow.isEmpty) return const SizedBox.shrink();

        return Column(
          key: _categoryKeys.putIfAbsent(category, () => GlobalKey()),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Category Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                category,
                textScaler: TextScaler.linear(1.0),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // ✅ Grid of items for this category
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              itemCount: itemsToShow.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 6,
                childAspectRatio: boxHeight,
              ),
              itemBuilder: (context, index) {
                final item = itemsToShow[index];
                return buildItemCardWithImage_half_full(item);
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(color: Colors.blue.shade400, thickness: 1.5),
            ),
          ],
        );
      },
    );
  }

  Widget buildItemCardWithImage_half_full(Map<String, dynamic> item,) {
    String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
    String imagePath = "$baseDir${item['name']}.jpeg";
    File imageFile = File(imagePath);
    bool hasImage = imageFile.existsSync();
        // Check if the file exists
    if (!hasImage) {
      String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
      imagePath = "$baseDir${item['name']}.jpg";
      File imageFile = File(imagePath);
      hasImage = imageFile.existsSync();
    }
    
    //if available, otherwise fallback to f_price, otherwise 0
    double fPrice;
    // debugPrint(" $billingType == REGULAR  buildItemCardWithImage_half_full");
    switch (billingType) {
      case "AC":
        fPrice = double.tryParse(item['acSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        fPrice = double.tryParse(item['nonAcSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        fPrice = double.tryParse(item['onlineSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        fPrice = double.tryParse(item['onlineDeliveryPrice']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $fPrice");
        break;
      default:
        fPrice = double.tryParse(item['f_price']?.toString() ?? '0.0') ?? 0;
        break;
    }

    // double hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
    double hPrice;
    // debugPrint(" $billingType == REGULAR  buildItemCardWithImage_half_full");
    switch (billingType) {
      case "AC":
        hPrice = double.tryParse(item['acSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        hPrice = double.tryParse(item['nonAcSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        hPrice = double.tryParse(item['onlineSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        hPrice = double.tryParse(item['onlineDeliveryPriceHalf']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $fPrice");
        break;
      default:
        hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
        break;
    }
    

    return GestureDetector(
      child: Container(
        decoration: BoxDecoration(
          color: item['selected'] == true ? Colors.green[100] : Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Container(
                  height: imageHeight.toDouble(),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    image: hasImage
                        ? DecorationImage(
                            image: FileImage(imageFile),
                            fit: BoxFit.fill,
                          )
                        : null,
                  ),
                  child: !hasImage
                      ? Center(child: Icon(Icons.image, color: Colors.grey))
                      : null,
                ),

                // Item Name
                Padding(
                  padding: EdgeInsets.only(
                    top: 1,
                    bottom: 1,
                    left: 1,
                    right: 1,
                  ),
                  child: Text(
                    item["name"],
                    textScaler: TextScaler.linear(1.0),
                    style: TextStyle(
                      height: 0.9,
                        fontSize: (item["name"].toString().length > 23)
                          ? boxText - 4
                          : (item["name"].toString().length > 16 ? boxText - 4 : boxText),
                      fontWeight: FontWeight.bold,
                    ),
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),

                // Spacer to push portion sections to bottom
                Expanded(child: Container()),

                // Half Portion Section - Only show when hPrice > 0
                if (hPrice > 0)
                  GestureDetector(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                      padding: EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                      decoration: BoxDecoration(
                        // color: item['selectedPortion'] == 'half' 
                        //     ? Colors.blue[100] 
                        //     : Colors.grey[100],
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          // Half Label
                          Text(
                            'HALF ${hPrice.toStringAsFixed(0)}', //₹
                            textScaler: TextScaler.linear(1.0),
                            style: TextStyle(
                              fontSize: boxText * 0.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 4),
                          // Half Quantity and Price
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Quantity Controls
                              Row(
                                children: [
                                  // Decrease Quantity Button (-)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (item['h_qty'] > 0) {
                                          item['h_qty'] -= 1;
                                          cartProvider?.addToCart(item,'half',hPrice);
                                          if (item['h_qty'] == 0 && (item['qty'] == 0)) {
                                              item['selected'] = false;
                                          }
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 25,
                                      height: 25,
                                      decoration: BoxDecoration(
                                        color:  item['h_qty'] > 0 ? Colors.red : Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '-',
                                          textScaler: TextScaler.linear(1.0),
                                          style: TextStyle(
                                            fontSize: boxText * 0.9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Quantity Display
                                  Container(
                                    width: 24,
                                    height: 24,
                                    margin: EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: item['h_qty'] > 0 ? Colors.blue : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        item['h_qty'] > 0 ? item['h_qty'].toString() : '0',
                                        textScaler: TextScaler.linear(1.0),
                                        style: TextStyle(
                                          fontSize: boxText * 1,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Increase Quantity Button (+)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        item['h_qty'] += 1;
                                        item['selected'] = true;
                                        cartProvider?.addToCart(item,'half',hPrice);
                                      });
                                      // debugPrint("added item is ${item}");
                                    },
                                    child: Container(
                                      width: 25,
                                      height: 25,
                                      decoration: BoxDecoration(
                                        color: item['h_qty'] > 0 ? Colors.green : Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '+',
                                          textScaler: TextScaler.linear(1.0),
                                          style: TextStyle(
                                            fontSize: boxText * 0.9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Full Portion Section
                GestureDetector(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                    padding: EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                    decoration: BoxDecoration(
                      // color: item['selectedPortion'] == 'full' 
                      //     ? Colors.green[100] 
                      //     : Colors.grey[100],
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        // Full Label
                        Text(
                          'FULL ${fPrice.toStringAsFixed(0)}', //₹
                          textScaler: TextScaler.linear(1.0),
                          style: TextStyle(
                            fontSize: boxText * 0.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(height: 2),
                        // Full Quantity and Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Quantity Controls
                            Row(
                              children: [
                                // Decrease Quantity Button (-)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (item['qty'] > 0) {
                                        item['qty'] -= 1;
                                        if (item['h_qty'] == 0 && (item['qty'] == 0)) {
                                            item['selected'] = false;
                                        }
                                        cartProvider?.addToCart(item,'Full',fPrice);
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      color: item['qty'] > 0 ? Colors.red : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '-',
                                        textScaler: TextScaler.linear(1.0),
                                        style: TextStyle(
                                          fontSize: boxText * 0.8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Quantity Display
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin: EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: item['qty'] > 0 ? Colors.blue : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      item['qty'] > 0 ? item['qty'].toString() : '0',
                                      textScaler: TextScaler.linear(1.0),
                                      style: TextStyle(
                                        fontSize: boxText * 1,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Increase Quantity Button (+)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      item['qty'] += 1;
                                      item['selected'] = true;
                                      cartProvider?.addToCart(item,'Full',fPrice);
                                    });
                                  },
                                  child: Container(
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      color: item['qty'] > 0 ? Colors.green : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+',
                                        textScaler: TextScaler.linear(1.0),
                                        style: TextStyle(
                                          fontSize: boxText * 0.8,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Spacer
                SizedBox(height: 4),
              ],
            ),

            // Close button (only show when item is selected)
            if (item['selected'] == true)
              Positioned(
                top: 1,
                right: 1,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      item['selected'] = false;
                      item['qty'] = 0;
                      item['h_qty'] = 0;
                      item['selectedPortion'] = null;
                      cartProvider?.removeFromCart(item['id'],'half');
                      cartProvider?.removeFromCart(item['id'],'full');
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),

            // Favorite Icon in the top-left corner
            Positioned(
              top: 1,
              left: 1,
              child: GestureDetector(
                onTap: () {
                  toggleFavorite(item);
                },
                child: Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item['favorites'] == true 
                        ? Icons.favorite 
                        : Icons.favorite_border,
                    color: item['favorites'] == true 
                        ? Colors.red 
                        : Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildItemCardWithImage(Map<String, dynamic> item,selectedStyle) {
        String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
    String imagePath = "$baseDir${item['name']}.jpeg";
    File imageFile = File(imagePath);
    bool hasImage = imageFile.existsSync();
        // Check if the file exists
    if (!hasImage) {
      String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
      imagePath = "$baseDir${item['name']}.jpg";
      File imageFile = File(imagePath);
      hasImage = imageFile.existsSync();
    }
    double price;
    // debugPrint(" $billingType == REGULAR  buildItemCardWithImage_half_full");
    switch (billingType) {
      case "AC":
        price = double.tryParse(item['acSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        price = double.tryParse(item['nonAcSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        price = double.tryParse(item['onlineSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        price = double.tryParse(item['onlineDeliveryPrice']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $fPrice");
        break;
      default:
        price = double.tryParse(item['f_price']?.toString() ?? '0.0') ?? 0;
        break;
    }

    // double hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
    double hPrice;
    // debugPrint(" $billingType == REGULAR  buildItemCardWithImage_half_full");
    switch (billingType) {
      case "AC":
        hPrice = double.tryParse(item['acSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        hPrice = double.tryParse(item['nonAcSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        hPrice = double.tryParse(item['onlineSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        hPrice = double.tryParse(item['onlineDeliveryPriceHalf']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $fPrice");
        break;
      default:
        hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
        break;
    }
    
    // debugPrint("menu items $item ");

    return GestureDetector(
      onTap: () {
          setState(() {
          item['qty'] += 1;
          item['selected'] = true;
          cartProvider?.addToCart(item,'Full', double.tryParse(price.toString()) ?? 0.0);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: item['selected'] == true ? Colors.green[100] : Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (selectedStyle == "Restaurant With Image Style")
                  Container(
                    height: imageHeight.toDouble(),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      image: hasImage
                          ? DecorationImage(
                              image: FileImage(imageFile),
                              fit: BoxFit.fill,
                            )
                          : null,
                    ),
                    child: !hasImage
                        ? Center(child: Icon(Icons.image, color: Colors.grey))
                        : null,
                  ),
                

                // Item Name
                Padding(
                  padding: EdgeInsets.only(
                    top: selectedStyle == "Restaurant With Image Style" ? 1 : 20 , // Increased top padding
                    bottom: 1,
                    left: 1,
                    right: 1,
                  ),
                  child: Text(
                    item["name"],
                    textScaler: TextScaler.linear(1.0),
                    style: TextStyle(
                      fontSize: boxText,
                      fontWeight: FontWeight.bold,
                    ),
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),

                // Spacer to push the price row to bottom
                Expanded(child: Container()),
              ],
            ),

            // Price and Quantity Row at bottom
            Positioned(
              bottom: 6,
              left: 2,
              right: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuantitySelector(item,cartProvider,price),
                  _buildPriceTag(item, price.toString()),
                ],
              ),
            ),

            // Close button
            if (item['selected'] == true)
              Positioned(
                top: 1,
                right: 1,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      item['selected'] = false;
                      item['qty'] = 0;
                      // updateCart(item);
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),

            // NEW: Favorite Icon in the top-left corner
            Positioned(
              top: 1,
              left: 1,
              child: GestureDetector(
                onTap: () {
                  toggleFavorite(item);
                },
                child: Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    // Conditionally show a filled heart or a border heart
                    item['favorites'] == true 
                        ? Icons.favorite 
                        : Icons.favorite_border,
                    color: item['favorites'] == true 
                        ? Colors.red 
                        : Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
          
          ],
        ),
      ),
    );
  }

  Widget buildPriceTag(Map<String, dynamic> item) {
    bool hasPortionPricing = (item['f_price'] != null && item['f_price'] > 0) && 
                            (item['h_price'] != null && item['h_price'] > 0);
    
    String priceText;
    
    // if (hasPortionPricing) {
    //   // Show both prices with current selection highlighted
    //   priceText = '₹${item['h_price']} / ₹${item['f_price']}';
    // } else {
      // Show single price
      priceText = '${(item['f_price'] ?? 0)}'; //₹
    // }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green),
      ),
      child: Text(
        priceText,
        textScaler: TextScaler.linear(1.0),
        style: TextStyle(
          fontSize: boxText * 0.8,
          fontWeight: FontWeight.bold,
          color: Colors.green[800],
        ),
      ),
    );
  }
 
  Widget _buildQuantitySelector(
    Map<String, dynamic> item, CartProvider? cartProvider, double fprice, {
    double fontSize = 14,
  }) {
    return GestureDetector(
      onTap: () async {
        TextEditingController controller = TextEditingController(
          text: (item['qty'] ?? 0).toString(),
        );

        final newQuantity = await showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Enter Quantity",textScaler: TextScaler.linear(1.0),),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: "Enter quantity"),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  child: Text("Cancel",textScaler: TextScaler.linear(1.0),),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text("OK",textScaler: TextScaler.linear(1.0),),
                  onPressed: () => Navigator.of(context).pop(controller.text),
                ),
              ],
            );
          },
        );

        if (newQuantity != null && newQuantity.isNotEmpty) {
          setState(() {
            int newQty = int.tryParse(newQuantity) ?? 0;
            item['qty'] = newQty;
            item['selected'] = item['qty'] > 0; // Update selected state
            cartProvider?.updateQuantity(item['id'], newQty, fprice ,item['name'],'full');
            // updateCart(item); // Update the cart with new quantity
          });
        }
      },
      child: Container(
        width: fontSize * 2.2, // scale width based on font size
        height: fontSize * 1.8, // scale height based on font size
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          color: item['qty'] == 0 ? Colors.grey[200] : Colors.green[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: FittedBox(
            child: Text(
              (item['qty'] ?? 0).toString(),
              textScaler: TextScaler.linear(1.0),
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }




  Widget _buildListView() {
    if (filteredItems.isEmpty) {
      return const Center(
        child: Text(
          'No items found',
          textScaler: TextScaler.linear(1.0),
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // Group filtered items by category (only once, small map)
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in filteredItems) {
      final category = item["category"];
      grouped.putIfAbsent(category, () => []).add(item);
    }

    final categoriesToShow = grouped.keys.toList();

    return ListView.builder(
      controller: _scrollController,
      itemCount: categoriesToShow.length,
      itemBuilder: (context, categoryIndex) {
        final category = categoriesToShow[categoryIndex];
        final categoryItems = grouped[category] ?? [];

        return Column(
          key: _categoryKeys.putIfAbsent(category, () => GlobalKey()),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                category,
                textScaler: TextScaler.linear(1.0),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // Lazy List of Items
            ListView.builder(
              itemCount: categoryItems.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = categoryItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                  child: _buildItemListCard(item, isList: true),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(color: Colors.blue.shade400, thickness: 1.5),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemListCard(Map<String, dynamic> item, {bool isList = false}) {

    double price;
    // debugPrint(" $billingType == REGULAR  _buildItemListCard");
    switch (billingType) {
      case "AC":
        price = double.tryParse(item['acSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        price = double.tryParse(item['nonAcSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        price = double.tryParse(item['onlineSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        price = double.tryParse(item['onlineDeliveryPrice']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $price");
        break;
      default:
        price = double.tryParse(item['f_price']?.toString() ?? '0.0') ?? 0;
        break;
    }

    // double hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
    double hPrice;
    // debugPrint(" $billingType == REGULAR  buildItemCardWithImage_half_full");
    switch (billingType) {
      case "AC":
        hPrice = double.tryParse(item['acSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        hPrice = double.tryParse(item['nonAcSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        hPrice = double.tryParse(item['onlineSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        hPrice = double.tryParse(item['onlineDeliveryPriceHalf']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $hPrice");
        break;
      default:
        hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
        break;
    }
    return GestureDetector(
      onTap: () {
        // setState(() {
        //   // Always increment quantity when item is tapped, whether selected or not
        //   item['h_qty'] = (item['h_qty'] ?? 0) + 1;
        //   item['selected'] = true; // Mark as selected
        //   cartProvider?.addToCart(item, 'full', price);
        //   // updateCart(item);
        // });
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: item['selected'] == true
                  ? Colors.green[100]
                  : Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(2),
            ),
            padding: EdgeInsets.symmetric(vertical: 0,horizontal: 0),
            child: isList ? _buildListItem(item, price.toStringAsFixed(0),hPrice.toStringAsFixed(0)) : _buildListItem(item, price.toStringAsFixed(0),hPrice.toStringAsFixed(0)),
          ),

          if (item['selected'] == true)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    item['selected'] = false;
                    item['qty'] = 0;
                    item['h_qty'] = 0;
                    cartProvider?.removeFromCart(item['id'], 'full');
                    cartProvider?.removeFromCart(item['id'], 'half');
                    // updateCart(item);
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
        
          // NEW: Favorite Icon in the top-left corner
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () {
                toggleFavorite(item);
              },
              child: Container(
                padding: EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  // Conditionally show a filled heart or a border heart
                  item['favorites'] == true 
                      ? Icons.favorite 
                      : Icons.favorite_border,
                  color: item['favorites'] == true 
                      ? Colors.red 
                      : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildListItem(Map<String, dynamic> item, String? price,String? hprice ) {
  //     // Local image path
  //         String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
  //   String imagePath = "$baseDir${item['name']}.jpeg";
  //   File imageFile = File(imagePath);
  //   bool hasImage = imageFile.existsSync();
  //       // Check if the file exists
  //   if (!hasImage) {
  //     String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
  //     imagePath = "$baseDir${item['name']}.jpg";
  //     File imageFile = File(imagePath);
  //     hasImage = imageFile.existsSync();
  //   }

  //     // Dynamic font sizes based on image size
  //     double nameFontSize = imageHeight / 6; // ~35% of image height
  //     double priceFontSize = imageHeight / 6; // ~30% of image height
  //     double qtyFontSize = imageHeight / 6; // ~30% of image height
  //     final fprice = double.tryParse(price ?? 0)

  //     return Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // Item Image
  //         ClipRRect(
  //            onPressed: () {
  //             setState(() {
  //               // Always increment quantity when item is tapped, whether selected or not
  //               item['h_qty'] = (item['h_qty'] ?? 0) + 1;
  //               item['selected'] = true; // Mark as selected
  //               cartProvider?.addToCart(item, 'full', double.tryParse(price) ?? 0.0);
  //             });
  //           },
  //           borderRadius: BorderRadius.circular(8),
  //           child: imageFile.existsSync()
  //               ? Image.file(
  //                   imageFile,
  //                   width: imageHeight.toDouble() - 6,
  //                   height: imageHeight.toDouble(),
  //                   fit: BoxFit.cover,
  //                 )
  //               : Container(
  //                   width: imageHeight.toDouble() - 6,
  //                   height: imageHeight.toDouble(),
  //                   color: Colors.grey[300],
  //                   child: Icon(Icons.image, color: Colors.grey[600]),
  //                 ),
  //         ),

  //         SizedBox(width: 3),
          
  //         // Right side with Column for layout
  //         Expanded(
  //            onPressed: () {
  //             setState(() {
  //               // Always increment quantity when item is tapped, whether selected or not
  //               item['h_qty'] = (item['h_qty'] ?? 0) + 1;
  //               item['selected'] = true; // Mark as selected
  //               cartProvider?.addToCart(item, 'full', double.tryParse(price) ?? 0.0);
  //             });
  //           },
  //           child: Container(
  //             height: imageHeight.toDouble(), // Same height as image
              
  //             // ✅ CHANGED Stack to Column
  //             child: Column( 
  //               crossAxisAlignment: CrossAxisAlignment.start, // Aligns name to the left
  //               children: [
  //                 // Item Name at top
  //                 Text(
  //                   item["name"],
  //                   textScaler: TextScaler.linear(1.0),
  //                   style: TextStyle(
  //                     fontSize: boxText,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                   softWrap: true,
  //                   maxLines: 2,
  //                   overflow: TextOverflow.visible,
  //                 ),

  //                 // ✅ ADDED Spacer to push everything else to the bottom
  //                 const Spacer(),

  //                 // Price + Quantity at bottom (Half)
  //                 // (No longer needs Positioned)
  //                 Row(
  //                   // Use spaceBetween to fix spacing
  //                   // mainAxisAlignment: MainAxisAlignment.spaceBetween, 
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     Text(
  //                       'Half',
  //                       textScaler: TextScaler.linear(1.0),
  //                       style: TextStyle(fontSize: boxText * 0.7,),
  //                     ),
  //                     SizedBox(width: 6),
  //                     // Wrap selector and price in a Row to keep them together
  //                     Row(
  //                       mainAxisSize: MainAxisSize.min,
  //                       children: [
  //                         _half_buildQuantitySelector(item, fontSize: qtyFontSize),
  //                         SizedBox(width: 8),
  //                         _half_buildPriceTag(item, hprice, fontSize: priceFontSize),
  //                       ],
  //                     )
  //                   ],
  //                 ),
                  
  //                 // ✅ ADDED a small gap between the two rows
  //                 SizedBox(height: 2), 

  //                 // Price + Quantity at bottom (Full)
  //                 // (No longer needs Positioned)
  //                 Row(
  //                   // Use spaceBetween to fix spacing
  //                   // mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     Text(
  //                       'Full',
  //                       textScaler: TextScaler.linear(1.0),
  //                       style: TextStyle(fontSize: boxText * 0.7,),
  //                     ),
  //                     SizedBox(width: 6),
  //                     // Wrap selector and price in a Row to keep them together
  //                     Row(
  //                       mainAxisSize: MainAxisSize.min,
  //                       children: [
  //                         _buildQuantitySelector(item, fontSize: qtyFontSize),
  //                         SizedBox(width: 8),
  //                         _buildPriceTag(item, price, fontSize: priceFontSize),
  //                       ],
  //                     )
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
          
  //       ],
  //     );
  //   }


  Widget _buildListItem(Map<String, dynamic> item, String price, String hprice) {
    // Local image path
    String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
    String imagePath = "$baseDir${item['name']}.jpeg";
    File imageFile = File(imagePath);
    bool hasImage = imageFile.existsSync();
    if (!hasImage) {
      imagePath = "$baseDir${item['name']}.jpg";
      imageFile = File(imagePath);
      hasImage = imageFile.existsSync();
    }

    // Dynamic font sizes based on image size
    double nameFontSize = imageHeight / 6;
    double priceFontSize = imageHeight / 6;
    double qtyFontSize = imageHeight / 6;

    // --- 1. FIXED SYNTAX & ADDED HPRICE ---
    final double fPrice = double.tryParse(price ?? '0.0') ?? 0.0;
    final double hPrice = double.tryParse(hprice ?? '0.0') ?? 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 2. WRAPPED IMAGE IN GESTUREDETECTOR ---
        GestureDetector(
          onTap: () {
            if (hPrice > 0){
              setState(() {
                // --- 3. FIXED LOGIC TO ADD 'half' ITEM ---
                item['h_qty'] = (item['h_qty'] ?? 0) + 1; // Use half quantity
                item['selected'] = true; // Mark as selected
                cartProvider?.addToCart(item, 'half', hPrice); // Use 'half' and hPrice
              });
            }
          },
          child: ClipRRect(
            // (onPressed was removed from here)
            borderRadius: BorderRadius.circular(8),
            child: imageFile.existsSync()
                ? Image.file(
                    imageFile,
                    width: imageHeight.toDouble() - 6,
                    height: imageHeight.toDouble(),
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: imageHeight.toDouble() - 6,
                    height: imageHeight.toDouble(),
                    color: Colors.grey[300],
                    child: Icon(Icons.image, color: Colors.grey[600]),
                  ),
          ),
        ),

        SizedBox(width: 3),

        // Right side with Column for layout
        Expanded(
          // (onPressed was removed from here)
          child: Container(
            height: imageHeight.toDouble(), // Same height as image
            
            // --- 4. WRAPPED CONTAINER IN GESTUREDETECTOR ---
            // This makes the whole right side tappable
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // Ensures tap works on empty space
              onTap: () {
                setState(() {
                  // --- 5. FIXED LOGIC TO ADD 'full' ITEM ---
                  item['qty'] = (item['qty'] ?? 0) + 1; // Use 'qty' (full quantity)
                  item['selected'] = true; // Mark as selected
                  cartProvider?.addToCart(item, 'full', fPrice); // Use 'full' and fPrice
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Name at top
                  Text(
                    item["name"],
                    textScaler: TextScaler.linear(1.0),
                    
                    style: TextStyle(
                      height: 0.9,
                      fontSize: boxText,
                      fontWeight: FontWeight.bold,
                    ),
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),

                  const Spacer(), // Pushes everything else to the bottom

                  // --- 6. FIXED LAYOUT FOR "Half" ROW ---
                  if (hPrice > 0)
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      // (Removed mainAxisSize: MainAxisSize.min from here)
                      children: [
                        Text(
                          'Half',
                          textScaler: TextScaler.linear(1.0),
                          style: TextStyle(fontSize: boxText * 0.7,),
                        ),
                        SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _half_buildQuantitySelector(item, cartProvider, hPrice, fontSize: qtyFontSize),
                            SizedBox(width: 8),
                            _half_buildPriceTag(item, hprice, fontSize: priceFontSize),
                          ],
                        )
                      ],
                    ),

                  if (hPrice > 0) 
                    SizedBox(height: 2),

                  // --- 7. FIXED LAYOUT FOR "Full" ROW ---
                  Row(
                    // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    // (Removed mainAxisSize: MainAxisSize.min from here)
                    children: [
                      Text(
                        'Full',
                        textScaler: TextScaler.linear(1.0),
                        style: TextStyle(fontSize: boxText * 0.7,),
                      ),
                      SizedBox(width: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQuantitySelector(item, cartProvider, hPrice,fontSize: qtyFontSize),
                          SizedBox(width: 8),
                          _buildPriceTag(item, price, fontSize: priceFontSize),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

     
  Widget _half_buildQuantitySelector( Map<String, dynamic> item, CartProvider? cartProvider, double hprice, {double fontSize = 14,}) {
    return GestureDetector(
      onTap: () async {
        TextEditingController controller = TextEditingController(
          text: (item['h_qty'] ?? 0).toString(),
        );

        final newQuantity = await showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Enter Quantity",textScaler: TextScaler.linear(1.0),),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: "Enter quantity"),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  child: Text("Cancel",textScaler: TextScaler.linear(1.0),),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text("OK",textScaler: TextScaler.linear(1.0),),
                  onPressed: () => Navigator.of(context).pop(controller.text),
                ),
              ],
            );
          },
        );

        if (newQuantity != null && newQuantity.isNotEmpty) {
          setState(() {
            int newQty = int.tryParse(newQuantity) ?? 0; 
            item['h_qty'] = newQty;
            item['selected'] = item['h_qty'] > 0; // Update selected state
            cartProvider?.updateQuantity(item['id'], newQty, hprice, item['name'], 'half');
            // updateCart(item); // Update the cart with new quantity
          });
        }
      },
      child: Container(
        width: fontSize * 2.2, // scale width based on font size
        height: fontSize * 1.8, // scale height based on font size
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          color: item['h_qty'] == 0 ? Colors.grey[200] : Colors.green[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: FittedBox(
            child: Text(
              (item['h_qty'] ?? 0).toString(),
              textScaler: TextScaler.linear(1.0),
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }


  Widget _half_buildPriceTag(Map<String, dynamic> item, String? price1, {double fontSize = 14}) {
    double price = double.tryParse(price1?.toString() ?? '0.0') ?? 0.0;
    return FutureBuilder<String?>(
      future: _getBillingType(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(); 
        }

        return DottedBorder(
          // 1. Move styling into the 'options' parameter
          options: RectDottedBorderOptions(
            color: Colors.black54,
            strokeWidth: 1,
            dashPattern: [4, 2],
            // radius: Radius.circular(4),
            // Note: 'dashPattern' and 'radius' might not be supported 
            // exactly the same way in this package's options.
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            child: Text(
              "${price.toStringAsFixed(0)}",
              textScaler: TextScaler.linear(1.0),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildListView_half_full() {
    if (filteredItems.isEmpty) {
      return const Center(
        child: Text('No items found',textScaler: TextScaler.linear(1.0), style: TextStyle(fontSize: 16)),
      );
    }
    debugPrint(" $selectedCategory selected items $filteredItems");

        return ListView.builder(
      controller: _scrollController,
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        if (cartProvider == null) {
          return const SizedBox.shrink(); // or show an error widget
        }
        return ListViewHalfFull(
          item: item,
          cartProvider: cartProvider!,
          imageHeight: imageHeight,
          billingType: billingType,
        );
      },
    );
  }



  Widget _buildPriceTag(Map<String, dynamic> item, String? price1, {double fontSize = 14}) {
    double price = double.tryParse(price1?.toString() ?? '0.0') ?? 0.0;
    return FutureBuilder<String?>(
      future: _getBillingType(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(); 
        }

        return DottedBorder(
          // 1. Move styling into the 'options' parameter
          options: RectDottedBorderOptions(
            color: Colors.black54,
            strokeWidth: 1,
            dashPattern: [4, 2],
            // radius: Radius.circular(4),
            // Note: 'dashPattern' and 'radius' might not be supported 
            // exactly the same way in this package's options.
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            child: Text(
              "${price.toStringAsFixed(0)}",
              textScaler: TextScaler.linear(1.0),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _getBillingType() async {
    // final prefs = await SharedPreferences.getInstance();
    // prefs.getString('selectedBillingType') ?? "REGULAR";
    debugPrint(" $billingType == REGULAR _getBillingType");
    return billingType;
    
  }

  void _extractCategories(List<MenuItem> items) async {
    categories =  items.map((item) => item.category).toSet().toList()..sort();
    for (var category in categories) {
      _categoryKeys[category] = GlobalKey();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final imageHeightStr = prefs.getString("imageheight_key");
    final boxHeightStr = prefs.getString("boxheight_key");
    final boxTextStr = prefs.getString("boxtext_key");

    final imageHeightVal = int.tryParse(imageHeightStr ?? "") ?? 90;
    final boxHeightVal = double.tryParse(boxHeightStr ?? "") ?? 0.40;
    final boxTextVal = double.tryParse(boxTextStr ?? "") ?? 16;

    setState(() {
      imageHeight = imageHeightVal;
      boxHeight = boxHeightVal;
      boxText = boxTextVal;
    });
    
    setState(() {
      billingType = (widget.billingType != null) ? widget.billingType  : prefs.getString('selectedBillingType') ?? "REGULAR";
      debugPrint("(billingType != null) ${(billingType != null)}  ${widget.billingType} $billingType");
    });


  }


  void _handleCartChange() {
    if (!mounted) return;

    if (cartProvider!.cart.isEmpty) {
      if (mounted) {
        setState(() {
          for (var item in items) {
            item['selected'] = false;
            item['qty'] = 0;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> loadSelectedStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStyle = prefs.getString('selectedStyle') ?? "List Style Half Full";
    });
  }

  // Extracted into a separate method for better readability and error handling.
  // Future<void> _handlePrintAndSettle(BuildContext context,cart,total) async {
  //   // 1. Set state to "loading" to disable the button and show an indicator.
  //   setState(() {
  //     _isPrinting = true;
  //   });

  //   try {
  //     // 2. Perform the asynchronous printing task.
  //     await printer.printCart(
  //       context: context,
  //       cart1: cart ?? [],
  //       total: (total ?? 0.0).toInt(),
  //       mode: "settle1",
  //       payment_mode: selected,
  //     );

  //     if (!context.mounted) return;
  //   } catch (e) {
  //     // 5. Catch any unexpected errors during printing.
  //     if (!context.mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('An unexpected error occurred: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     // 6. ALWAYS re-enable the button, whether printing succeeded, failed, or threw an error.
  //     if (context.mounted) {
  //       setState(() {
  //         _isPrinting = false;
  //       });
  //     }
  //   }
  // }


  // Function to read password from SharedPreferences
  Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_password'); // 🔑 key for password
  }

  void showCartItems() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cart = cartProvider.cart;
  }

  /// A reusable widget to build category buttons.
  Widget _buildCategoryButton({
    required String label,
    required String categoryIdentifier,
    IconData? icon, // Optional icon
  }) {
    // debugPrint("selectedCategory == categoryIdentifier , $selectedCategory == $categoryIdentifier");
    final isSelected = selectedCategory == categoryIdentifier;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = categoryIdentifier;
        });
        _filterItems(category: categoryIdentifier);
      },

      child: Container(
        margin: EdgeInsets.all(2), // Increased margin slightly for better spacing
        width: 90,
        height: 53,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[300] : Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: Center(
          child: Builder(
            builder: (context) {
              double fontSize = 12;
              Widget textWidget;
              try {
                textWidget = Text(
                  label,
                  textScaler: TextScaler.linear(1.0),
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 0.9,
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.normal : FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                );
              } catch (e) {
                // If a pixel/font error occurs, reduce font size and try again
                fontSize = 10;
                textWidget = Text(
                  label,
                  textScaler: TextScaler.linear(1.0),
                  style: TextStyle(
                    fontSize: fontSize,
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.normal : FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null)
                    Icon(icon, color: isSelected ? Colors.white : Colors.black, size: 15),
                  if (icon != null)
                    SizedBox(height: 1),
                  textWidget,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

    // --- Your page's methods ---
  void _handleDetails() async{
    await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(hideadd: widget.hideadd)));
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cart = cartProvider.cart;
    _loadItems_cart(items_all,cart);
    _filterItems(category:selectedCategory);
  }


  void _addItemsinTable() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cart = cartProvider.cart;
    debugPrint("Save button tapped! $cart ");
    // To go back to the very first screen (the "home" screen)
    Navigator.of(context).popUntil((route) => route.isFirst);
    // In a real app, you would call your showPrintOptions(context) here
  }


  @override
  Widget build(BuildContext context) {

    for (var item in items) {
      String category = item["category"];
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text("Select Items",textScaler: TextScaler.linear(1.0),),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 10),
                curve: Curves.easeInOut,
                height: 40,
                width: isSearching ? double.infinity : 0,
                child: isSearching
                    ? TextField(
                        //controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.blue[700],
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (query) {
                          _filterItems(searchQuery: query);
                        },
                      )
                    : SizedBox.shrink(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (isSearching) _searchController.clear();
                isSearching = !isSearching;
              });
              _filterItems(searchQuery: '');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                // Left Category Panel
                Container(
                  width: 80,
                  height: constraints.maxHeight,
                  color: Colors.grey[350],
                  child: Column(
                    children: [
                      // 1. "ALL" Button using the new helper method
                      _buildCategoryButton(
                        label: "ALL",
                        categoryIdentifier: "ALL",
                      ),

                      // 2. "Favorites" Button ❤️
                      _buildCategoryButton(
                        label: "Favorites",
                        categoryIdentifier: "FAVORITES", // A unique identifier
                        icon: Icons.favorite,
                      ),
                      
                      SizedBox(height: 3),

                      // 3. ListView using the new helper method
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80.0),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return _buildCategoryButton(
                              label: category,
                              categoryIdentifier: category,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),


                // Right side Grid
                Expanded(
                  child: Column(
                    children: [
                      // Top grey patch (T-head) with square buttons
                      Container(
                        width: double.infinity,
                        color: Colors.grey[350], // Flat grey background
                        padding: EdgeInsets.symmetric(horizontal: 12,vertical: 1),
                        //margin: EdgeInsets.only(bottom: 8), // Space before GridView
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildFlatSquareButton(Icons.mic, "Voice Bill", () {
                              setState(() {
                                _isVoiceSelected = !_isVoiceSelected;
                              });

                              if (_isVoiceSelected) {
                                // TODO: add voice
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (context) =>
                                //         //const SpeechToTextPage(),
                                //   ),
                                // ).then((_) {
                                //   // Reset toggle after returning
                                //   setState(() {
                                //     _isVoiceSelected = false;
                                //   });
                                // });
                              }
                            }),

                            _buildFlatSquareButton(
                              Icons.edit,
                              "HOLD",
                              () async {
                                setState(() {
                                  isHoldEnabled = !isHoldEnabled;
                                });

                                final prefs =await SharedPreferences.getInstance();
                                prefs.setBool('isHoldEnabled', isHoldEnabled);
                              },

                              isActive: isHoldEnabled,
                            ),

                            // _buildFlatSquareButton(
                            //   Icons.local_shipping,
                            //   "PARCEL",
                            //   () {
                            //     //TODO: Do something
                            //   },
                            // ),
                          ],
                        ),
                      ),
                      // Item grid below
                      Expanded(
                        child: Container(
                          color: Colors.grey[200],

                          child:selectedStyle == "List Style Half Full"
                              ? _buildListView_half_full()    //_buildListView()
                              : selectedStyle == "List Style"
                              ? _buildListView()
                              : selectedStyle == "Restaurant With Image Style"
                              ? buildGridView(selectedStyle)
                              : selectedStyle == "Restaurant With Image Half Full Style"
                              ? buildGridView_half_full()
                              : buildGridView(selectedStyle), // fallback if none match
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),

    bottomNavigationBar: Consumer<CartProvider>(
      builder: (context, cartData, child) {
        final cart = cartData.cart;
        final total = cartData.total;

        return BottomAppBar(
          color: Colors.grey[300],
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
            child: (widget.tableno != null)
                // IF table number exists, show the ADD button
                ? Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addItemsinTable,
                      icon: const Icon(Icons.add),
                      label: const Text('ADD Items',textScaler: TextScaler.linear(1.0),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                // ELSE, show the original button logic
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6,vertical: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: (widget.mode != null)
                              ? ElevatedButton(
                                  onPressed: cart.isNotEmpty
                                      ? () => Navigator.pop(context, cart)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey[400],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text(
                                    "ADD ITEMS (₹ ${total.toStringAsFixed(2)})",
                                    textScaler: TextScaler.linear(1.0),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: cart.isNotEmpty ? _handleDetails : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey[400],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text(
                                    "NEXT (₹ ${total.toStringAsFixed(2)})",
                                    textScaler: TextScaler.linear(1.0),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    ),



    );
  }
  
  
}


class ListViewHalfFull extends StatefulWidget {
  final Map<String, dynamic> item;
  final CartProvider cartProvider;
  final int imageHeight;
  final String? billingType;

  const ListViewHalfFull({
    required this.item,
    required this.cartProvider, 
    required this.imageHeight,
    required this.billingType,
    
   });

  @override
  State<ListViewHalfFull> createState() => _ListViewHalfFullState();
}

class _ListViewHalfFullState extends State<ListViewHalfFull> {

  Widget _buildListItem_half_full(Map<String, dynamic> item,) {
    String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
    String imagePath = "$baseDir${item['name']}.jpeg";
    File imageFile = File(imagePath);
    bool hasImage = imageFile.existsSync();
        // Check if the file exists
    if (!hasImage) {
      String baseDir = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/";
      imagePath = "$baseDir${item['name']}.jpg";
      File imageFile = File(imagePath);
      hasImage = imageFile.existsSync();
    }

    final imageHeight = widget.imageHeight;
    final billingType = widget.billingType;
    // reuse your existing build logic for _buildItemListCard_half_full here
    
    double fPrice;
    // debugPrint(" $billingType == REGULAR  buildItemCardWithImage_half_full");
    switch (billingType) {
      case "AC":
        fPrice = double.tryParse(item['acSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        fPrice = double.tryParse(item['nonAcSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        fPrice = double.tryParse(item['onlineSellPrice']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        fPrice = double.tryParse(item['onlineDeliveryPrice']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $fPrice");
        break;
      default:
        fPrice = double.tryParse(item['f_price']?.toString() ?? '0.0') ?? 0;
        break;
    }

    // double hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
    double hPrice;
    // debugPrint(" $billingType == REGULAR  buildItemCardWithImage_half_full");
    switch (billingType) {
      case "AC":
        hPrice = double.tryParse(item['acSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "Non-Ac":
        hPrice = double.tryParse(item['nonAcSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online-sale":
        hPrice = double.tryParse(item['onlineSellPriceHalf']?.toString() ?? '0.0')?? 0;
        break;
      case "online Delivery Price (parcel)":
        hPrice = double.tryParse(item['onlineDeliveryPriceHalf']?.toString() ?? '0.0')?? 0;
        // debugPrint(" $billingType == REGULAR _ListViewHalfFullState $hPrice");
        break;
      default:
        hPrice = double.tryParse(item['h_price']?.toString() ?? '0.0') ?? 0;
        break;
    }


    double nameFontSize = imageHeight / 6;
    double priceFontSize = imageHeight / 6;
    double qtyFontSize = imageHeight / 6;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image on left
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(imagePath),
            width: imageHeight.toDouble()-5.0,
            height: imageHeight.toDouble(),
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: imageHeight.toDouble() -5.0,
                height: imageHeight.toDouble(),
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_not_supported),
              );
            },
          ),
        ),

        const SizedBox(width: 1),

        // Details on right
        Expanded(
          child: Container(
            height: imageHeight.toDouble()+4.0,
            padding: const EdgeInsets.symmetric(vertical:0 , horizontal: 0), // <-- padding at right
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Name at top
                Text(
                  item["name"],
                  textScaler: TextScaler.linear(1.0),
                  style: TextStyle(
                    fontSize: boxText,
                    fontWeight: FontWeight.bold,
                  ),
                  // softWrap: true,
                  // maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // Half portion row
                if (hPrice > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HALF ${hPrice.toStringAsFixed(0)}', //₹
                          textScaler: TextScaler.linear(1.0),
                          style: TextStyle(
                            fontSize: priceFontSize * 0.8,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: _buildHalfQuantitySelector(
                            item,
                            hPrice,
                            fontSize: qtyFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Full portion row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FULL ${fPrice.toStringAsFixed(0)}', //₹
                      textScaler: TextScaler.linear(1.0),
                      style: TextStyle(
                        fontSize: priceFontSize * 0.8,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: _buildFullQuantitySelector(
                        item,
                        fPrice,
                        fontSize: qtyFontSize,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Half Quantity Selector Widget
  Widget _buildHalfQuantitySelector(Map<String, dynamic> item, double price, {required double fontSize}) {
double buttonSize = 34;
    double buttonSize1 = 19;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Decrease Quantity Button (-)
        GestureDetector(
          onTap: () {
            setState(() {
              if (item['h_qty'] > 0) {
                item['h_qty'] -= 1;
                cartProvider?.addToCart(item, 'half', price);
                if (item['h_qty'] == 0 && (item['qty'] == 0)) {
                  item['selected'] = false;
                }
              }
            });
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: item['h_qty'] > 0 ? Colors.red : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '-',
                textScaler: TextScaler.linear(1.0),
                style: TextStyle(
                  fontSize: buttonSize1,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        
        // Quantity Display
        Container(
          width: buttonSize -5,
          height: buttonSize -5,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: item['h_qty'] > 0 ? Colors.blue : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              item['h_qty'] > 0 ? item['h_qty'].toString() : '0',
              textScaler: TextScaler.linear(1.0),
              style: TextStyle(
                fontSize: buttonSize1,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // Increase Quantity Button (+)
        GestureDetector(
          onTap: () {
            setState(() {
              item['h_qty'] += 1;
              item['selected'] = true;
              cartProvider?.addToCart(item, 'half', price);
            });
            // debugPrint("added item is ${item}");
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: item['h_qty'] > 0 ? Colors.green : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+',
                textScaler: TextScaler.linear(1.0),
                style: TextStyle(
                  fontSize: buttonSize1,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Full Quantity Selector Widget
  Widget _buildFullQuantitySelector(Map<String, dynamic> item, double price, {required double fontSize}) {
    double buttonSize = 34;
    double buttonSize1 = 19;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Decrease Quantity Button (-)
        GestureDetector(
          onTap: () {
            setState(() {
              if (item['qty'] > 0) {
                item['qty'] -= 1;
                if (item['h_qty'] == 0 && (item['qty'] == 0)) {
                  item['selected'] = false;
                }
                cartProvider?.addToCart(item, 'Full', price);
              }
            });
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: item['qty'] > 0 ? Colors.red : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '-',
                textScaler: TextScaler.linear(1.0),
                style: TextStyle(
                  fontSize: buttonSize1,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        
        // Quantity Display
        Container(
          width: buttonSize-5,
          height: buttonSize-5,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: item['qty'] > 0 ? Colors.blue : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              item['qty'] > 0 ? item['qty'].toString() : '0',
              textScaler: TextScaler.linear(1.0),
              style: TextStyle(
                fontSize: buttonSize1,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // Increase Quantity Button (+)
        GestureDetector(
          onTap: () {
            setState(() {
              item['qty'] += 1;
              item['selected'] = true;
              cartProvider?.addToCart(item, 'Full', price);
            });
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: item['qty'] > 0 ? Colors.green : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+',
                textScaler: TextScaler.linear(1.0),
                style: TextStyle(
                  fontSize: buttonSize1,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

 void toggleFavorite(Map<String, dynamic> item,) {
    final itemId = item['id'] as int;
    if (itemId == 0) return;
    final menuItem = menuItemBox?.get(itemId);
    if (menuItem != null) {
      setState(() {
        bool isFavorite = item['favorites'] ?? false;
        item['favorites'] = !isFavorite;
        menuItem.favorites = item['favorites'];
        menuItemBox?.put(menuItem);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTap: () {},
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: item['selected'] == true
                  ? Colors.green[100]
                  : Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: EdgeInsets.all(1),
            child: _buildListItem_half_full(item),
          ),

          if (item['selected'] == true)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    item['selected'] = false;
                    item['qty'] = 0;
                    item['h_qty'] = 0;
                    cartProvider?.removeFromCart(item['id'], 'half');
                    cartProvider?.removeFromCart(item['id'], 'full');
                    // updateCart(item);
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
        
          // NEW: Favorite Icon in the top-left corner
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () {
                toggleFavorite(item);
              },
              child: Container(
                padding: EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  // Conditionally show a filled heart or a border heart
                  item['favorites'] == true 
                      ? Icons.favorite 
                      : Icons.favorite_border,
                  color: item['favorites'] == true 
                      ? Colors.red 
                      : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  
  }
}


  Widget _buildFlatSquareButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isActive = false,
  }) {
    return Container(
      color: isActive ? Colors.green : Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: InkWell(
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            SizedBox(width: 6),
            Text(label,textScaler: TextScaler.linear(1.0), style: TextStyle(color: Colors.black87, fontSize: 13)),
          ],
        ),
      ),
    );
  }
