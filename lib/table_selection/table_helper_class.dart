// lib/table_helper_class.dart
import '../objectbox.g.dart';
import './tabledata.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class table_helper_class  extends ChangeNotifier {
  late final Store _store;
  
  late final Box<Active_Table_view> _tableBox;
  late final Box<CartItem> _cartItemBox; // For cart items
  late final Box<OrderItem> _orderItemBox; // For order history

  table_helper_class(this._store) {
    _tableBox = Box<Active_Table_view>(_store);
    _cartItemBox = Box<CartItem>(_store);
    _orderItemBox = Box<OrderItem>(_store);
  }

  // --- Active_Table_view MANAGEMENT ---
  void addTable(Active_Table_view activeTableView) {
    _tableBox.put(activeTableView);
    notifyListeners(); // <-- ADD THIS
  }

  void deleteTable(int tableId) {
    _tableBox.remove(tableId);
    notifyListeners(); // <-- ADD THIS
  }

  List<Active_Table_view> getAllTables() {
    return _tableBox.getAll();
  }

    /// Finds a table by its ID, updates its payment method, and saves it.
  void updateTablePaymentMethod(int tableId, String newMethod) {
    // 1. Get the specific table object from the database using its ID
    final table = _tableBox.get(tableId);

    // 2. Check if the table exists
    if (table != null) {
      // 3. Modify the property
      table.paymentMethod = newMethod; // Assuming your entity has this field

      // 4. Save the updated object back to the database
      _tableBox.put(table);

      // 5. Notify all listening widgets that data has changed
      notifyListeners();
    }
  }


  // --- CART MANAGEMENT FUNCTIONS ---

  /// Adds a menu item to cart or increments quantity if it already exists
  // void addToCart(MenuItem menuItem) {
  //   // Query for existing cart item with the same menu item
  //   final query = _cartItemBox
  //       .query(CartItem_.menuItem.equals(menuItem.id))
  //       .build();
    
  //   final existingCartItem = query.findFirst();
  //   query.close();

  //   if (existingCartItem != null) {
  //     // Increment quantity if already in cart
  //     existingCartItem.quantity++;
  //     _cartItemBox.put(existingCartItem);
  //   } else {
  //     // Create new cart item
  //     final newCartItem = CartItem(
  //       name: menuItem.name,
  //       price: menuItem.price,
  //       quantity: 1,
  //     );
  //     newCartItem.menuItem.target = menuItem;
  //     _cartItemBox.put(newCartItem);
  //   }
  // }

  /// Gets all items currently in the cart
  List<CartItem> getCartItems() {
    return _cartItemBox.getAll();
  }

  /// Updates cart item quantity
  void updateCartItemQuantity(int cartItemId, int newQuantity) {
    final cartItem = _cartItemBox.get(cartItemId);
    if (cartItem != null) {
      if (newQuantity <= 0) {
        _cartItemBox.remove(cartItemId);
      } else {
        cartItem.quantity = newQuantity;
        _cartItemBox.put(cartItem);
      }
    }
  }

  /// Removes a single item from the cart by its ID
  void removeFromCart(int cartItemId) {
    _cartItemBox.remove(cartItemId);
  }

  /// Clears all items from the cart
  void clearCart() {
    _cartItemBox.removeAll();
  }


  // --- ORDER MANAGEMENT ---
  // void createOrderFromCart(Active_Table_view Active_Table_view, List<CartItem> cartItems) {
  //   for (final cartItem in cartItems) {
  //     final orderItem = OrderItem(
  //       name: cartItem.name,
  //       quantity: cartItem.quantity,
  //       price: cartItem.price,
  //     );
  //     orderItem.Active_Table_view.target = Active_Table_view;
  //     _orderItemBox.put(orderItem);
  //   }
    
  //   // Clear cart after creating order
  //   clearCart();
  // }

  // Close the store when done
  void close() {
    _store.close();
  }

  








}