
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/utilities.dart';
import '../objectbox.g.dart';
import 'package:provider/provider.dart';
import '../database_Module/ObjectBoxService.dart';
import 'package:http/http.dart' as http;
import '../purchase/purchase_invoice_page.dart';
import 'package:test1/database_Module/supplier_database.dart';
import 'package:test1/database_Module/cunsuption.dart';
import 'package:test1/database_Module/expensDB.dart';
import 'package:test1/database_Module/menu_item.dart';
import 'package:test1/pages/PartyListPage.dart';
import 'package:test1/inventory/inventory_page.dart';

class ExpensesService {
  static final ValueNotifier<double> totalExpensesNotifier =
      ValueNotifier<double>(0.0);

  static Future<void> updateTotal(double newTotal) async {
    totalExpensesNotifier.value = newTotal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalExpenses', newTotal);
  }

  static Future<double> getTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('totalExpenses') ?? 0.0;
  }

  // Method to get date range total from any page
  static Future<Map<String,dynamic>> getDateRangeTotal(
    DateTime startDate,
    DateTime endDate,
    List<expences> expensesJson
  ) async {
    try {
      List<String> expensesmap = [];

      final normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      );

      double total = 0.0;

      for (final expenseJson in expensesJson) {
        try {
          // print_log("expense ${expenseJson.expence.toString()}");
          final map = Map<String, dynamic>.from(jsonDecode(expenseJson.expence));
          final expense = Expense.fromMap(map);

          // Check if expense falls within the date range
          if ((expense.date.isAfter(normalizedStart) || expense.date.isAtSameMomentAs(normalizedStart)) && (expense.date.isBefore(normalizedEnd) || expense.date.isAtSameMomentAs(normalizedEnd))) {
            total += expense.amount;
            expensesmap.add(expenseJson.expence);
          } 
        } catch (e) {
          print_log_red('Error parsing expense: $e');
        }
      }

      return {'total':total, 'expenses': jsonEncode(expensesmap)};
    } catch (e) {
      print_log_red('Error getting date range total: $e');
      return {'total':0.0, 'expenses': jsonEncode([])};
    }
  }

  // Method to get daywise expenses from any page
  static Future<Map<DateTime, double>> getDaywiseExpenses(List<expences> expensesJson) async {
    final Map<DateTime, double> daywiseTotals = {};

    try {

      for (final expenseJson in expensesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(expenseJson.expence));
          final expense = Expense.fromMap(map);

          // Normalize the date to remove time component
          final dateOnly = DateTime(expense.date.year,expense.date.month,expense.date.day,);
          // print_log_red('Error parsing expense: ${expenseJson.runtimeType} ${expenseJson.toString()}');
          daywiseTotals.update(
            dateOnly,
            (value) => value + expense.amount,
            ifAbsent: () => expense.amount,
          );
          // print_log_red('Error parsing expense: ${daywiseTotals.runtimeType} ${daywiseTotals.toString()}');
        } catch (e) {
          print_log_red('Error parsing expense: $e');
        }
      }

      // Sort by date (most recent first)
      final sortedEntries = daywiseTotals.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      // print_log_red('Error parsing expense: ${sortedEntries.runtimeType} ${sortedEntries}');
      return Map.fromEntries(sortedEntries);
    } catch (e) {
      print_log_red('Error getting daywise expenses: $e');
      return {};
    }
  }
}