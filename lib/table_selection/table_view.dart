// --- table_view.dart ---

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:objectbox/objectbox.dart';

// --- Import your other files ---
import '../cartprovier/ObjectBoxService.dart';
import 'tabledata.dart'; // This has Active_Table_view
import '../NewOrderPage.dart'; // For _navigateToOrderPage
import '../MenuItemPage.dart'; // For _navigateToOrderPage
import '../cartprovier/cart_provider.dart'; // For _navigateToOrderPage
import '../editBillPrint/editBill.dart';
import '../models/transaction.dart';

class TableView extends StatefulWidget {
  const TableView({Key? key}) : super(key: key);

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  late Store store;
  late Box<Active_Table_view> _tablesList;
  List<Active_Table_view> activeTables = [];
  String selectedStyle = "List Style Half Full"; // Default

  @override
  void initState() {
    super.initState();

    store = Provider.of<ObjectBoxService>(context, listen: false).store;
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
    _tablesList.remove(tableId);
    // After deleting, reload the data to update the UI
    _loadTables();
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

    debugPrint("✅ Table #${table.number} total updated to: $newTotal from $cart");
    setState(() { });
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
    final key = "table$tableNo";
    
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    
    List<Map<String, dynamic>> existingCart = [];
    if (jsonString != null) {
      final decodedList = jsonDecode(jsonString) as List<dynamic>;
      existingCart = decodedList.map((item) => item as Map<String, dynamic>).toList();
    }
    // final cart = await _loadOrdersFromPrefs(table.number);
    Map<String, dynamic> tt = await loadRecentTransactions(table);
    debugPrint("table transections $tt");

      try{
        final carttt = await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(cart1:existingCart,
                          transaction: tt,
                          mode:"edit",
                          table:{'total':table.total.toInt(),'mode':"onlySettle",'kot': table.number},
                          )));
        final prefs = await SharedPreferences.getInstance();
        String? _cart1 = prefs.getString(key);
        debugPrint("item['sellPrice'] ${_cart1} cartProvider.cart ${(_cart1).runtimeType}");
        if ((_cart1 ?? '').isEmpty) {
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

    // List<Map<String, dynamic>>? updatedCart;
    // if (selectedStyle == "half-Full View") {
    //   updatedCart = await Navigator.push<List<Map<String, dynamic>>>(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => MenuItemPage(
    //         cart1: existingCart,
    //         mode: "edit",
    //         tableno: tableNo,
    //       ),
    //     ),
    //   );
    //   // ... (rest of your navigation logic) ...
    // } else {
    //    updatedCart = await Navigator.push<List<Map<String, dynamic>>>(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => NewOrderPage(cart1: existingCart, tableno: tableNo,),
    //     ),
    //   );
      
    // }
    
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
                                        'Table',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: (table.total > 0) ? const Color.fromARGB(255, 255, 255, 255) : Colors.green.shade900),
                                      ),
                                      Text(
                                        table.number.toString(),
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                          color:  (table.total > 0) ? const Color.fromARGB(255, 255, 255, 255) :const Color.fromARGB(
                                              255, 0, 0, 0),
                                        ),
                                      ),
                                      Text(
                                        '₹${table.total.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color:  (table.total > 0) ? const Color.fromARGB(255, 255, 255, 255) : Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Edit icon
                                // Positioned(
                                //   top: 0,
                                //   right: 0,
                                //   child: GestureDetector(
                                //     onTap: () {
                                //       _navigateToOrderPage(table);
                                //     },
                                //     child: Container(
                                //       padding: EdgeInsets.zero,
                                //       child: Icon(
                                //         Icons.edit,
                                //         color:  (table.total > 0) ? const Color.fromARGB(255, 51, 255, 0) : const Color.fromARGB(
                                //             255, 247, 62, 62),
                                //         size: 20.0,
                                //       ),
                                //     ),
                                //   ),
                                // ),
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