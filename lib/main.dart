import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:http/http.dart' as http;
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
import 'package:permission_handler/permission_handler.dart';
import './pages/login_page.dart';
import 'package:archive/archive.dart';
import './udhari/data_models.dart';
import './udhari/DashboardPage.dart';
import './MenuItemPage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import './table_selection/tabledata.dart';
import 'table_selection/table_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      // debugPrint("loadRecentTransactions calle");
      loadRecentTransactions(store);
    };
    loadRecentTransactions(store);
    loadSelectedStyle();
    _loadTables();
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
          content: Text("Business Date Changed To ${(businessDate.toIso8601String()).split("T")[0]}"),
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

    // ✅ NEW: The filtering logic
  // void _filterTransactionsForSelectedDate() {
  //   setState(() {
  //     filteredTransactions = allTransactions.where((tx) {
  //       final txDate = tx['time'] as DateTime?;
  //       if (txDate == null) return false;
        
  //       return txDate.year == _selectedDate.year &&
  //              txDate.month == _selectedDate.month &&
  //              txDate.day == _selectedDate.day;
  //     }).toList();
  //   });
  // }
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

  Future<String> saveResponseReliably(String jsonResponse) async {
    try {
      // Always works - app's private directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final file = File('${appDocDir.path}/api_response.json');
      await file.writeAsString(jsonResponse);

      // Try to copy to external storage if possible
      try {
        if (await Permission.storage.request().isGranted) {
          final externalDir = await getExternalStorageDirectory();
          final externalFile = File('${externalDir?.path}/api_response.json');
          await externalFile.writeAsString(jsonResponse);
          return '✅ Saved to: ${externalFile.path}';
        }
      } catch (e) {
        // Ignore external storage errors
      }

      return '📁 Saved to app storage: ${file.path}';
    } catch (e) {
      return '❌ Could not save file: $e';
    }
  }

  Future<void> ApiCallPage() async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // force choice
      builder: (ctx) {
        return AlertDialog(
          title: const Text("⚠️ Caution"),
          content: const Text(
            "Syncing with server will delete some entries not updated at the server.\n\n"
            "Do you want to continue?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // ❌ Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // warning color
              ),
              onPressed: () => Navigator.pop(ctx, true), // ✅ Proceed
              child: const Text("Proceed"),
            ),
          ],
        );
      },
    );

    if (proceed != true) {
      // debugPrint("❌ User cancelled sync");
      return;
    }

    final isVerified = await _askPassword(context);

    if (isVerified) {
      // print("ApiCallPage started...");
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? "";
      final hotelName = username;
      // .split("_")
      // .sublist(0, username.split("_").length - 1)
      // .join("_");
      // print("hotelName $hotelName");

      try {
        final response = await http
            .get(
              Uri.parse(
                "https://api2.nextorbitals.in/api/get_menu.php?hotel_name=$hotelName&menutype=ac",
              ),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 300));

        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          // print("server response $jsonData");

          final dataList = jsonData['data'];
          if (dataList is List) {
            List<MenuItem> menuItems = dataList.map((item) => MenuItem.fromJson(item)).toList();

            await downloadHotelZip(context, hotelName);
            saveMenuItemsReliably(menuItems);

            // print("✅ Menu loaded from server: ${menuItems.length} items");
          } else {
            // print("❌ 'data' is not a list");
          }
        } else {
          debugPrint('HTTP Error: ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (error) {
        debugPrint("❌ Error in ApiCallPage: $error");
      }
    }
  }

  Future<void> downloadHotelZip(BuildContext context, String hotelName) async {
    try {
      // print("hotelName ${hotelName}");
      // 2️⃣ Call your PHP API to get the menu filename
      final apiUrl = Uri.parse(
        "https://api2.nextorbitals.in/api/menu_filename.php?hotel_name=${hotelName}",
      );
      final apiResponse = await http.get(apiUrl);

      if (apiResponse.statusCode != 200) {
        throw Exception(
          "❌ Failed to fetch filename: ${apiResponse.statusCode}",
        );
      }

      final data = jsonDecode(apiResponse.body);
      if (data['success'] != true || data['menu_filename'] == null) {
        throw Exception("❌ API error: ${data['message'] ?? 'Unknown error'}");
      }

      final fileName = data['menu_filename']; // e.g., hotelA.zip
      // debugPrint("📥 Filename received from API: $fileName");

      final fileId = fileName; // Replace if you return a Google Drive ID directly
      final downloadUrl = Uri.parse(
        "https://drive.google.com/uc?export=download&id=$fileId",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⬇️ Downloading $fileName for $hotelName...")),
      );

      // 4️⃣ Download the ZIP
      final response = await http.get(downloadUrl);
      if (response.statusCode != 200) {
        throw Exception("❌ HTTP Error: ${response.statusCode}");
      }

      // 5️⃣ Save ZIP to temporary storage
      final tempDir = await getTemporaryDirectory();
      final zipFile = File("${tempDir.path}/$hotelName.zip");
      await zipFile.writeAsBytes(response.bodyBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Download complete. Extracting...")),
      );

      final picturesDir = (await getExternalStorageDirectories(
        type: StorageDirectory.pictures,
      ))?.first;
      if (picturesDir == null) {
        throw Exception("❌ Pictures directory unavailable");
      }

      final extractDir = Directory("${picturesDir.path}/menu_images");

      if (!await extractDir.exists()) {
        await extractDir.create(recursive: true);
      } else {
        final files = extractDir.listSync();
        for (var file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }

      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      int fileCount = 0;

      for (final file in archive) {
        if (file.isFile) {
          final outFile = File("${extractDir.path}/${file.name}");
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          fileCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🎉 Extracted $fileCount files for $hotelName")),
      );

      // debugPrint("✅ Extracted $fileCount images to ${extractDir.path}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error while downloading images: $e")),
      );
      debugPrint("❌ Error while downloading images: $e");
    }
  }

  void saveMenuItemsReliably(List<MenuItem> menuItems) {
    // ❌ Remove all old items first
    menuItemBox.removeAll();

    // ✅ Insert fresh items
    for (int i = 0; i < menuItems.length; i++) {
      final item = menuItems[i];
      menuItemBox.put(item);
      // debugPrint('💾 Saved item: ${item}');
    }
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

  Widget buildChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.grey.shade200,
      ),
      child: Text(label, style: TextStyle(fontSize: 12)),
    );
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
        title: Text('Transaction: Table ${tx['tableNo']}'),
        content: Text('Choose an action for this transaction.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              _printTransaction(tx);
            },
            child: Text('🖨️ Print'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close current dialog

              _editTransaction(tx);
            },
            child: Text('✏️ Edit'),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool> _askPassword(BuildContext context) async {
    final TextEditingController _pwdController = TextEditingController();
    bool verified = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Enter Password"),
          content: TextField(
            controller: _pwdController,
            keyboardType: TextInputType.number, // 🔑 Number keypad
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Password",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // cancel
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final savedPwd = await getSavedPassword();

                if (_pwdController.text == savedPwd) {
                  verified = true;
                  Navigator.pop(ctx); // ✅ close only if correct
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text("❌ Password is wrong"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );

    return verified;
  }

  Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_password'); // 🔑 key for password
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

  /// Adds a new table to the database and reloads the list.
  void _addNewTable() {
    final box = store.box<Active_Table_view>();
    
    // Find the highest existing table number to avoid duplicates
    final maxNumber = activeTables.isNotEmpty
        ? activeTables.map((t) => t.number).reduce((a, b) => a > b ? a : b)
        : 0;
    
    final newTableNumber1 = maxNumber + 1;
    final int newTableNumber;

    if (newTableNumber1.toString().contains("13")){
      newTableNumber = maxNumber + 2;
    } else{
      newTableNumber = maxNumber + 1;
    }
    // Create and save the new table object
    final newTableObject = Active_Table_view(number: newTableNumber);
    box.put(newTableObject);
    
    // Reload the list from the database to show the new table
    _loadTables();
    // Navigator.pop(context); // Optional: close the drawer
  }

  /// Fetches all tables from ObjectBox and updates the UI.
  void _loadTables() async {
    final box = store.box<Active_Table_view>();
    setState(() {
      activeTables = box.getAll();
      activeTables.sort((a, b) => a.number.compareTo(b.number));
    });
  }

  /// Deletes a table from the database by its ID.
  void _deleteTable(int tableId) {
    final box = store.box<Active_Table_view>();
    box.remove(tableId);
    
    // After deleting, reload the data to update the UI
    _loadTables();
  }

  void _navigateToOrderPage(Active_Table_view table) async {
    await loadSelectedStyle(); // Assuming this function is available
    final int tableNo = table.number;
    final key = "table$tableNo";
    // debugPrint("tableno $tableNo");
    
    // --- Step 1: Safely load the existing cart ---
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    
    List<Map<String, dynamic>> existingCart = [];
    // ❗️ FIX: Handle case where no cart is saved yet (jsonString is null)
    if (jsonString != null) {
      final decodedList = jsonDecode(jsonString) as List<dynamic>;
      existingCart = decodedList.map((item) => item as Map<String, dynamic>).toList();
    }

    // --- Step 2: Navigate and wait for the updated cart ---
    List<Map<String, dynamic>>? updatedCart;
    if (selectedStyle == "half-Full View") {
      updatedCart = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(
          builder: (context) => MenuItemPage(
            cart1: existingCart,
            mode: "edit",
            tableno: tableNo,
          ),
        ),
      );
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      updatedCart = cartProvider.cart;
    } else {
      updatedCart = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(
          builder: (context) => NewOrderPage(cart1: existingCart, tableno: tableNo,),
        ),
      );
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      updatedCart = cartProvider.cart;
    }

    // --- Step 3: Save the result if the user didn't cancel ---
    if (updatedCart != null && updatedCart.isNotEmpty) {
      // Update the table total in your database
      updateTableTotal(table, updatedCart);
      
      // Save the updated cart back to SharedPreferences
      final newJsonString = jsonEncode(updatedCart);
      await prefs.setString(key, newJsonString);
      setState(() {});

      // Clear any temporary global cart if necessary
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();
    } else {
      debugPrint(" KOT operation cancelled or cart was empty. No changes saved.");
    }
  }
    
  void updateTableTotal(Active_Table_view table, List<Map<String, dynamic>> cart) {
    double newTotal = 0.0;
    
    // Loop through each item in the cart
    for (final item in cart) {
      // ❗️ FIX: The value could be a String, int, or double.
      // .toString() and parse() handles all cases safely.
      // debugPrint("item['sellPrice'], ${item['sellPrice']}");
      final int quantity = int.parse(item['qty'].toString());
      final double price = double.parse(item['sellPrice'].toString());

      // Perform the calculation
      newTotal += price * quantity;
    }
    
    // Update the table's total property
    table.total = newTotal;
    
    // Save the updated table object to the database
    _tablesList.put(table); 
    
    // debugPrint("✅ Table #${table.number} total updated to: $newTotal");
  }

  // Place this method inside your State class (e.g., _DostiKitchenPageState)
  Future<List<Map<String, dynamic>>> _loadOrdersFromPrefs(int tableNo) async {
    // 1. Get the SharedPreferences instance
    final prefs = await SharedPreferences.getInstance();
    
    // 2. Create the dynamic key
    final key = "table$tableNo";
    
    // 3. Get the stored JSON string
    final jsonString = prefs.getString(key);

    // 4. Handle case where no data is saved for this table
    if (jsonString == null) {
      return []; // Return an empty list
    }

    // 5. Decode the string into a List and cast it to the correct type
    final List<dynamic> decodedList = jsonDecode(jsonString);
    final List<Map<String, dynamic>> items = decodedList
        .map((item) => item as Map<String, dynamic>)
        .toList();
        
    return items;
  }
    

Future<void> _updateItemQuantity(Active_Table_view table, Map<String, dynamic> item, int newQty) async {
  final prefs = await SharedPreferences.getInstance();
  final key = "table${table.number}";
  final cartJson = prefs.getString(key);
  
  if (cartJson != null) {
    List<dynamic> cart = json.decode(cartJson);
    
    // Find and update the item
    for (int i = 0; i < cart.length; i++) {
      if (cart[i]['id'] == item['id'] && cart[i]['name'] == item['name']) {
        cart[i]['qty'] = newQty;
        break;
      }
    }

    List<Map<String, dynamic>> cartMap = cart.map((e) => e as Map<String, dynamic>).toList();
    updateTableTotal(table, cartMap);
    // Save updated cart
    await prefs.setString(key, json.encode(cart));
  }
}

Future<void> _removeItemFromCart(Active_Table_view table, Map<String, dynamic> item) async {
  final prefs = await SharedPreferences.getInstance();
  final key = "table${table.number}";
  final cartJson = prefs.getString(key);
  
  if (cartJson != null) {
    List<dynamic> cart = json.decode(cartJson);
    
    // Remove the item
    cart.removeWhere((cartItem) => 
      cartItem['id'] == item['id'] && cartItem['name'] == item['name']);
    
    // Save updated cart
    List<Map<String, dynamic>> cartMap = cart.map((e) => e as Map<String, dynamic>).toList();
    updateTableTotal(table, cartMap);
    await prefs.setString(key, json.encode(cart));
  }
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
                              DropdownMenuItem(
                                value: 'mr',
                                child: Text('मराठी'),
                              ),
                              DropdownMenuItem(
                                value: 'hi',
                                child: Text('हिंदी'),
                              ),
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
                        title: Text("Exit App"),
                        content: Text("Are you sure you want to exit the app?"),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(), // cancel
                            child: Text("Cancel"),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              SystemNavigator.pop();
                            },
                            child: Text("Exit"),
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

      // Right Drawer table view 
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 150,
              child: DrawerHeader(
                decoration: BoxDecoration(color: Colors.green.shade600),
                child: Center(
                  child: Text('Tables', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            // -- Add New Table Button --
            // ListTile(
            //   leading: Icon(Icons.add_circle_outline, color: Colors.green.shade800, size: 28),
            //   title: Text('Add New Table', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            //   onTap: _addNewTable,
            // ),
            Divider(),

            // -- List of Active Tables from ObjectBox --
            ...activeTables.map(
              (table) => ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: InkWell(
                  onTap: () {
                    _navigateToOrderPage(table); // Pass the table object to navigate
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade700, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Table ${table.number}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900),
                        ),
                        Text(
                          '₹${table.total.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                          onPressed: () => {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Delete Table ${table.number}?'),
                                content: const Text('This will clear the table and its items. This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
                                    onPressed: () async{
                                      _deleteTable(table.id);
                                      Navigator.of(ctx).pop();
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ), //showDialog
                          },
                          constraints: BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),

                children: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadOrdersFromPrefs(table.number),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error loading items: ${snapshot.error}"));
                      }
                      final items = snapshot.data ?? [];

                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No items added yet.', style: TextStyle(color: Colors.grey)),
                        );
                      } else {
                        return Column(
                          children: items.map<Widget>(
                            (item) {
                              final int qty = int.parse(item['qty'].toString());
                              final double price = double.parse(item['sellPrice'].toString());
                              final double total = qty * price;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1.0),
                                child: Row(
                                  children: [
                                    // Item name and basic info
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'] ?? 'No Name',
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                            maxLines: 2,
                                            overflow: TextOverflow.fade,
                                          ),
                                          Text(
                                            '₹${price.toStringAsFixed(2)} each',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Quantity controls
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Decrease button
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 15),
                                            onPressed: () async {
                                              if (qty > 1) {
                                                await _updateItemQuantity(table, item, qty - 1);
                                                // Refresh the FutureBuilder
                                                if (mounted) {
                                                  setState(() {});
                                                }
                                              } else {
                                                // Remove item if quantity becomes 0
                                                await _removeItemFromCart(table, item);
                                                if (mounted) {
                                                  setState(() {});
                                                }
                                              }
                                            },
                                            style: IconButton.styleFrom(
                                              padding: const EdgeInsets.all(0),
                                              backgroundColor: Colors.grey[200],
                                              minimumSize: const Size(30, 30), // Reduced minimum size
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                          
                                          // Quantity display
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 0),
                                            child: Text(
                                              qty.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          
                                          // Increase button
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 18),
                                            onPressed: () async {
                                              await _updateItemQuantity(table, item, qty + 1);
                                              if (mounted) {
                                                setState(() {});
                                              }
                                            },
                                            style: IconButton.styleFrom(
                                              padding: const EdgeInsets.all(1),
                                              backgroundColor: Colors.grey[200],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Total price
                                    SizedBox(
                                      width: 30, // Fixed width
                                      child: Text(
                                        '₹${total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ).toList(),
                        );
                      }
                    },
                  ),
  
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: isPrinting ? null : () async {
                            setState(() {
                              isPrinting = true;
                            });
                            try {
                              final cart = await _loadOrdersFromPrefs(table.number);
                              if (cart.isNotEmpty) {
                                await printer.printCart(
                                  context: context,
                                  cart1: cart,
                                  total: 12,
                                  mode: "kot",
                                  payment_mode: table_payment_mode,
                                  kot: table.number,
                                );
                              }
                            } catch (e) {
                              debugPrint("Print error: $e");
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isPrinting = false;
                                });
                              }
                            }
                          },
                          child: isPrinting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text('KOT'),
                        ),
                        
                        ElevatedButton.icon(
                          onPressed: isPrinting ? null : () async {
                            setState(() {
                              isPrinting = true;
                            });
                            try {
                              final cart = await _loadOrdersFromPrefs(table.number);
                              if (cart.isNotEmpty){
                                await printer.printCart(context: context, cart1: cart,
                                                total:(table.total).toInt(),
                                                mode:"onlyPrint",
                                                payment_mode:table_payment_mode,
                                                kot:table.number);
                              }
                            } catch (e) {
                              debugPrint("Print error: $e");
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isPrinting = false;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.print, size: 18),
                          label: isPrinting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              :const Text('Print'),
                        ),
                        ElevatedButton.icon(
                          onPressed: isPrinting ? null : () async {
                            final cart = await _loadOrdersFromPrefs(table.number);
                            if (cart.isEmpty){
                              return;
                            }
                            setState(() {
                              isPrinting = true;
                            });
                            try{
                              await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(cart1:cart,mode:"edit",table:{'total':table.total.toInt(),
                                                      'mode':"onlySettle",
                                                      'kot': table.number})));
                              final prefs = await SharedPreferences.getInstance();
                              final key = "table${table.number}";
                              String? _cart1 = prefs.getString(key);
                              // debugPrint("table is settle : ${_cart1}");
                              if ((_cart1 ?? '').isEmpty) {
                                updateTableTotal(table, []);
                                // table_payment_mode = "Cash";
                                loadRecentTransactions(store); 
                              }else{
                                Navigator.of(context).pop(); // This will close the drawer or navigate back
                              }
                            } catch (e) {
                              debugPrint("Print error: $e");
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isPrinting = false;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: isPrinting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Settle'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],

              ),
            ),
          ],
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
                  Text('Loading...', style: TextStyle(color: Colors.white)),
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
                          '📊 Reports \n',
                          'Total: ₹ ${getTodayTotalSale()}\n' // If this also needs to be reactive, use similar approach
                          'Expenses: ₹ ${totalExpenses.toStringAsFixed(2)}\n',
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _infoCard(
                    '💰 Sale (for ${DateFormat('dd/MM').format(_selectedDate)})',
                    'Cash: ₹ ${getSelectedDateCashSale()}\n'
                    'UPI: ₹ ${getSelectedDateUpiSale()}\n'
                    'Total: ₹ ${getSelectedDateTotalSale()}\n',
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('RECENT SALE TRANSACTIONS',
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
                  'Total Transactions: ${filteredTransactions.length}',
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
                                'Bill No: ${tx['billNo']}(${tx['id']}) / Table: ${tx['tableNo'] ?? "-"}',
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
                                      child: const Text('Settle'),
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
                                  'Mode: ${tx['payment_mode']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Sale: ₹${tx['total']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text('Items: ${tx['cart'].length}',
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
            label: Text('New Order'),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Party"),
          BottomNavigationBarItem(icon: Icon(Icons.balance), label: "Udhari"),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: "Expenses",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: "Inventory",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_bar_sharp),
            label: "Tables",
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
          content: Text("Business Date Changed To $_date"),
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
