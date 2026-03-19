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
import 'package:test1/database_Module/udharicustomer.dart';
import 'package:test1/inventory/sync_service.dart';

String foldername = "expense_images";


class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Expense> _expenses = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _supplierMobileController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _recivedAmountController = TextEditingController(text: '0');
  late TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier<bool>(false);

  String _selectedPaymentMethod = 'Cash';
  String _selectedUnit = 'unit';
  String _expenseType = 'Expense';
  String? expenseType;
  // --------------------------------
  late DateTime _selectedDate;
  String _selectedCategory = 'Food';
  File? _selectedImage; // used while adding a new expense
  String? _imagePath; // path used while adding a new expense
  final ImagePicker _picker = ImagePicker();
  late Store _store = Provider.of<ObjectBoxService>(context, listen: false).store;

  List<String> _categories = [
    'Food',
    'Transport',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Healthcare',
    'Other',
  ];

  List<Supplier> _suppliers = [];
  List<String> _supplierNames = [];
  List<String> _expenseTitles = []; // For existing expense titles
  List<String> _inventoryItemNames = []; // For inventory items (consumption)
  List<String> _menuItemNames = []; // For menu items (sell items)
  final sync = SyncService();
  // Add these variables in your State class
  // final FocusNode _titleFocusNode = FocusNode();
  // final FocusNode _amountFocusNode = FocusNode();
  // final FocusNode _supplierFocusNode = FocusNode();
  // final FocusNode _qtyFocusNode = FocusNode();
  // final FocusNode _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _dueDateController.text = _formatDate(DateTime.now().add(const Duration(days: 7)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _loadSuppliers(); // Add this line
      _loadExpenseTitles(); // Add this
      _loadInventoryItems(); // Add this
      _loadMenuItems(); // Add this
      _loadExpenses().then((_) {
        _saveExpenses();
      });


    });
  }

    @override
    void dispose() {
      _titleController.dispose();
      _amountController.dispose();
      _supplierController.dispose();
      _supplierMobileController.dispose();
      _qtyController.dispose();
      _descriptionController.dispose();
      _dueDateController.dispose();
      _unitController.dispose();
      _recivedAmountController.dispose();
      _isSavingNotifier.dispose();
      super.dispose();
    }

    // Format date for display
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
// Date picker method
Future<void> _selectDueDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now().add(const Duration(days: 7)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.orange, // Header color
            onPrimary: Colors.white, // Header text color
            onSurface: Colors.black, // Body text color
          ),
        ),
        child: child!,
      );
    },
  );
  
  if (picked != null) {
    setState(() {
      _dueDateController.text = _formatDate(picked);
    });
  }
}
  // Add this method to load suppliers
Future<void> _loadSuppliers() async {
  try {
    final box = _store.box<Supplier>();
    final allSuppliers = box.getAll();
    setState(() {
      _suppliers = allSuppliers;
      _supplierNames = allSuppliers.map((s) => s.supplierName).toList();
    });
  } catch (e) {
    print_log_red('Error loading suppliers: $e');
  }
}
// Add these methods to load data
Future<void> _loadExpenseTitles() async {
  try {
    final box = _store.box<expences>();
    final allExpenses = box.getAll();
    final Set<String> titles = {};
    
    for (final entity in allExpenses) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
        final expense = Expense.fromMap(map);
        if (expense.title.isNotEmpty) {
          titles.add(expense.title);
        }
      } catch (e) {
        // Skip invalid entries
      }
    }
    
    setState(() {
      _expenseTitles = titles.toList()..sort();
    });
  } catch (e) {
    print_log_red('Error loading expense titles: $e');
  }
}

Future<void> _loadInventoryItems() async {
  try {
    final box = _store.box<InventoryItem>();
    final items = box.getAll();
    setState(() {
      _inventoryItemNames = items.map((item) => item.name).toList()..sort();
    });
  } catch (e) {
    print_log_red('Error loading inventory items: $e');
  }
}

Future<void> _loadMenuItems() async {
  try {
    final box = _store.box<MenuItem>();
    final items = box.getAll();
    setState(() {
      _menuItemNames = items.map((item) => item.name).toList()..sort();
    });
  } catch (e) {
    print_log_red('Error loading menu items: $e');
  }
}

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList('expense_categories');
    if (savedCategories != null && savedCategories.isNotEmpty) {
      setState(() {
        _categories = savedCategories;
        if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('expense_categories', _categories);
  }

  // ---------- Persistence ----------
  Future<void> _loadExpenses() async {
    try {

      _selectedDate = AppConstants.businessDate!;
      print_log("selected date in _loadExpenses $_selectedDate");
      final box = _store.box<expences>();
      final prefs = await SharedPreferences.getInstance();
      final loadedExpenses = <Expense>[];

      // 1. Load from SharedPreferences (old source)
      final expensesJson1 = prefs.getStringList('expenses') ?? [];
      if(expensesJson1.isNotEmpty){
        // print_log("Expenses from SharedPreferences: ${expensesJson1.length}");
        for (final s in expensesJson1) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(s));
            String expence_string = jsonEncode(map);
            print_log("expence_string ${expence_string}");
            final expenseEntity = expences(syid:ganarateID(), expence: expence_string,);
            box.put(expenseEntity);
            // loadedExpenses.add(Expense.fromMap(map));
          } catch (e) {
            print_log_red('Skipping malformed expense from SharedPreferences: $e');
          }
        }
        prefs.remove('expenses');
      }
      // 2. Load from ObjectBox (new source)
      final expensesJson = box.getAll();
      print_log("Expenses from ObjectBox: ${expensesJson.length}");
      for (final s in expensesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(s.expence));
          loadedExpenses.add(Expense.fromMap(map));
        } catch (e) {
          print_log_red('Skipping malformed expense entry: $e');
        }
      }
      
      // Sort expenses by date, newest first
      loadedExpenses.sort((a, b) => b.id.compareTo(a.id));

      setState(() {
        _expenses.clear();
        _expenses.addAll(loadedExpenses);
        ExpensesService.updateTotal(_totalExpenses);
      });
    } catch (e) {
      print_log('Error loading expenses: $e');
    }
  }

  Future<void> _saveExpenses() async {
    final box = _store.box<expences>();
    final expensesJson = box.getAll();
      print_log("Expenses from ObjectBox: ${expensesJson.length}");
      for (final s in expensesJson) {
        try {
          if(s.synced == false){
            final map = Map<String, dynamic>.from(jsonDecode(s.expence));
            final exp = Expense.fromMap(map);
            syncExpenseToCloud(s.id,exp,AppConstants.username,box);
          }
        } catch (e) {
          print_log_red('Skipping malformed expense entry: $e');
        }
      }
        
  }

  Future<void> _saveExpensesToPrefs({Expense? newExpense, int? id, String? update}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hotelName = await prefs.getString(AppConstants.usernameKey) ?? "";

      final box = _store.box<expences>();
      if (id != null && newExpense == null && update == null) {
        // Delete expense
        final allExpenses = box.getAll();
        for (var i = 0; i < allExpenses.length; i++) {
          final expenseEntity = allExpenses[i];
          final expenseMap = jsonDecode(expenseEntity.expence);
          int jsonId = int.tryParse(expenseMap['id']) ?? 0;
          if(jsonId == id){
            box.remove(expenseEntity.id);
            removeFileFromExternalStorage(expenseMap['photoPath']);
            print_log('Deleted Expense ID: $jsonId (ObjectBox ID: ${expenseEntity.id})');
            break;
          }
        }
      } else if (id != null && update != null) {
        // Update photo path only
        final allExpenses = box.getAll();
        for (var i = 0; i < allExpenses.length; i++) {
          final expenseEntity = allExpenses[i];
          final expenseMap = jsonDecode(expenseEntity.expence);
          int jsonId = int.tryParse(expenseMap['id']) ?? 0;
          if(jsonId == id){
            expenseMap['photoPath'] = update;
            expenseEntity.expence = jsonEncode(expenseMap);
            box.put(expenseEntity);
            print_log('Updated photo for Expense ID: $jsonId');
            break;
          }
        }
      } else if (newExpense != null) {
        // Add new expense
        print_log("selected date ${newExpense.date}");
        String expence_string = jsonEncode(newExpense.toMap());
        print_log("expence_string ${expence_string}");
        final expenseEntity = expences(syid:ganarateID(), expence: expence_string,);
        int id = await box.put(expenseEntity);
        
        syncExpenseToCloud(id,newExpense,hotelName,box);

        // update shared total
        await ExpensesService.updateTotal(_totalExpenses);

        final daywise = _getDaywiseExpenses();
        print_log("sortedEntries in _saveExpensesToPrefs $daywise");
        // final today = _selectedDate;
        final todayNormalized = _selectedDate;
        final todayTotal = daywise[todayNormalized] ?? 0.0;
        //debugPrint('$todayNormalized total: ₹$todayTotal');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('Todayexpenses', todayTotal);
      }
    } catch (e) {
      //debugPrint('Error saving expenses: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving data: $e')));
      }
    }
  }

  // SAVE OR UPDATE
  Future<void> syncExpenseToCloud(int id, Expense expense, String hotelName,Box<expences> box) async {
    final prefs = await SharedPreferences.getInstance();
    final apicall = await prefs.getString("adminPanel") ?? "no";
    bool demo = prefs.getBool('demo') ?? false;   
    
    if (apicall.toLowerCase().contains("no") || demo) {
      print_log("❌ in settel transection adminPanel not yes so Not send transection to the sever $apicall");
      return;
    }
    try {
      final payload = {
          'login_user': hotelName,
          'id': expense.id.toString(), // External ID
          'amount': expense.amount,
          'date': expense.date.toIso8601String(),
          'expense_data': expense.toMap(), // Full JSON blob
        };
      http.Response? response = await apiCalls("ex_save", hotelName, payload);
      if (response == null) {
        
        return;
      }

      if (response.statusCode == 200) {
        final Expensetoupdate =  box.get(id);
          if (Expensetoupdate != null) {
            // //debugPrint('Settling ${tx['tableNo']} with $selectedPayment',);
            Expensetoupdate.synced = true;
            box.put(Expensetoupdate);
            print_log("Cloud Sync Successful ${response.toString()}");
          }
      }
    } catch (e) {
      print_log_red("Sync Error: $e");
    }
  }

  // FETCH ALL
  Future<void> fetchExpenses() async {
    try{
      final box = _store.box<expences>();
      final prefs = await SharedPreferences.getInstance();
      final hotelName = await prefs.getString(AppConstants.usernameKey) ?? "";
      http.Response? response = await apiCalls("ex_get", hotelName, {});
      if (response == null || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      List<dynamic> serverList = data['data'];
      final localEntities = box.getAll();
      final Set<String> localIds = localEntities.map((e) {
          final map = jsonDecode(e.expence);
          return map['id'].toString(); 
        }).toSet();
      bool addedNew = false;
      for (var item in serverList) {
        final Map<String, dynamic> expenseMap = item['expense_json'];
        final String serverId = expenseMap['id'].toString();
        if (!localIds.contains(serverId)) {
          final newEntity = expences(syid:ganarateID(), expence: jsonEncode(expenseMap),);
          box.put(newEntity);
          addedNew = true;
          print_log("Added missing expense from cloud: ID $serverId $newEntity");
        }
      }

      // 4. Update the UI if something changed or if it's the first load
      if (addedNew || _expenses.isEmpty) {
        final updatedEntities = box.getAll();
        final List<Expense> loadedExpenses = [];

        for (final s in updatedEntities) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(s.expence));
            loadedExpenses.add(Expense.fromMap(map));
          } catch (e) {
            // print_log_red('Error parsing entity: $e');
          }
        }

        // Sort: Newest first
        loadedExpenses.sort((a, b) => b.date.compareTo(a.date));

        setState(() {
          _expenses.clear();
          _expenses.addAll(loadedExpenses);
          ExpensesService.updateTotal(_totalExpenses);
        });
      }
    } catch (e) {
      // print_log_red('Error parsing entity: $e');
    }
  }

  // DELETE
  Future<void> deleteExpenseFromCloud(String id,) async {
    final prefs = await SharedPreferences.getInstance();
    final apicall = await prefs.getString("adminPanel") ?? "no";
    try{
    if (apicall.toLowerCase().contains("no")) {
      print_log("❌ in settel expense adminPanel not yes so Not send transection to the sever $apicall");
      return;
    }
    final hotelName = await prefs.getString(AppConstants.usernameKey) ?? "";
    print_log("deleted id $id hotelName $hotelName");
    await apiCalls("ex_delete", hotelName,{},id:id);
    }catch (e){
      // print_log_red("error in deleteExpenseFromCloud $e");
    }
  }

  // ---------- Totals & stats ----------
  double get _totalExpenses {
    return _expenses.fold(0.0, (sum, exp) => sum + exp.amount);
  }

  double _getTodayExpenses() {
    final today = DateTime.now();
    final total = _expenses
        .where(
          (expense) =>
              expense.date.day == today.day &&
              expense.date.month == today.month &&
              expense.date.year == today.year,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
    // Persist today's total if needed
    _saveTotalExpensesToPrefs(total);
    return total;
  }

  Future<void> _saveTotalExpensesToPrefs(double total) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('totalExpenses', total);
      await ExpensesService.updateTotal(total);
    } catch (e) {
      print_log_red('Error saving total: $e');
    }
  }

  double _getWeekExpenses() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _expenses
        .where((expense) => expense.date.isAfter(weekAgo))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _getMonthExpenses(int month, int year) {
    return _expenses
        .where((expense) => 
            expense.date.month == month && 
            expense.date.year == year)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double _getYearTotal(int year) {
  return _expenses
      .where((e) => e.date.year == year)
      .fold(0.0, (sum, item) => sum + item.amount);
}



  // ---------- UI Builders ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Purchase Invoice Button
          IconButton(
            icon: const Icon(Icons.receipt),
            tooltip: 'Purchase Invoices',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchaseInvoicePage(),
                ),
              );
            },
          ),

          // Cloud Sync Button
          IconButton(
            icon: const Icon(Icons.cloud_download_sharp),
            tooltip: 'Sync with Server',
            onPressed: () async {
              await fetchExpenses();   // <-- call your sync method here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 1),
          Expanded(child: _buildExpensesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewExpense(null), // Pass null for new expense
        backgroundColor: Colors.blue.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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

    // Get payment method wise totals for today
    // final todayPaymentTotals = _getTodayPaymentWiseExpenses();
    // final todayCash = todayPaymentTotals['Cash'] ?? 0;
    // final todayOnline = todayPaymentTotals['Online'] ?? 0;
    // final todayCard = todayPaymentTotals['Card'] ?? 0;
    // final todayCredit = todayPaymentTotals['Credit'] ?? 0;

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
                child: _buildMainStat('$currentMonthName', _getMonthExpenses(now.month, now.year)),
              ),
              Container(width: 1, height: 40, color: Colors.blue.withOpacity(0.2)), // Divider
              Expanded(
                child: _buildMainStat('$lastMonthName', _getMonthExpenses(lastMonthIndex, lastMonthYear)),
              ),
            ],
          ),
          const SizedBox(height: 1),
          const Divider(),
          const SizedBox(height: 1),
          
          // Bottom Row: Today, Week, and Year Avg
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Today', '₹${_getTodayExpenses().toStringAsFixed(2)}'),
              _buildStatCard('This Week', '₹${_getWeekExpenses().toStringAsFixed(2)}'),
              _buildStatCard('Year Avg/Day', '₹${avgDailyExpense.toStringAsFixed(2)}'),
            ],
          ),
          
          // const SizedBox(height: 16),
          // const Divider(),
          // const SizedBox(height: 10),
          
          // // Payment Method Breakdown for Today
          // Column(
          //   crossAxisAlignment: CrossAxisAlignment.start,
          //   children: [
          //     const Text(
          //       'Today\'s Payment Breakdown',
          //       style: TextStyle(
          //         fontSize: 14,
          //         fontWeight: FontWeight.bold,
          //         color: Colors.blue,
          //       ),
          //     ),
          //     const SizedBox(height: 8),
          //     Row(
          //       children: [
          //         _buildPaymentMethodCard('Cash', todayCash, Icons.money, Colors.green),
          //         _buildPaymentMethodCard('Online', todayOnline, Icons.payment, Colors.purple),
          //       ],
          //     ),
          //     const SizedBox(height: 8),
          //     Row(
          //       children: [
          //         _buildPaymentMethodCard('Card', todayCard, Icons.credit_card, Colors.orange),
          //         _buildPaymentMethodCard('Credit', todayCredit, Icons.credit_score, Colors.red),
          //       ],
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  // Add this method to get payment-wise expenses for today
  // Map<String, double> _getTodayPaymentWiseExpenses() {
  //   final today = DateTime.now();
  //   final Map<String, double> paymentTotals = {
  //     'Cash': 0,
  //     'Online': 0,
  //     'Card': 0,
  //     'Credit': 0,
  //   };
    
  //   for (final expense in _expenses) {
  //     // Check if expense is from today
  //     if (expense.date.day == today.day &&
  //         expense.date.month == today.month &&
  //         expense.date.year == today.year) {
        
  //       final paymentMethod = expense.paymentMethod ?? 'Cash';
  //       if (paymentTotals.containsKey(paymentMethod)) {
  //         paymentTotals[paymentMethod] = (paymentTotals[paymentMethod] ?? 0) + expense.amount;
  //       } else {
  //         paymentTotals['Cash'] = (paymentTotals['Cash'] ?? 0) + expense.amount;
  //       }
  //     }
  //   }
    
  //   return paymentTotals;
  // }

  // New payment method card widget
  // Widget _buildPaymentMethodCard(String method, double amount, IconData icon, Color color) {
  //   return Expanded(
  //     child: Container(
  //       margin: const EdgeInsets.symmetric(horizontal: 4),
  //       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
  //       decoration: BoxDecoration(
  //         color: color.withOpacity(0.1),
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(color: color.withOpacity(0.3)),
  //       ),
  //       child: Column(
  //         children: [
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Icon(icon, size: 14, color: color),
  //               const SizedBox(width: 4),
  //               Text(
  //                 method,
  //                 style: TextStyle(
  //                   fontSize: 11,
  //                   fontWeight: FontWeight.w600,
  //                   color: color,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 4),
  //           Text(
  //             '₹${amount.toStringAsFixed(2)}',
  //             style: TextStyle(
  //               fontSize: 13,
  //               fontWeight: FontWeight.bold,
  //               color: color,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }


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

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return const Center(child: Text('No expenses yet'));
    }
    return ListView.builder(
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return _buildExpenseItem(expense);
      },
    );
  }


Widget _buildExpenseItem(Expense expense) {
  return Dismissible(
    key: Key(expense.id),
    direction: DismissDirection.endToStart,
    background: Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white, size: 30),
    ),
    confirmDismiss: (direction) async => await _showDeleteConfirmation(expense),
    onDismissed: (direction) => _deleteExpense(expense),
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            if (expense.photoPath != null) {
              _showAttachedPhoto(expense.photoPath!);
            } else {
              _showAddPhotoDialog(expense);
            }
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: _getCategoryColor(expense.category),
            backgroundImage: expense.photoPath != null && File(expense.photoPath!).existsSync()
                ? FileImage(File(expense.photoPath!))
                : null,
            child: expense.photoPath == null || !File(expense.photoPath!).existsSync()
                ? Icon(
                    _getCategoryIcon(expense.category),
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${expense.category} • ${DateFormat('MMM dd, yyyy').format(expense.date)}',
            ),
            if (expense.quantity != null)
              Text(
                'Qty: ${expense.quantity} ${expense.unit ?? ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            if (expense.paymentMethod != null)
              Row(
                children: [
                  Icon(_getPaymentMethodIcon(expense.paymentMethod!), size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    expense.paymentMethod!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (expense.paymentMethod == 'Credit' && expense.dueAmount != null && expense.dueAmount! > 0)
                    Text(
                      ' • ₹${expense.dueAmount!.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                    ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () => _addNewExpense(expense),
            ),
            Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: expense.amount > 50 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Add helper method for payment method icons
IconData _getPaymentMethodIcon(String? method) {
  switch (method) {
    case 'Cash':
      return Icons.money;
    case 'Card':
      return Icons.credit_card;
    case 'Online':
      return Icons.payment;
    case 'Credit':
      return Icons.credit_score;
    default:
      return Icons.payment;
  }
}


  void _deleteExpense(Expense expense) async {
    try {
      final box = _store.box<expences>();
      final allExpenses = box.getAll();
      bool deleted = false;
      
      // Find the entity that contains this expense
      for (final entity in allExpenses) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
          // Compare with the expense ID (the one you see in logs: 1773411126136)
          if (map['id'].toString() == expense.id) {
            // Delete the photo if exists
            if (map['photoPath'] != null && map['photoPath'].toString().isNotEmpty) {
              await removeFileFromExternalStorage(map['photoPath']);
            }
            
            // Delete the entity using ObjectBox ID
            box.remove(entity.id);
            deleted = true;
            print_log('Deleted expense with ID: ${expense.id} (ObjectBox ID: ${entity.id})');
            break;
          }
        } catch (e) {
          print_log_red('Error parsing expense during delete: $e');
          continue;
        }
      }
      
      if (!deleted) {
        print_log_red('Expense with ID ${expense.id} not found in database');
        screen_massage(context, 'Expense not found in database');
        return;
      }
      
      // Update UI
      setState(() {
        _expenses.removeWhere((e) => e.id == expense.id);
      });
      
      // Delete from cloud
      await deleteExpenseFromCloud(expense.id);
      
      // Show success message
      screen_massage(context, '${expense.title} deleted successfully!');
      
      // Update total
      await ExpensesService.updateTotal(_totalExpenses);
      
    } catch (e) {
      print_log_red('Error deleting expense: $e');
      screen_massage(context, 'Error deleting expense: $e');
    }
  }

  Future<bool> _showDeleteConfirmation(Expense expense) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Expense'),
          content: Text('Are you sure you want to delete "${expense.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                
                final type = expense.expenseType ?? '';
                final title = expense.title;
                final qty   = expense.quantity ?? 0.0;

                // ----------------------------
                // DELETE STOCK RESTORATION LOGIC
                // ----------------------------
                if (type == 'Consumption') {
                  _updateInventoryStock(title, qty, type, delete: 'delete');

                } else if (type == 'Wastage') {
                  if (_inventoryItemNames.contains(title)) {
                    _updateInventoryStock(title, qty, type, delete: 'delete');

                  } else if (_menuItemNames.contains(title)) {
                    _updateMenuItemStock(title, qty, type, delete: 'delete');
                  }

                } else if (type == 'Sell') {
                  _updateMenuItemStock(title, qty, type, delete: 'delete');
                }

                Navigator.of(context).pop(true);
              },

              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ??
    false;
  }

  // ---------- Photo viewing & editing ----------
  void _showAttachedPhoto(String photoPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(photoPath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 50,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddPhotoDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Photo'),
          content: const Text(
            'This expense doesn\'t have a photo attached. Would you like to add one?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _editExpensePhoto(expense);
              },
              child: const Text('Add Photo'),
            ),
          ],
        );
      },
    );
  }

  void _editExpensePhoto(Expense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index == -1) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Photo to "${expense.title}"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (expense.photoPath != null)
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.file(
                    File(expense.photoPath!),
                    fit: BoxFit.cover,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _takePhotoFromCamera(expense);
                    },
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade800,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _pickPhotoFromGallery(expense);
                    },
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                    ),
                  ),
                  if (expense.photoPath != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _removeExpensePhoto(expense);
                      },
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade800,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhotoFromCamera([Expense? expense]) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera,imageQuality: 70,maxWidth: 800,);
    if (image == null) return;

    String? savedimagepath = await saveImageInternalStorageDirectory(image.path,foldername);
    if(savedimagepath == null) return ;

    if (expense != null) {
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        setState(
          () => _expenses[idx] = _expenses[idx].copyWith(photoPath: savedimagepath),
        );
        await _saveExpensesToPrefs(id: int.tryParse(expense.id) ,update: savedimagepath);
      }
    } else {
      setState(() {
        _selectedImage = File(savedimagepath);
        _imagePath = savedimagepath;
      });
    }
  }

  Future<void> _pickPhotoFromGallery([Expense? expense]) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image == null) return;

    String? savedimagepath = await saveImageInternalStorageDirectory(image.path,foldername);
    if(savedimagepath == null) return ;
    print_log("Expence Image saved to $savedimagepath");

    if (expense != null) {
      final idx = _expenses.indexWhere((e) => e.id == expense.id);
      if (idx != -1) {
        setState(
          () => _expenses[idx] = _expenses[idx].copyWith(photoPath: savedimagepath),
        );
        await _saveExpensesToPrefs(id: int.tryParse(expense.id) ,update: savedimagepath);
      }
    } else {
      setState(() {
        _selectedImage = File(savedimagepath);
        _imagePath = savedimagepath;
      });
    }
  }

  void _removeExpensePhoto(Expense expense) {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      setState(() => _expenses[idx] = _expenses[idx].copyWith(photoPath: null));
      _saveExpensesToPrefs(id: int.tryParse(expense.id) ,update: null);
      if (expense.photoPath != null && expense.photoPath!.isNotEmpty) {
        removeFileFromExternalStorage(expense.photoPath!);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo removed')));
    }
  }

  // ---------- Daywise Expenses Total ----------
  Map<DateTime, double> _getDaywiseExpenses() {
    final Map<DateTime, double> daywiseTotals = {};

    for (final expense in _expenses) {
      // Normalize the date to remove time component
      // print_log("expense date ${expense.date}");
      final dateOnly = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );

      daywiseTotals.update(
        dateOnly,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    // Sort by date (most recent first)
    final sortedEntries = daywiseTotals.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    // print_log("expense date ${sortedEntries}");
    return Map.fromEntries(sortedEntries);
  }

  void _showAddCategoryDialog(StateSetter setModalState) {
    final TextEditingController categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(hintText: 'Category Name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCategory = categoryController.text.trim();
              if (newCategory.isNotEmpty && !_categories.contains(newCategory)) {
                setState(() {
                  _categories.add(newCategory);
                  _selectedCategory = newCategory;
                });
                _saveCategories();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setModalState(() {
                    _selectedCategory = newCategory;
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Helper method to get supplier by name
// Future<Supplier?> _getSupplierByName(String name) async {
//   try {
//     final box = _store.box<Supplier>();
//     final query = box.query(Supplier_.supplierName.equals(name)).build();
//     final suppliers = query.find();
//     query.close();
//     return suppliers.isNotEmpty ? suppliers.first : null;
//   } catch (e) {
//     print_log_red('Error finding supplier: $e');
//     return null;
//   }
// }


// Optional: Edit supplier
// void _showEditSupplierDialog(Supplier supplier) {
//   // Navigate to your edit supplier page or show dialog
//   // You can implement this based on your existing supplier edit functionality
// }

// Helper methods for the dynamic title field
Color _getTypeColor() {
  switch (_expenseType) {
    case 'Expense':
      return Colors.blue;
    case 'Consumption':
      return Colors.green;
    case 'Wastage':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

String _getTypeLabel() {
  switch (_expenseType) {
    case 'Expense':
      return 'EXPENSE';
    case 'Consumption':
      return 'CONSUMPTION';
    case 'Wastage':
      return 'CONSUMPTION';
    default:
      return 'SELL';
  }
}

String _getTitleLabel() {
  switch (_expenseType) {
    case 'Expense':
      return 'Expense Title';
    case 'Consumption':
      return 'Inventory Item';
    case 'Wastage':
      return 'Inventory Item';
    default:
      return 'Menu Item';
  }
}

String _getHintText() {
  switch (_expenseType) {
    case 'Expense':
      return 'Type to search previous expenses...';
    case 'Consumption':
      return 'Type to search inventory items...';
    default:
      return 'Type to search menu items...';
  }
}

IconData _getTitleIcon() {
  switch (_expenseType) {
    case 'Expense':
      return Icons.receipt;
    case 'Consumption':
      return Icons.inventory;
    default:
      return Icons.restaurant_menu;
  }
}

// // Get details for inventory item
// Widget? _getInventoryItemDetails(String itemName) {
//   try {
//     final box = _store.box<InventoryItem>();
//     final query = box.query(InventoryItem_.name.equals(itemName)).build();
//     final items = query.find();
//     query.close();
    
//     if (items.isNotEmpty) {
//       final item = items.first;
//       return Text(
//         'Stock: ${item.stockQuantity} ${item.unit} • ${item.category ?? 'No Category'}',
//         style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//       );
//     }
//   } catch (e) {
//     print_log_red('Error getting inventory details: $e');
//   }
//   return null;
// }

// Get details for menu item
// Widget? _getMenuItemDetails(String itemName) {
//   try {
//     final box = _store.box<MenuItem>();
//     final query = box.query(MenuItem_.name.equals(itemName)).build();
//     final items = query.find();
//     query.close();
    
//     if (items.isNotEmpty) {
//       final item = items.first;
//       return Text(
//         'Price: ₹${item.sellPrice} • ${item.category}',
//         style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//       );
//     }
//   } catch (e) {
//     print_log_red('Error getting menu details: $e');
//   }
//   return null;
// }

// Get details for existing expense
Widget? _getExpenseDetails(String title) {
  // Find the most recent expense with this title
  final matchingExpenses = _expenses.where((e) => e.title == title).toList();
  if (matchingExpenses.isNotEmpty) {
    final expense = matchingExpenses.first;
    return Text(
      'Last amount: ₹${expense.amount} • ${expense.category}',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }
  return null;
}

// Auto-fill fields based on selection
void _autoFillBasedOnSelection(String selection, StateSetter setModalState) {

// Auto-fill category from previous expense
    final matchingExpenses = _expenses.where((e) => e.title == selection).toList();
    if (matchingExpenses.isNotEmpty) {
      final expense = matchingExpenses.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setModalState(() {
          _supplierController.text = expense.supplierName ?? "";
          _amountController.text = (expense.amount).toString();
          _qtyController.text = (expense.quantity ?? 0).toString();
          _descriptionController.text = expense.description ?? "";
          _recivedAmountController.text = (expense.receivedAmount?? 0).toString();
          _unitController.text = expense.unit ?? 'unit';
          _selectedPaymentMethod = expense.paymentMethod ?? 'Cash';
          _selectedUnit = expense.unit ?? 'unit';
          _selectedCategory = expense.category;
          
        });
      });

    } else {

    if (_expenseType == 'Consumption'|| _expenseType == 'Wastage') {
      // Auto-fill unit from inventory
      try {
        final box = _store.box<InventoryItem>();
        final query = box.query(InventoryItem_.name.equals(selection)).build();
        final items = query.find();
        query.close();
        
        if (items.isNotEmpty) {
          final item = items.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
          setModalState(() {
            _selectedUnit = item.unit;
            // You might also want to set category or other fields
          });
          });
        }
      } catch (e) {
        print_log_red('Error auto-filling inventory: $e');
      }
    } else if (_expenseType == 'Expense') {
      // Auto-fill category from previous expense
      final matchingExpenses = _expenses.where((e) => e.title == selection).toList();
      if (matchingExpenses.isNotEmpty) {
        final expense = matchingExpenses.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setModalState(() {
            // _selectedCategory = expense.category;
            // if (expense != null) {
            _supplierController.text = expense.supplierName!;
            _amountController.text = expense.amount.toString();
            _qtyController.text = expense.quantity.toString();
            _descriptionController.text = expense.description!;
            _recivedAmountController.text = expense.receivedAmount.toString();
            _unitController.text = expense.unit!;
            _selectedPaymentMethod = expense.paymentMethod!;
            _selectedUnit = expense.unit!;
            _expenseType = expense.expenseType!;
            _selectedCategory = expense.category;
          // }
          });
        });
      }
    } else {
      // Auto-fill for menu items
      try {
        final box = _store.box<MenuItem>();
        final query = box.query(MenuItem_.name.equals(selection)).build();
        final items = query.find();
        query.close();
        
        if (items.isNotEmpty) {
          final item = items.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
          setModalState(() {
            _amountController.text = (item.f_price ?? 0).toString();
            // _qtyController.text = (item.adjustStock ?? 0).toString();
            // _selectedCategory = item.category;
          });
          });
        }
      } catch (e) {
        print_log_red('Error auto-filling menu: $e');
      }
    }
  }
}

// Build selected item info
Widget _buildSelectedItemInfo() {
  // print_log(" $_expenseType  ${(_expenseType == 'Wastage' && _inventoryItemNames.contains(_titleController.text))}");
  if (_expenseType == 'Consumption' || (_expenseType == 'Wastage' && _inventoryItemNames.contains(_titleController.text))) {
    return FutureBuilder<InventoryItem?>(
      future: _getInventoryItemByName(_titleController.text),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final item = snapshot.data!;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Stock: ${item.stockQuantity} ${item.unit} • ${item.category ?? 'No Category'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  } else if (_expenseType == 'Expense') {
    // Show recent expense info
    final recentExpenses = _expenses.where((e) => e.title == _titleController.text).toList();
    if (recentExpenses.isNotEmpty) {
      final expense = recentExpenses.first;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.history, color: Colors.blue, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Previous: ₹${expense.amount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Category: ${expense.category}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  } else if (_expenseType == 'Sell' || (_expenseType == 'Wastage' && _menuItemNames.contains(_titleController.text))) {
    // Menu item info
    return FutureBuilder<MenuItem?>(
      future: _getMenuItemByName(_titleController.text),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final item = snapshot.data!;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Stock: ₹${item.adjustStock} • Price: ₹${item.h_price} • ${item.category}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  return const SizedBox.shrink();
}

// Helper methods to get items by name
Future<InventoryItem?> _getInventoryItemByName(String name) async {
  try {
    final box = _store.box<InventoryItem>();
    final query = box.query(InventoryItem_.name.equals(name)).build();
    final items = query.find();
    query.close();
    return items.isNotEmpty ? items.first : null;
  } catch (e) {
    print_log_red('Error finding inventory item: $e');
    return null;
  }
}

Future<MenuItem?> _getMenuItemByName(String name) async {
  try {
    final box = _store.box<MenuItem>();
    final query = box.query(MenuItem_.name.equals(name)).build();
    final items = query.find();
    query.close();
    return items.isNotEmpty ? items.first : null;
  } catch (e) {
    print_log_red('Error finding menu item: $e');
    return null;
  }
}



// Stock management methods
Future<void> _updateInventoryStock(String itemName, double quantity, String action,{String? delete}) async {
  try {
    if(delete != null){
      
      final box = _store.box<InventoryItem>();
      final query = box.query(InventoryItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();
      double? addValue;
      if (items.isNotEmpty) {
        final item = items.first;
        
        switch (action) {
          case 'Consumption':
            item.stockQuantity -= quantity;
            addValue = -quantity;
            break;
          case 'Wastage':
            item.stockQuantity += quantity;
            addValue = quantity;
            break;
          case 'add':
            item.stockQuantity -= quantity;
            break;
        }
        
        await box.putAsync(item);
        print_log('Inventory updated: ${item.name} - New stock: ${item.stockQuantity} ${item.unit} $addValue $delete');
        if(addValue != null) await sync.sendStockToServer(item,addValue,"");
        
        
        
      } else {
        throw Exception('Item "$itemName" not found in inventory');
      }
    }else{

      final box = _store.box<InventoryItem>();
      final query = box.query(InventoryItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();
      double? addValue;
      if (items.isNotEmpty) {
        final item = items.first;
        
        switch (action) {
          case 'Consumption':
            item.stockQuantity += quantity;
            addValue = quantity;
            break;
          case 'Wastage':
            item.stockQuantity -= quantity;
            addValue = -quantity;
            break;
          case 'add':
            item.stockQuantity += quantity;
            break;
        }
        
        await box.putAsync(item);
        if(addValue != null) await sync.sendStockToServer(item,addValue,"");
        
        print_log('Inventory updated: ${item.name} - New stock: ${item.stockQuantity} ${item.unit}');
        
      } else {
        throw Exception('Item "$itemName" not found in inventory');
      }
    }
  } catch (e) {
    print_log_red('Error updating inventory: $e');
    throw Exception('Error updating inventory: $e');
    // rethrow;
  }
}

Future<void> _updateMenuItemStock(String itemName, double quantity, String action,{String? delete}) async {
  try {
    if(delete != null){
      final box = _store.box<MenuItem>();
      final query = box.query(MenuItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();
      int? addValue;
      if (items.isNotEmpty) {
        final item = items.first;
        
        // For menu items, we track available quantity
        if (item.adjustStock! < 1) item.available = 0;
        
        switch (action) {
          case 'Sell':
            item.adjustStock = item.adjustStock! - quantity.toInt();
            addValue = (-quantity.toInt());
            break;
          case 'Wastage':
            item.adjustStock = item.adjustStock! + quantity.toInt();
            addValue = (quantity.toInt());
            break;
          case 'add':
            item.adjustStock = (item.adjustStock ?? 0) - quantity.toInt();
            break;
        }
        
        await box.putAsync(item);
        if (addValue != null) await sendStockToServer(item, addValue);
        print_log('Menu item updated: ${item.name} - New available: ${item.adjustStock}');
        

      } else {
        throw Exception('Item "$itemName" not found in menu');
      }
    }else{
      final box = _store.box<MenuItem>();
      final query = box.query(MenuItem_.name.equals(itemName)).build();
      final items = query.find();
      query.close();
      int? addValue;
      if (items.isNotEmpty) {
        final item = items.first;
        
        // For menu items, we track available quantity
        if (item.adjustStock! < 1) item.available = 0;
        
        switch (action) {
          case 'Sell':
            item.adjustStock = item.adjustStock! + quantity.toInt();
            addValue = quantity.toInt();
            break;
          case 'Wastage':
            // print_log("Wastage ${item.adjustStock} ${quantity.toInt()}");
            item.adjustStock = item.adjustStock! - quantity.toInt();
            addValue = (-quantity.toInt());
            // print_log("Wastage ${item.adjustStock}");
            break;
          case 'add':
            item.adjustStock = (item.adjustStock ?? 0) + quantity.toInt();
            break;
        }
        
        await box.putAsync(item);
        if (addValue != null) await sendStockToServer(item, addValue);
        print_log('Menu item updated: ${item.name} - New available: ${item.adjustStock}');
        

      } else {
        throw Exception('Item "$itemName" not found in menu');
      }
    }
    } catch (e) {
      print_log_red('Error updating menu item: $e');
      rethrow;
    }
}



// In the optionsViewBuilder of your autocomplete, enhance the item display
Widget? _getInventoryItemDetails(String itemName) {
  try {
    final box = _store.box<InventoryItem>();
    final query = box.query(InventoryItem_.name.equals(itemName)).build();
    final items = query.find();
    query.close();
    
    if (items.isNotEmpty) {
      final item = items.first;
      final isLowStock = item.stockQuantity < 10;
      final stockColor = isLowStock ? Colors.red : Colors.green;
      
      return Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: stockColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Stock: ${item.stockQuantity} ${item.unit} • ${item.category ?? 'No Category'}',
              style: TextStyle(
                fontSize: 12,
                color: isLowStock ? Colors.red : Colors.grey.shade600,
                fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      );
    }
  } catch (e) {
    print_log_red('Error getting inventory details: $e');
  }
  return null;
}

Widget? _getMenuItemDetails(String itemName) {
  try {
    final box = _store.box<MenuItem>();
    final query = box.query(MenuItem_.name.equals(itemName)).build();
    final items = query.find();
    query.close();
    
    if (items.isNotEmpty) {
      final item = items.first;
      final available = item.available ?? 0;
      final isLowStock = available < 5;
      final stockColor = isLowStock ? Colors.red : Colors.green;
      
      return Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: stockColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Available: $available • ₹${item.sellPrice} • ${item.category}',
              style: TextStyle(
                fontSize: 12,
                color: isLowStock ? Colors.red : Colors.grey.shade600,
                fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      );
    }
  } catch (e) {
    print_log_red('Error getting menu details: $e');
  }
  return null;
}

// Future<double?> _getCurrentStock(String itemName, String type) async {
//   try {
//     if (type == 'Consumption' || type == 'Wastage') {
//       final box = _store.box<InventoryItem>();
//       final query = box.query(InventoryItem_.name.equals(itemName)).build();
//       final items = query.find();
//       query.close();
//       return items.isNotEmpty ? items.first.stockQuantity : null;
//     } else if (type == 'Sell') {
//       final box = _store.box<MenuItem>();
//       final query = box.query(MenuItem_.name.equals(itemName)).build();
//       final items = query.find();
//       query.close();
//       return items.isNotEmpty ? (items.first.available ?? 0).toDouble() : null;
//     }
//     return null;
//   } catch (e) {
//     print_log_red('Error getting current stock: $e');
//     return null;
//   }
// }
// Future<void> _logStockAdjustment(String itemName, double quantity, String action, String type) async {
//   // You can create a separate entity for stock logs if needed
//   final logEntry = {
//     'timestamp': DateTime.now().toIso8601String(),
//     'itemName': itemName,
//     'quantity': quantity,
//     'action': action, // 'consume', 'wastage', 'sell', 'add'
//     'type': type,
//     'expenseId': ganarateID().toString(),
//   };
  
//   // Store in SharedPreferences or create a new entity
//   final prefs = await SharedPreferences.getInstance();
//   final logs = prefs.getStringList('stock_logs') ?? [];
//   logs.add(jsonEncode(logEntry));
//   await prefs.setStringList('stock_logs', logs);
  
//   print_log('Stock adjustment logged: $logEntry');
// }

// Helper method to get color based on item type
Color _getTypeColorForItem(String itemName, String itemType) {
  if (_expenseType == 'Wastage') {
    if (itemType == 'Inventory') {
      return Colors.green;
    } else if (itemType == 'Menu Item') {
      return Colors.orange;
    }
  }
  return _getTypeColor();
}

// Helper method to get icon based on item type
IconData _getIconForItemType(String itemType) {
  switch (itemType) {
    case 'Inventory':
      return Icons.inventory;
    case 'Menu Item':
      return Icons.restaurant_menu;
    default:
      return Icons.receipt;
  }
}



  /// ---------- Add new expense ----------
 void _addNewExpense(Expense? expense) {
  _clearForm();
   _recivedAmountController.text = "0.0";
  if(expense != null){
      // Pre-fill the form with existing expense data
    _titleController.text = expense.title;
    _amountController.text = expense.amount.toString();
    _selectedDate = expense.date;
    _selectedCategory = expense.category;
    _imagePath = expense.photoPath;
    if (expense.photoPath != null && File(expense.photoPath!).existsSync()) {
      _selectedImage = File(expense.photoPath!);
    } else {
      _selectedImage = null;
    }
    
    // Pre-fill new fields
    _supplierController.text = expense.supplierName ?? '';
    if (expense.quantity != null) {
      _qtyController.text = expense.quantity.toString();
    }
    _selectedUnit = expense.unit ?? 'unit';
    _selectedPaymentMethod = expense.paymentMethod ?? 'Cash';
    if (expense.receivedAmount != null) {
      _recivedAmountController.text = expense.receivedAmount.toString();
    }
    _descriptionController.text = expense.description ?? '';
    _expenseType = expense.expenseType ?? 'Expense';
    _selectedUnit = 'unit';
    if(mounted){
      setState(() {
        
      });
    }
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text(
                      'Add New Expense',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // TOP SECTION: Image (Left) | Camera/Gallery & Date (Right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Photo Preview
                        SizedBox(
                          width: 120,
                          height: 100,
                          child: _buildPhotoUploadSection(), 
                        ),
                        const SizedBox(width: 8),
                        
                        // Right: Controls & Date
                        Expanded(
                          child: Column(
                            children: [
                              // Date Picker Styled Input
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() => _selectedDate = picked);
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: _buildInputDecoration('Expense Date', Icons.calendar_today),
                                  child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // You mentioned Camera/Gallery on right - 
                              // usually these are buttons inside your _buildPhotoUploadSection,
                              // but if you want them separate as buttons:
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await _takePhotoFromCamera();
                                        setState(() {});
                                      }, // Trigger Camera
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800, elevation: 0),
                                      child: const Icon(Icons.camera_alt),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await _pickPhotoFromGallery();
                                        setState(() {});
                                      }, // Trigger Gallery
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800, elevation: 0),
                                      child: const Icon(Icons.photo_library),
                                    ),
                                  ),
                                  if (_selectedImage != null)
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          _removePhoto();
                                            setState(() {});
                                        }, // Trigger Gallery
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800, elevation: 0),
                                        child: const Icon(Icons.remove),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // 2. Selection Type: Consumption vs Expense
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text("Expense")),
                                selected: _expenseType == 'Expense',
                                selectedColor: Colors.blue.shade100,
                                onSelected: (bool selected) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setModalState(() {
                                    _expenseType = 'Expense';
                                    _titleController.clear(); // Clear when switching types
                                  });
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text("Consumption")),
                                selected: _expenseType == 'Consumption',
                                selectedColor: Colors.green.shade100,
                                onSelected: (bool selected) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setModalState(() {
                                    _expenseType = 'Consumption';
                                    _titleController.clear(); // Clear when switching types
                                  });
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text("Sell Item")),
                                selected: _expenseType == 'Sell',
                                selectedColor: Colors.orange.shade100,
                                onSelected: (bool selected) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setModalState(() {
                                    _expenseType = 'Sell';
                                    _titleController.clear(); // Clear when switching types
                                  });
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text("Wastage")),
                                selected: _expenseType == 'Wastage',
                                selectedColor: Colors.red.shade100,
                                onSelected: (bool selected) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                  setModalState(() {
                                    _expenseType = 'Wastage';
                                    _titleController.clear(); // Clear when switching types
                                  });
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selection Titel 
                    Row(
                      children: [
                        Expanded(
                          child:  Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getTypeLabel(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getTitleLabel(),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              RawAutocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  
                                  // Get suggestions based on expense type
                                  List<String> suggestions = [];
                                  if (_expenseType == 'Expense') {
                                    suggestions = _expenseTitles;
                                  } else if (_expenseType == 'Consumption') {
                                    suggestions = _inventoryItemNames;
                                  } else if (_expenseType == 'Sell') {
                                    // For sell items (you can add another type)
                                    suggestions = _menuItemNames;
                                  } else{
                                    // For sell items (you can add another type)
                                    suggestions = [..._inventoryItemNames, ..._menuItemNames];
                                  }
                                  
                                  return suggestions.where((item) => item.toLowerCase().contains(textEditingValue.text.toLowerCase())).take(10);

                                },
                                onSelected: (String selection) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setModalState(() {
                                      _titleController.text = selection;
                                      // _titleFocusNode.unfocus();
                                      _autoFillBasedOnSelection(selection, setModalState);
                                      // Focus on amount field after a short delay
                                      // Future.delayed(const Duration(milliseconds: 200), () {
                                      //   FocusScope.of(context).requestFocus(_amountFocusNode);
                                      // });
                                      
                                    });
                                  });
                                },
                                
                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                  textEditingController.text = _titleController.text;
                                  });
                                  
                                  return TextFormField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    onChanged: (value) {
                                      _titleController.text = value;
                                    },
                                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                    onEditingComplete: () {
                                      // Hide keyboard and suggestions when editing is complete
                                      focusNode.unfocus();
                                    },
                                    decoration: InputDecoration(
                                      hintText: _getHintText(),
                                      prefixIcon: Icon(
                                        _getTitleIcon(),
                                        color: Colors.blue.shade700,
                                      ),
                                      suffixIcon: _titleController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () {
                                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                                  setModalState(() {
                                                    _titleController.clear();
                                                    textEditingController.clear();
                                                  });
                                                });
                                              },
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: Colors.blue.shade50.withValues(alpha:0.3),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade100),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  );

                                },
                                optionsViewBuilder: (BuildContext context, 
                                  AutocompleteOnSelected<String> onSelected, 
                                Iterable<String> options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width * 0.8,
                                      constraints: const BoxConstraints(maxHeight: 250),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withValues(alpha:0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        shrinkWrap: true,
                                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                        itemBuilder: (BuildContext context, int index) {
                                          final option = options.elementAt(index);
                                          
                                          // Determine the type of item for wastage
                                          String itemType = '';
                                          Widget? subtitle;
                                          
                                          if (_expenseType == 'Wastage') {
                                            // Check if it's an inventory item
                                            if (_inventoryItemNames.contains(option)) {
                                              itemType = 'Inventory';
                                              subtitle = _getInventoryItemDetails(option);
                                            } else if (_menuItemNames.contains(option)) {
                                              itemType = 'Menu Item';
                                              subtitle = _getMenuItemDetails(option);
                                            }
                                          } else {
                                            // For other types, use existing logic
                                            if (_expenseType == 'Consumption') {
                                              subtitle = _getInventoryItemDetails(option);
                                            } else if (_expenseType == 'Sell') {
                                              subtitle = _getMenuItemDetails(option);
                                            } else if (_expenseType == 'Expense') {
                                              subtitle = _getExpenseDetails(option);
                                            }
                                          }
                                          
                                          return ListTile(
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: _getTypeColorForItem(option, itemType).withValues(alpha:0.2),
                                              child: Icon(
                                                _getIconForItemType(itemType),
                                                size: 16,
                                                color: _getTypeColorForItem(option, itemType),
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    option,
                                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                                if (itemType.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getTypeColorForItem(option, itemType).withValues(alpha:0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      itemType,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: _getTypeColorForItem(option, itemType),
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            subtitle: subtitle,
                                            onTap: () {
                                              onSelected(option);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              ),
                              
                              // Show additional info if an item is selected
                              if (_titleController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildSelectedItemInfo(),
                              ],
                            ],
                          ),
                                        
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add_business, color: Colors.green.shade700),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const InventoryPage()),
                              );
                              if (mounted) {
                                setModalState(() {
                                  _loadInventoryItems();
                                });
                              }
                            },
                            tooltip: 'View Inventory',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Amount & Payment Method Section
                    Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // Keeps items aligned at top
                          children: [
                            // 1. Total Amount
                            Expanded(
                              flex: 2, // Give Amount slightly more room
                              child: TextFormField(
                                controller: _amountController,
                                decoration: _buildInputDecoration('Total Amount', Icons.account_balance_wallet),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // 2. Payment Method
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedPaymentMethod,
                                decoration: _buildInputDecoration('Payment', Icons.payments),
                                items: ['Cash', 'Online', 'Card', 'Credit']
                                    .map((m) => DropdownMenuItem(
                                          value: m, 
                                          child: Text(m, style: const TextStyle(fontSize: 12)) // Slightly smaller font
                                        ))
                                    .toList(),
                                onChanged: (v) => setModalState(() => _selectedPaymentMethod = v!),
                              ),
                            ),
                          ],
                        ),
                        
                        // 3. Show Received Amount below if Credit is selected
                        if (_selectedPaymentMethod == 'Credit') ...[
                        const SizedBox(height: 12),
                        
                        // Row for Received Amount and Due Date
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Received Amount Field
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: _recivedAmountController,
                                onTap: () {
                                  if (_recivedAmountController.text == '0') {
                                    _recivedAmountController.clear();
                                  }
                                },
                                onChanged: (value) {
                                  setState(() {}); // Update UI for remaining amount
                                },
                                decoration: _buildInputDecoration('Received Amount', Icons.payments,),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }
                                  if (double.tryParse(v) == null) {
                                    return 'Invalid amount';
                                  }
                                  return null;
                                },
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Due Date Field
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: _dueDateController,
                                readOnly: true,
                                onTap: () => _selectDueDate(context),
                                decoration: InputDecoration(
                                      labelText: "Due Date",
                                      filled: true,
                                      fillColor: Colors.blue.shade50.withOpacity(0.3),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade100),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                    ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Select due date' : null,
                              ),
                            ),
                          ],
                        ),
                        
                        // Remaining amount info
                        if (_recivedAmountController.text.isNotEmpty && 
                            double.tryParse(_recivedAmountController.text) != null &&
                            double.tryParse(_recivedAmountController.text) != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Remaining: ₹ ${((double.tryParse(_amountController.text)??0.0) - (double.tryParse(_recivedAmountController.text) ?? 0.0)).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Qty & unit Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            decoration: _buildInputDecoration('Quantity', Icons.production_quantity_limits),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // Use the String variable here, NOT the controller
                            value: _selectedUnit, 
                            decoration: _buildInputDecoration('unit', Icons.straighten),
                            items: units
                                .map((u) => DropdownMenuItem(
                                      value: u, 
                                      child: Text(u, style: const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                              setModalState(() {
                                _selectedUnit = v!;
                              });
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // After the supplier autocomplete field, add a quick add button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Supplier Input with Autocomplete
                              RawAutocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  // Filter supplier names based on input
                                  return _supplierNames.where(
                                    (supplier) => supplier.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase(),
                                    ),
                                  ).take(10); // Limit to 10 suggestions
                                },
                                onSelected: (String selection) {
                                  // When a supplier is selected, find and set the full supplier
                                  final selectedSupplier = _suppliers.firstWhere(
                                    (s) => s.supplierName == selection,
                                    orElse: () => Supplier(syid:ganarateID(), supplierName: selection),
                                  );
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setModalState(() {
                                      _supplierController.text = selection;
                                      _supplierMobileController.text = selectedSupplier.mobileNumber ?? '';
                                    });
                                    
                                  });
                                  
                                  // Optional: Show supplier details in a snackbar
                                  if (selectedSupplier.mobileNumber != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Supplier: ${selectedSupplier.supplierName}\nMobile: ${selectedSupplier.mobileNumber}'),
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                },
                                fieldViewBuilder: (BuildContext context,TextEditingController textEditingController,FocusNode focusNode,VoidCallback onFieldSubmitted) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    textEditingController.text = _supplierController.text;
                                  });
                                  
                                  return TextFormField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    validator: (value) {
                                      if (_selectedPaymentMethod == 'Credit') {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Supplier is required for credit';
                                        }
                                      }
                                      return null;
                                    },
                                    onChanged: (value) {
                                      // Update the main controller
                                      _supplierController.text = value;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Select Supplier',
                                      prefixIcon: Icon(Icons.person_search, color: Colors.blue.shade700),
                                      suffixIcon: _supplierController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () {
                                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                                  setModalState(() {
                                                    _supplierController.clear();
                                                    textEditingController.clear();
                                                  });
                                                });
                                              },
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: Colors.blue.shade50.withOpacity(0.3),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade100),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                    ),
                                  );
                                },
                                optionsViewBuilder: (BuildContext context, 
                                    AutocompleteOnSelected<String> onSelected, 
                                    Iterable<String> options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4.0,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: MediaQuery.of(context).size.width * 0.8,
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListView.separated(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          shrinkWrap: true,
                                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = options.elementAt(index);
                                            final supplier = _suppliers.firstWhere(
                                              (s) => s.supplierName == option,
                                              orElse: () => Supplier(syid:ganarateID(), supplierName: option),
                                            );
                                            
                                            return ListTile(
                                              leading: CircleAvatar(
                                                radius: 16,
                                                backgroundColor: Colors.blue.shade100,
                                                child: Text(
                                                  option.isNotEmpty ? option[0].toUpperCase() : '?',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade800,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                option,
                                                style: const TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              subtitle: supplier.mobileNumber != null
                                                  ? Text(
                                                      supplier.mobileNumber!,
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                    )
                                                  : null,
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add_business, color: Colors.green.shade700),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PartyListPage()),
                              );
                              if (mounted) {
                                setModalState(() {
                                  _loadSuppliers();
                                });
                              }
                            },
                            tooltip: 'View Suppliers',
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    // Category with Add Button
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
                            decoration: _buildInputDecoration('Category', Icons.category),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) {
                              setModalState(() => _selectedCategory = v ?? _categories.first);
                              setState(() => _selectedCategory = v ?? _categories.first);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: () => _showAddCategoryDialog(setModalState),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextFormField(
                      controller: _descriptionController, // Ensure this controller exists
                      maxLines: 2,
                      decoration: _buildInputDecoration('Description / Notes', Icons.description),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // In your button
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _isSavingNotifier,
                            builder: (context, isLoading, child) {
                              return ElevatedButton(
                                onPressed: isLoading 
                                    ? null 
                                    : (expense != null ? () => _updateExpense(expense.id) : _saveExpense),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  disabledBackgroundColor: Colors.grey.shade400,
                                ),
                                child: Text(
                                  isLoading 
                                      ? 'Saving...' 
                                      : (expense != null ? 'Update Expense' : 'Save Expense'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// Add update method
void _updateExpense(String expenseId) {
  if (!_formKey.currentState!.validate()) return;

  double? receivedAmount;
  if (_selectedPaymentMethod == 'Credit' && _recivedAmountController.text.isNotEmpty) {
    receivedAmount = double.tryParse(_recivedAmountController.text);
  }

  final updatedExpense = Expense(
    id: expenseId,
    title: _titleController.text.trim(),
    amount: double.parse(_amountController.text),
    date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
    category: _selectedCategory,
    photoPath: _imagePath,
    supplierName: _supplierController.text.isNotEmpty ? _supplierController.text.trim() : null,
    quantity: _qtyController.text.isNotEmpty ? double.tryParse(_qtyController.text) : null,
    unit: _selectedUnit != 'unit' ? _selectedUnit : null,
    paymentMethod: _selectedPaymentMethod,
    receivedAmount: receivedAmount,
    description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : null,
    expenseType: _expenseType,
  );

  // Update in list
  final index = _expenses.indexWhere((e) => e.id == expenseId);
  if (index != -1) {
    setState(() {
      _expenses[index] = updatedExpense;
    });
  }

  // Update in database
  _updateExpenseInDatabase(updatedExpense);
  
  _clearForm();
  Navigator.pop(context);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('"${updatedExpense.title}" updated successfully!'),
      backgroundColor: Colors.blue,
    ),
  );
}

// Add method to update in database
Future<void> _updateExpenseInDatabase(Expense expense) async {
  try {
    final box = _store.box<expences>();
    final allExpenses = box.getAll();
    
    for (final entity in allExpenses) {
      final map = Map<String, dynamic>.from(jsonDecode(entity.expence));
      if (map['id'].toString() == expense.id) {
        entity.expence = jsonEncode(expense.toMap());
        await box.putAsync(entity);
        
        // Sync with cloud
        final prefs = await SharedPreferences.getInstance();
        final hotelName = await prefs.getString(AppConstants.usernameKey) ?? "";
        await syncExpenseToCloud(entity.id, expense, hotelName,box);
        
        print_log('Expense updated: ${expense.id}');
        break;
      }
    }
  } catch (e) {
    print_log_red('Error updating expense: $e');
  }
}



// Shared Styling Helper (Blue version for Expenses)
InputDecoration _buildInputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: Colors.blue.shade700),
    filled: true,
    fillColor: Colors.blue.shade50.withOpacity(0.3),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.blue.shade100),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
  );
}

  Widget _buildPhotoUploadSection() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _selectedImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                )
              : Icon(Icons.receipt, size: 40, color: Colors.grey.shade400),
        ),
      ],
    );
  }




  udhariCustomer _findOrCreateCustomer(Box<udhariCustomer> customerBox, String name, String phone,String adreess) {
    //debugPrint("currentCustomer $name ");

    final query = customerBox.query(udhariCustomer_.name.equals(name.trim())).build();
    udhariCustomer? existingCustomer = query.findFirst();
    query.close(); // Always close your queries

    if (existingCustomer != null) {
      // Customer was found, return them
      //debugPrint("Udhari currentCustomer Found existing customer: ${existingCustomer.name}");
      return existingCustomer;
    } else {
      // Customer not found, create a new one
      //debugPrint("Udhari currentCustomer Creating new customer: $name");
      final newCustomer = udhariCustomer(
        syid:ganarateID(), 
        ucuniid : DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        phone: phone.isNotEmpty ? phone.trim() : '',
        adreess: adreess.isNotEmpty ? adreess.trim() : '',
      );
      
      // Save the new customer to the box and return them
      customerBox.put(newCustomer);
      return newCustomer;
    }
  }



  void saveEntry(String name, String phone,String adreess, String amountController, String descriptionController) {
    
    // Get the ObjectBox service and the customer box
    Box<udhariCustomer> customerBox = _store.box<udhariCustomer>();

    // This is the logic you wanted:
    // "i want to check the name is exist in the udhariCustomer if not create else assign to currentCustomer"
    final udhariCustomer currentCustomer = _findOrCreateCustomer(customerBox, name, phone, adreess);
    //debugPrint("Udhari currentCustomer $currentCustomer");

    // Now the rest of your code will work, because 'currentCustomer' is set!
    double  amount = double.parse(amountController); // You may want to use double.tryParse for safety
    String  description = descriptionController.trim();
    // Parse due date
    DateTime dueDate;
    try {
      // Parse from format "dd-MM-yyyy"
      List<String> parts = _dueDateController.text.split('-');
      if (parts.length == 3) {
        dueDate = DateTime(
          int.parse(parts[2]), 
          int.parse(parts[1]), 
          int.parse(parts[0])
        );
      } else {
        dueDate = DateTime.now().add(const Duration(days: 7)); // Default
      }
    } catch (e) {
      dueDate = DateTime.now().add(const Duration(days: 7)); // Default on error
    }

    TransactionUdhari newTransaction = TransactionUdhari.create(
      syid:ganarateID(), 
      amount: amount,
      type: TransactionType.got,
      date: DateTime.now(),
      description: description.isEmpty ? '' : description,
      dueDate: dueDate,
    );


    //debugPrint("Udhari currentCustomer $newTransaction");

    // Link the transaction to the customer
    newTransaction.customer.target = currentCustomer;

    // Save the transaction
    _store.box<TransactionUdhari>().put(newTransaction);
    
    // Save the customer to update their list of transactions
    // (This is from your original code and is correct for updating the relation)
    currentCustomer.transactions.add(newTransaction);
    _store.box<udhariCustomer>().put(currentCustomer);

    //debugPrint("Udhari currentCustomer Transaction saved for customer: ${currentCustomer.name}");

    // Send SMS right after saving
    // _sendTransactionSms(currentCustomer, newTransaction);
  }



void _saveExpense() async {

  if(!(_inventoryItemNames.contains(_titleController.text) || _menuItemNames.contains(_titleController.text)) && _expenseType != "Expense") {
    Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add this Item in Inventry First!'),
          backgroundColor: Colors.red,
        ),
      );
      // Navigator.pop(context);
      return;
  }
  if (_isSavingNotifier.value) return;
  if (!_formKey.currentState!.validate()) return;
   _isSavingNotifier.value = true;
  try {
    double? receivedAmount;
    double pendingamount = 0.0;
    if (_selectedPaymentMethod == 'Credit' && _recivedAmountController.text.isNotEmpty && _amountController.text.isNotEmpty) {
      receivedAmount = double.tryParse(_recivedAmountController.text) ?? 0.0;
      pendingamount = double.parse(_amountController.text) - receivedAmount;
    }

    // Get quantity
    double quantity = _qtyController.text.isNotEmpty 
        ? double.tryParse(_qtyController.text) ?? 0 
        : 0;

    // Validate stock for consumption, sell, and wastage
    if ((_expenseType == 'Consumption' || _expenseType == 'Sell' || _expenseType == 'Wastage') && quantity > 0) {
      
      // Check if item exists
      if (_titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an item'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show confirmation dialog for wastage
      if (_expenseType == 'Wastage') {
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Wastage'),
            content: Text('Are you sure you want to mark $quantity ${_selectedUnit} of "${_titleController.text}" as wastage?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        
        if (confirm != true) return;
      }
    } else {
      print_log("qty is $quantity");
    }


    // Create expense object
    final newExpense = Expense(
      id: ganarateID().toString(),
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      category: _selectedCategory,
      photoPath: _imagePath,
      supplierName: _supplierController.text.isNotEmpty ? _supplierController.text.trim() : null,
      quantity: quantity > 0 ? quantity : null,
      unit: _selectedUnit != 'unit' ? _selectedUnit : null,
      paymentMethod: _selectedPaymentMethod,
      receivedAmount: receivedAmount,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : null,
      expenseType: _expenseType,
    );

  
    // Update stock based on expense type
    print_log('Menu item updated: _menuItemNames $_expenseType ${'Wastage' == _expenseType}');
    if (quantity > 0) {
      if (_expenseType == 'Consumption' && (_inventoryItemNames.contains(_titleController.text))) {
        await _updateInventoryStock(_titleController.text, quantity, _expenseType);
      }else if (_expenseType == 'Wastage') {
        // Check if it's inventory or menu item
        if (_inventoryItemNames.contains(_titleController.text)) {
          // print_log('Menu item updated: _inventoryItemNames ${_inventoryItemNames.contains(_titleController.text)}');
          await _updateInventoryStock(_titleController.text, quantity, _expenseType);
        } else if (_menuItemNames.contains(_titleController.text)) {
          // print_log('Menu item updated: _menuItemNames ${_menuItemNames.contains(_titleController.text)}');
          await _updateMenuItemStock(_titleController.text, quantity,_expenseType);
        }

      } else if (_expenseType == 'Sell' && (_menuItemNames.contains(_titleController.text))) {
        await _updateMenuItemStock(_titleController.text, quantity, _expenseType);
      }
    } else{
       print_log("qty is $quantity");
    }

    // Save expense
    setState(() => _expenses.insert(0, newExpense));
    await _saveExpensesToPrefs(newExpense: newExpense);
    
    if(_selectedPaymentMethod == 'Credit'){
      debugPrint("!_isChecked going to udhari${_selectedPaymentMethod == 'Credit'} ${_supplierController.text.trim()}-${(_supplierMobileController.text.trim())}-${(pendingamount)}");
      String descriptionController = "For item ${_titleController.text.trim()} on date- ${DateTime.now()}";
      // //debugPrint("currentCustomer $descriptionController");
      saveEntry(_supplierController.text.trim() , _supplierMobileController.text.trim() ,"", (pendingamount).toStringAsFixed(0), descriptionController);
    }


    _clearForm();
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${newExpense.title}" added successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Refresh expense titles if it was an expense
    if (_expenseType == 'Expense') {
      _loadExpenseTitles();
    }




  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      _isSavingNotifier.value = false;
    }
  }

}




  // Update _clearForm to include all new controllers
  void _clearForm() async {
    _titleController.clear();
    _amountController.clear();
    _supplierController.clear();
    _qtyController.clear();
    _descriptionController.clear();
    _recivedAmountController.clear();
    _unitController.clear();
    
    _selectedDate = await getBussinessDateOnly();
    _selectedCategory = _categories.contains('Food') ? 'Food' : (_categories.isNotEmpty ? _categories.first : 'Other');
    _selectedUnit = 'unit';
    _selectedPaymentMethod = 'Cash';
    _expenseType = 'Expense';
    _selectedImage = null;
    _imagePath = null;
  }

  void _removePhoto() {
    setState(() {
      _selectedImage = null;
      _imagePath = null;
    });
    removeFileFromExternalStorage(_imagePath ?? "");
  }



  // ---------- Helpers ----------
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Entertainment':
        return Colors.purple;
      case 'Shopping':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_bus;
      case 'Entertainment':
        return Icons.movie;
      case 'Shopping':
        return Icons.shopping_bag;
      default:
        return Icons.money;
    }
  }
}


// ---------- ExpensesService ----------
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
