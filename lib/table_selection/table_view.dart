// --- table_view.dart ---

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:objectbox/objectbox.dart';
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

  @override
  void initState() {
    super.initState();

    _tablesList = store.box<Active_Table_view>();
    cartProvider = Provider.of<CartProvider>(context,listen: false);
    
    // Load initial data
    _loadTables();
    loadSelectedStyle();
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
      
  void updateTableTotal(Active_Table_view table, List<Map<String, dynamic>> cart) {
    double newTotal = 0.0;

    debugPrint("item['sellPrice'], ${cart.runtimeType} ${cart}");
    
    // Loop through each item in the cart
    for (final item in cart) {
      // ❗️ FIX: The value could be a String, int, or double.
      // .toString() and parse() handles all cases safely.
      debugPrint("item['sellPrice'], ${item['sellPrice']}");
      final int quantity = int.parse(item['qty'].toString());
      final double price = double.parse(item['sellPrice'].toString());

      // Perform the calculation
      newTotal += price * quantity;
    }
    
    // Update the table's total property
    table.total = newTotal;
    
    // Save the updated table object to the database
    _tablesList.put(table); 
    
    _updateTableTimer(table.number, newTotal);

    debugPrint("✅ Table #${table.number} total updated to: $newTotal from $cart");
    setState(() { });
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
        updateTableTotal(table, []);
        _loadTables();
      } else {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        debugPrint("item['sellPrice'] ${cartProvider.cart.isNotEmpty} cartProvider.cart ${(cartProvider.cart).runtimeType}");
        if (cartProvider.cart.isNotEmpty){
          updateTableTotal(table, cartProvider.cart);
          _loadTables();
        } else{
          final cart = jsonDecode(_cart1 ?? "[]");
          final cartData = List<Map<String, dynamic>>.from(cart); // Simpler conversion
          debugPrint("item['sellPrice'] ${cartData} cartProvider.cart ${cartData.runtimeType}");
          updateTableTotal(table, cartData);
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
      ),
      
      // 4. NEW: The body is now a Column
      body: Column(
        children: [
          
          // 5. NEW: The Live Orders Box
          _buildLiveOrdersBox(liveOrderCount, liveOrderTables),

          // 6. NEW: We wrap the ListView in Expanded
          Expanded(
            child: ListView.builder(
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final sectionName = sections[index];
                final tablesInSecion = groupedTables[sectionName]!;

                // --- The rest of your ListView.builder code is unchanged ---
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION HEADER
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

                    // List of tables for this section
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
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _addNewTable,
      //   backgroundColor: Colors.green.shade700,
      //   child: const Icon(Icons.add),
      // ),
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