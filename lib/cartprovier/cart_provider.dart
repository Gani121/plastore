import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _cart = [];

  List<Map<String, dynamic>> get cart => _cart;

  // Add this to track selected items
  final Set<int> _selectedItemIds = {};
  Set<int> get selectedItemIds => _selectedItemIds;

  int get total => _cart.fold(0, (sum, item) {
    // int price = int.tryParse(item['sellPrice'] ?? '') ?? 0;
    // int qty = item['qty'] ?? 0;
    int total = ((item['total'] ?? 0) as num).toInt();
    return sum + total;
  });

  // Check if cart is empty
  bool get isCartEmpty => _cart.isEmpty;

  // Get item count
  int get itemCount => _cart.length;

  void updateHalfPrice(int index, double price) {
    if (index >= 0 && index < cart.length) {
      cart[index]['h_price'] = price;
      notifyListeners();
    }
  }

  Future<void> loadCartIfEmpty(String cart) async {
    if (_cart.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(cart);
      if (data != null && data.isNotEmpty) {
        _cart.clear();
        _cart = List<Map<String, dynamic>>.from(jsonDecode(data));
        debugPrint("✅ Restored cart with ${_cart.length} items");
        notifyListeners();
      }
    }
  }

  void addItem(Map<String, dynamic> item) {
    _cart.add(item);
    _selectedItemIds.add(item['id']);
    notifyListeners();
  }

  // Add item to cart
  void addToCart(
    Map<String, dynamic> item,
    String portion,
    double price, {
    int? tableNo,
  }) {
    try {
      final key = _getKey(tableNo);
      // final prefs = await SharedPreferences.getInstance();

      // Create cart item
      final Map<String, dynamic> cartItem;

      if (portion.toLowerCase() == 'half') {
        cartItem = {
          'id': item['id'],
          'name': "${item['name']} (Half)",
          'sellPrice': price,
          'qty': item['h_qty'] ?? 1,
          'portion': 'half',
          'total': (item['h_qty'] ?? 1) * price,
        };
      } else {
        cartItem = {
          'id': item['id'],
          'name': item['name'],
          'sellPrice': price,
          'qty': item['qty'] ?? 1,
          'portion': 'full',
          'total': (item['qty'] ?? 1) * price,
        };
      }

      // final String? existingCartJson = prefs.getString(key);
      // List<Map<String, dynamic>> cartList = [];

      // if (existingCartJson != null && existingCartJson.isNotEmpty) {
      //   try {
      //     final List<dynamic> decodedList = jsonDecode(existingCartJson);
      //     cartList = decodedList.map<Map<String, dynamic>>((item) =>
      //       Map<String, dynamic>.from(item)
      //     ).toList();
      //   } catch (e) {
      //     if (kDebugMode) {
      //       print('Error decoding cart: $e');
      //     }
      //     cartList = [];
      //   }
      // }

      // Check if item already exists in cart (same ID and portion)
      bool itemExists = false;
      // debugPrint("cart item to set item is $cartItem");
      for (int i = 0; i < _cart.length; i++) {
        if (_cart[i]['id'] == cartItem['id'] && _cart[i]['portion'] == cartItem['portion'] && _cart[i]['name'] == cartItem['name']) {
          _cart[i]['qty'] = cartItem['qty'];
          _cart[i]['total'] = cartItem['total'];

          itemExists = true;
          break;
        }
      }

      // If item doesn't exist, add it to cart
      // debugPrint("asdfghjkl1");
      if (!itemExists) {
        // debugPrint("asdfghjkl2");
        // Find the last index of an item with the same base name to group them.
        final newName = cartItem['name'] as String;
        final baseName = newName.contains('_') ? newName.substring(0, newName.lastIndexOf('_')) : newName;
        // debugPrint("asdfghjkl3");
        final count = (_cart.where((cartItem) => (cartItem['name'] as String).startsWith(baseName)).length) - 1;
        // debugPrint("asdfghjkl4");
        final baseName1 = count > 0  ? newName.substring(0, newName.lastIndexOf('_')) + '_${count}': newName.split("_")[0];
        // debugPrint("asdfghjkl5");
        

        // debugPrint("asdfghjkl5");
        int index = -1;
        for(int i = 0; i < _cart.length; i++){
            // debugPrint("asdfghjkl ${_cart[i]['name']} $baseName1");
            // debugPrint("asdfghjkl ${_cart[i]['name'] == baseName1 } $i");
            if(_cart[i]['name'] == baseName1){
              index = i;
              break;
            }
        }

        // debugPrint("asdfghjkl6;${count} $newName ${count > 0} $index $baseName $baseName1 ");

        if (index != -1) {
          // If found, insert the new item right after the last one.
          _cart.insert(index +1, cartItem);
          if (kDebugMode) {
            debugPrint('Cart inserted successfully. Total items: ${_cart}');
          }
        } else {
          // debugPrint("asdfghjkl add item");
          // Otherwise, add it to the end of the list.
          _cart.add(cartItem);
          if (kDebugMode) {
            debugPrint('Cart added successfully. Total items: ${_cart}');
          }
        }
      }
      // _cart.add(cartItem);

      // debugPrint("cart item to set item is $item");

      // Save updated cart

      // final String updatedCartJson = jsonEncode(cartList);
      // await prefs.setString(key, updatedCartJson);

      // Update local state
      // _cart.add(_cart);
      notifyListeners();

      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('\x1B[31m Error saving cart: $e \x1B[0m');
      }
    }
  }

  void removeItemByName(String name) {
    // First find the item to get its ID
    final itemToRemove = _cart.firstWhere(
      (item) => item['name'] == name,
      orElse: () => {},
    );

    if (itemToRemove.isNotEmpty && itemToRemove.containsKey('id')) {
      // Remove from both cart and selected IDs
      _cart.removeWhere((item) => item['name'] == name);
      _selectedItemIds.remove(itemToRemove['id']);
      notifyListeners();
    }
  }

  int indexOfByName(String name) {
    return cart.indexWhere(
      (item) =>
          item['name'] == name ||
          (item['displayName']?.replaceAll(' (Half)', '') == name),
    );
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  void updateQty(int index, int qty) {
    _cart[index]['qty'] = qty;
    notifyListeners();
  }

  void removeItem(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  void removeFromCart(String name, String portion, {int? tableNo}) {
    try {
      // Convert both to lowercase for case-insensitive comparison
      final targetPortion = portion.toLowerCase().trim();
      //debugPrint(" $id $targetPortion");

      _cart.removeWhere((item) {
        final itemName = item['name'];
        final itemPortion = (item['portion']?.toString() ?? '')
            .toLowerCase()
            .trim();
        debugPrint(" $itemName $itemPortion");
        return itemName == name && itemPortion == targetPortion;
      });

      notifyListeners();
      debugPrint('Item removed from cart. Remaining items: ${_cart}');
    } catch (e) {
      debugPrint('Error removing item from cart: $e');
    }
  }

  // void setCart(List<Map<String, dynamic>> newCart) {
  //   _cart = newCart;
  //   notifyListeners();
  // }

  void updatePrice(int index, double price) {
    _cart[index]['sellPrice'] = price;
    notifyListeners();
  }

  // Update item quantity in cart
  void updateQuantity(
    int id,
    int newQty,
    double sellPrice,
    String itemName,
    String portion, 
    {int? tableNo, }
    ) async {
    
    // 1. TRY TO FIND AND UPDATE THE ITEM
    for (int i = 0; i < _cart.length; i++) {
      if (_cart[i]['name'] == itemName && (_cart[i]['portion'].toString()).toLowerCase() == portion.toLowerCase()) {
        _cart[i]['qty'] = newQty;
        _cart[i]['total'] = _cart[i]['sellPrice'] * newQty;
        debugPrint("Updated item in cart: $_cart");
        notifyListeners();
        return; 
      }
    }

    // Don't add an item with 0 or less quantity
    if (newQty <= 0) {
      return;
    }

    // We must have the price and name to add a new item
    if (sellPrice == null || itemName == null) {
      debugPrint("Error: Cannot add new item. Price or name not provided.");
      return;
    }
    final Map<String, dynamic> cartItem;

    if (portion.toLowerCase() == 'half') {
        cartItem = {
          'id': id,
          'name': "${itemName} (Half)",
          'qty': newQty,
          'portion': portion.toLowerCase(),
          'sellPrice': sellPrice,
          'total': sellPrice * newQty,
        };
      } else {
        cartItem = {
          'id': id,
          'name': itemName,
          'qty': newQty,
          'portion': portion.toLowerCase(),
          'sellPrice': sellPrice,
          'total': sellPrice * newQty,
        };
      }


    _cart.add(cartItem);
    debugPrint("Added new item to cart: $_cart");
    notifyListeners();
  }

    // Update item price in cart
  void updatePricePortion(
    String name,
    int newPrice,
    String portion, {
    int? tableNo,
  }) async {
    for (int i = 0; i < _cart.length; i++) {
      if (_cart[i]['name'] == name &&
          (_cart[i]['portion'].toString()).toLowerCase() ==
              portion.toLowerCase()) {
        // Update quantity if item exists
        _cart[i]['sellPrice'] = newPrice;
        _cart[i]['total'] = _cart[i]['qty'] * newPrice;
        notifyListeners();
        break;
      }
    }
  }

  // // Load external cart data
  // void setCart(dynamic cartData, {int? tableNo}) {
  //   // final key = _getKey(tableNo);
  //   // final prefs = await SharedPreferences.getInstance();

  //   try {
  //     // final String cartJson = jsonEncode(cartData);
  //     // await prefs.setString(key, cartJson);

  //     // Update local state
  //     // _cart.clear();
  //     debugPrint('\x1B[31m (cartData is List<Map<String, dynamic>>) ${(cartData is List<Map<String, dynamic>>)} \x1B[0m');
  //     if(cartData is List<Map<String, dynamic>>){
  //       _cart = List.from(cartData);
  //     } else {
  //       if(cartData is String){
  //         final decodedList = jsonDecode(cartData) as List<dynamic>;
  //         final existingCart = decodedList.map((item) => item as Map<String, dynamic>).toList();
  //         _cart = List.from(existingCart);
  //       }else {
  //         _cart = List<Map<String, dynamic>>.from(cartData);
  //       }
  //     }

  //     notifyListeners();

  //     if (kDebugMode) {
  //       debugPrint('External cart data loaded. Items: ${cartData.length}');
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       debugPrint('Error loading external cart: $e');
  //     }
  //   }
  // }


  /// give string list map
  void setCart(dynamic cartData, {int? tableNo}) {
    // final key = _getKey(tableNo);
    // final prefs = await SharedPreferences.getInstance();

    try {
      List<dynamic> sourceList;

      // --- 1. Determine the source list ---

      if (cartData == null) {
        // Handle null input by setting an empty cart
        sourceList = [];
      } else if (cartData is String) {
        // If it's a string, decode it
        if (cartData.isEmpty) {
          sourceList = [];
        } else {
          sourceList = jsonDecode(cartData) as List<dynamic>;
        }
      } else if (cartData is List) {
        // If it's already a list (e.g., List<dynamic>), use it directly
        sourceList = cartData;
      } else if (cartData is List<Map<String, dynamic>>) {
        sourceList = cartData;
      } 
      else {
        // Handle unsupported types
        throw FormatException('Unsupported cartData type: ${cartData.runtimeType}');
      }

      // --- 2. Safely convert the source list to List<Map<String, dynamic>> ---

      final List<Map<String, dynamic>> newCart = sourceList
          .map((item) {
            // Ensure each item is a Map before converting
            if (item is Map) {
              // Map.from() is safer than 'as'.
              // It correctly handles Map<dynamic, dynamic> from jsonDecode
              // and creates a new Map<String, dynamic>.
              return Map<String, dynamic>.from(item);
            } else {
              // Log a warning if an item in the list is not a map
              if (kDebugMode) {
                final message = 'Warning: Non-map item found in cart data: $item';
                debugPrint('\x1B[31m $message \x1B[0m');
              }
              return null; // This item will be filtered out
            }
          })
          .whereType<Map<String, dynamic>>() // Filter out any nulls
          .toList();

      // --- 3. Update state and notify ---

      _cart = newCart; // Assign the newly created list
      notifyListeners();

      if (kDebugMode) {
        final message = 'External cart data loaded. Items: ${_cart.length}';
        debugPrint('\x1B[31m $message \x1B[0m');
      }
    } catch (e) {
      if (kDebugMode) {
        final message = 'Error loading external cart: $e. Input: "$cartData"';
        debugPrint('\x1B[31m $message \x1B[0m');
      }
      // Optionally, reset the cart to a safe state
      // _cart = [];
      // notifyListeners();
    }
  }

  // Get total
  int getTotal({int? tableNo}) {
    Future.delayed(const Duration(milliseconds: 100));
    // final key = _getKey(tableNo);
    // final prefs = await SharedPreferences.getInstance();
    // final String? cartJson = prefs.getString(key);

    // if (cartJson == null || cartJson.isEmpty) {
    //   return 0;
    // }

    int total = 0;
    try {
      // final List<dynamic> decodedList = jsonDecode(cartJson);
      // final cartList = decodedList.map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item)).toList();
      for (var item in _cart) {
        total = total + (item['total'] as num).toInt();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating total: $e');
      }
      return 0;
    }

    if (kDebugMode) {
      debugPrint('Cart total calculated: $total');
    }
    return total;
  }

  // Get item by ID and portion
  Map<String, dynamic>? getItemByIdAndPortion(int id, String portion) {
    try {
      return _cart.firstWhere(
        (item) =>
            item['id'] == id &&
            (item['portion'].toString()).toLowerCase() == portion.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Helper method to get the storage key
  String _getKey(int? tableNo) {
    return tableNo == null ? 'cart' : 'cart$tableNo';
  }

    // Update item price in cart
  void updateNote(
    int id,
    String portion,
    String note,
    ) async {
    for (int i = 0; i < _cart.length; i++) {
      if (_cart[i]['id'] == id && (_cart[i]['portion'].toString()).toLowerCase() == portion.toLowerCase()) {
        // Update quantity if item exists
        _cart[i]['note'] = note;
        notifyListeners();
        break;
      }
    }
  }

  // Save current cart to SharedPreferences
  void saveCartToPrefs({int? tableNo}) async {
    final key = _getKey(tableNo);
    final prefs = await SharedPreferences.getInstance();
    try {
      final String cartJson = jsonEncode(_cart);
      await prefs.setString(key, cartJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving cart to prefs: $e');
      }
    }
  }

  // Get current cart From SharedPreferences
  void getCartFromPrefs({int? tableNo}) async {
    final key = _getKey(tableNo);
    final prefs = await SharedPreferences.getInstance();
    try {
      // final String cartJson = jsonEncode(_cart);
      final tablecart = await prefs.getString(key);
      if(tablecart != null){
        _cart = jsonDecode(tablecart);
      } else {
        _cart = [];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving cart to prefs: $e');
      }
    }
  }

  
}
