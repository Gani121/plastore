import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:test1/main.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ExpensesPage.dart';
import '../objectbox.g.dart';
import '../database_Module/expensDB.dart'; // Fixed typo: expensDB
import '../utilities.dart';
import '../database_Module/menu_item.dart';
import '../bill_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database_Module/cunsuption.dart';

// Add Expense model if not already defined elsewhere
class Expense {
  final String title;
  final String category;
  final double amount;
  final DateTime date;

  Expense({
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      title: map['title'] ?? '',
      category: map['category'] ?? 'Other',
      amount: (map['amount'] is int ? (map['amount'] as int).toDouble() : map['amount']) ?? 0.0,
      date: map['date'] is String ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  List<Transaction> _transactions = [];
  double todayTotal = 0;
  double profit = 0;
  double weekTotal = 0;
  double monthTotal = 0;
  double cashTotal = 0;
  double cardTotal = 0;
  double upiTotal = 0;
  double otherTotal = 0;
  double todayExpenses = 0;
  double expensesToday = 0.0;
  double expensesDateRange = 0.0;
  // Map<DateTime, double> daywiseExpensesMap = {};
  List<String> expensesList = [];
  Map<String, int> itemQtyMap = {};
  Map<String, double> itemPriceMap = {};
  Map<String, int> citemQtyMap = {};
  Map<String, double> citemPriceMap = {};
  Map<String, int> orderTypeCountMap = {};
  Map<String, double> orderTypeTotalMap = {};
  Map<String, double> categoryPriceMap = {};
  Map<String, int> categoryQtyMap = {};
  Map<String, int> adjustStock = {};
  Map<String, int> unavailabelstock = {};
  Map<String, double> purchesprice = {};
  DateTime? fromDate;
  DateTime? toDate;
  late Store store;
  String giveamount = "0";
  bool _showMoreOptions = false;
  String takeamount = "0";
  bool _isLoading = false;
  Map<String, double> consumptionReport = {};
  Map<String, double> currentInventoryStock = {};
  Map<String, Map<String, double>> menuItemConsumptionMap = {};
  Map<String, String> inventoryUnitMap = {};

  @override
  void initState() {
    super.initState();
    store = Provider.of<ObjectBoxService>(context, listen: false).store;
    fromDate = getDateWithFourAMOffset();
    toDate = getDateWithFourAMOffset();
    if(mounted){
    Future.delayed(const Duration(milliseconds: 200), _loadTransactions);
    }
  }

  // Helper method to format date
  String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  // Helper method to get data from SharedPreferences
  Future<String> getDatafromPrefs(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) ?? "0";
    } catch (e) {
      return "0";
    }
  }

  DateTime getDateWithFourAMOffset() {
    // final now = getBussinessDateStorage(); // DateTime.now();
    // final fourAMToday = DateTime(now.year, now.month, now.day, 4);
      return AppConstants.businessDate ?? DateTime.now();
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        fromDate = picked;
      });
      await _loadTransactions();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        toDate = picked;
      });
      await _loadTransactions();
    }
  }

  Map<String, int> _loadMenu() {
    try {
      final menuItemBox = store.box<MenuItem>();
      final itemsAll = menuItemBox.getAll();
      final items = itemsAll.map((item) => item.toMap()).toList();
      Map<String, int> adjustStock1 = {};
      Map<String, double> _purchesprice = {};

      for (var tx in items) {
        if (tx['adjustStock'] != null && tx['adjustStock'] > 0) {
          final raw = tx['adjustStock'];
          final value = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
          adjustStock1["${tx['name']}"] = value;
        }
        final purchasePrice = tx['purchasePrice'] ?? "0.0"; // "25.00"
        final purchasePriceDouble = double.tryParse(purchasePrice) ?? 0.0;
        final purchasePriceValue = purchasePriceDouble.round();
        if (purchasePriceValue > 0) {
          _purchesprice["${tx['name']}"] = purchasePriceDouble;
          // print_log("purchase _purchesprice $_purchesprice");
          // print_log("massage $purchasePrice ${purchasePrice.runtimeType}");
          // print_log("massage $purchasePriceValue ${purchasePriceValue.runtimeType}");
         }
      }
      
      if (mounted) {
        setState(() {
          purchesprice = _purchesprice;
        });
      }
      
      return adjustStock1;
    } catch (e, st) {
      print_log_red('Error in _loadMenu: $e\n$st');
      return <String, int>{};
    }
  }
    
  Future<Map<String, int>> _loadUnavailabelstock() async {
    try {
      final menuItemBox = store.box<MenuItem>();
      final itemsAll = menuItemBox.getAll();
      final items = itemsAll.map((item) => item.toMap()).toList();
      Map<String, int> adjustStock1 = {};

      for (var tx in items) {
        if (tx['adjustStock'] != null && tx['adjustStock'] <= 0) {
          final raw = tx['adjustStock'];
          final value = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
          adjustStock1["${tx['name']}"] = value;
        }
      }
      return adjustStock1;
    } catch (e, st) {
      print_log_red('Error in _loadMenu: $e\n$st');
      return <String, int>{};
    }
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, int> _adjustStock2 = await _loadMenu();
      Map<String, int> _unavailabelstock = await _loadUnavailabelstock();

      // Create a map of item names to categories for quick lookup
      final menuItemBox = store.box<MenuItem>();
      final allMenuItems = menuItemBox.getAll();
      final Map<String, String> itemCategoryMap = {
        for (var item in allMenuItems) item.name: item.category
      };
      giveamount = await getDatafromPrefs("You_will_give");
      takeamount = await getDatafromPrefs("You_will_get");
      
      // First, load purchase prices from menu items
      final purchasePriceMap = purchesprice;
      
      final box = store.box<Transaction>();
      final transactions = box.getAll();

      DateTime now = DateTime.now();
      DateTime today;
      if (fromDate == toDate) {
        if (fromDate != null) {
          today = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
        } else {
          today = DateTime(now.year, now.month, now.day);
        }
      } else {
        today = DateTime(now.year, now.month, now.day);
      }

      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      DateTime startOfMonth = DateTime(now.year, now.month, 1);

      double tTotal = 0, wTotal = 0, mTotal = 0, _profit = 0;
      double cTotal = 0, crTotal = 0, uTotal = 0, oTotal = 0;
      Map<String, int> qtyMap = {};
      Map<String, double> priceMap = {};
      Map<String, int> cqtyMap = {};
      Map<String, double> cpriceMap = {};
      Map<String, int> tempOrderTypeCount = {};
      Map<String, double> tempOrderTypeTotal = {};
      Map<String, double> tempCategoryPriceMap = {};
      Map<String, int> tempCategoryQtyMap = {};

      // --- Consumption Logic Setup ---
      final consumptionBox = store.box<ItemConsumption>();
      final inventoryBox = store.box<InventoryItem>();
      
      // Load Inventory Stock
      Map<String, double> _currentInventoryStock = {};
      Map<String, String> _inventoryUnitMap = {};
      final allInventory = inventoryBox.getAll();
      for (var item in allInventory) {
        _currentInventoryStock[item.name] = item.stockQuantity;
        _inventoryUnitMap[item.name] = item.unit;
      }

      // Load Recipes (Map MenuItem Name -> List of Consumption Rules)
      final allConsumption = consumptionBox.getAll();
      Map<String, List<ItemConsumption>> recipeMap = {};
      for (var c in allConsumption) {
        final menuName = c.menuItem.target?.name;
        if (menuName != null) {
          if (!recipeMap.containsKey(menuName)) {
            recipeMap[menuName] = [];
          }
          recipeMap[menuName]!.add(c);
        }
      }
      Map<String, double> _consumptionReport = {};
      Map<String, Map<String, double>> _menuItemConsumptionMap = {};
      // -------------------------------

      DateTime from = fromDate != null
          ? DateTime(fromDate!.year, fromDate!.month, fromDate!.day)
          : DateTime(2000);
      DateTime to = toDate != null
          ? DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59)
          : DateTime.now();

      // Load expenses data
      double expensesTodayTotal = 0.0;
      double expensesDateRangeTotal = 0.0;
      Map<DateTime, double> daywiseExpenses = {};
      List<String> expensesListData = [];

      try {
        // final todayNormalized = AppConstants.businessDate!;
        final expensesBox = store.box<expences>();
        final expensesJson = expensesBox.getAll();
        // final daywiseData = await ExpensesService.getDaywiseExpenses(expensesJson);

        // expensesTodayTotal = daywiseData[todayNormalized] ?? 0.0;
        // print_log("expense expensesListData $expensesListData $expensesDateRangeTotal $todayNormalized");
        Map<String, dynamic> expenceMap = await ExpensesService.getDateRangeTotal(from, to, expensesJson);
        expensesDateRangeTotal = expenceMap['total'] ?? 0.0;
        expensesTodayTotal = expensesDateRangeTotal;
        expensesListData = List<String>.from(jsonDecode(expenceMap['expenses'] ?? '[]'));
        print_log("expense expensesListData $expensesListData expensesDateRangeTotal $expensesDateRangeTotal expensesTodayTotal $expensesTodayTotal");
        // daywiseExpenses = daywiseData;
      } catch (e) {
        print_log_red('Error loading expenses data: $e');
      }

      // Process transactions
      for (var tx in transactions) {
        if (tx.time.isBefore(from) || tx.time.isAfter(to)) continue;

        final transactionTotal = tx.total;
        double transactionProfit = 0.0;

        if (tx.time.isAfter(from) && tx.time.isBefore(to)) {
          tTotal += transactionTotal;
        }
        
        if (tx.time.isAfter(startOfWeek)) wTotal += transactionTotal;
        if (tx.time.isAfter(startOfMonth)) mTotal += transactionTotal;

        // Parse cart data
        List<dynamic> cartItems = [];
        try {
          if (tx.cartData != null && tx.cartData.isNotEmpty) {
            cartItems = jsonDecode(tx.cartData);
          }
        } catch (e) {
          print_log_red('Error parsing cart data: $e');
        }

        // Calculate profit for this transaction
        for (var item in cartItems) {
          try {
            final itemName = item['name']?.toString() ?? '';
            final sellPrice = (item['sellPrice'] is int ? (item['sellPrice'] as int).toDouble() : double.tryParse(item['sellPrice']?.toString() ?? '') ?? 0.0);
            
            final qty = int.tryParse(item['qty']?.toString() ?? '') ?? 0;
            
            // Get purchase price from the map we loaded earlier
            print_log("purchasePriceMap $purchasePriceMap");
            final purchasePrice = purchasePriceMap[itemName] ?? 0;
            print_log("purchasePrice  $sellPrice - ${purchasePrice.toDouble()} * $qty");
            // Calculate profit for this item: (sellPrice - purchasePrice) * quantity
            final itemProfit = (sellPrice - purchasePrice.toDouble()) * qty;
            transactionProfit += itemProfit;
            
            // Update item-wise statistics
            qtyMap[itemName] = (qtyMap[itemName] ?? 0) + qty;
            priceMap[itemName] = (priceMap[itemName] ?? 0) + (sellPrice * qty);
            
            final itemCategory = item['portion']?.toString() ?? 'Uncategorized';
            cqtyMap[itemCategory] = (cqtyMap[itemCategory] ?? 0) + qty;
            cpriceMap[itemCategory] = (cpriceMap[itemCategory] ?? 0) + (sellPrice * qty);

            // --- Category-wise aggregation ---
            String baseNameForCategory = itemName.replaceAll(' (Half)', '').trim();
            final category = itemCategoryMap[baseNameForCategory] ?? 'Uncategorized';
            tempCategoryPriceMap[category] = (tempCategoryPriceMap[category] ?? 0) + (sellPrice * qty);
            tempCategoryQtyMap[category] = (tempCategoryQtyMap[category] ?? 0) + qty;
            
            // --- Calculate Consumption ---
            String baseName = itemName.replaceAll(' (Half)', '').trim();
            // Assume half portion uses 50% of ingredients if not explicitly defined otherwise
            bool isHalf = itemName.toLowerCase().contains('(half)') || (item['portion']?.toString().toLowerCase() == 'half');
            double ratio = isHalf ? 0.5 : 1.0;

            if (recipeMap.containsKey(baseName)) {
              for (var rule in recipeMap[baseName]!) {
                final invItemName = rule.inventoryItem.target?.name;
                if (invItemName != null) {
                  double used = rule.quantityUsed * qty * ratio;
                  _consumptionReport[invItemName] = (_consumptionReport[invItemName] ?? 0) + used;
                  
                  // --- Item-wise Consumption ---
                  if (!_menuItemConsumptionMap.containsKey(itemName)) {
                    _menuItemConsumptionMap[itemName] = {};
                  }
                  _menuItemConsumptionMap[itemName]![invItemName] = (_menuItemConsumptionMap[itemName]![invItemName] ?? 0) + used;
                }
              }
            }
            // -----------------------------

          } catch (e) {
            print_log('Error processing cart item: $e');
          }
        }
        
        _profit += transactionProfit;

        // Process payment modes
        switch (tx.payment_mode.toUpperCase()) {
          case "CASH":
            cTotal += transactionTotal;
            break;
          case "CARD":
            crTotal += transactionTotal;
            break;
          case "UPI":
            uTotal += transactionTotal;
            break;
          case "OTHER":
            cTotal += tx.cashamount?.toDouble() ?? 0.0;
            uTotal += tx.upiamount?.toDouble() ?? 0.0;
            break;
          default:
            oTotal += transactionTotal;
            //debugPrint('Uncategorized payment mode: ${tx.payment_mode} - Amount: $transactionTotal');
            break;
        }

        // Aggregate by orderType
        final orderType = tx.orderType?.isNotEmpty == true ? tx.orderType! : 'Other';
        tempOrderTypeCount[orderType] = (tempOrderTypeCount[orderType] ?? 0) + 1;
        tempOrderTypeTotal[orderType] = (tempOrderTypeTotal[orderType] ?? 0) + transactionTotal;
      }

      final prefs = await SharedPreferences.getInstance();
      final storedExpenses = prefs.getDouble('Todayexpenses') ?? 0.0;

      

      if (mounted) {
        setState(() {
          _transactions = transactions.reversed.toList();
          todayTotal = tTotal;
          weekTotal = wTotal;
          monthTotal = mTotal;
          cashTotal = cTotal;
          cardTotal = crTotal;
          upiTotal = uTotal;
          otherTotal = oTotal;
          profit = _profit;
          itemQtyMap = qtyMap;
          itemPriceMap = priceMap;
          citemQtyMap = cqtyMap;
          citemPriceMap = cpriceMap;
          todayExpenses = storedExpenses;
          expensesToday = expensesTodayTotal;
          categoryPriceMap = tempCategoryPriceMap;
          categoryQtyMap = tempCategoryQtyMap;
          expensesDateRange = expensesDateRangeTotal;
          orderTypeCountMap = tempOrderTypeCount;
          orderTypeTotalMap = tempOrderTypeTotal;
          // daywiseExpensesMap = daywiseExpenses;
          adjustStock = _adjustStock2;
          unavailabelstock = _unavailabelstock;
          expensesList = expensesListData;
          consumptionReport = _consumptionReport;
          currentInventoryStock = _currentInventoryStock;
          menuItemConsumptionMap = _menuItemConsumptionMap;
          inventoryUnitMap = _inventoryUnitMap;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      //debugPrint('Error in _loadTransactions: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  Future<void> _syncTransactionsFromServer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      // Date range logic: 1 year
      // final businessDate = (AppConstants.businessDate ?? DateTime.now()).toString().split(" ")[0];
      // DateTime currentDate = DateTime.parse(businessDate);
      // DateTime previousDate = currentDate.subtract(const Duration(days: 365)); // One year
      // String previousDateString = "${previousDate.year}-${previousDate.month.toString().padLeft(2, '0')}-${previousDate.day.toString().padLeft(2, '0')}";
      final _fromDate = (fromDate ?? DateTime.now()).toString().split(" ")[0];
      String _toDate = (toDate ?? DateTime.now()).toString().split(" ")[0];
      final hotelname = AppConstants.username;
      
      print_log("Syncing transactions from $_fromDate to $_toDate $hotelname");
      
      http.Response? response = await apiCalls('get_t', hotelname, {}, start:_fromDate, end:_toDate);
      
      await loadtransections(response, prefs);
      
      // Reload local transactions to update UI
      await _loadTransactions();
      
    } catch (e) {
      print_log_red("Error syncing transactions: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error syncing: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> loadtransections(http.Response? response, SharedPreferences prefs) async {
      final box = store.box<Transaction>();
      final printer = BillPrinter();
      try {
        if (response == null) {
          print_log_red("transection server response GOT NULL");
          return;
        }
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          // print_log_red("transection server response $jsonData");
          final dataList = jsonData['data'];
          if (dataList is List) {
            final localTransactions = box.getAll();
            final localBillNos = localTransactions.map((tx) => tx.billNo).toSet();
            int newTransactionsCount = 0;

            for (var serverTxData in dataList) {
              try {
                final serverTxMap = Map<String, dynamic>.from(serverTxData);
                final transactionField = serverTxMap['transaction'];
                Map<String, dynamic> transactionData;
                // print_log_red("transection server response ${transactionField.runtimeType}");
                if (transactionField is String) {
                  final decoded = jsonDecode(transactionField);
                  if (decoded is Map) {
                    transactionData = Map<String, dynamic>.from(decoded);
                  } else {
                    print_log("❌ Decoded data is not a Map");
                    continue;
                  }
                } else if (transactionField is Map) {
                  transactionData = Map<String, dynamic>.from(transactionField);
                } else {
                  print_log("❌ Unexpected transaction field type $transactionField");
                  continue;
                }
                
                // SAFELY parse all fields with proper null handling
                final int serverBillNo = _safeParseInt(transactionData['billNo'], defaultValue: 0);
                final int total = _safeParseInt(transactionData['total'], defaultValue: 0);
                final int tableNo = _safeParseInt(transactionData['tableNo'], defaultValue: 0);
                final int upiamount = _safeParseInt(transactionData['upiamount'], defaultValue: 0);
                final int cashamount = _safeParseInt(transactionData['cashamount'], defaultValue: 0);
                final double discount = _safeParseDouble(transactionData['discount'], defaultValue: 0.0);
                final double serviceCharge = _safeParseDouble(transactionData['serviceCharge'], defaultValue: 0.0);
                final double discountPercent = _safeParseDouble(transactionData['discountPercent'], defaultValue: 0.0);
                
                // Handle string fields with empty string as default
                final String status = _safeParseString(transactionData['status'], defaultValue: 'settle');
                final String paymentMode = _safeParseString(
                  transactionData['payment_mode'] ?? serverTxMap['payment_mode'], 
                  defaultValue: 'UNKNOWN'
                );
                final String mobileNo = _safeParseString(transactionData['mobileNo']);
                final String reserved = _safeParseString(transactionData['reserved']);
                final String orderType = _safeParseString(transactionData['orderType'], defaultValue: 'Dine-In');
                final String customerName = _safeParseString(transactionData['customerName']);
                final String reservedField = _safeParseString(transactionData['reserved_field']);
                
                // Parse time
                final DateTime time = _safeParseDateTime(
                  transactionData['time'] ?? serverTxMap['transaction_time'],
                  defaultValue: DateTime.now()
                );
                
                // Handle cart data
                String cartDataString = '[]';
                if (transactionData.containsKey('cart')) {
                  final cartValue = transactionData['cart'];
                  if (cartValue is List) {
                    cartDataString = jsonEncode(cartValue);
                  } else if (cartValue is String) {
                    try {
                      jsonDecode(cartValue);
                      cartDataString = cartValue;
                    } catch (e) {
                      cartDataString = '[]';
                    }
                  }
                }
                
                if (serverBillNo != 0 && !localBillNos.contains(serverBillNo)) {
                  final Map<String, dynamic> cleanTransactionData = {
                    'id': serverBillNo,
                    'billNo': serverBillNo,
                    'time': time.toIso8601String(),
                    'tableNo': tableNo,
                    'total': total,
                    'cartData': cartDataString,
                    'payment_mode': paymentMode,
                    'status': status,
                    'synced': true,
                    'discount': discount,
                    'mobileNo': mobileNo,
                    'reserved': reserved,
                    'orderType': orderType,
                    'upiamount': upiamount,
                    'cashamount': cashamount,
                    'customerName': customerName,
                    'serviceCharge': serviceCharge,
                    'reserved_field': reservedField,
                    'discountPercent': discountPercent,
                  };
                  
                  try {
                    final transaction = Transaction.fromMap(cleanTransactionData);
                    box.put(transaction);
                    printer.setNextBillNo(context, cleanTransactionData['billNo']);
                    newTransactionsCount++;
                    print_log("✅ Added transaction: $serverBillNo");
                  } catch (e) {
                    print_log_red("❌ Error creating transaction: $e");
                    print_log("Transaction data: $cleanTransactionData");
                  }
                }
                
              } catch (e) {
                print_log_red("❌ Error processing transaction: $e");
                continue;
              }
            }
            if (newTransactionsCount > 0) {
              print_log("✅ Synced $newTransactionsCount new transactions from server.");
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Synced $newTransactionsCount new transactions")),
                );
              }
            } else {
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("No new transactions found")),
                );
              }
            }
          } else {
            print_log_red("❌ 'data' is not a list");
          }
        } else {
          print_log_red('HTTP Error: ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (error) {
        screen_massage(context, "Error syncing transactions: $error");
        print_log_red("❌ Error in loadtransections: $error");
      }
    }

  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return int.tryParse(value) ?? defaultValue;
    }
    if (value is num) return value.toInt();
    return defaultValue;
  }

  double _safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return double.tryParse(value) ?? defaultValue;
    }
    if (value is num) return value.toDouble();
    return defaultValue;
  }

  String _safeParseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  DateTime _safeParseDateTime(dynamic value, {DateTime? defaultValue}) {
    defaultValue ??= DateTime.now();
    
    if (value == null) return defaultValue;
    if (value is DateTime) return value;
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return DateTime.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<void> _shareReport() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    final DateTime today = DateTime.now();
    final bool isTodaySelected =
        fromDate != null &&
        toDate != null &&
        fromDate!.day == today.day &&
        fromDate!.month == today.month &&
        fromDate!.year == today.year &&
        toDate!.day == today.day &&
        toDate!.month == today.month &&
        toDate!.year == today.year;

    final bool isDateRangeSelected =
        fromDate != null && toDate != null && !isTodaySelected;

    final double displayExpenses = isDateRangeSelected
        ? expensesDateRange
        : expensesToday;
    final String expensesLabel = isDateRangeSelected
        ? "Date Range Expenses"
        : "Today's Expenses";

    final reportBuffer = StringBuffer();
    reportBuffer.writeln("📊 Sales Report");
    reportBuffer.writeln("Generated on: $formattedDate");

    reportBuffer.writeln(
      "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate!)}"
      " → ${DateFormat('dd MMM yyyy').format(toDate!)}",
    );

    reportBuffer.writeln("=======================");
    reportBuffer.writeln(
      isDateRangeSelected
          ? "Selected Range Sales: ₹ ${todayTotal.toStringAsFixed(2)}"
          : "Today's Sales: ₹ ${todayTotal.toStringAsFixed(2)}",
    );
    reportBuffer.writeln("This Week: ₹ ${weekTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("This Month: ₹ ${monthTotal.toStringAsFixed(2)}");

    reportBuffer.writeln("");
    reportBuffer.writeln("By Payment Mode:");
    reportBuffer.writeln("💵 Cash: ₹ ${cashTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("💳 Card: ₹ ${cardTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("📱 UPI: ₹ ${upiTotal.toStringAsFixed(2)}");
    reportBuffer.writeln("📱 Not Settled: ₹ ${otherTotal.toStringAsFixed(2)}");

    reportBuffer.writeln("");
    final giveamount = await getDatafromPrefs("You_will_give");
    final takeamount = await getDatafromPrefs("You_will_get");
    reportBuffer.writeln("Udhari Get and Give:");
    reportBuffer.writeln("You_will_give: ₹ $giveamount");
    reportBuffer.writeln("You_will_get: ₹ $takeamount");

    reportBuffer.writeln("");
    reportBuffer.writeln("💰 $expensesLabel:");
    reportBuffer.writeln("₹ ${displayExpenses.toStringAsFixed(2)}");
    
    // reportBuffer.writeln("");
    // if (isDateRangeSelected && expensesToday > 0) {
    //   reportBuffer.writeln("Today's expenses:- ₹${expensesToday.toStringAsFixed(2)}");
    // }

    reportBuffer.writeln("");
    reportBuffer.writeln("💼 Sales:");
    reportBuffer.writeln("₹ ${(todayTotal).toStringAsFixed(2)}");

    reportBuffer.writeln("");
    if (expensesList.isNotEmpty) {
      reportBuffer.writeln("Today's Expenses List:");
      for (String ex in expensesList) {
        try {
          Map<String, dynamic> expence = jsonDecode(ex);
          String sDate = expence['date'];
          DateTime _date = DateTime.parse(sDate);
          reportBuffer.writeln("${expence['title']} - ${expence['category']} - ${formatDate(_date)} - ₹ ${expence['amount']}");
        } catch (e) {
          reportBuffer.writeln("Error parsing expense entry");
        }
      }
    }

    await SharePlus.instance.share(ShareParams(
      text: reportBuffer.toString(),
      subject: 'Sales Report - $formattedDate',
      // title: "Date Range: ${DateFormat('dd MMM yyyy').format(fromDate!)} → ${DateFormat('dd MMM yyyy').format(toDate!)}"
      )
    );
  }

  Future<void> _generatePdf() async {
    final doc = pw.Document();
    
    // Use standard font to avoid loading issues
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Sales & Consumption Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: boldFont)),
            ),
            pw.Text("Date: ${DateFormat('dd MMM yyyy').format(fromDate!)} - ${DateFormat('dd MMM yyyy').format(toDate!)}", style: pw.TextStyle(font: font)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            // Sales Summary
            pw.Text("Sales Summary", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: boldFont)),
            pw.SizedBox(height: 5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("Total Sales:", style: pw.TextStyle(font: font)),
              pw.Text("Rs. ${todayTotal.toStringAsFixed(2)}", style: pw.TextStyle(font: boldFont)),
            ]),
             pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("Total Profit:", style: pw.TextStyle(font: font)),
              pw.Text("Rs. ${profit.toStringAsFixed(2)}", style: pw.TextStyle(font: boldFont, color: PdfColors.green)),
            ]),
            
            pw.SizedBox(height: 20),
            
            // Consumption Table
            pw.Text("Consumption & Inventory Report", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: boldFont)),
            pw.SizedBox(height: 5),
            pw.Table.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont),
              cellStyle: pw.TextStyle(font: font),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              data: <List<String>>[
                <String>['Inventory Item', 'Consumed Qty', 'Current Stock'],
                ...consumptionReport.entries.map((e) {
                  final unit = inventoryUnitMap[e.key] ?? '';
                  return [
                    "${e.key} ($unit)",
                    e.value.toStringAsFixed(2),
                    (currentInventoryStock[e.key] ?? 0).toStringAsFixed(2)
                  ];
                }).toList()
              ],
            ),
          ];
        },
      ),
    );

    // Open print preview which allows saving as PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  Future<void> _generateItemWisePdf() async {
    final doc = pw.Document();
    
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final sortedEntries = itemPriceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          content.add(pw.Header(
            level: 0,
            child: pw.Text('Item-Wise Sales & Consumption Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: boldFont)),
          ));
          content.add(pw.Text("Date: ${DateFormat('dd MMM yyyy').format(fromDate!)} - ${DateFormat('dd MMM yyyy').format(toDate!)}", style: pw.TextStyle(font: font)));
          content.add(pw.Divider());
          content.add(pw.SizedBox(height: 20));

          for (var entry in sortedEntries) {
            final itemName = entry.key;
            final totalAmount = entry.value;
            final count = itemQtyMap[itemName] ?? 0;
            final consumption = menuItemConsumptionMap[itemName];

            // Main item row
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text('$itemName (Qty: $count)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('₹${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont), textAlign: pw.TextAlign.right),
                    ),
                  ]
                )
              )
            );

            // Consumption details if they exist
            if (consumption != null && consumption.isNotEmpty) {
              content.add(pw.Container(
                padding: const pw.EdgeInsets.only(left: 15, top: 5, bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Ingredients Consumed:', style: pw.TextStyle(font: font, color: PdfColors.grey800, fontSize: 10, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 2),
                    ...consumption.entries.map((cEntry) {
                      final unit = inventoryUnitMap[cEntry.key] ?? '';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, top: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("- ${cEntry.key} ($unit)", style: pw.TextStyle(font: font, color: PdfColors.grey700, fontSize: 10)),
                            pw.Text('${cEntry.value.toStringAsFixed(2)} used', style: pw.TextStyle(font: font, color: PdfColors.grey700, fontSize: 10)),
                          ]
                        )
                      );
                    }).toList(),
                  ]
                )
              ));
            } else {
               content.add(pw.SizedBox(height: 8));
            }
          }

          return content;
        },
      ),
    );

    // Open print preview which allows saving as PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: _syncTransactionsFromServer,
            tooltip: 'Sync Transactions',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Share Report',
          ),
          // IconButton(
          //   icon: const Icon(Icons.print),
          //   onPressed: () {
          //     BillPrinter().printSalesReportSummary(
          //       context: context,
          //       fromDate: fromDate,
          //       toDate: toDate,
          //       todayTotal: todayTotal,
          //       weekTotal: weekTotal,
          //       monthTotal: monthTotal,
          //       cashTotal: cashTotal,
          //       cardTotal: cardTotal,
          //       upiTotal: upiTotal,
          //       otherTotal: otherTotal,
          //       giveamount: giveamount,
          //       takeamount: takeamount,
          //       expensesDateRange: expensesDateRange,
          //       expensesToday: expensesToday,
          //       isDateRangeSelected: isDateRangeSelected,
          //     );
          //   },
          //   tooltip: 'Print Summary Report',
          // ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildDateFilterSection(),
                  _buildSectionTitle("Sales Summary"),
                  _buildSummaryCard(),
                  _buildConsumptionSummaryCard(), // Added Consumption Card
                  if (orderTypeTotalMap.isNotEmpty) _buildOrderTypeSummaryCard(),
                  _buildSectionTitle("Expenses Summary"),
                  _buildExpensesList(),
                  if (citemPriceMap.isNotEmpty) _buildportionWiseSummaryCard(),
                  if (categoryPriceMap.isNotEmpty) _buildCategoryWiseSummaryCard(),
                  if (adjustStock.isNotEmpty) _buildadjustStockSummaryCard(),
                  if (itemPriceMap.isNotEmpty) _builditemWiseSummaryCard(),
                  if (_showMoreOptions && unavailabelstock.isNotEmpty)
                    _buildUnavailabelstockSummaryCard(),
                  if (!_showMoreOptions)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showMoreOptions = true;
                          });
                        },
                        child: const Text('More Options'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryWiseSummaryCard() {
    if (categoryPriceMap.isEmpty) return const SizedBox.shrink();

    final sortedEntries = categoryPriceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printCategoryWiseSalesReport(
                    context: context,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    categoryPriceMap: categoryPriceMap,
                    categoryQtyMap: categoryQtyMap,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final categoryName = entry.key;
              final totalAmount = entry.value;
              final count = categoryQtyMap[categoryName] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$categoryName (QTY: $count)',
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumptionSummaryCard() {
    if (consumptionReport.isEmpty) return const SizedBox.shrink();

    final sortedEntries = consumptionReport.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Consumption Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: _generatePdf,
                  tooltip: 'Download PDF',
                ),
              ],
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 2, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Consumed', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Stock', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final itemName = entry.key;
              final consumed = entry.value;
              final stock = currentInventoryStock[itemName] ?? 0;
              final unit = inventoryUnitMap[itemName] ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        "$itemName ($unit)",
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        consumed.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: Colors.red),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        stock.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 15, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeSummaryCard() {
    final sortedEntries = orderTypeTotalMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales by Order Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printOrderTypeSalesReport(
                    context: context,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    orderTypeTotalMap: orderTypeTotalMap,
                    orderTypeCountMap: orderTypeCountMap,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final orderType = entry.key;
              final totalAmount = entry.value;
              final count = orderTypeCountMap[orderType] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$orderType ($count Orders)',
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _builditemWiseSummaryCard() {
    final sortedEntries = itemPriceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales by Item-Wise',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print),
                      onPressed: () => BillPrinter().printItemWiseSalesReport(
                        context: context,
                        fromDate: fromDate!,
                        toDate: toDate!,
                        itemPriceMap: itemPriceMap,
                        itemQtyMap: itemQtyMap,
                      ),
                      tooltip: 'Print Report',
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      onPressed: _generateItemWisePdf,
                      tooltip: 'Export to PDF',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final itemName = entry.key;
              final totalAmount = entry.value;
              final count = itemQtyMap[itemName] ?? 0;
              final consumption = menuItemConsumptionMap[itemName];
              print_log("menuItemConsumptionMap[itemName] $consumption");

              if (consumption == null || consumption.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '$itemName (QTY: $count)',
                          style: const TextStyle(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '$itemName (QTY: $count)',
                          style: const TextStyle(fontSize: 15, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                  children: consumption.entries.map((cEntry) {
                    final unit = inventoryUnitMap[cEntry.key] ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${cEntry.key} ($unit)", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                          Text('${cEntry.value.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildportionWiseSummaryCard() {
    final sortedEntries = citemPriceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales by Portion-Wise',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printPortionWiseSalesReport(
                    context: context,
                    fromDate: fromDate!,
                    toDate: toDate!,
                    portionPriceMap: citemPriceMap,
                    portionQtyMap: citemQtyMap,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final portion = entry.key;
              final totalAmount = entry.value;
              final count = citemQtyMap[portion] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$portion (QTY: $count)',
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildadjustStockSummaryCard() {
    final sortedEntries = adjustStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Stocks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printStockReport(
                    context: context,
                    stockMap: adjustStock,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final itemName = entry.key;
              final stockCount = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        itemName,
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$stockCount Qty',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailabelstockSummaryCard() {
    final sortedEntries = unavailabelstock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Unavailable Stocks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => BillPrinter().printStockReport(
                    context: context,
                    stockMap: unavailabelstock,
                  ),
                  tooltip: 'Print Report',
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) {
              final itemName = entry.key;
              final stockCount = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        itemName,
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$stockCount Qty',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    if (expensesList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          "No expenses found",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expensesList.length,
      itemBuilder: (context, index) {
        try {
          final expenseMap = jsonDecode(expensesList[index]);
          final expense = Expense.fromMap(expenseMap);
          return _buildExpenseCard(expense);
        } catch (e) {
          //debugPrint("Error parsing expense: $e");
          return Container();
        }
      },
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(expense.category),
            color: Colors.blue.shade800,
            size: 24,
          ),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              expense.category,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatDate(expense.date),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: Text(
          "₹${expense.amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red[700],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'utilities':
        return Icons.bolt;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'healthcare':
        return Icons.medical_services;
      default:
        return Icons.money;
    }
  }

  Widget _buildDateFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    fromDate != null
                        ? "From: ${DateFormat('dd MMM yyyy').format(fromDate!)}"
                        : "Select From Date",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    toDate != null
                        ? "To: ${DateFormat('dd MMM yyyy').format(toDate!)}"
                        : "Select To Date",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (isDateRangeSelected)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    fromDate = getDateWithFourAMOffset();
                    toDate = getDateWithFourAMOffset();
                  });
                  
                  _loadTransactions();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset to Today'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade50,
                  foregroundColor: Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final DateTime today = DateTime.now();
    final bool isTodaySelected =
        fromDate != null &&
        toDate != null &&
        fromDate!.day == today.day &&
        fromDate!.month == today.month &&
        fromDate!.year == today.year &&
        toDate!.day == today.day &&
        toDate!.month == today.month &&
        toDate!.year == today.year;

    final bool isDateRangeSelected = fromDate != null && toDate != null && !isTodaySelected;
    
    final double displayExpenses = isDateRangeSelected ? expensesDateRange : expensesToday;
    final String expensesLabel = isDateRangeSelected ? "Date Range Expenses" : "Today's Expenses";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDateRangeSelected)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "📅 Selected Date Range:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  "${DateFormat('dd MMM yyyy').format(fromDate!)} → ${DateFormat('dd MMM yyyy').format(toDate!)}",
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade600),
                ),
                const SizedBox(height: 8),
              ],
            ),
          Text(
            isDateRangeSelected
                ? "Selected Range Sales: ₹ ${todayTotal.toStringAsFixed(2)}"
                : "Today's Sales: ₹ ${todayTotal.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "This Week: ₹ ${weekTotal.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            "This Month: ₹ ${monthTotal.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 16),
          ),
          const Divider(),
          const Text(
            "By Payment Mode:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text("💵 Cash: ₹ ${cashTotal.toStringAsFixed(2)}"),
          Text("💳 Card: ₹ ${cardTotal.toStringAsFixed(2)}"),
          Text("📱 UPI: ₹ ${upiTotal.toStringAsFixed(2)}"),
          Text("📱 Not Settled: ₹ ${otherTotal.toStringAsFixed(2)}"),
          const Divider(),
          const Text(
            "Udhari Get and Give:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text("You_will_give: ₹ $giveamount"),
          Text("You_will_get: ₹ $takeamount"),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "💰 $expensesLabel: ₹ ${displayExpenses.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red.shade800,
                  ),
                ),
                if (isDateRangeSelected && expensesToday > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "(Today's expenses: ₹ ${expensesToday.toStringAsFixed(2)})",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "SALES:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  "₹ ${(todayTotal).toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Net Profit (after expenses)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: profit >= 0 ? Colors.green.shade200 : Colors.red.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "PROFIT:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: profit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                Text(
                  "₹ ${profit.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get isDateRangeSelected {
    return fromDate != null &&
        toDate != null &&
        (fromDate!.day != toDate!.day ||
            fromDate!.month != toDate!.month ||
            fromDate!.year != toDate!.year);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              BillPrinter().printSalesReportSummary(
                context: context,
                fromDate: fromDate,
                toDate: toDate,
                todayTotal: todayTotal,
                weekTotal: weekTotal,
                monthTotal: monthTotal,
                cashTotal: cashTotal,
                cardTotal: cardTotal,
                upiTotal: upiTotal,
                otherTotal: otherTotal,
                giveamount: giveamount,
                takeamount: takeamount,
                expensesDateRange: expensesDateRange,
                expensesToday: expensesToday,
                isDateRangeSelected: isDateRangeSelected,
              );
            },
            tooltip: 'Print Summary Report',
          ),
        ],
      ),
    );
  }
}