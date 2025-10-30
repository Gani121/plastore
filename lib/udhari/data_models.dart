import 'package:flutter/material.dart';

// Enum to define Transaction_udhari type
enum TransactionType { gave, got }

// Model for a single Transaction_udhari
class Transaction_udhari {
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String description;

  Transaction_udhari({
    required this.amount,
    required this.type,
    required this.date,
    this.description = '',
  });
}

// Model for a customer
class Customer {
  final int id;
  final String name;
  final String phone;
  final List<Transaction_udhari> transactions;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.transactions,
  });

    // ADD THIS FACTORY CONSTRUCTOR
  factory Customer.fromMap(Map<String, dynamic> map, List<Transaction_udhari> transactions) {
    return Customer(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'],
      transactions: transactions,
    );
  }

  // Helper to calculate the balance for a customer
  double get balance {
    double total = 0.0;
    for (final Transaction_udhari in transactions) {
      if (Transaction_udhari.type == TransactionType.gave) {
        total += Transaction_udhari.amount; // You gave them money, so they owe you
      } else {
        total -= Transaction_udhari.amount; // You got money, so they owe you less
      }
    }
    return total;
  }
}

// State Management using Provider
class AppState extends ChangeNotifier {
  final List<Customer> _customers = [
    // --- Mock Data ---
    Customer(id: 1, name: "Anjali Sharma", phone: "9876543210", transactions: [
      Transaction_udhari(amount: 500, type: TransactionType.gave, date: DateTime.now()),
      Transaction_udhari(amount: 200, type: TransactionType.got, date: DateTime.now()),
    ]),
    Customer(id: 2, name: "Rajesh Kumar", phone: "8765432109", transactions: [
       Transaction_udhari(amount: 1000, type: TransactionType.got, date: DateTime.now()),
       Transaction_udhari(amount: 300, type: TransactionType.got, date: DateTime.now()),
    ]),
     Customer(id: 3, name: "Priya Singh", phone: "7654321098", transactions: []),
  ];

  List<Customer> get customers => _customers;


  // --- Calculated Totals for Dashboard ---
  double get totalToGet {
    double total = 0;
    for (var customer in _customers) {
      if (customer.balance > 0) {
        total += customer.balance;
      }
    }
    return total;
  }

  double get totalToGive {
     double total = 0;
    for (var customer in _customers) {
      if (customer.balance < 0) {
        total += customer.balance.abs();
      }
    }
    return total;
  }


    // --- Calculated Totals for Dashboard ---
  double get totalToGet1 {
    double total = 0;
    for (var customer in _customers) {
      if (customer.balance > 0) {
        total += customer.balance;
      }
    }
    return total;
  }

  double get totalToGive1 {
     double total = 0;
    for (var customer in _customers) {
      if (customer.balance < 0) {
        total += customer.balance.abs();
      }
    }
    return total;
  }

  // --- Methods to update state ---
  void addTransaction(int customerId, Transaction_udhari Transaction_udhari) {
    final customerIndex = _customers.indexWhere((c) => c.id == customerId);
    if (customerIndex != -1) {
      _customers[customerIndex].transactions.add(Transaction_udhari);
      notifyListeners(); // This tells the UI to rebuild
    }
  }

  void addCustomer(String name, String phone) {
    final newCustomer = Customer(
      id: _customers.length + 1, // Simple ID generation
      name: name,
      phone: phone,
      transactions: [],
    );
    _customers.add(newCustomer);
    notifyListeners();
  }
}