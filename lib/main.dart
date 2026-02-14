import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'NewOrderPage.dart';
import 'settings/SettingsPage.dart';
import 'inventory/inventory_page.dart';
import './objectbox.g.dart';
import 'dart:io';
import './cartprovier/cart_provider.dart';
import 'database_Module/ObjectBoxService.dart';
import 'package:provider/provider.dart';
import 'database_Module/transaction.dart';
import 'bill_printer.dart'; // Adjust the import path
import 'editBillPrint/editBill.dart';
import './pages/PartyListPage.dart';
import './pages/SalesReportPage.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'settings/ProfilePage.dart';
import 'theme_setting/theme_provider.dart';
import 'package:objectbox/objectbox.dart';
import 'database_Module/menu_item.dart';
import './pages/ExpensesPage.dart';
import './pages/login_page.dart';
import './udhari/data_models.dart';
import './udhari/DashboardPage.dart';
import './MenuItemPage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_Module/tabledata.dart';
import 'table_selection/table_view.dart';
import 'package:test1/l10n/app_localizations.dart';
import 'package:test1/cartprovier/locale_provider.dart';
import '../utilities.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final printer = BillPrinter();
String selectedStyle = "";
bool _isOnline = true;

// @pragma('vm:entry-point')
// Future<void> _firebaseBackgroundMessage(RemoteMessage message) async {
//   await Firebase.initializeApp();
  
//   final cart = message.data['printData'];
//   print_log("massage ${cart.runtimeType} $cart");
//   List<Map<String, dynamic>> cart1 = List<Map<String, dynamic>>.from(jsonDecode(cart));

//   print_log("massage ${cart1.runtimeType} ${cart1[0]['total']} $cart1 ");
//   int totalAmt = (cart1[0]['total'] as num).toInt();
//   int tableNum = int.tryParse(cart1[0]['tableno'].toString()) ?? 0;
//   // printer.printCart111111111(cart1:cart1,total:totalAmt,mode:'kot',payment_mode: "",transactionData:{},tableNo:tableNum);
  
//   print_log("Background message new: ${message.data}, ${message.from}, ${message.notification},${message.senderId},${message.threadId},${message.sentTime},${message.threadId},${message.category},${message.messageType}");
// }

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
  await AppConstants.initialize(); // <-- Add this line
  final objectBoxService = ObjectBoxService.instance;
  await objectBoxService.init();
  HttpOverrides.global = MyHttpOverrides();
  final cartProvider = CartProvider();

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
          // initialRoute: '/',
          // routes: {
          //   '/': (context) => const DostiKitchenPage(),
          //   '/details': (context) => const DostiKitchenPage(),
          // },
          title: 'Orbipay',
          
          // 2. Now you can access the 'locale' property from the instance
          locale: localeProvider.locale, 
          
          // These lines are correct
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(primarySwatch: Colors.blue),

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
  final store_path = AppConstants.objectbox_path;
  final objectboxDir = Directory(store_path);
  if (await objectboxDir.exists()) {
    print_log("Deleting old ObjectBox store...");
    await objectboxDir.delete(recursive: true);
  }
}

DateTime getBusinessDate({int cutoffHour = 4}) {
  final now = DateTime.now();
  // Check if the current hour is before the cutoff time (e.g., 00:00 to 03:59)
  if (now.hour < cutoffHour) {
    DateTime businessDate = now.subtract(const Duration(days: 1));
    AppConstants.businessDate = DateTime(businessDate.year, businessDate.month, businessDate.day);;
    print_log_red("business date saved ${AppConstants.businessDate}");
    return businessDate;
  } else {
    AppConstants.businessDate = DateTime(now.year, now.month, now.day);
    print_log_red("business date saved ${AppConstants.businessDate}");
    return now;
  }
}



// Future<void> initDeviceId() async {
//   final prefs = await SharedPreferences.getInstance();
  
//     final deviceInfo = DeviceInfoPlugin();
//     String deviceId;
    
//     if (Platform.isAndroid) {
//       final androidInfo = await deviceInfo.androidInfo;
//       deviceId = androidInfo.id;
//     } else if (Platform.isIOS) {
//       final iosInfo = await deviceInfo.iosInfo;
//       deviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
//     } else {
//       deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
//     }
    
//     await prefs.setString('device_id', deviceId);
//     //debugPrint("📱 Device ID initialized: $deviceId");
//   }

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
  String businessName = 'My Business';
  String contactPhone =  '';
  String imagePath = '';
  bool hide_sales_report = false;
  bool hide_transections =  false;
  bool hide_total = false;
  bool hide_udhari = false;
  bool hide_expence = false;
  bool hide_cash_sale = false;
  bool hide_upi_sell =  false;
  bool hide1 =  false;
  bool hide2 =  false;
  final excludedOrderTypes = ['Parcel', 'Dine-In', 'Takeaway'];
  bool transectionColor = false;
  bool _isNewOrderProcessing = false;


  @override
  void initState() {
    super.initState();
    _loadTotalExpenses();
    _loadimagepath();
    _tablesList = store.box<Active_Table_view>();
    printer.onTransactionAdded = () {
      loadRecentTransactions(store);
    };
    loadRecentTransactions(store);
    loadSelectedStyle();
    // printer.syncPendingTransactions(context);
  }


  // ✅ NEW: This function handles the asynchronous saving
  Future<void> _initializeAndStoreBusinessDate() async {
    final prefs = await SharedPreferences.getInstance();
    final businessDate = getBusinessDate(cutoffHour: 4);
    String? ddd = prefs.getString(AppConstants.businessDateKey);
    print_log('✅ Business date saved: ${ddd!.split("T")[0]} != ${(businessDate.toIso8601String()).split("T")[0]} ${ddd.split("T")[0] != (businessDate.toIso8601String()).split("T")[0]}');
    // if(ddd.split("T")[0] != (businessDate.toIso8601String()).split("T")[0]){
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text("${AppLocalizations.of(context)!.businessDateChanged} ${(businessDate.toIso8601String()).split("T")[0]}"),
    //       backgroundColor: Colors.red,
    //       duration: Duration(seconds: 3),
    //     ),
    //   );
    // }
    await prefs.setString(AppConstants.businessDateKey, businessDate.toIso8601String());
    setState(() {
      _selectedDate = businessDate;
      AppConstants.businessDate = businessDate;
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
      _filterTransactionsForSelectedDate(); // Re-run the filter with the new date
    }
  }

  Future<void> _loadTotalExpenses() async {
    final total = await getTodayTotalexpenses();
    _totalExpensesNotifier.value = total;
  }

  Future<void> _loadimagepath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      businessName =prefs.getString('businessName') ?? 'My Business';
      contactPhone = prefs.getString('contactPhone') ?? '';
      imagePath = prefs.getString('imagePath') ?? '';
      hide_sales_report = prefs.getBool('hide_sales_report') ?? false;
      hide_transections = prefs.getBool('hide_transections') ?? false;
      hide_total = prefs.getBool('hide_total') ?? false;
      hide_udhari = prefs.getBool('hide_udhari') ?? false;
      hide_expence = prefs.getBool('hide_expence') ?? false;
      hide_cash_sale = prefs.getBool('hide_cash_sale') ?? false;
      hide_upi_sell = prefs.getBool('hide_upi_sell') ?? false;
      hide1 = prefs.getBool('hide1') ?? false;
      hide2 = prefs.getBool('hide2') ?? false;
    });
    print_log("imagePath $imagePath  businessName $businessName contactPhone $contactPhone");
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
    try {
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
    } catch (e) {
      print_log('Error loading transactions: $e');
    }
  }

    // ✅ UPDATED: Calculates sale from the filtered list
  int getSelectedDateCashSale() {
    return filteredTransactions.fold(0, (sum, tx) {
      if (tx['payment_mode'] == 'CASH') {
        return sum + (tx['total'] as int? ?? 0);
      }else if(tx['payment_mode'] == "other"){
        return sum + (tx['cashamount'] as int? ?? 0);
      }
      return sum;
    });
  }

  // ✅ UPDATED: Calculates sale from the filtered list
  int getSelectedDateUpiSale() {
    return filteredTransactions.fold(0, (sum, tx) {
      if (tx['payment_mode'] == 'UPI') {
        return sum + (tx['total'] as int? ?? 0);
      }else if(tx['payment_mode'] == "other"){
        return sum + (tx['upiamount'] as int? ?? 0);
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
      // print_log("allTransactions ${tx}");
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

      if (txDate.year == now.year &&
          txDate.month == now.month &&
          txDate.day == now.day && // only today
          tx['payment_mode'] == 'CASH') {
        return sum + (tx['total'] as int? ?? 0); // Regular cash transaction
      } else if (txDate.year == now.year &&
          txDate.month == now.month &&
          txDate.day == now.day && tx['payment_mode'] == "other") {
        return sum + (tx['cashamount'] as int? ?? 0); // Cash part of a split payment
      }
      return sum; // No match
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
      if (txDate.year == now.year &&
          txDate.month == now.month &&
          txDate.day == now.day &&
          tx['payment_mode'] == 'UPI') {
        return sum + (tx['total'] as int? ?? 0); // Regular UPI transaction
      } else if (txDate.year == now.year &&
          txDate.month == now.month &&
          txDate.day == now.day && tx['payment_mode'] == "other"){
        return sum + (tx['upiamount'] as int? ?? 0); // UPI part of a split payment
      }
      return sum; // No match
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

  void _showTransactionOptionsDialog(
    BuildContext context,
    Map<String, dynamic> tx,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text( (tx['tableNo'] == 0)? '${tx['orderType']}' : ' ${AppLocalizations.of(context)!.table} ${tx['tableNo']}'),
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
      // //debugPrint("Printing transaction: $tx");

      // The await here is important for the try-catch to work on this async call
      tx['udhari'] = false;
      await printer.printCart(
        context: context,
        cart1: (tx['cart'] as List).cast<Map<String, dynamic>>(),
        total: tx['total'],
        mode: "onlyPrint",
        payment_mode: "",
        transactionData : tx,
      );
    } on PlatformException catch (e) {
      // This block ONLY runs for platform-related errors (like Bluetooth)
      //debugPrint("❌ Printer PlatformException: ${e.message}");

      // Safety check before using context in an async function
      if (!context.mounted) return;
      screen_massage(context, '❌ Printer error. Please check if it is on and paired.');
    } catch (e) {
      // This block catches all OTHER errors (like bad data, null values, etc.)
      //debugPrint("❌ An unexpected error occurred in _printTransaction: $e");

      if (!context.mounted) return;
      screen_massage(context, 'An unexpected error occurred: $e');
      
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
      transectionColor = prefs.getBool("transection_color") ?? false;
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
            String _businessName =prefs.getString('businessName') ?? businessName;
            String _contactPhone = prefs.getString('contactPhone') ?? contactPhone;
            String _imagePath = prefs.getString('imagePath') ?? imagePath;
            hide_sales_report = prefs.getBool('hide_sales_report') ?? false;
            print_log("_imagePath $_imagePath businessName $_businessName contactPhone $_contactPhone");

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
                          backgroundImage: _imagePath.isNotEmpty
                              ? FileImage(File(_imagePath))
                              : null,
                          child: _imagePath.isEmpty
                              ? Text(
                                  _businessName.isNotEmpty
                                      ? _businessName[0].toUpperCase()
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
                          _businessName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_contactPhone.isNotEmpty)
                          Text(
                            '+91 $_contactPhone',
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
                    ).then(
                     (value) => _loadimagepath(),
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
                    if(hide_sales_report){
                      screen_massage(context,AppLocalizations.of(context)!.access_denied);
                      return;
                    }

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

      // endDrawer: Drawer(
        // child: ListView(
        //   padding: EdgeInsets.zero,
        //   children: [
        //     DrawerHeader(
        //       decoration: BoxDecoration(
        //         color: themeProvider.primaryColor,
        //       ),
        //       child: Center(
        //         child: Text(
        //           'Right Menu',
        //           style: TextStyle(
        //             color: Colors.white,
        //             fontSize: 24,
        //             fontWeight: FontWeight.bold,
        //           ),
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
      // ),
      

      appBar: AppBar(
        backgroundColor: themeProvider.primaryColor,
        elevation: 0,

        // 🔹 Left Menu Button
        leading: IconButton(
          icon: Icon(Icons.settings, color: Colors.black),
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
                  Text('${AppLocalizations.of(context)!.loding}...', 
                    style: TextStyle(color: Colors.white,fontSize: 10)
                  ),
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
                Text(businessName, style: TextStyle(color: Colors.white,fontSize: 18)),
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
                      if(hide_sales_report){
                      screen_massage(context, "Access Denied");
                      return;
                    }
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
                          '${AppLocalizations.of(context)!.total}: ₹ ${(hide_total) ? 0 : getTodayTotalSale()}\n' // If this also needs to be reactive, use similar approach
                          '${AppLocalizations.of(context)!.expenses}:  ₹ ${totalExpenses.toStringAsFixed(0)}',
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _infoCard(
                    '💰 ${AppLocalizations.of(context)!.saleFor}( ${DateFormat('dd/MM').format(_selectedDate)} )',
                    'Cash: ₹ ${(hide_cash_sale) ? 0 : getSelectedDateCashSale()}\n'
                    'UPI: ₹ ${(hide_upi_sell) ? 0 : getSelectedDateUpiSale()}\n'
                    '${AppLocalizations.of(context)!.total}: ₹ ${(hide_total) ? 0 : getSelectedDateTotalSale()}',
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
                final tableNo = tx['tableNo'] ?? 0;
                final orderType = tx['orderType'] ?? 0;

                final text = "${AppLocalizations.of(context)!.billNo} ${tx['billNo']} (${tx['id']}) / "
                    "${tableNo == 0 ? orderType : "${AppLocalizations.of(context)!.table} $tableNo"}";

                return GestureDetector(
                  onTap: () => _showTransactionOptionsDialog(context, tx),
                  child: Card(
                    color: transectionColor && !excludedOrderTypes.contains(orderType) ? Colors.yellow[200] : Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.black, width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      //i want yallow color when orderType != dinein
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
                                text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!tx['status'].toString().contains('settle'))
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
                                              // //debugPrint('Settling ${tx['tableNo']} with $selectedPayment',);
                                              transaction.payment_mode = selectedPayment!;
                                              transaction.status = 'settle';
                                              box.put(transaction);
                                              printer.sendTransactionToServer(box,tx['id'],);
                                              loadRecentTransactions(store);
                                            }
                                          }
                                        : null,
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,),
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
                                  'payment: ${tx['payment_mode']}',
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
          FloatingActionButton.extended(
            label: _isNewOrderProcessing
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(AppLocalizations.of(context)!.newOrder,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
            icon: _isNewOrderProcessing
                ? null
                : Icon(
                    Icons.add,
                    color: Colors.white,
                  ),
            backgroundColor: _isNewOrderProcessing
                ? Colors.grey
                : themeProvider.primaryColor,
            onPressed: _isNewOrderProcessing
                ? null
                : () async {
                    setState(() {
                      _isNewOrderProcessing = true;
                    });
                    try {
                      _initializeAndStoreBusinessDate();
                      await loadSelectedStyle();

                      // make cart empty
                      final cartProvider =
                          Provider.of<CartProvider>(context, listen: false);
                      do {
                        cartProvider.clearCart();
                      } while (cartProvider.total != 0);

                      if (selectedStyle == "half-Full View") {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MenuItemPage()),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => NewOrderPage()),
                        );
                      }
                      loadRecentTransactions(store);
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isNewOrderProcessing = false;
                        });
                      }
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
    } else {
      setState(() {
        _isOnline = false;
        prefs.setBool('isOnline',_isOnline);
      });
    }
    // if(isConnected){
      // final objectBoxService = Provider.of<ObjectBoxService>(context,listen: false,);
      // final store = objectBoxService.store;
      printer.syncPendingTransactions(context);
    // }
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
    String? ddd = prefs.getString(AppConstants.businessDateKey);
    _date = businessDate.toIso8601String().toString().split("T")[0];
    // if(ddd != businessDate.toIso8601String()){
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text("${AppLocalizations.of(context)!.businessDateChanged} $_date"),
    //       backgroundColor: Colors.red,
    //       duration: Duration(seconds: 3),
    //     ),
    //   );
    // }
    await prefs.setString(AppConstants.businessDateKey, businessDate.toIso8601String());
    // //debugPrint('✅ Business date saved: ${ddd}');
  }

  void _updateTime() {
    try {
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
      });
    } catch (e) {
      //debugPrint("time is not required $e ");
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final statusText = _isOnline ? 'Online' : 'Offline';
    final barColor = _isOnline ? themeProvider.primaryColor : Colors.grey.shade400;
    final gradientColors = _isOnline 
        ? [themeProvider.primaryColor, themeProvider.primaryColor.withOpacity(0.8)]
        : [Colors.grey.shade400, Colors.grey.shade600];
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            "$_date  •  $_currentTime",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
