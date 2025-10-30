import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:objectbox/objectbox.dart';
import 'models/menu_item.dart';
import '/cartprovier/ObjectBoxService.dart';
import 'bill_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'editBillPrint/editBill.dart';
import 'cartprovier/cart_provider.dart';
import 'package:provider/provider.dart';
import './ActionBar.dart';
import './printer_pages/cartandprint.dart';


import './editBillPrint/BillService.dart';


final printer = BillPrinter();



class MenuItemPage extends StatefulWidget {
  final List<Map<String, dynamic>>? cart1;
  final String? mode;
  final int? tableno;
  
  // const MenuItemPage({
  //   this.cart1 = null, // Set default value to null
  //   super.key,
  // });

  const MenuItemPage({this.cart1, this.mode, this.tableno, Key? key}) : super(key: key);

  @override
  State<MenuItemPage> createState() => _MenuItemPageState();
}

class _MenuItemPageState extends State<MenuItemPage> {
  late Box<MenuItem> _menuItemBox;
  List<MenuItem> _menuItems = [];
  List<MenuItem> _displayedItems = [];
  bool _showFavoritesOnly = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";
  List<String> _categories = [];
  int imageHeight = 90;
  double TextSize = 16;
  bool miniPrinter = false;

  final Map<int, TextEditingController> _halfControllers = {};
  final Map<int, TextEditingController> _fullControllers = {};
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMenu());
    _loadPrefs();
    setState(() {
      for (var key in _halfControllers.keys) {
        _halfControllers[key]?.text = "0";
      }
      for (var key in _fullControllers.keys) {
        _fullControllers[key]?.text = "0";
      }
    });
    // if (widget.cart1 != null) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     final cartProvider = Provider.of<CartProvider>(context, listen: false);
    //     print("cart before cartProvider in menuitempage ${cartProvider.cart}");
    //     print("cart widget.cart1 in menuitempage  ${widget.cart1}");
    //     cartProvider.setCart(widget.cart1 ?? []);
    //     print("cart after cartProvider in menuitempage ${cartProvider.cart}");
    //   });
    // }

   final objectBox = Provider.of<ObjectBoxService>(context, listen: false);

  //  // ✅ If in edit mode, pre-fill quantities for items already in the cart
  // if (widget.mode == 'edit' && widget.cart1 != null) {
  //   final cartItems = (widget.cart1 as List).cast<Map<String, dynamic>>();

  //   for (final cartItem in cartItems) {
  //     final id = cartItem['id'];
  //     final portion = (cartItem['portion'] ?? 'Full').toString().toLowerCase();
  //     final qty = cartItem['qty'] ?? 0;

  //     // ✅ Check if controllers exist for this item
  //     if (_halfControllers[id] != null && portion.contains('half')) {
  //       _halfControllers[id]!.text = qty.toString();
  //     } else if (_fullControllers[id] != null) {
  //       _fullControllers[id]!.text = qty.toString();
  //     }
  //   }

  //   setState(() {}); // refresh UI to show highlightsr
  // }

    // Initialize controllers first
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadMenu().then((_) {
      // After menu is loaded, load cart data if in edit mode
      if (widget.mode == 'edit' && widget.cart1 != null) {
        _loadEditModeCartData();
      }
    });
  });
}

// New method specifically for edit mode cart loading
void _loadEditModeCartData() {
  final cartItems = (widget.cart1 as List).cast<Map<String, dynamic>>();
  
  for (final cartItem in cartItems) {
    final id = cartItem['id'];
    final name = cartItem['name']?.toString() ?? '';
    final qty = cartItem['qty'] is int 
        ? cartItem['qty'] as int 
        : int.tryParse(cartItem['qty']?.toString() ?? '0') ?? 0;

    if (qty == 0) continue;

    // Find the matching menu item
    MenuItem? foundItem;
    for (var item in _menuItems) {
      if (item.id == id) {
        foundItem = item;
        break;
      }
    }

    if (foundItem != null && foundItem.id != null) {
      if (name.toLowerCase().contains('(half)')) {
        _halfControllers[foundItem.id]?.text = qty.toString();
      } else {
        _fullControllers[foundItem.id]?.text = qty.toString();
      }
    }
  }
  
  setState(() {}); // Refresh UI to show highlights

  }



  // void _loadMenu() {
   
  //   final store = Provider.of<ObjectBoxService>(context, listen: false).store;
  //   _menuItemBox = store.box<MenuItem>();
  //   final items = _menuItemBox.getAll();

  //   setState(() {
  //     _menuItems = items;
  //     _displayedItems = List.from(items);

  //     // Initialize controllers
  //     for (var item in _menuItems) {
  //       _halfControllers[item.id] = TextEditingController(text: "0");
  //       _fullControllers[item.id] = TextEditingController(text: "0");
  //     }


  //     // Load cart data into controllers AFTER menu items are loaded
  //     if (widget.cart1 != null){
  //       _loadCartData();
  //     }

  //     // Extract categories dynamically
  //     _categories = _extractCategories(_menuItems);
  //     _selectedCategory = "All";
  //   });

  //   // Attach listener **after menu items are ready**
  //   _searchController.addListener(() {
  //     _filterItems();
  //   });

  // }


  Future<void> _loadMenu() async {
  final store = Provider.of<ObjectBoxService>(context, listen: false).store;
  _menuItemBox = store.box<MenuItem>();
  final items = _menuItemBox.getAll();

  setState(() {
    _menuItems = items;
    _displayedItems = List.from(items);

    // Initialize controllers with "0" as default
    for (var item in _menuItems) {
      _halfControllers[item.id] = TextEditingController(text: "0");
      _fullControllers[item.id] = TextEditingController(text: "0");
    }

    // Extract categories dynamically
    _categories = _extractCategories(_menuItems);
    _selectedCategory = "All";
  });

  // Attach listener after menu items are ready
  _searchController.addListener(() {
    _filterItems();
  });
}

  void _loadCartData() {
    print("cartProvider.cart ${widget.cart1}");
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.cart.isEmpty){
      cartProvider.setCart(widget.cart1 ?? []);
    }
    print("cartProvider.cart ${cartProvider.cart}");
    for (var cartItem in cartProvider.cart) {
      final itemName = cartItem['name']?.toString() ?? '';
      final quantity = cartItem['qty'] is int 
          ? cartItem['qty'] as int 
          : int.tryParse(cartItem['qty']?.toString() ?? '0') ?? 0;
      
      if (quantity == 0) continue;

      // Find the matching menu item
      MenuItem? foundItem;
      for (var item in _menuItems) {
        final baseName = item.name ?? '';
        if (itemName.contains('(Half)') && itemName.contains(baseName)) {
          foundItem = item;
          break;
        }
        if (itemName.contains('(Full)') && itemName.contains(baseName)) {
          foundItem = item;
          break;
        }
      }

      if (foundItem != null && foundItem.id != null) {
        if (itemName.contains('(Half)')) {
          _halfControllers[foundItem.id]?.text = quantity.toString();
        } else if (itemName.contains('(Full)')) {
          _fullControllers[foundItem.id]?.text = quantity.toString();
        }
      }
    }
    setState(() {}); // Refresh UI to show selected quantities
  }

  


  void toggleFavorite(Map<String, dynamic> item,) {
    // 1. Get the ID of the item that was tapped.
    final itemId = item['id'] as int;
    if (itemId == 0) return; // Cannot update an item without a valid ID

    // 2. Find the actual MenuItem object in the database.
    final menuItem = _menuItemBox.get(itemId);

    if (menuItem != null) {
      setState(() {
        // 3. Toggle the favorite status in your local state (the map).
        // This makes the UI update instantly.
        bool isFavorite = item['favorites'] ?? false;
        item['favorites'] = !isFavorite;

        // 4. Update the object retrieved from the database.
        // debugPrint("final menuItem = _menuItemBox.get(itemId); ${item['favorites']}");
        menuItem.favorites = item['favorites'];
        // debugPrint("final menuItem = _menuItemBox.get(itemId); ${menuItem}");

        // 5. Save the updated object back to ObjectBox. This persists the change.
        _menuItemBox.put(menuItem);
        // debugPrint("final menuItem = _menuItemBox.get(itemId); ${_menuItemBox.get(itemId)}");
      });
    }
  }



  List<String> _extractCategories(List<MenuItem> items) {
    final categories = items
        .map((item) => item.category ?? "Other")
        .toSet()
        .toList();
    //categories.sort();
    categories.insert(0, "All"); // Always add "All" at top
    return categories;
  }

  void _filterCategory(String category) {
    _selectedCategory = category;
    _filterItems();
  }

  void _filterItems() {
    setState(() {
      _displayedItems = _menuItems.where((item) {
        final matchesCategory =
            _selectedCategory == "All" || item.category == _selectedCategory;
        final matchesSearch =
            _searchController.text.isEmpty ||
            (item.name?.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ) ??
                false);
        
        // NEW: Filter by favorites if _showFavoritesOnly is true
        final matchesFavorites = !_showFavoritesOnly || (item.favorites == true);
        
        return matchesCategory && matchesSearch && matchesFavorites;
      }).toList();
    });
  }

  void _updateQty(int id, bool isHalf, int change) {
    final controller = isHalf ? _halfControllers[id] : _fullControllers[id];
    if (controller == null) return;
    final current = int.tryParse(controller.text) ?? 0;
    final newVal = (current + change).clamp(0, 999);
    setState(() {
      controller.text = newVal.toString();
    });
  }

  Color _getCardColor(int id) {
    final half = int.tryParse(_halfControllers[id]?.text ?? "0") ?? 0;
    final full = int.tryParse(_fullControllers[id]?.text ?? "0") ?? 0;

    if (half > 0 && full > 0) return Colors.green;
    if (half > 0) return Colors.red;
    if (full > 0) return Colors.yellow;
    return Colors.white;
  }
    
  Widget _qtyRowWithButtons({
    required String label,
    required double price,
    required TextEditingController controller,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("$label ₹${price.toStringAsFixed(0)}"),
        Row(
          children: [
            // 🔴 Round Red Minus Button
            Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                onPressed: () {
                  int qty = int.tryParse(controller.text) ?? 0;
                  if (qty > 0) {
                    qty--;
                    setState(() => controller.text = qty.toString());
                  }
                },
              ),
            ),
            const SizedBox(width: 5),

            // ✏ Editable Quantity Field with Auto-Select
            SizedBox(
              width: 40,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  border: OutlineInputBorder(),
                ),
                onTap: () {
                  // Auto-select all text when tapped
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                },
                onChanged: (value) {
                  // Validate and clamp quantity between 0 and 99
                  final newQty = int.tryParse(value) ?? 0;
                  final clamped = newQty.clamp(0, 99);
                  if (clamped.toString() != value) {
                    controller.text = clamped.toString();
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  }
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 5),

            // 🟢 Round Green Plus Button
            Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: () {
                  int qty = int.tryParse(controller.text) ?? 0;
                  if (price > 0) {
                    qty = (qty + 1).clamp(0, 99);
                    setState(() => controller.text = qty.toString());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("❌ You cannot select a zero-price item."),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _buildPrinterCart() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    
    // Clear the cart first to avoid duplicates
    cartProvider.clearCart();

    for (var item in _menuItems) {
      final halfQty = int.tryParse(_halfControllers[item.id]?.text ?? "0") ?? 0;
      final fullQty = int.tryParse(_fullControllers[item.id]?.text ?? "0") ?? 0;

      // Skip unselected items
      if (halfQty == 0 && fullQty == 0) continue;

      // Add half item
      if (halfQty > 0) {
        final halfPrice = item.h_price;
        
        // Check if item already exists in cart
        final existingIndex = cartProvider.indexOfByName("${item.name} (Half)");
        
        if (existingIndex != -1) {
          // Update quantity for existing item
          final currentQty = cartProvider.cart[existingIndex]['qty'] ?? 0;
          cartProvider.updateQty(existingIndex, currentQty + halfQty);
        } else {
          // Add new item
          cartProvider.addItem({
            'id': item.id, // Make sure to include the ID
            'name': "${item.name ?? 'Item'} (Half)",
            'qty': halfQty,
            'sellPrice': halfPrice,
          });
        }
      }

      // Add full item
      if (fullQty > 0) {
        final fullPrice = item.f_price;
        
        // Check if item already exists in cart
        final existingIndex = cartProvider.indexOfByName("${item.name} (Full)");
        
        if (existingIndex != -1) {
          // Update quantity for existing item
          final currentQty = cartProvider.cart[existingIndex]['qty'] ?? 0;
          cartProvider.updateQty(existingIndex, currentQty + fullQty);
        } else {
          cartProvider.addItem({
            'id': item.id, // Make sure to include the ID
            'name': "${item.name ?? 'Item'}",
            'qty': fullQty,
            'sellPrice': fullPrice,
          });
        }
      }
    }

    return cartProvider.cart;
  }

  int _calculateTotal() {
    int total = 0;

    for (var item in _buildPrinterCart()) {
      // Parse quantity safely
      final int qty = item['qty'] is int
          ? item['qty'] as int
          : int.tryParse(item['qty'].toString()) ?? 0;

      // Parse sellPrice as num first, then to int
      final dynamic rawPrice = item['sellPrice'];
      final int sellPrice = rawPrice is num
          ? rawPrice.toInt()
          : int.tryParse(rawPrice.toString().replaceAll(',', '')) ??
                double.tryParse(rawPrice.toString())?.toInt() ??
                0;

      print("DEBUG => qty=$qty, sellPrice=$sellPrice"); // Check values

      total += qty * sellPrice;
    }

    return total;
  }

  @override
  void dispose() {
    for (var c in _halfControllers.values) c.dispose();
    for (var c in _fullControllers.values) c.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final imageHeightStr = prefs.getString("imageheight_key");
    final boxTextStr = prefs.getString("boxtext_key");
    miniPrinter = prefs.getBool('miniPrinter') ?? false;

    final imageHeightVal = int.tryParse(imageHeightStr ?? "") ?? 90;
    final boxTextVal = double.tryParse(boxTextStr ?? "") ?? 16;

    setState(() {
      imageHeight = imageHeightVal;
      TextSize = boxTextVal;
    });
  }


  

  String wrapTextByChar(String text, int charsPerLine) {
    List<String> lines = [];
    for (var i = 0; i < text.length; i += charsPerLine) {
      lines.add(text.substring(i, (i + charsPerLine).clamp(0, text.length)));
    }
    return lines.join('\n');
  }

    void _showPreviewAndPrint() {
    print(" in the _showPreviewAndPrint");
  
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: PrinterPreviewWidget(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final objectBox = Provider.of<ObjectBoxService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Row(
          children: [
            // Favorite icon on left side of search
            IconButton(
              icon: Icon(
                _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                color: _showFavoritesOnly ? Colors.red : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showFavoritesOnly = !_showFavoritesOnly;
                  _filterItems();
                });
              },
            ),
            const SizedBox(width: 4), // Add some spacing
            // Search field takes remaining space
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search Menu Items...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: const BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Only clear button in actions now
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _searchController.clear(),
          ),
        ],
      ),

    drawer: Drawer(
  child: Column(
    children: [
      const DrawerHeader(
        decoration: BoxDecoration(color: Colors.green),
        child: Center(
          child: Text(
            "Categories",
            style: TextStyle(color: Colors.white, fontSize: 22),
          ),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category;

            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _filterCategory(category);
              },
              child: Container(
                height: 60, // Fixed height for square-like look
                margin: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.green.shade700 : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  ),
),
body: _displayedItems.isEmpty
    ? const Center(child: Text("No items found"))
    : ListView.builder(
        padding: const EdgeInsets.only(bottom: 80.0),
        itemCount: _displayedItems.length,
        itemBuilder: (context, index) {
          final item = _displayedItems[index];
          final imagePath =
              "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/${item.name}.jpeg";
          final halfPrice = double.tryParse((item.h_price ?? "0").toString()) ?? 0.0;
          final priceToUse = (item.sellPrice != null && item.sellPrice != "0") 
              ? item.sellPrice 
              : item.f_price ?? "0";
          final fullPrice = double.tryParse(priceToUse.toString()) ?? 0.0;
          
          final hasSelection = 
              (int.tryParse(_halfControllers[item.id]?.text ?? "0") ?? 0) > 0 ||
              (int.tryParse(_fullControllers[item.id]?.text ?? "0") ?? 0) > 0;

          return Stack(
            children: [
              Card(
                color: hasSelection 
                    ? const Color.fromARGB(255, 175, 217, 237)   // ✅ Light blue highlight
                    : Colors.white,               // Default background
                margin: const EdgeInsets.all(8),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imagePath),
                          width: imageHeight.toDouble(),
                          height: imageHeight.toDouble(),
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: imageHeight.toDouble(),
                              height: imageHeight.toDouble(),
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image_not_supported),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // ✅ Item Details + Quantity Controls
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      item.name ?? "Unnamed",
                                      style: TextStyle(
                                        fontSize: TextSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasSelection)
                                  InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      setState(() {
                                        _halfControllers[item.id]?.text = "0";
                                        _fullControllers[item.id]?.text = "0";
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(0),
                                      child: Icon(Icons.close, size: 20),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            // ✅ Half Quantity Row (show only if price > 0)
                            if (halfPrice > 0)
                              _qtyRowWithButtons(
                                label: "Half",
                                price: halfPrice,
                                controller: _halfControllers[item.id]!,
                              ),

                            // ✅ Full Quantity Row (always shown, but handles its own price check for +)
                            _qtyRowWithButtons(
                              label: "Full",
                              price: fullPrice,
                              controller: _fullControllers[item.id]!,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

             // ✅ Favorite Icon in the top-left corner - SIMPLE APPROACH
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    // Toggle directly on the MenuItem
                    item.favorites = !(item.favorites ?? false);
                    _menuItemBox.put(item); // Save to database
                    
                    // Update the main list as well
                    final mainIndex = _menuItems.indexWhere((element) => element.id == item.id);
                    if (mainIndex != -1) {
                      _menuItems[mainIndex].favorites = item.favorites;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.favorites == true 
                        ? Icons.favorite 
                        : Icons.favorite_border,
                    color: item.favorites == true 
                        ? Colors.red 
                        : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            ],
          );
        },
      ),
      
      
      
      
      floatingActionButton: (widget.mode == 'edit')
        ? FloatingActionButton.extended(
            onPressed: () {
              // 1. Get the newly selected/modified items from the current page
              final newOrModifiedItems = _buildPrinterCart();
              // 2. Get the original cart from the provider
              final originalCart = (widget.cart1 as List).cast<Map<String, dynamic>>();
              // 3. Merge the two carts using a Map to handle updates and prevent duplicates
              final Map<String, Map<String, dynamic>> mergedCartMap = {};
              // Add original items to the map first
              for (final item in originalCart) {
                // Create a unique key for each item (e.g., "1_half", "1_full")
                final id = item['id'];
                final isHalf = (item['name'] as String).contains('(Half)');
                final key = '${id}_${isHalf ? 'half' : 'full'}';
                mergedCartMap[key] = item;
              }

              // Add/update with new items. If a key already exists, its value is overwritten.
              for (final item in newOrModifiedItems) {
                final id = item['id'];
                final isHalf = (item['name'] as String).contains('(Half)');
                final key = '${id}_${isHalf ? 'half' : 'full'}';
                mergedCartMap[key] = item;
              }
              
              // 4. Convert the map back to a list, filtering out any items that now have a quantity of 0
              final finalCart = mergedCartMap.values.where((item) {
                    final qty = item['qty'] is num
                        ? (item['qty'] as num).toInt()
                        : int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
                    return qty > 0;
              }).toList();


              // 5. Check if the final cart is empty before navigating
              if (finalCart.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No items selected")),
                );
                return;
              }


              final formattedCart = newOrModifiedItems.map((item) {
  final id = item['id'];
  final name = item['name']?.toString() ?? 'Unknown Item';
  final qty = item['qty'] is num
      ? (item['qty'] as num).toInt()
      : int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
  final sellPrice = item['sellPrice'] is num
      ? (item['sellPrice'] as num).toDouble()
      : double.tryParse(item['sellPrice']?.toString() ?? '0') ?? 0.0;

  // Detect portion type (Half/Full)
  final portion = name.toLowerCase().contains('(half)') ? 'Half' : 'Full';

  // Calculate total
  final total = qty * sellPrice;

  return {
    'id': id,
    'name': name,
    'sellPrice': sellPrice,
    'qty': qty,
    'portion': portion,
    'total': total,
  };
}).toList();

// ✅ POP THE PAGE AND RETURN THE FORMATTED CART
Navigator.pop(context, formattedCart);



              // Get the final list of items the user has selected
              //final finalCart = _buildPrinterCart();

              // ✅ POP THE PAGE AND RETURN THE FINAL CART AS THE RESULT
              //Navigator.pop(context, finalCart);

              // 6. Navigate to the DetailPage with the correctly merged and updated cart
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (_) => DetailPage(
              //       cart1: finalCart,
              //       mode: "edit",
              //     ),
              //   ),
              // );
            },
            label: const Text("Add Items"),
            icon: const Icon(Icons.add_shopping_cart), // Changed icon for clarity
          ) : FloatingActionButton.extended(
          onPressed: () {
            

              final newOrModifiedItems = _buildPrinterCart();
              
             

              // 🧾 Transform finalCart into desired structure
final formattedCart = newOrModifiedItems.map((item) {
  final id = item['id'];
  final name = item['name']?.toString() ?? 'Unknown Item';
  final qty = item['qty'] is num
      ? (item['qty'] as num).toInt()
      : int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
  final sellPrice = item['sellPrice'] is num
      ? (item['sellPrice'] as num).toDouble()
      : double.tryParse(item['sellPrice']?.toString() ?? '0') ?? 0.0;

  // Detect portion type (Half/Full)
  final portion = name.toLowerCase().contains('(half)') ? 'Half' : 'Full';

  // Calculate total
  final total = qty * sellPrice;

  return {
    'id': id,
    'name': name,
    'sellPrice': sellPrice,
    'qty': qty,
    'portion': portion,
    'total': total,
  };
}).toList();

// ✅ POP THE PAGE AND RETURN THE FORMATTED CART
//Navigator.pop(context, formattedCart);


            
            
            final printerCart = formattedCart;

            debugPrint("printerCart $printerCart ");
            final total = _calculateTotal();

            if (printerCart.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("No items selected")));
              return;
            }

            String selectedPayment = "CASH";

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    // ✅ ValueNotifier for immediate button disable
                    final isPrintingNotifier = ValueNotifier<bool>(false);

                    Widget buildButton({
                      required IconData icon,
                      required String label,
                      required Future<void> Function() onPressed,
                    }) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: isPrintingNotifier,
                        builder: (context, isPrinting, _) {
                          return ElevatedButton.icon(
                            // --- Moved from the nested button ---
                            onPressed: isPrinting
                                ? null // Button is disabled while printing
                                : () async {
                                    isPrintingNotifier.value = true;
                                    
                                    // Ensure 'onPressed' is the correct function to call, e.g., widget.onPressed
                                    try{
                                      await onPressed(); 
                                    } catch (e) {
                                          debugPrint("got error at the on press $e");
                                    }
                                    
                                    isPrintingNotifier.value = false;
                                  },
                            icon: isPrinting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(icon), // Assumes 'icon' is a variable in your scope
                            label: Text(isPrinting ? "Processing..." : label), // Assumes 'label' is a variable
                          );
                        },
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 50,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const Text(
                            "Print Cart",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cart list
                          SizedBox(
                            height: 250,
                            child: ListView.builder(
                              itemCount: printerCart.length,
                              itemBuilder: (context, index) {
                                final item = printerCart[index];
                                final qty = item['qty'] is num
                                    ? (item['qty'] as num).toInt()
                                    : int.tryParse(
                                            item['qty']?.toString() ?? '0',
                                          ) ??
                                          0;
                                final price = item['sellPrice'] is num
                                    ? (item['sellPrice'] as num).toDouble()
                                    : double.tryParse(
                                            item['sellPrice']?.toString() ?? '0',
                                          ) ??
                                          0.0;
                                final lineTotal = qty * price;

                                return ListTile(
                                  title: Text(item['name'] ?? 'Unnamed Item'),
                                  subtitle: Text(
                                    "Qty: $qty × ₹${price.toStringAsFixed(2)}",
                                  ),
                                  trailing: Text(
                                    "₹${lineTotal.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const Divider(),

                          // Total & payment
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Total: ₹${total.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ChoiceChip(
                                label: const Text("Cash"),
                                selected: selectedPayment == "CASH",
                                selectedColor: Colors.green,
                                onSelected: (_) {
                                  setModalState(() => selectedPayment = "CASH");
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text("UPI"),
                                selected: selectedPayment == "UPI",
                                selectedColor: Colors.green,
                                onSelected: (_) {
                                  setModalState(() => selectedPayment = "UPI");
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: buildButton(
                                  icon: Icons.print,
                                  label: "KOT",
                                  onPressed: () async {
                                    debugPrint("printerCart $printerCart");
                                    debugPrint("miniPrinter $miniPrinter");
                                    if (miniPrinter) {
                                      _showPreviewAndPrint();
                                    }else{
                                      await printer.printCart(
                                        context: context,
                                        cart1: printerCart,
                                        total: total,
                                        mode: "print",
                                        payment_mode: "KOT",
                                       transactionData:{"billNo": BillService.getNextBillNo(objectBox.store), "serviceCharge": 0.0},
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildButton(
                                  icon: Icons.print,
                                  label: "Print",
                                  onPressed: () async {
                                    debugPrint("printerCart $printerCart");
                                    debugPrint("miniPrinter $miniPrinter");
                                    if (miniPrinter) {
                                      _showPreviewAndPrint();
                                    }else{
                                      await printer.printCart(
                                        context: context,
                                        cart1: printerCart,
                                        total: total,
                                        mode: "print",
                                        payment_mode: "print",
                                        transactionData:{"billNo": BillService.getNextBillNo(objectBox.store), "serviceCharge": 0.0},
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildButton(
                                  icon: Icons.done_all,
                                  label: "Print & Settle",
                                  onPressed: () async {
                                    await printer.printCart(
                                      context: context,
                                      cart1: printerCart,
                                      total: total,
                                      mode: "settle1",
                                      payment_mode: selectedPayment,
                                      transactionData:{"billNo": BillService.getNextBillNo(objectBox.store), "serviceCharge": 0.0},
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
          label: const Text("Print Cart"),
          icon: const Icon(Icons.print),
        ),
    );
  }

  Future<bool> _askPassword(BuildContext context) async {
    final TextEditingController _pwdController = TextEditingController();
    bool verified = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Enter Password"),
          content: TextField(
            controller: _pwdController,
            keyboardType: TextInputType.number, // 🔑 Number keypad
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Password",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // cancel
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final savedPwd = await getSavedPassword();

                if (_pwdController.text == savedPwd) {
                  verified = true;
                  Navigator.pop(ctx); // ✅ close only if correct
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text("❌ Password is wrong"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );

    return verified;
  }

  // Function to read password from SharedPreferences
  Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_password'); // 🔑 key for password
  }
}
