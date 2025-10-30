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
          'portion': 'Half',
          'total': (item['h_qty'] ?? 1) * price,
        };
      } else {
        cartItem = {
          'id': item['id'],
          'name': item['name'],
          'sellPrice': price,
          'qty': item['qty'] ?? 1,
          'portion': 'Full',
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
        if (_cart[i]['id'] == cartItem['id'] &&
            _cart[i]['portion'] == cartItem['portion']) {
          _cart[i]['qty'] = cartItem['qty'];
          _cart[i]['total'] = cartItem['total'];

          itemExists = true;
          break;
        }
      }

      // If item doesn't exist, add it to cart
      if (!itemExists) {
        _cart.add(cartItem);
        // _selectedItemIds.add(cartItem['id']);
      }

      // debugPrint("cart item to set item is $item");

      // Save updated cart

      // final String updatedCartJson = jsonEncode(cartList);
      // await prefs.setString(key, updatedCartJson);

      // Update local state
      // _cart.add(_cart);
      notifyListeners();

      if (kDebugMode) {
        debugPrint('Cart updated successfully. Total items: ${_cart}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving cart: $e');
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

  void removeFromCart(int id, String portion, {int? tableNo}) {
    try {
      // Convert both to lowercase for case-insensitive comparison
      final targetPortion = portion.toLowerCase().trim();
      //debugPrint(" $id $targetPortion");

      _cart.removeWhere((item) {
        final itemId = item['id'];
        final itemPortion = (item['portion']?.toString() ?? '')
            .toLowerCase()
            .trim();
        debugPrint(" $itemId $itemPortion");
        return itemId == id && itemPortion == targetPortion;
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
    String portion, {
    int? tableNo,
  }) async {
    for (int i = 0; i < _cart.length; i++) {
      if (_cart[i]['id'] == id &&
          (_cart[i]['portion'].toString()).toLowerCase() ==
              portion.toLowerCase()) {
        // Update quantity if item exists
        _cart[i]['qty'] = newQty;
        _cart[i]['total'] = _cart[i]['sellPrice'] * newQty;
        debugPrint("_cart $_cart");
        notifyListeners();
        break;
      }
    }
  }

    // Update item price in cart
  void updatePricePortion(
    int id,
    int newPrice,
    String portion, {
    int? tableNo,
  }) async {
    for (int i = 0; i < _cart.length; i++) {
      if (_cart[i]['id'] == id &&
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

  // Load external cart data
  void setCart(List<Map<String, dynamic>> cartData, {int? tableNo}) {
    // final key = _getKey(tableNo);
    // final prefs = await SharedPreferences.getInstance();

    try {
      // final String cartJson = jsonEncode(cartData);
      // await prefs.setString(key, cartJson);

      // Update local state
      _cart = List.from(cartData);
      notifyListeners();

      if (kDebugMode) {
        print('External cart data loaded. Items: ${cartData.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading external cart: $e');
      }
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
        print('Error calculating total: $e');
      }
      return 0;
    }

    if (kDebugMode) {
      print('Cart total calculated: $total');
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

  // Save current cart to SharedPreferences
  void _saveCartToPrefs({int? tableNo}) async {
    final key = _getKey(tableNo);
    final prefs = await SharedPreferences.getInstance();
    try {
      final String cartJson = jsonEncode(_cart);
      await prefs.setString(key, cartJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving cart to prefs: $e');
      }
    }
  }
}
