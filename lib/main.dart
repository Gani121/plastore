import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'NewOrderPage.dart';
import 'SettingsPage.dart';
import 'inventory/inventory_page.dart';
import './objectbox.g.dart';
import 'dart:io';
import './cartprovier/cart_provider.dart';
import './cartprovier/ObjectBoxService.dart';
import 'package:provider/provider.dart';
import './models/transaction.dart';
import 'bill_printer.dart'; // Adjust the import path
import 'editBillPrint/editBill.dart';
import './pages/PartyListPage.dart';
import './pages/SalesReportPage.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'ProfilePage.dart';
import 'theme_setting/theme_provider.dart';
import 'package:objectbox/objectbox.dart';
import '../models/menu_item.dart';
import './pages/ExpensesPage.dart';
import './pages/login_page.dart';
import './udhari/data_models.dart';
import './udhari/DashboardPage.dart';
import './MenuItemPage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import './table_selection/tabledata.dart';
import 'table_selection/table_view.dart';
import 'package:test1/l10n/app_localizations.dart';
import 'package:test1/cartprovier/locale_provider.dart';

final printer = BillPrinter();
String selectedStyle = "";
bool _isOnline = true;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final objectBoxService = ObjectBoxService.instance;
  await objectBoxService.init();
  HttpOverrides.global = MyHttpOverrides();
  final cartProvider = CartProvider();
  // await cartProvider.loadCart(); //
  runApp(
    MultiProvider(
      providers: [
        Provider<ObjectBoxService>.value(value: objectBoxService),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: cartProvider), // ✅ Reuse same instance
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Wrap your MaterialApp in a Consumer for LocaleProvider
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        // 'localeProvider' (lowercase 'l') is now the
        // ACTUAL INSTANCE of your provider.

        return MaterialApp(
          title: 'Orbipay',
          
          // 2. Now you can access the 'locale' property from the instance
          locale: localeProvider.locale, 
          
          // These lines are correct
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(primarySwatch: Colors.red),

          // --- ADD THIS BUILDER FOR TEXT SCALING ---
          // ✅ CORRECT
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            
            final newScaler = TextScaler.linear(1.0);
            
            final newMediaQueryData = mediaQueryData.copyWith(
              textScaler: newScaler,
            );

            return MediaQuery(
              data: newMediaQueryData,
              child: child!,
            );
          },
          
          

          home: const LoginPage(), 
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

Future<void> deleteOldObjectBoxStore() async {
  final dir = await getApplicationDocumentsDirectory(); // <- await is important
  final objectboxDir = Directory('${dir.path}/objectbox');
  if (await objectboxDir.exists()) {
    // print("Deleting old ObjectBox store...");
    await objectboxDir.delete(recursive: true);
  }
}

DateTime getBusinessDate({int cutoffHour = 4}) {
  final now = DateTime.now();
  // Check if the current hour is before the cutoff time (e.g., 00:00 to 03:59)
  if (now.hour < cutoffHour) {
    return now.subtract(const Duration(days: 1));
  } else {
    return now;
  }
}

class DostiKitchenPage extends StatefulWidget {
  const DostiKitchenPage({super.key});

  @override
  _DostiKitchenPageState createState() => _DostiKitchenPageState();
}


class _DostiKitchenPageState extends State<DostiKitchenPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  double _totalExpenses = 0.0;
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? selectedDevice;
  List<Map<String, dynamic>> allTransactions  = [];
  List<Map<String, dynamic>> filteredTransactions = [];
  DateTime _selectedDate = getBusinessDate(cutoffHour: 4);
  late Store store = Provider.of<ObjectBoxService>(context, listen: false).store;
  late Box<MenuItem> menuItemBox = store.box<MenuItem>();
  late Box<Active_Table_view> _tablesList;
  final Map<String, String> _selectedPayments = {};
  final ValueNotifier<double> _totalExpensesNotifier = ValueNotifier<double>(0.0,);
  List<Active_Table_view> activeTables = [];
  String table_payment_mode = "CASH";
  bool isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadTotalExpenses();
    _tablesList = store.box<Active_Table_view>();
    printer.onTransactionAdded = () {
      loadRecentTransactions(store);
    };
    loadRecentTransactions(store);
    loadSelectedStyle();
  }


  // ✅ NEW: This function handles the asynchronous saving
  Future<void> _initializeAndStoreBusinessDate() async {
    final businessDate = getBusinessDate(cutoffHour: 4);
    final prefs = await SharedPreferences.getInstance();
    String? ddd = prefs.getString('businessDate');
    // debugPrint('✅ Business date saved: ${ddd!.split("T")[0]} != ${(businessDate.toIso8601String()).split("T")[0]} ${ddd!.split("T")[0] != (businessDate.toIso8601String()).split("T")[0]}');
    if(ddd!.split("T")[0] != (businessDate.toIso8601String()).split("T")[0]){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${AppLocalizations.of(context)!.businessDateChanged} ${(businessDate.toIso8601String()).split("T")[0]}"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
    await prefs.setString('businessDate', businessDate.toIso8601String());
    setState(() {
      _selectedDate = businessDate;
    });
  }


  void _filterTransactionsForSelectedDate() {
    setState(() {
      filteredTransactions = allTransactions.where((tx) {
        // 1. Get the value as a String
        final timeString = tx['time'] as String?;
        if (timeString == null) return false;

        // 2. Parse the String into a DateTime object
        final DateTime txDate;
        try {
          txDate = DateTime.parse(timeString);
        } catch (e) {
          // Handle cases where the string might be invalid
          return false; 
        }
        
        // 3. Now you can compare correctly
        return txDate.year == _selectedDate.year &&
              txDate.month == _selectedDate.month &&
              txDate.day == _selectedDate.day;
      }).toList();
    });
  }

  // ✅ NEW: Function to show the date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // _initializeAndStoreBusinessDate(_selectedDate);
      _filterTransactionsForSelectedDate(); // Re-run the filter with the new date
    }
  }

  Future<void> _loadTotalExpenses() async {
    final total = await getTodayTotalexpenses();
    _totalExpensesNotifier.value = total;
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    store = Provider.of<ObjectBoxService>(context, listen: false).store;

    loadRecentTransactions(store);
  }

  void _loadHoldStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isHoldEnabled = prefs.getBool('isHoldEnabled') ?? false;
    });
  }



  // ✅ MODIFIED: This function now populates the main list and triggers filtering
  Future<void> loadRecentTransactions(Store store) async {
    final box12 = store.box<Transaction>();
    final all = box12.getAll();
    
    // This part can stay as it is
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final isHoldEnabled = prefs.getBool('isHoldEnabled') ?? false;

      if (!isHoldEnabled) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        cartProvider.clearCart();
        await prefs.remove('selectedItems');
      }
    });
    setState(() {
      allTransactions = all.map((tx) => tx.toMap()).toList();
    });
    
    // After loading all transactions, filter them for the currently selected date
    _filterTransactionsForSelectedDate(); 
  }

    // ✅ UPDATED: Calculates sale from the filtered list
  int getSelectedDateCashSale() {
    return filteredTransactions.fold(0, (sum, tx) {
      if (tx['payment_mode'] == 'CASH') {
        return sum + (tx['total'] as int? ?? 0);
      }
      return sum;
    });
  }

  // ✅ UPDATED: Calculates sale from the filtered list
  int getSelectedDateUpiSale() {
    return filteredTransactions.fold(0, (sum, tx) {
      if (tx['payment_mode'] == 'UPI') {
        return sum + (tx['total'] as int? ?? 0);
      }
      return sum;
    });
  }
  
  // ✅ UPDATED: Calculates total from the new functions
  int getSelectedDateTotalSale() {
    return getSelectedDateCashSale() + getSelectedDateUpiSale();
  }

  int getTodayCashSale() {
    final now = DateTime.now();
    return allTransactions.fold(0, (sum, tx) {
      // final txDate = tx['time'] as DateTime?;
      final timeString = tx['time'] as String?;
      if (timeString == null) return 0;

      // 2. Parse the String into a DateTime object
      final DateTime txDate;
      try {
        txDate = DateTime.parse(timeString);
      } catch (e) {
        // Handle cases where the string might be invalid
        return 0; 
      }

      if (txDate != null &&
          txDate.year == now.year &&
          txDate.month == now.month &&
          txDate.day == now.day && // only today
          tx['payment_mode'] == 'CASH') {
        return sum + (tx['total'] as int? ?? 0);
      }
      return sum;
    });
  }

  int getTodayUpiSale() {
    final now = DateTime.now();
    return allTransactions.fold(0, (sum, tx) {
      // final txDate = tx['time'] as DateTime?;
      final timeString = tx['time'] as String?;
      if (timeString == null) return 0;

      // 2. Parse the String into a DateTime object
      final DateTime txDate;
      try {
        txDate = DateTime.parse(timeString);
      } catch (e) {
        // Handle cases where the string might be invalid
        return 0; 
      }
      if (txDate != null &&
          txDate.year == now.year &&
          txDate.month == now.month &&
          txDate.day == now.day && // only today
          tx['payment_mode'] == 'UPI') {
        return sum + (tx['total'] as int? ?? 0);
      }
      return sum;
    });
  }

  int getTodayTotalSale() {
    return getTodayCashSale() + getTodayUpiSale();
  }

  double getTodayTotalexpenses() {
    return _totalExpenses;
  }

  String formatDateTime(String isoTime) {
    final dt = DateTime.tryParse(isoTime);
    if (dt == null) return "-";
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }


  Widget _infoCard(String title, String value, {Widget? icon}) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) icon,
              if (icon != null) SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
          SizedBox(height: 0),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> table = {
    "number": 5,
    "total": 270,
    "orders": [
      {"name": "Veg Burger", "qty": 2, "price": 60},
      {"name": "French Fries", "qty": 1, "price": 50},
      {"name": "Coke", "qty": 2, "price": 50},
    ],
  };

  void _showTransactionOptionsDialog(
    BuildContext context,
    Map<String, dynamic> tx,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppLocalizations.of(context)!.table} ${tx['tableNo']}'),
        content: Text(AppLocalizations.of(context)!.edit_trans),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              _printTransaction(tx);
            },
            child: Text('🖨️ ${AppLocalizations.of(context)!.print}'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close current dialog

              _editTransaction(tx);
            },
            child: Text('✏️ ${AppLocalizations.of(context)!.edit}'),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('${AppLocalizations.of(context)!.cancel}'),
          ),
        ],
      ),
    );
  }

  void _printTransaction(Map<String, dynamic> tx) async {
    try {
      // debugPrint("Printing transaction: $tx");

      // The await here is important for the try-catch to work on this async call
      await printer.printCart(
        context: context,
        cart1: (tx['cart'] as List).cast<Map<String, dynamic>>(),
        total: tx['total'],
        mode: "onlyPrint",
        payment_mode: "",
      );
    } on PlatformException catch (e) {
      // This block ONLY runs for platform-related errors (like Bluetooth)
      debugPrint("❌ Printer PlatformException: ${e.message}");

      // Safety check before using context in an async function
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Printer error. Please check if it is on and paired.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // This block catches all OTHER errors (like bad data, null values, etc.)
      debugPrint("❌ An unexpected error occurred in _printTransaction: $e");

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: Colors.deepOrange,
        ),
      );
    }
  }

  void _editTransaction(Map<String, dynamic> tx) async {
    final List<Map<String, dynamic>> cart = (tx['cart'] as List).cast<Map<String, dynamic>>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DetailPage(cart1: cart, mode: "edit", transaction: tx),
      ),
    );
    loadRecentTransactions(store); 
  }

  Future<void> loadSelectedStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStyle = prefs.getString('selectedStyle') ?? "List Style Half Full";
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      key: _scaffoldKey,

      // Left Drawer setting
      drawer: Drawer(
        child: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final prefs = snapshot.data!;
            String businessName =
                prefs.getString('businessName') ?? 'My Business';
            String contactPhone = prefs.getString('contactPhone') ?? '';
            String imagePath = prefs.getString('imagePath') ?? '';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: 260,
                  child: DrawerHeader(
                    decoration: BoxDecoration(
                      color: themeProvider.primaryColor,
                    ), //Colors.blue.shade600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: imagePath.isNotEmpty
                              ? FileImage(File(imagePath))
                              : null,
                          child: imagePath.isEmpty
                              ? Text(
                                  businessName.isNotEmpty
                                      ? businessName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(height: 12),
                        Text(
                          businessName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (contactPhone.isNotEmpty)
                          Text(
                            '+91 $contactPhone',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ⬇️ PASTE THIS NEW WIDGET HERE ⬇️
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title for the dropdown
                      Text(
                        AppLocalizations.of(context)!.language, // "Language"
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      // The dropdown itself, wrapped in a Consumer
                      Consumer<LocaleProvider>(
                        builder: (context, localeProvider, child) {
                          
                          // Determine the currently selected language
                          String currentLangCode;
                          if (localeProvider.locale != null) {
                            // Use the language saved in the provider
                            currentLangCode = localeProvider.locale!.languageCode;
                          } else {
                            // Otherwise, use the one Flutter detected
                            currentLangCode = AppLocalizations.of(context)!.localeName;
                          }

                          return DropdownButton<String>(
                            value: currentLangCode,
                            underline: Container(), // Removes the default underline
                            icon: Icon(Icons.language, color: themeProvider.primaryColor),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                // Tell the provider to set the new language
                                localeProvider.setLocale(Locale(newValue));
                              }
                            },
                            items: const [
                              // These MUST match your .arb file names
                              DropdownMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                              // DropdownMenuItem(
                              //   value: 'mr',
                              //   child: Text('मराठी'),
                              // ),
                              // DropdownMenuItem(
                              //   value: 'hi',
                              //   child: Text('हिंदी'),
                              // ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(), // Adds a line to separate it from menu items
                // ⬆️ END OF NEW WIDGET ⬆️

                // Menu Items
                ListTile(
                  leading: Icon(Icons.dashboard),
                  title: Text(AppLocalizations.of(context)!.dashbord,),
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.inventory),
                  title: Text(AppLocalizations.of(context)!.inventory),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => InventoryPage()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings),
                  title: Text(AppLocalizations.of(context)!.setting),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage(menuItemBox: menuItemBox)),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text(AppLocalizations.of(context)!.profile),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text(AppLocalizations.of(context)!.sales_report),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SalesReportPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout),
                  title: Text(AppLocalizations.of(context)!.logout),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context)!.exit_App),
                        content: Text(AppLocalizations.of(context)!.exit_sms),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(), // cancel
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              SystemNavigator.pop();
                            },
                            child: Text(AppLocalizations.of(context)!.exit),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),


      appBar: AppBar(
        backgroundColor: themeProvider.primaryColor,
        elevation: 0,

        // 🔹 Left Menu Button
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),

        title: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Row(
                children: [
                  // Icon(Icons.restaurant, size: 24, color: Colors.white),
                  // SizedBox(width: 8),
                  Text('${AppLocalizations.of(context)!.loding}...', style: TextStyle(color: Colors.white)),
                  Spacer(),
                ],
              );
            }

            final prefs = snapshot.data!;
            String businessName = prefs.getString('businessName') ?? 'My Business';
            return Row(
              children: [
                // Icon(Icons.restaurant, size: 24, color: Colors.white),
                // SizedBox(width: 8),
                Text(businessName, style: TextStyle(color: Colors.white)),
                Spacer(),
              ],
            );
          },
        ),

        bottom: LiveTimeBar(),
      ),

      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SalesReportPage(),
                        ),
                      );
                    },
                    child: ValueListenableBuilder<double>(
                      valueListenable: ExpensesService.totalExpensesNotifier,
                      builder: (context, totalExpenses, child) {
                        return _infoCard(
                          '📊 ${AppLocalizations.of(context)!.reports} \n',
                          '${AppLocalizations.of(context)!.total}: ₹ ${getTodayTotalSale()}\n' // If this also needs to be reactive, use similar approach
                          '${AppLocalizations.of(context)!.expenses}:  ₹ ${totalExpenses.toStringAsFixed(2)}\n',
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _infoCard(
                    '💰 ${AppLocalizations.of(context)!.saleFor}( ${DateFormat('dd/MM').format(_selectedDate)} )',
                    'Cash: ₹ ${getSelectedDateCashSale()}\n'
                    'UPI: ₹ ${getSelectedDateUpiSale()}\n'
                    '${AppLocalizations.of(context)!.total}: ₹ ${getSelectedDateTotalSale()}\n',
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(AppLocalizations.of(context)!.recentSell,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.totalTransection}: ${filteredTransactions.length}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                TextButton.icon(
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                  ),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final tx = filteredTransactions.reversed.toList()[index];
                final transactionKey = '${tx['tableNo']}_${tx['time']}';

                return GestureDetector(
                  onTap: () => _showTransactionOptionsDialog(context, tx),
                  child: Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.black, width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ' ${tx['time'] != null ? DateFormat('dd/MM HH:mm:ss').format(DateTime.parse(tx['time'])) : "-"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '${AppLocalizations.of(context)!.billNo} ${tx['billNo']}(${tx['id']}) / ${AppLocalizations.of(context)!.table}: ${tx['tableNo'] ?? "-"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (tx['status'] == 'print' || tx['status'] == 'print1')
                            StatefulBuilder(
                              builder: (context, setState) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('UPI'),
                                      selected:_selectedPayments[transactionKey] =='UPI',
                                      onSelected: (value) {
                                        setState(() {_selectedPayments[transactionKey] ='UPI';});
                                      },
                                      selectedColor: Colors.blue,
                                    ),
                                    ChoiceChip(
                                      label: const Text('CASH'),
                                      selected:_selectedPayments[transactionKey] =='CASH',
                                      onSelected: (value) {
                                        setState(() {_selectedPayments[transactionKey] ='CASH';
                                        });
                                      },
                                      selectedColor: Colors.green,
                                    ),
                                    ElevatedButton(
                                      onPressed:_selectedPayments[transactionKey] != null
                                        ? () async {
                                            final store =Provider.of<ObjectBoxService>(context,listen: false,).store;
                                            final box = store.box<Transaction>();
                                            final selectedPayment = _selectedPayments[transactionKey];
                                            final transaction = box.get(tx['id'],);
                                            if (transaction != null) {
                                              // debugPrint('Settling ${tx['tableNo']} with $selectedPayment',);
                                              transaction.payment_mode = selectedPayment!;
                                              transaction.status = 'settle';
                                              box.put(transaction);
                                              printer.sendTransactionToServer(box,tx['id'],);
                                              loadRecentTransactions(store);
                                            }
                                          }
                                        : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                      ),
                                      child: Text(AppLocalizations.of(context)!.settle),
                                    ),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10,horizontal: 12,),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${AppLocalizations.of(context)!.mode}: ${tx['payment_mode']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${AppLocalizations.of(context)!.sale}: ₹${tx['total']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text('${AppLocalizations.of(context)!.items}: ${tx['cart'].length}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // FloatingActionButton(
          //   onPressed: () {
          //     ApiCallPage();
          //   },
          //   child: Icon(Icons.api),
          //   backgroundColor: Colors.orange,
          //   heroTag: 'api_button', // Unique heroTag required
          // ),
          // SizedBox(height: 16),
          FloatingActionButton.extended(
            label: Text(AppLocalizations.of(context)!.newOrder),
            icon: Icon(Icons.add),
            backgroundColor: themeProvider.primaryColor,
            onPressed: () async {
              _initializeAndStoreBusinessDate();
              await loadSelectedStyle();
              if (selectedStyle == "half-Full View") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MenuItemPage()),
                ).then((_) {
                  loadRecentTransactions(store);
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NewOrderPage()),
                ).then((_) {
                  loadRecentTransactions(store);
                });
              }
            },
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor:  Colors.blue,
        unselectedItemColor: Colors.blue,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PartyListPage()),
            ).then((_) {
              loadRecentTransactions(store);
            });
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DashboardPage(),
              ), // Use the new page here
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ExpensesPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => InventoryPage()),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TableView()),
            ).then((_) {
              loadRecentTransactions(store);
            });
          }
        },
        items:  [
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: AppLocalizations.of(context)!.party),
          BottomNavigationBarItem(icon: Icon(Icons.balance), label: AppLocalizations.of(context)!.udhari),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: AppLocalizations.of(context)!.expenses,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: AppLocalizations.of(context)!.inventory,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_bar_sharp),
            label: AppLocalizations.of(context)!.tables,
          ),
        ],
      ),
    );
  }

}

class LiveTimeBar extends StatefulWidget implements PreferredSizeWidget {
  const LiveTimeBar({super.key});
  @override
  _LiveTimeBarState createState() => _LiveTimeBarState();

  @override
  Size get preferredSize => Size.fromHeight(28); // Match your height
}

class _LiveTimeBarState extends State<LiveTimeBar> {
  late String _currentTime;
  late Timer _timer;
  late String _date = "business date";
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeAndStoreBusinessDate();
    _updateTime();
    _timer = Timer.periodic(Duration(seconds: 2), (_) => _updateTime());
    loadSelectedStyle();
    _initConnectivity();
  }

    // NEW: Function to check initial status and start listening to the stream
  Future<void> _initConnectivity() async {
    // Check the initial connection status
    final initialResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(initialResult);

    // Listen for subsequent changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  // NEW: Function to update the UI based on connectivity status
  void _updateConnectionStatus(List<ConnectivityResult> result) async {
    final prefs = await SharedPreferences.getInstance();
    final isConnected = await printer.isDeviceConnected();
    final bool isOnline = !result.contains(ConnectivityResult.none);
    if(isConnected && isOnline){
      setState(() {
        _isOnline = true;
        prefs.setBool('isOnline',_isOnline);
      });
      printer.syncPendingTransactions(context);
    } else {
      setState(() {
        _isOnline = false;
        prefs.setBool('isOnline',_isOnline);
      });
    }
  }

  Future<void> loadSelectedStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStyle = prefs.getString('selectedStyle') ?? "List Style Half Full";
    });
    // print("selected style $selectedStyle");
  }

  // ✅ NEW: This function handles the asynchronous saving
  Future<void> _initializeAndStoreBusinessDate() async {
    final businessDate = getBusinessDate(cutoffHour: 4);
    final prefs = await SharedPreferences.getInstance();
    String? ddd = prefs.getString('businessDate');
    _date = businessDate.toIso8601String().toString().split("T")[0];
    if(ddd != businessDate.toIso8601String()){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${AppLocalizations.of(context)!.businessDateChanged} $_date"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
    await prefs.setString('businessDate', businessDate.toIso8601String());
    // debugPrint('✅ Business date saved: ${ddd}');
  }

  void _updateTime() {
    try {
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
      });
    } catch (e) {
      debugPrint("time is not required $e ");
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _isOnline ? 'Online' : 'Offline';
    final barColor = _isOnline ? Colors.lightGreenAccent.shade700 : Colors.grey.shade400;
    return Container(
      padding: EdgeInsets.all(4),
      alignment: Alignment.centerLeft,
      color: barColor,
      child: Text(
        "$_date  $_currentTime  •  $statusText",
        style: TextStyle(color: Colors.black, fontSize: 12),
      ),
    );
  }
}
