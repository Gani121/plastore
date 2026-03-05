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
  double sLastMonth = 0.0;
  double rangetotal = 0.0;
  double totalTransections = 0.0;
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
  List<expences> _allExpenses = [];

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
          // print_log("massage $purchasePrice ${purchasePrice.runtimeType}");
          // print_log("massage $purchasePriceValue ${purchasePriceValue.runtimeType}");
         }
      }
      print_log("purchase _purchespriceMap $_purchesprice");
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
      final now = DateTime.now();

      // --- 1. DEFINE FIXED TIME RANGES ---
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfLastMonth = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 1);
      final endOfLastMonth = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
      // Monday to Sunday Logic:
      // weekday 1 = Monday, 7 = Sunday. 
      // This finds the Monday of the current week.
      final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // --- 2. DEFINE SELECTED RANGE ---
      DateTime from = fromDate != null ? DateTime(fromDate!.year, fromDate!.month, fromDate!.day) : startOfToday;
      DateTime to = toDate != null ? DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59) : DateTime.now();

      final Map<String, String> itemCategoryMap = {for (var item in allMenuItems) item.name: item.category};
      giveamount = await getDatafromPrefs("You_will_give");
      takeamount = await getDatafromPrefs("You_will_get");
      
      // First, load purchase prices from menu items
      final purchasePriceMap = purchesprice;
      
      final box = store.box<Transaction>();
      final transactions = box.getAll();

      double tTotal = 0, wTotal = 0, mTotal = 0, _profit = 0, _sLastMonth = 0, _rangetotal = 0, _totalTransections = 0;
      double cash = 0, card = 0, upi = 0, pending = 0;
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



      // Load expenses data
      double expensesTodayTotal = 0.0;
      double expensesDateRangeTotal = 0.0;
      Map<DateTime, double> daywiseExpenses = {};
      List<String> expensesListData = [];

      try {
        // final todayNormalized = AppConstants.businessDate!;
        final expensesBox = store.box<expences>();
        final expensesJson = expensesBox.getAll();
        _allExpenses = expensesJson;


        Map<String, dynamic> expenceMap = await ExpensesService.getDateRangeTotal(from, to, expensesJson);
        expensesDateRangeTotal = expenceMap['total'] ?? 0.0;
        expensesTodayTotal = expensesDateRangeTotal;
        expensesListData = List<String>.from(jsonDecode(expenceMap['expenses'] ?? '[]'));
        print_log("expense expensesListData $expensesListData expensesDateRangeTotal $expensesDateRangeTotal expensesTodayTotal $expensesTodayTotal");
      } catch (e) {
        print_log_red('Error loading expenses data: $e');
      }

      // Process transactions
      for (var tx in transactions) {

        final transactionTotal = tx.total;
         // Calculate FIXED Stats (Always based on current time)
        if (tx.time.isAfter(startOfToday)) tTotal += transactionTotal;
        if (tx.time.isAfter(startOfWeek)) wTotal += transactionTotal;
        if (tx.time.isAfter(startOfMonth)) mTotal += transactionTotal;
        if (tx.time.isAfter(startOfLastMonth) && tx.time.isBefore(endOfLastMonth)) _sLastMonth += transactionTotal;
        // print_log("total rangetotal month $_sLastMonth transactionTotal month $transactionTotal");


        if (tx.time.isBefore(from) || tx.time.isAfter(to)) continue;
        // @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


        _totalTransections += 1;
        // Calculate Range/FILTERED Stats dates(Payment Mode, Range Total, Profit)
        if (tx.time.isAfter(from) && tx.time.isBefore(to)) {
          _rangetotal += transactionTotal;
          
          
          // Payment Mode Breakdown (Only for selected range)
          switch (tx.payment_mode.toUpperCase()) {
            case "CASH":
              cash += transactionTotal;
              break;
            case "CARD":
              card += transactionTotal;
              break;
            case "UPI":
              upi += transactionTotal;
              break;
            case "OTHER":
              cash += tx.cashamount?.toDouble() ?? 0.0;
              upi += tx.upiamount?.toDouble() ?? 0.0;
              break;
            default:
              pending += transactionTotal;
              break;
          }
        }

        // Aggregate by orderType
        final orderType = tx.orderType?.isNotEmpty == true ? tx.orderType! : 'Other';
        tempOrderTypeCount[orderType] = (tempOrderTypeCount[orderType] ?? 0) + 1;
        tempOrderTypeTotal[orderType] = (tempOrderTypeTotal[orderType] ?? 0) + transactionTotal;








        // Parse cart data*************************************
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
            final purchasePrice = purchasePriceMap[itemName] ?? 0;
            final itemProfit = (sellPrice - purchasePrice.toDouble()) * qty;
            _profit += itemProfit;
            
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
            print_log_red('Error processing cart item: $e');
          }
        }
        

        // _profit += transactionProfit;




      }

      final prefs = await SharedPreferences.getInstance();
      final storedExpenses = prefs.getDouble('Todayexpenses') ?? 0.0;

      final reversedTransactions = transactions.reversed.toList();

      if (mounted) {
        setState(() {
          _transactions = transactions.reversed.toList();
          _transactions = reversedTransactions;
          todayTotal = tTotal;
          weekTotal = wTotal;
          monthTotal = mTotal;
          cashTotal = cash;
          cardTotal = card;
          upiTotal = upi;
          otherTotal = pending;
          print_log("UI rangetotal updated to: $_sLastMonth");
          sLastMonth = _sLastMonth;
          rangetotal = _rangetotal;
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
          totalTransections = _totalTransections;
          _isLoading = false;
        });
      }
    } catch (e) {
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
    // reportBuffer.writeln("💳 Card: ₹ ${cardTotal.toStringAsFixed(2)}");
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


double _getWeekExpenses() {
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  
  double total = 0.0;
  for (var e in _allExpenses) {
    try {
      Map<String, dynamic> data = jsonDecode(e.expence);
      DateTime expenseDate = DateTime.parse(data['date']);
      
      if (expenseDate.isAfter(weekAgo)) {
        total += (data['amount'] ?? 0).toDouble();
      }
    } catch (err) { /* Skip invalid JSON */ }
  }
  return total;
}

double _getMonthExpenses(int month, int year) {
  double total = 0.0;
  for (var e in _allExpenses) {
    try {
      Map<String, dynamic> data = jsonDecode(e.expence);
      DateTime expenseDate = DateTime.parse(data['date']);
      
      if (expenseDate.month == month && expenseDate.year == year) {
        total += (data['amount'] ?? 0).toDouble();
      }
    } catch (err) { }
  }
  return total;
}

double _getYearTotal(int year) {
  double total = 0.0;
  for (var e in _allExpenses) {
    try {
      Map<String, dynamic> data = jsonDecode(e.expence);
      DateTime expenseDate = DateTime.parse(data['date']);
      
      if (expenseDate.year == year) {
        total += (data['amount'] ?? 0).toDouble();
      }
    } catch (err) { }
  }
  return total;
}

double _getTodayExpenses() {
  final today = DateTime.now();
  double total = 0.0;
  
  for (var e in _allExpenses) {
    try {
      Map<String, dynamic> data = jsonDecode(e.expence);
      DateTime expenseDate = DateTime.parse(data['date']);
      
      if (expenseDate.day == today.day &&
          expenseDate.month == today.month &&
          expenseDate.year == today.year) {
        total += (data['amount'] ?? 0).toDouble();
      }
    } catch (err) { }
  }
  return total;
}

  // Helper for the top Row display
  Widget _buildMainStat(String label, double amount) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}', // Rounded for cleaner look in Row
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }




  Widget _buildHeader() {
    final now = DateTime.now();
    
    List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    String currentMonthName = months[now.month - 1];
    int lastMonthIndex = now.month == 1 ? 12 : now.month - 1;
    int lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
    String lastMonthName = months[lastMonthIndex - 1];

    // Logic for Yearly Average Day
    double yearTotal = _getYearTotal(now.year);
    int dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    double avgDailyExpense = yearTotal / dayOfYear;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top Row: Current and Last Month side-by-side
          Row(
            children: [
              Expanded(
                child: _buildMainStat('This Month', _getMonthExpenses(now.month, now.year)),
              ),
              Container(width: 1, height: 40, color: Colors.blue.withOpacity(0.2)), // Divider
              Expanded(
                child: _buildMainStat('Last Month', _getMonthExpenses(lastMonthIndex, lastMonthYear)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          // Bottom Row: Today, Week, and Year Avg
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Today', '₹${_getTodayExpenses().toStringAsFixed(2)}'),
              _buildStatCard('This Week', '₹${_getWeekExpenses().toStringAsFixed(2)}'),
              _buildStatCard('Year Avg/Day', '₹${avgDailyExpense.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildDateFilterSection(),
                  _buildSectionTitle("Sales Summary (T - $totalTransections)"),
                  _buildSummaryCard(),
                  tital("Expence Summary (From 1 To 30)"),
                  _buildHeader(),
                  _buildConsumptionSummaryCard(), // Added Consumption Card
                  if (orderTypeTotalMap.isNotEmpty) _buildOrderTypeSummaryCard(),
                  _buildExpenseSummaryCard(),
                  _buildExpensecategryCard(),
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

  Widget _buildExpenseSummaryCard() {
    // Sort expenses by date (most recent first)
    List<String> sortedExpenses = expensesList;
  print_log("$sortedExpenses");
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Expense List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const Divider(),

            // The List of Expenses
            if (sortedExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text("No expenses found for this range")),
              )
            else
              ...sortedExpenses.map((expense) {
                // Note: Since your data is stored as JSON in 'expence', 
                // we decode it here to get the display values.
                Map<String, dynamic> data = jsonDecode(expense);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      // Icon based on category
                      // Container(
                      //   padding: const EdgeInsets.all(8),
                      //   decoration: BoxDecoration(
                      //     color: Colors.blue.shade50,
                      //     borderRadius: BorderRadius.circular(8),
                      //   ),
                      //   child: Icon(
                      //     _getCategoryIcon(data['category'] ?? ''),
                      //     size: 20,
                      //     color: Colors.blue.shade800,
                      //   ),
                      // ),
                      // const SizedBox(width: 12),
                      
                      // Title and Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? 'Unnamed',
                              style: const TextStyle(
                                fontSize: 15, 
                                fontWeight: FontWeight.w500
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${data['category'] ?? 'Unknown'} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(data['date']))}",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      
                      // Amount
                      Text(
                        '₹${(data['amount'] ?? 0).toDouble().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15, 
                          fontWeight: FontWeight.bold,
                          color: Colors.red
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


  Widget _buildExpensecategryCard() {
    // 1. Group and Sum expenses by Category
    Map<String, double> categoryTotals = {};
    
    for (var expenseStr in expensesList) {
      try {
        Map<String, dynamic> data = jsonDecode(expenseStr);
        String category = data['category'] ?? 'Other';
        double amount = (data['amount'] ?? 0).toDouble();
        
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      } catch (e) {
        print_log("Error decoding expense: $e");
      }
    }

    // 2. Sort categories by highest spending
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Expense by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                // Text(
                //   'Total: ₹${expensesDateRange.toStringAsFixed(2)}',
                //   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                // ),
              ],
            ),
            const Divider(),

            if (sortedCategories.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text("No expenses found for this range")),
              )
            else
              ...sortedCategories.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category Name and Icon (Optional)
                      Row(
                        children: [
                          Icon(Icons.pie_chart, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      
                      // Category Total
                      Text(
                        '₹${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15, 
                          fontWeight: FontWeight.bold,
                          color: Colors.red
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
  final bool isTodaySelected = fromDate != null &&
      toDate != null &&
      fromDate!.day == today.day && fromDate!.month == today.month && fromDate!.year == today.year &&
      toDate!.day == today.day && toDate!.month == today.month && toDate!.year == today.year;

  final bool isDateRangeSelected = fromDate != null && toDate != null && !isTodaySelected;
  final double displayExpenses = isDateRangeSelected ? expensesDateRange : expensesToday;
  final String expensesLabel = isDateRangeSelected ? "Range Expenses" : "Today's Expenses";
  final String totalSell = isDateRangeSelected ? "Range Total Sell" : "Today's Total Sell";

  
  List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  String currentMonthName = months[today.month - 1];
  int lastMonthIndex = today.month == 1 ? 12 : today.month - 1;
  String lastMonthName = months[lastMonthIndex - 1];

  return Container(
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(
      children: [
        // --- Header Section: Date Range Info ---
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDateRangeSelected ? "Custom Report" : "Daily Overview",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              if (isDateRangeSelected)
                Text(
                  "${DateFormat('dd MMM').format(fromDate!)} - ${DateFormat('dd MMM').format(toDate!)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Main Sales Stats ---
              _buildModernRow("Today's Sales", "₹${todayTotal.toStringAsFixed(2)}", Colors.black87, isBold: true),
              _buildModernRow("This Week", "₹${weekTotal.toStringAsFixed(2)}", Colors.grey.shade700),
              _buildModernRow("This Month", "₹${monthTotal.toStringAsFixed(2)}", Colors.grey.shade700),
              _buildModernRow("Last Month", "₹${sLastMonth.toStringAsFixed(2)}", Colors.grey.shade700),
              const Divider(height: 24),

              // --- Payment Modes (Grid Style) ---
              const Text("Payment Breakdown", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildMiniChip("💵 Cash", cashTotal),
                  // _buildMiniChip("💳 Card", cardTotal),
                  _buildMiniChip("📱 UPI", upiTotal),
                  _buildMiniChip("🕒 Pending", otherTotal),
                ],
              ),

              const Divider(height: 24),
              const Text("Udhari", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              // --- Udhari Section ---
              Row(
                children: [
                  Expanded(child: _buildUdhariBox("You'll Give", giveamount, Colors.red)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildUdhariBox("You'll Get", takeamount, Colors.green)),
                ],
              ),

              const SizedBox(height: 16),

              // --- Bottom Line: Expenses & Profit ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildModernRow(expensesLabel, "₹${displayExpenses.toStringAsFixed(2)}", Colors.red.shade700),
                    _buildModernRow(totalSell, "₹${rangetotal.toStringAsFixed(2)}", Colors.black),
                    const Divider(),
                    _buildModernRow("NET PROFIT", "₹${(profit-displayExpenses).toStringAsFixed(2)}",profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,isBold: true,fontSize: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// --- Helper Widgets for a cleaner look ---

Widget _buildModernRow(String label, String value, Color valueColor, {bool isBold = false, double fontSize = 15}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: valueColor)),
      ],
    ),
  );
}

Widget _buildMiniChip(String label, double amount) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
    child: Text("$label: ₹${amount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  );
}

Widget _buildUdhariBox(String label, String amount, Color color) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha:0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text("₹$amount", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
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
  Widget tital(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }


}