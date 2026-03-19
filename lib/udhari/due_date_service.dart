import 'package:flutter/material.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/udharicustomer.dart';

class DueDateService extends ChangeNotifier {
  static final DueDateService _instance = DueDateService._internal();
  factory DueDateService() => _instance;
  DueDateService._internal();

  bool _hasDueToday = false;
  bool get hasDueToday => _hasDueToday;

  // Check if any customer has transactions due today
  Future<void> checkDueToday(ObjectBoxService objectbox) async {
    try {
      final customerBox = objectbox.store.box<udhariCustomer>();
      final customers = customerBox.getAll();
      
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      
      bool foundDueToday = false;
      
      for (var customer in customers) {
        for (var transaction in customer.transactions) {
          if (transaction.dueDate != null) {
            DateTime dueDate = DateTime(
              transaction.dueDate!.year,
              transaction.dueDate!.month,
              transaction.dueDate!.day
            );
            
            if (dueDate.isAtSameMomentAs(today)) {
              foundDueToday = true;
              break;
            }
          }
        }
        if (foundDueToday) break;
      }
      
      if (_hasDueToday != foundDueToday) {
        _hasDueToday = foundDueToday;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking due today: $e');
    }
  }

  // Reset the notification (call this when user opens Udhari page)
  void resetDueToday() {
    _hasDueToday = false;
    notifyListeners();
  }
}