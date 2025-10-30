import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import 'dart:convert';
import 'dart:io';



// Get cart items
Future<List<Map<String, dynamic>>> getCartItems({int? tableNo}) async {
  // await Future.delayed(Duration(milliseconds: 1000)); 
  final key;
  if (tableNo == null){
    key = 'cart';
  }else{
    key = 'cart$tableNo';
  }
  final prefs = await SharedPreferences.getInstance();
  final String? cartJson = prefs.getString(key);
  if (cartJson == null || cartJson.isEmpty) {
    return [];
  }
  
  try {
    final List<dynamic> decodedList = jsonDecode(cartJson);
    print('Error getting cart items: G $decodedList');
    return decodedList.map<Map<String, dynamic>>((item) => 
      Map<String, dynamic>.from(item)
    ).toList();
  } catch (e) {
    print('Error getting cart items: $e');
    return [];
  }
}

// Clear cart
Future<void> clearCart({int? tableNo}) async {
  final key;
  if (tableNo == null){
    key = 'cart';
  }else{
    key = 'cart$tableNo';
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}

// Remove item from cart
Future<void> removeFromCart(int id, String portion,{int? tableNo}) async {
  final prefs = await SharedPreferences.getInstance();
  final key;
  if (tableNo == null){
    key = 'cart';
  }else{
    key = 'cart$tableNo';
  }
  final String? existingCartJson = prefs.getString(key);
  
  if (existingCartJson == null || existingCartJson.isEmpty) {
    return;
  }
  
  try {
    final List<dynamic> decodedList = jsonDecode(existingCartJson);
    final List<Map<String, dynamic>> cartList = decodedList.map<Map<String, dynamic>>((item) => 
      Map<String, dynamic>.from(item)
    ).toList();
    
    cartList.removeWhere((item) => 
      item['id'] == id && (item['portion'].toString()).toLowerCase() == portion.toLowerCase()
    );
    
    final String updatedCartJson = jsonEncode(cartList);
    print('Error getting cart items: R $cartList');
    await prefs.setString(key, updatedCartJson);
  } catch (e) {
    print('Error removing item from cart: $e');
  }
}

Future<int> getTotal({int? tableNo}) async {
  await Future.delayed(Duration(milliseconds: 100)); 
  final key;
  if (tableNo == null){
    key = 'cart';
  }else{
    key = 'cart$tableNo';
  }
  final prefs = await SharedPreferences.getInstance();
  final String? cartJson = prefs.getString(key);

  if (cartJson == null || cartJson.isEmpty) {
    return 0;
  }
  int total = 0;
  try {
    final List<dynamic> decodedList = jsonDecode(cartJson);
    final _cartList = decodedList.map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item)).toList();
    for (var item in _cartList){
        total = total + (item['total'] as num).toInt();
    }
  } catch (e) {
    print('Error getting cart items: $e');
    return 0;
  }
  print('Error getting cart items: T $total');
  return total;
}

