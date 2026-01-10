// --- table_view.dart ---

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:objectbox/objectbox.dart';
import 'package:test1/utilities.dart';
import 'dart:async';

// --- Import your other files ---
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/tabledata.dart'; // This has Active_Table_view
import '../NewOrderPage.dart'; // For _navigateToOrderPage
import '../MenuItemPage.dart'; // For _navigateToOrderPage
import '../cartprovier/cart_provider.dart'; // For _navigateToOrderPage
import '../editBillPrint/editBill.dart';
import '../database_Module/transaction.dart';
import '../database_Module/tableCart.dart';
import '../objectbox.g.dart';

import '../settings/SettingsPage.dart';
import '../database_Module/menu_item.dart';
import 'dart:io'; // Add this for File class
import 'package:path_provider/path_provider.dart'; // Add this for getApplicationDocumentsDirectory
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:test1/utility_captain.dart';

class TableView extends StatefulWidget {
  const TableView({Key? key}) : super(key: key);

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  late Store store = Provider.of<ObjectBoxService>(context, listen: false).store;
  late Box<Active_Table_view> _tablesList;
  List<Active_Table_view> activeTables = [];
  String selectedStyle = "List Style Half Full"; // Default
  late Box<MenuItem> menuItemBox = store.box<MenuItem>();

  
  late StreamSubscription<FileSystemEvent>? _kotWatcher;
  late StreamSubscription<FileSystemEvent>? _settleWatcher;
  String lastKotHash = "";
  String lastSettleHash = "";
  Timer? _debounce;
  Timer? _settleDebounce;


  @override
  void initState() {
    super.initState();

    _tablesList = store.box<Active_Table_view>();
    cartProvider = Provider.of<CartProvider>(context,listen: false);
    
    // Load initial data
    // Call your methods sequentially
    _loadTables();
    loadSelectedStyle();

    watchKOTFile();
    watchSettleFile();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await readAndSaveToPrefs();
      await processSettleTables();
      _loadTables();
      debugPrint("✅ Sync completed");
    });
  }

  /// Fetches all tables from ObjectBox and updates the UI.
  void _loadTables() {
    setState(() {
      activeTables = _tablesList.getAll();
      activeTables.sort((a, b) => a.number.compareTo(b.number));
    });
    debugPrint("✅ Table #${activeTables} total updated to:");
  }

  /// Loads the user's preferred order page style
  Future<void> loadSelectedStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStyle = prefs.getString('selectedStyle') ?? "List Style Half Full";
    });
  }




String getMd5(String input) {
  return md5.convert(utf8.encode(input)).toString();
}


void watchKOTFile() async {
  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('role') ?? '';
  final deviceId = prefs.getString('device_id') ?? ''; // Add device ID

  final dir = await getApplicationSupportDirectory();
  final kotFile = File('${dir.path}/pending_kot.json');

  if (!await kotFile.exists()) {
    await kotFile.writeAsString("[]");
    debugPrint("🆕 Created pending_kot.json");
  }

  _kotWatcher = kotFile.watch(events: FileSystemEvent.modify).listen((event) async {
    if (event.type != FileSystemEvent.modify) return;

    final text = await kotFile.readAsString();
    debugPrint("⛔ text read from file $text");
    final currentHash = getMd5(text);

    if (currentHash == lastKotHash) {
      debugPrint("⛔ No change in KOT file → ignoring");
      return;
    }

    lastKotHash = currentHash;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      debugPrint("🔄 KOT file updated → checking role/device...");

      try {
        final List decoded = jsonDecode(text);

        if (decoded.isNotEmpty &&
            decoded[0]["items"] != null &&
            decoded[0]["items"].isNotEmpty) {
          
          final item = decoded[0]["items"][0];
          final dataFor = item["datafor"]?.toString() ?? "";
           final type = item["type"]?.toString() ?? "";
          final senderDevice = item["sender_device"]?.toString() ?? ""; // Add sender device field

          debugPrint("🔍 File datafor = $dataFor | User role = $role | Sender device = $senderDevice | deviceId = $deviceId");

          // 🔥 CRITICAL FIX: Check if this update came from THIS device
          if (senderDevice == deviceId) {
            debugPrint("⏭️ Update came from this device → ignoring to prevent duplicate");
            await kotFile.writeAsString("[]"); // Clear the file
            return;
          }

          if (dataFor == "ALL" || dataFor == role) {
            debugPrint("✅ ROLE MATCH → Processing KOT");
            if(type == "KOT")
            {
               await readAndSaveToPrefsforkot();
            }else{
              await readAndSaveToPrefs();
            }
            
            if (mounted) setState(() => _loadTables());
            debugPrint("✅ Sync complete");
          } else {
            debugPrint("⛔ ROLE MISMATCH → Ignoring KOT");
            await kotFile.writeAsString("[]");
            debugPrint("⛔ ROLE MISMATCH → Ignoring KOT & file cleared");
          }
        }
      } catch (e) {
        debugPrint("❌ JSON parse error: $e");
      }
    });
  });
}

void watchSettleFile() async {
  final dir = await getApplicationSupportDirectory();
  final settleFile = File('${dir.path}/pending_settle.json');

  // Ensure file exists
  if (!await settleFile.exists()) {
    await settleFile.writeAsString("[]");
  }

  debugPrint("SETTLE → watching directory: ${dir.path}");

  _settleWatcher = dir.watch().listen((event) async {
    if (!event.path.endsWith("pending_settle.json")) return;
    if (event.type != FileSystemEvent.modify) return;

    final text = await settleFile.readAsString();
    final currentHash = getMd5(text);

    if (currentHash == lastSettleHash) {
      debugPrint("⛔ No real change");
      return;
    }

    lastSettleHash = currentHash;

    _settleDebounce?.cancel();
    _settleDebounce = Timer(const Duration(milliseconds: 600), () async {
      debugPrint("🔄 SETTLE updated → syncing...");
      await processSettleTables();
      if (mounted) setState(() => _loadTables());
      debugPrint("✅ SETTLE Sync complete");
    });
  });
}

@override
void dispose() {
  _kotWatcher?.cancel(); // Cancel the watcher
  _settleWatcher?.cancel();
  _debounce?.cancel();
  _settleDebounce?.cancel();
  super.dispose();
}

  Future<void> sendFcmNotification( BuildContext context, List<Map<String, dynamic>> cartItems ,int tablenumber) async {
  try {
    // // Generate order ID
    // String orderId = "ORD${DateTime.now().millisecondsSinceEpoch}";
    
    // Get table name
    String tableName = tablenumber.toString();

     final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'unknown';

     final captain_name = prefs.getString('captain_name') ?? '';

     final role = prefs.getString("role")?? '';
     
      final hotelname = prefs.getString("username")?? '';

    if(hotelname =='')
    {
      debugPrint("Failed to send order for hotel $hotelname");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send order for hotel $hotelname"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }


    var order_tpe = '';

    debugPrint("sentfcm trigger through table_view $tableName");

    if(tableName=="Takeaway")
    {
      return;
    }

    if(role=="captain")
    {
      order_tpe= "KOT";
    }else{
      order_tpe= "OTHER";
    }



 
 
  List<Map<String, dynamic>> updatedCart = cartItems.map((item) {
          return {
            ...item,
            "tableno": tableName,   // 🔥 insert table name
            "datafor": "captain", 
            "sender_device": deviceId, // 🔥 ADD sender device ID
           "type":order_tpe,
          };
        }).toList();

    
    // Prepare the request data
    Map<String, dynamic> requestData = {
      "hotel": hotelname,
      "data": {
                  // 🔥 added here
        "printData": json.encode(updatedCart),
      }
    };

    
    debugPrint("Sending FCM notification after table price upate: ${json.encode(requestData)}");
    
    // Make API call
    final response = await apiCalls('s',hotelname,requestData);
    
    if (response!.statusCode == 200) {
      debugPrint("FCM notification sent successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Order sent to kitchen successfully"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // After sending FCM, update the table to reflect the cart
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final activeBox = store.box<Active_Table_view>();
    final tQuery = activeBox.query(Active_Table_view_.number.equals(tablenumber)).build();
    final tableList = tQuery.find();
    tQuery.close();
    
    if (tableList.isNotEmpty) {
      // 🔥 Update with skipFcm: true to prevent another FCM
      // updateTableTotal(tableList.first, cartItems, skipFcm: true);
      Active_Table_view table = tableList.first;
      double newTotal = 0.0;
      for (final item in cartItems) {
        final int quantity = int.parse(item['qty'].toString());
        final double price = double.parse(item['sellPrice'].toString());
        newTotal += price * quantity;
      }
      table.total = newTotal;
      activeBox.put(table);
    } else {
      debugPrint("Failed to send FCM notification: ${response.statusCode}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send order to kitchen"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
    }
  } catch (e) {
    debugPrint("Error sending FCM notification: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error sending order to kitchen: $e"),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }
}



  
Future<void> processSettleTables() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File("${dir.path}/pending_settle.json");

    if (!file.existsSync()) {
      debugPrint("❌ pending_settle.json file not found");
      return;
    }

    final text = await file.readAsString();

    debugPrint("pending_settle.json file $text");
    if (text.isEmpty) return;

    final List<dynamic> settleList = jsonDecode(text);

    if (settleList.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    for (var entry in settleList) {
      if (entry is Map<String, dynamic>) {
        final tableNo = entry['tableNo']?.toString();
        if (tableNo != null) {
          final key = "table$tableNo";
          if (prefs.containsKey(key)) {
            await prefs.remove(key);
            debugPrint("✅ Removed table $tableNo from SharedPreferences");
            // -----------------------------
      // 5️⃣ Update ObjectBox table total
      // -----------------------------
      final store = Provider.of<ObjectBoxService>(context, listen: false).store;
      final box = store.box<Active_Table_view>();

      final query = box
          .query(Active_Table_view_.number.equals(int.parse(tableNo)))
          .build();

      final tableList = query.find();
      query.close();

      if (tableList.isNotEmpty) {
        final table = tableList.first;

        // Update total inside ObjectBox
        updateTableTotal(table, []);

        final tableNo1 = int.tryParse(entry['tableNo']) ?? 0;
          // 3. Find if an entry for this table already exists
    final box = store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo1)).build();
    tableCart? existingTableCart = query.findFirst();
    query.close();
    debugPrint("✅ Updated cart for table #$tableNo in ObjectBox. existingTableCart $existingTableCart");

    // 5. If the cart is empty, remove the entry from the database
    if (existingTableCart != null) {
      box.remove(existingTableCart.id);
      debugPrint("🗑️ Removed empty cart for table #$tableNo from ObjectBox.");
    }


       

        _loadTables(); // refresh UI

        debugPrint("🔄 Updated ObjectBox table ${table.number}");
      } else {
        debugPrint("❌ No ObjectBox table found for number: $tableNo");
      }

          } else {
            debugPrint("⚠️ Table $tableNo key not found in SharedPreferences");

               final store = Provider.of<ObjectBoxService>(context, listen: false).store;
      final box = store.box<Active_Table_view>();

             final query = box
          .query(Active_Table_view_.number.equals(int.parse(tableNo)))
          .build();

      final tableList = query.find();
      query.close();

  
        final table = tableList.first;
            updateTableTotal(table, [], skipFcm: true);


              final tableNo1 = int.tryParse(entry['tableNo']) ?? 0;
          // 3. Find if an entry for this table already exists
    final box1 = store.box<tableCart>();
    final query1 = box1.query(tableCart_.tableNo.equals(tableNo1)).build();
    tableCart? existingTableCart = query1.findFirst();
    query1.close();
    debugPrint("✅ Updated cart for table #$tableNo in ObjectBox. existingTableCart $existingTableCart");

    // 5. If the cart is empty, remove the entry from the database
    if (existingTableCart != null) {
      box1.remove(existingTableCart.id);
      debugPrint("🗑️ Removed empty cart for table #$tableNo from ObjectBox.");

    }

     if (mounted) setState(() => _loadTables());
          }
        }
      }
    }

    // Clear the pending_settle.json file after processing
    await file.writeAsString("[]");
    debugPrint("🧹 pending_settle.json cleared after processing");

    
  } catch (e) {
    debugPrint("❌ Error processing settle tables: $e");
  }
}

Future<void> readAndSaveToPrefsforkot() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File("${dir.path}/pending_kot.json");

    if (!file.existsSync()) {
      debugPrint("❌ pending_kot.json not found");
      return;
    }

    final raw = await file.readAsString();
    debugPrint("pending_kot File → $raw");

    final List<dynamic> rootList = jsonDecode(raw);

    // STEP 1️⃣ : GROUP ITEMS BY TABLE
    Map<String, List<Map<String, dynamic>>> tableMap = {};

    for (var entry in rootList) {
      final List<dynamic> items = entry["items"] ?? [];
      if (items.isEmpty) continue;

      final tableNo = items.first["tableno"]?.toString();
      if (tableNo == null || tableNo.isEmpty) continue;

      tableMap.putIfAbsent(tableNo, () => []);
      tableMap[tableNo]!.addAll(
        items.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
      );
    }

    // Access ObjectBox
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final activeBox = store.box<Active_Table_view>();
    final cartBox = store.box<tableCart>();

    // STEP 2️⃣ : PROCESS EACH TABLE ONCE
    for (var tableNo in tableMap.keys) {
      final int tNo = int.parse(tableNo);

      // Check existing cart
      final cartQuery =
          cartBox.query(tableCart_.tableNo.equals(tNo)).build();
      tableCart? existing = cartQuery.findFirst();
      cartQuery.close();

      // Decode old cart
      List<Map<String, dynamic>> oldItems = [];
      if (existing != null && existing.tCart.isNotEmpty) {
        oldItems =
            List<Map<String, dynamic>>.from(jsonDecode(existing.tCart));
      }

      // New KOT items
      List<Map<String, dynamic>> newItems = tableMap[tableNo]!;

      // STEP 3️⃣ : Merge (name + portion)
      Map<String, Map<String, dynamic>> merged = {};

      for (var item in oldItems) {
        final key = "${item['name']}_${item['portion']}";
        merged[key] = Map<String, dynamic>.from(item);
      }

      for (var item in newItems) {
        final key = "${item['name']}_${item['portion']}";
        if (merged.containsKey(key)) {
          merged[key]!['qty'] =
              (merged[key]!['qty'] as num) + (item['qty'] as num);
          merged[key]!['total'] =
              (merged[key]!['qty'] as num) * (merged[key]!['sellPrice'] as num);
        } else {
          merged[key] = Map<String, dynamic>.from(item);
        }
      }

      final finalList = merged.values.toList();
      final stringCart = jsonEncode(finalList);

      // STEP 4️⃣ : SAVE IN OBJECTBOX (NOT SHAREDPREFS)
      if (finalList.isNotEmpty) {
        if (existing != null) {
          existing.tCart = stringCart;
          cartBox.put(existing);
          debugPrint("🟢 Updated ObjectBox Cart → Table $tNo");


        } else {
          final newCart = tableCart(tableNo: tNo, tCart: stringCart);
          cartBox.put(newCart);
          debugPrint("🟢 Created ObjectBox Cart → Table $tNo");
        }
      } else {
        if (existing != null) {
          cartBox.remove(existing.id);
          debugPrint("🗑️ Deleted empty cart → Table $tNo");
        }
      }

      // STEP 5️⃣ : UPDATE ACTIVE TABLE TOTAL
      final tQuery = activeBox
          .query(Active_Table_view_.number.equals(tNo))
          .build();

      final tableList = tQuery.find();
      tQuery.close();

      if (tableList.isNotEmpty) {
        
        updateTableTotal(tableList.first, finalList,skipFcm: true);
        debugPrint("🔄 Updated Table Total → $tNo (skipFcm)");
      }
    }

    // STEP 6️⃣ : CLEAR FILE SAFELY
    //ignoreNextWrite = true;
    await file.writeAsString(jsonEncode([]));
    lastKotHash = getMd5("[]");

    debugPrint("🧹 pending_kot.json cleared successfully");

    if (mounted) setState(() => _loadTables());
  } catch (e) {
    debugPrint("❌ Error → $e");
  }
}


Future<void> readAndSaveToPrefs() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File("${dir.path}/pending_kot.json");

    if (!file.existsSync()) {
      debugPrint("❌ pending_kot.json not found");
      return;
    }

    final raw = await file.readAsString();
    debugPrint("pending_kot File → $raw");

    final List<dynamic> rootList = jsonDecode(raw);

    // STEP 1️⃣ : GROUP ITEMS BY TABLE
    Map<String, List<Map<String, dynamic>>> tableMap = {};

    for (var entry in rootList) {
      final List<dynamic> items = entry["items"] ?? [];
      if (items.isEmpty) continue;

      final tableNo = items.first["tableno"]?.toString();
      if (tableNo == null || tableNo.isEmpty) continue;

      tableMap.putIfAbsent(tableNo, () => []);
      tableMap[tableNo]!.addAll(items.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)));
    }
    print_log("create table map is $tableMap");

    // Access ObjectBox
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final activeBox = store.box<Active_Table_view>();
    final cartBox = store.box<tableCart>();

    // STEP 2️⃣ : PROCESS EACH TABLE ONCE
    for (var tableNo in tableMap.keys) {
      final int tNo = int.parse(tableNo);

      final cartQuery = cartBox.query(tableCart_.tableNo.equals(tNo)).build();
      tableCart? existing = cartQuery.findFirst();
      cartQuery.close();

      List<Map<String, dynamic>> newItems = tableMap[tableNo]!;
      List<Map<String, dynamic>> combinedItems = [];

      // Load existing items if they exist
      if (existing != null && existing.tCart.isNotEmpty) {
        try {
          combinedItems = List<Map<String, dynamic>>.from(jsonDecode(existing.tCart));
        } catch (e) {
          debugPrint("Error decoding existing cart: $e");
        }
      }

      // 🔥 FIX: Merge logic instead of .addAll()
      for (var newItem in newItems) {
        // Find if the item already exists in the combined list (check by ID)
        int existingIndex = combinedItems.indexWhere((item) => item['name'] == newItem['name']);

        if (existingIndex != -1) {
          
          int oldQty = (combinedItems[existingIndex]['qty'] as num? ?? 0).toInt();
          int newQty = (newItem['qty'] as num? ?? 0).toInt();

          double newPrice = (newItem['sellPrice'] as num? ?? 0.0).toDouble();

          combinedItems[existingIndex]['qty'] = oldQty + newQty;
          combinedItems[existingIndex]['total'] = (oldQty + newQty) * newPrice;
          
          debugPrint("marge and Updated ${newItem['name']} qty to ${combinedItems[existingIndex]['qty']} total to ${combinedItems[existingIndex]['total']}");
        } else{
          debugPrint("ITEM DOES NOT EXIST: Add new item $newItem");
          // ITEM DOES NOT EXIST: Add new item
          combinedItems.add(newItem);
        }
      }


      final stringCartNew = jsonEncode(combinedItems);
      print_log("stringCartNew $stringCartNew");

      // STEP 4️⃣ : SAVE IN OBJECTBOX
      if (newItems.isNotEmpty) {
        if (existing != null) {
          existing.tCart = stringCartNew;
          cartBox.put(existing);
          debugPrint("🟢 Merged ObjectBox Cart → Table $tNo");
        } else {
          final newCart = tableCart(tableNo: tNo, tCart: stringCartNew);
          cartBox.put(newCart);
          debugPrint("🟢 Created new ObjectBox Cart → Table $tNo");
        }
      } else {
        if (existing != null) {
          cartBox.remove(existing.id);
          debugPrint("🗑️ Deleted empty cart → Table $tNo");
        }
      }

      // STEP 5️⃣ : UPDATE ACTIVE TABLE TOTAL
      final tQuery = activeBox.query(Active_Table_view_.number.equals(tNo)).build();
      final tableList = tQuery.find();
      tQuery.close();

      updateTableTotal(tableList.first, combinedItems, skipFcm: true);
    }

    // STEP 6️⃣ : CLEAR FILE
    await file.writeAsString(jsonEncode([]));
    lastKotHash = getMd5("[]");

    debugPrint("🧹 pending_kot.json cleared successfully");

    if (mounted) setState(() => _loadTables());
  } catch (e) {
    debugPrint("❌ Error → $e");
  }
}








  /// Adds a new table to the database and reloads the list.
void _addNewTable() {
    // This controller will hold the section name
    final TextEditingController sectionController = TextEditingController(text: "Family Section");
    // 1. Get a unique list of all existing section names BEFORE showing the dialog
    //    I'm using 'paymentMethod' because that's what your constructor uses for the section.
    final allSections = activeTables
        .map((table) => table.paymentMethod) 
        .toSet() // .toSet() automatically gets only unique names
        .toList();

    // 2. Add a default "Family Section" section if it doesn't exist
    if (!allSections.contains("Family Section")) {
      allSections.insert(0, "Family Section");
    }

    // 3. These variables will hold the dialog's state
    String? selectedSection = allSections.first; // Default to the first section
    bool isAddingNewSection = false;
    final newSectionController = TextEditingController();
    const String addNewKey = 'ADD_NEW_SECTION'; // A special value for our dropdown

    showDialog(
      context: context,
      builder: (ctx) {
        // 4. Use StatefulBuilder to allow setState() calls inside the dialog
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Table'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 5. Check state: Show dropdown OR text field
                  if (isAddingNewSection)
                    ...[
                      // --- UI for ADDING A NEW section ---
                      TextField(
                        controller: newSectionController,
                        decoration: const InputDecoration(
                          labelText: 'New Section Name',
                          hintText: 'e.g., Rooftop',
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                      ),
                      TextButton(
                        child: const Text('Back to list'),
                        onPressed: () {
                          setState(() {
                            isAddingNewSection = false;
                          });
                        },
                      )
                    ]
                  else
                    ...[
                      // --- UI for SELECTING an existing section ---
                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedSection,
                        hint: const Text('Select a Section'),
                        items: [
                          // 6. Create a list item for each existing section
                          ...allSections.map((section) {
                            return DropdownMenuItem(
                              value: section,
                              child: Text(section),
                            );
                          }),
                          // 7. Add the special "Add New" button to the list
                          const DropdownMenuItem(
                            value: addNewKey,
                            child: Text(
                              '+ Add New Section',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            if (value == addNewKey) {
                              // User wants to add a new one
                              isAddingNewSection = true;
                              newSectionController.clear();
                            } else {
                              // User selected an existing one
                              selectedSection = value;
                            }
                          });
                        },
                      ),
                    ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // --- This logic for table number is unchanged ---
                    final maxNumber = activeTables.isNotEmpty
                        ? activeTables.map((t) => t.number).reduce((a, b) => a > b ? a : b)
                        : 0;
                    
                    final newTableNumber1 = maxNumber + 1;
                    final int newTableNumber;
                    
                    if (newTableNumber1.toString().contains("13")) {
                      newTableNumber = maxNumber + 2;
                    } else {
                      newTableNumber = maxNumber + 1;
                    }
                    
                    // --- 8. UPDATED: Get the section name from the correct state ---
                    String sectionName;
                    if (isAddingNewSection) {
                      // Get text from the controller
                      sectionName = newSectionController.text.trim();
                      if (sectionName.isEmpty) {
                        sectionName = "Family Section"; // Default if new and empty
                      }
                    } else {
                      // Get text from the dropdown
                      sectionName = selectedSection ?? "Family Section"; // Use selected or default
                    }

                    // --- This logic for creating the object is unchanged ---
                    // NOTE: You are saving the sectionName into the 'paymentMethod' field.
                    final newTableObject = Active_Table_view(
                      number: newTableNumber,
                      paymentMethod: sectionName,
                    );
                    _tablesList.put(newTableObject);

                    // --- This logic for reloading and closing is unchanged ---
                    _loadTables();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      }
    );
  }


  /// Deletes a table from the database by its ID.
  void _deleteTable(int tableId) {
    final table = _tablesList.get(tableId);
    if (table != null) {
      _updateTableTimer(table.number, 0);
    }
    _tablesList.remove(tableId);
    // After deleting, reload the data to update the UI
    _loadTables();
  }
      
  void updateTableTotal(Active_Table_view table, List<Map<String, dynamic>> cart, {bool skipFcm = false}) async {
    double newTotal = 0.0;
    
    debugPrint("updateTableTotal called with skipFcm: $skipFcm $cart");
    
    // Loop through each item in the cart
    for (final item in cart) {
      debugPrint("item['sellPrice'], ${item['sellPrice']}");
      final int quantity = int.parse(item['qty'].toString());
      final double price = double.parse(item['sellPrice'].toString());
      newTotal += price * quantity;
    }
    
    final double oldTotal = table.total ?? 0.0;

    // Only update if total actually changed
    if (newTotal != oldTotal) {
      table.total = newTotal;
      _tablesList.put(table); 
      _updateTableTimer(table.number, newTotal);
      debugPrint("🔥 Table #${table.number} total updated → ₹${newTotal.toStringAsFixed(2)}");
      
      // 🔥 PREVENT THE LOOP: Only send FCM if NOT skipping (i.e., not from FCM update)
      if (!skipFcm) {
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('role');
        
        if (role == 'cashier') {
          debugPrint("💰 Cashier role detected → sending FCM notification");
          await sendFcmNotification(context, cart, table.number);
        }
      } else {
        debugPrint("⏭️ Skipping FCM notification (skipFcm=true)");
      }
      
      if (mounted) setState(() { });
    } else {
      debugPrint("⏭️ Table #${table.number} total unchanged → ₹$oldTotal");
    }
  }

  Future<void> _updateTableTimer(int tableNumber, double total) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'table_timer_$tableNumber';
    if (total > 0) {
      if (!prefs.containsKey(key)) {
        await prefs.setString(key, DateTime.now().toIso8601String());
      }
    } else {
      await prefs.remove(key);
    }
  }

  Future<Map<String, dynamic>> loadRecentTransactions(Active_Table_view table) async {
    final box12 = store.box<Transaction>();
    final prefs = await SharedPreferences.getInstance();

    final int tableNo = table.number;
    final key = "tt$tableNo";
    
    // 1. Get the ID from prefs. It might be null.
    final int? ttid = prefs.getInt(key);

    // 2. Check if the ID even exists. If not, return an empty map.
    if (ttid == null) {
      return {};
    }

    // 3. Try to get the transaction from ObjectBox
    final Transaction? existingTx = box12.get(ttid);

    // 4. Check if the transaction was found
    if (existingTx != null) {
      // Success! Return its map.
      // (This assumes your Transaction class has a .toMap() method)
      return existingTx.toMap();
    } else {
      // We had an ID, but the transaction doesn't exist in ObjectBox
      // (it might have been deleted). Return an empty map.
      return {};
    }
  }

  Future<String?> _getUserRole() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('role');
}

  /// Navigates to the order page for the selected table
  void _navigateToOrderPage(Active_Table_view table) async {
    final int tableNo = table.number;
    // final key = "table$tableNo";

    final box = store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
    tableCart? existingTableCart = await query.findFirst();
    query.close();
    // debugPrint("✅ Updated cart for table #${existingTableCart!.tableNo} in ObjectBox. existingTableCart ${existingTableCart!.tCart}");
    String? _cart1;
    if (existingTableCart != null) {
      // 4a. If it exists, update it
      _cart1 = existingTableCart.tCart;
    }
    
    // final prefs = await SharedPreferences.getInstance();
    // final jsonString = prefs.getString(key);
    debugPrint("cart loded from the DB $_cart1");
    
    List<Map<String, dynamic>> existingCart = [];
    if (_cart1 != null) {
      final decodedList = jsonDecode(_cart1) as List<dynamic>;
      existingCart = decodedList.map((item) => item as Map<String, dynamic>).toList();
    }

    Map<String, dynamic> tt = await loadRecentTransactions(table);
    debugPrint("table transections $tt");

    try{
      final carttt = await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(cart1:existingCart,
                        transaction: tt,
                        mode:"edit",
                        table:{'total':table.total.toInt(),'mode':"onlySettle",'kot': table.number},
                        )));
      final tableNo = table.number;
      final box = store.box<tableCart>();
      final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
      tableCart? existingTableCart = query.findFirst();
      query.close();
      debugPrint("✅ Updated cart for table #$tableNo in ObjectBox. existingTableCart $existingTableCart");
      String? _cart1;
      if (existingTableCart != null) {
        // 4a. If it exists, update it
        _cart1 = existingTableCart.tCart;
      }
      // String? _cart1 = existingTableCart.tCart ?? "";
      debugPrint("item['sellPrice'] ${_cart1} cartProvider.cart ${(_cart1).runtimeType}");
      if ((_cart1 ?? '').isEmpty || _cart1 == null) {
        updateTableTotal(table, [], skipFcm: true);
        _loadTables();
      } else {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        debugPrint("item['sellPrice'] ${cartProvider.cart.isNotEmpty} cartProvider.cart ${(cartProvider.cart).runtimeType}");
        if (cartProvider.cart.isNotEmpty){
          updateTableTotal(table, cartProvider.cart,skipFcm: true);
          _loadTables();
        } else{
          final cart = jsonDecode(_cart1 ?? "[]");
          final cartData = List<Map<String, dynamic>>.from(cart); // Simpler conversion
          debugPrint("item['sellPrice'] ${cartData} cartProvider.cart ${cartData.runtimeType}");
          updateTableTotal(table, cartData, skipFcm: true);
          _loadTables();
        }
      }
    } catch (e) {
      debugPrint("Print error: $e");
    } 
    
    // After returning from the page, update the table total
    // (You'll need to add your updateTableTotal function back)
    _loadTables(); // Reload tables to see updated total
  }

@override
  Widget build(BuildContext context) {
    // 1. Group the tables by section (Unchanged)
    final Map<String, List<Active_Table_view>> groupedTables = {};
    for (final table in activeTables) {
      (groupedTables[table.paymentMethod] ??= []).add(table);
    }

    // 2. Get the list of section names and sort them (Unchanged)
    final List<String> sections = groupedTables.keys.toList()..sort();

    // 3. NEW: Calculate live orders
    final liveOrderTables = activeTables.where((t) => t.total > 0).toList();
    final liveOrderCount = liveOrderTables.length;

return Scaffold(
  appBar: AppBar(
    title: const Text('Tables Orders'),
    actions: [
      // Sync button
      IconButton(
        icon: const Icon(Icons.sync),
        tooltip: 'Sync',
        onPressed: () async {
          // Call your methods sequentially
          await readAndSaveToPrefs();
          await processSettleTables();
          _loadTables();
          debugPrint("✅ Sync completed");
        },
      ),

      // Settings button
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsPage(menuItemBox: menuItemBox),
            ),
          );
        },
      ),
    ],
  ),
  
 body: FutureBuilder<String?>(
  future: _getUserRole(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return Center(child: Text('Error loading role'));
    }
    
    final role = snapshot.data;
    
    return Column(
      children: [
        // Only show CaptainNameBox if role is NOT 'cashier'
        if (role != 'cashier')
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: CaptainNameBox(),
          ),

        // 🔥 Existing Live Orders Box
        _buildLiveOrdersBox(liveOrderCount, liveOrderTables),

        // Existing Expanded ListView
        Expanded(
          // ... your existing content
       
      child: ListView.builder(
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final sectionName = sections[index];
          final tablesInSecion = groupedTables[sectionName]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
                child: Text(
                  sectionName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),

                    GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      shrinkWrap: true,
                      primary: false,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: tablesInSecion.length,
                      itemBuilder: (ctx, tableIndex) {
                        final table = tablesInSecion[tableIndex];
                        debugPrint("table ttqwertyu ${table.number} ${table.total}");
                        return GestureDetector(
                          onTap: () => _navigateToOrderPage(table),
                          onLongPress: () => _showDeleteDialog(table),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 4,
                            color: (table.total > 0) ? const Color.fromARGB(255, 218, 3, 3) : Colors.green.shade50,
                            child: Stack(
                              children: [
                                // Centered content
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Table ${table.number.toString()}',
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: (table.total > 0) ? const Color.fromARGB(255, 255, 255, 255) : Colors.green.shade900),
                                      ),
                                      // Text(
                                      //   table.number.toString(),
                                      //   style: TextStyle(
                                      //     fontSize: 14,
                                      //     fontWeight: FontWeight.bold,
                                      //     color:  (table.total > 0) ? const Color.fromARGB(255, 255, 255, 255) :const Color.fromARGB(
                                      //         255, 0, 0, 0),
                                      //   ),
                                      // ),
                                      Text(
                                        '₹${table.total.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 15,
                                            color:  (table.total > 0) ? const Color.fromARGB(255, 255, 255, 255) : Colors.grey.shade700),
                                      ),
                                      TableTimerWidget(tableNumber: table.number, total: table.total),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
          );
        },
      ),
        )
      ],
    );
  },
),
    );
  }

/// A helper widget to build the "Live Orders" box
  Widget _buildLiveOrdersBox(int count, List<Active_Table_view> tables) {
    return GestureDetector(
      // onTap: () {
      //   // You can navigate to a summary page of all live orders here
      //   _navigateToOrderPage(tables);
      // },
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        elevation: 4,
        color: Colors.green.shade100,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16,12,8,12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count active tables',
                      style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                    ),

                    // --- 1. REPLACED SingleChildScrollView/Row ---
                    if (tables.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // 2. Use Wrap to automatically flow to the next line
                      Wrap(
                        spacing: 6.0, // Horizontal space between chips
                        runSpacing: 4.0, // Vertical space between rows
                        children: tables.map((table) {
                          // 3. No Padding widget needed, Wrap handles spacing
                          return ActionChip(
                            label: Text(table.number.toString()),
                            
                            // 2. 'onPressed' is a valid property for ActionChip
                            onPressed: () {
                              _navigateToOrderPage(table);
                            },

                            // The rest of your styling is correct
                            labelStyle: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            backgroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          );
                        }).toList(),
                      ),
                    ],
                    // --- END OF CHANGE ---
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.only(left: 1.0, top: 1.0),
                // 1. Wrap the IconButton with a Container
                child: Container(
                  // 2. Add the decoration for the border
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black, // Your black border
                      width: 1.0,          // You can change the thickness
                    ),
                  ),
                  child: IconButton(
                    onPressed: _addNewTable,
                    icon: Icon(
                      Icons.plus_one_sharp,
                      color: const Color.fromARGB(255, 1, 61, 4),
                      size: 30,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to show delete dialog (to avoid duplicate code)
  void _showDeleteDialog(Active_Table_view table) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Table ${table.number}?'),
        content: Text(
            'Section: ${table.paymentMethod}\n\nThis will clear the table and its items. This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _deleteTable(table.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


}

class CaptainNameBox extends StatefulWidget {

  
  @override
  State<CaptainNameBox> createState() => _CaptainNameBoxState();
}

class _CaptainNameBoxState extends State<CaptainNameBox> {
 
  final TextEditingController _controller = TextEditingController();
  String? captainName;
  bool editing = true;

  @override
  void initState() {
    super.initState();
    _loadCaptainName();
  }

  // 🔥 Load from SharedPreferences
  Future<void> _loadCaptainName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString("captain_name")?? '';

    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        captainName = savedName;
        editing = false;
      });
    }
  }

  // 🔥 Save to SharedPreferences
  Future<void> _saveCaptainName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("captain_name", name);
  }

  @override
  Widget build(BuildContext context) {
    
    return Column(
      
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // --- INPUT FIELD ---
        if (editing) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: "Enter Captain Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final name = _controller.text.trim();
                  if (name.isEmpty) return;

                  _saveCaptainName(name);

                  setState(() {
                    captainName = name;
                    editing = false;
                  });
                },
                child: const Text("Add"),
              )
            ],
          ),
        ],

        // --- DISPLAY SAVED NAME ---
        if (!editing && captainName != null) ...[
          Row(
            children: [
              Text(
                "Captain Name: $captainName",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red, // You can change color here
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _controller.text = captainName!;
                  setState(() => editing = true);
                },
              )
            ],
          ),
        ],
      ],
    );
  }

  
}

class DeviceIdBox extends StatefulWidget {
  @override
  State<DeviceIdBox> createState() => _DeviceIdBoxState();
}

class _DeviceIdBoxState extends State<DeviceIdBox> {
  String deviceId = "Loading...";
  String role = "";
  bool showFullId = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      deviceId = prefs.getString('device_id') ?? "Not set";
      role = prefs.getString('role') ?? "Not set";
    });
  }

  String _getShortDeviceId() {
    if (deviceId.length <= 8) return deviceId;
    return "${deviceId.substring(0, 4)}...${deviceId.substring(deviceId.length - 4)}";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.device_hub, size: 16, color: Colors.blueGrey),
                      SizedBox(width: 6),
                      Text(
                        'Device ID:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey[700],
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showFullId = !showFullId;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.fingerprint, size: 14, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(
                            showFullId ? deviceId : _getShortDeviceId(),
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Monospace',
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Right side: Role info
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getRoleColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (role.toLowerCase()) {
      case 'cashier':
        return Colors.green;
      case 'captain':
        return Colors.blue;
      case 'admin':
        return Colors.purple;
      case 'kitchen':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}





class TableTimerWidget extends StatefulWidget {
  final int tableNumber;
  final double total;

  const TableTimerWidget({
    Key? key,
    required this.tableNumber,
    required this.total,
  }) : super(key: key);

  @override
  State<TableTimerWidget> createState() => _TableTimerWidgetState();
}

class _TableTimerWidgetState extends State<TableTimerWidget> {
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkTimer();
  }

  @override
  void didUpdateWidget(covariant TableTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.total != widget.total) {
      _checkTimer();
    }
  }

  void _checkTimer() async {
    if (widget.total <= 0) {
      _timer?.cancel();
      _timer = null;
      if (mounted) setState(() => _duration = Duration.zero);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = 'table_timer_${widget.tableNumber}';
    String? startTimeStr = prefs.getString(key);

    if (startTimeStr == null) {
      final now = DateTime.now();
      await prefs.setString(key, now.toIso8601String());
      startTimeStr = now.toIso8601String();
    }

    final startTime = DateTime.parse(startTimeStr);
    _startTicker(startTime);
  }

  void _startTicker(DateTime startTime) {
    _timer?.cancel();
    _updateDuration(startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateDuration(startTime);
    });
  }

  void _updateDuration(DateTime startTime) {
    if (!mounted) return;
    setState(() {
      _duration = DateTime.now().difference(startTime);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.total <= 0) return const SizedBox.shrink();
    
    final hours = _duration.inHours.toString().padLeft(2, '0');
    final minutes = (_duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_duration.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      '$hours:$minutes:$seconds',
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}