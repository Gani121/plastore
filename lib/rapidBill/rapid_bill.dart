import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:test1/database_Module/supplier_database.dart';
// import 'package:test1/database_Module/cunsuption.dart';
// import 'package:test1/database_Module/expensDB.dart';
import 'package:test1/database_Module/menu_item.dart';
import 'package:test1/database_Module/tabledata.dart';
import 'package:test1/database_Module/tableCart.dart';
// import 'package:test1/pages/PartyListPage.dart';
// import 'package:test1/inventory/inventory_page.dart';
// import 'package:test1/database_Module/udharicustomer.dart';
import 'package:test1/database_Module/transaction.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import '../objectbox.g.dart';
import 'package:provider/provider.dart';
import 'package:test1/utilities.dart';
import 'package:test1/bill_printer.dart';
import 'package:windows_printer/windows_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/l10n/app_localizations.dart';
import '../NewOrderPage.dart'; // For _navigateToOrderPage
import '../MenuItemPage.dart'; // For _navigateToOrderPage
import '../cartprovier/cart_provider.dart'; // For _navigateToOrderPage
import '../editBillPrint/editBill.dart';

import 'dart:convert';
// import 'dart:io';
final printer = BillPrinter();
class RapidBillPage extends StatefulWidget {
  const RapidBillPage({super.key});

  @override
  State<RapidBillPage> createState() => _RapidBillPageState();
}

class _RapidBillPageState extends State<RapidBillPage> {
  // Controllers and Focus Nodes
  final TextEditingController _tableNoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final FocusNode _tableFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _searchFocus = FocusNode();

  // Add this near your other lists (cart, activeTables, etc.)
  double totalSalesOfTheDay = 5450.0; // Mock initial value

  // Mock Data (Replace with your actual service logic)
  List<Map<String, dynamic>> activeTables = []; // {'section': 'NON-AC', 'tableNumber': '5', 'total': 1200.0},
  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> pendingTables = []; // {'section': 'AC', 'tableNumber': '3', 'total': 890.0},

  late Store _store;
  late List<MenuItem> _menuItemNames;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<MenuItem> _filteredItems = [];
  
  late int _highlightedIndex = 0; // Tracks the arrow-key selectio
  MenuItem? _selectedMenuItem;
  late List<tableCart> allTables;
  Map<String, String> mapsection = {};
  late String tabletotal = "0";
  // Track current grid position: [row, column]
  // Column 0 = QTY, Column 1 = PRICE
  int _selectedRow = 0;
  int _selectedCol = 0;

  // To store focus nodes for each cell dynamically
  Map<String, FocusNode> _tableFocusNodes = {};
  late int todaysTotal = 0;



  @override
  void initState() {
    super.initState();
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _loadMenuItems();
    loadACsectionforACPrice();

    // Start focus on Table Number, similar to your React useEffect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadActiveTables();
      loadPendingTables();
      _tableFocus.requestFocus();
    });
  }

  void loadActiveTables() async {
    final box = _store.box<tableCart>();
    allTables = box.getAll();
    List<Map<String, dynamic>> _activetables = [];
    for(tableCart _tablecart in allTables){
      _activetables.add({'tableNumber': _tablecart.tableNo, 'total': _tablecart.reserved_field ?? 0.0});
    }
    setState(() {
      activeTables = _activetables;
    });
  }

  void loadPendingTables() async {
    final box12 = _store.box<Transaction>();
    final all = box12.getAll();
    final now = DateTime.now();
    print_log("all ${all.length}");
    final filteredTransactions = all.where((tx) {
        final timeString = tx.time;
        return timeString.year == now.year &&
              timeString.month == now.month &&
              timeString.day == now.day;
      }).toList();
    
    int _todaysTotal = 0;
    List<Map<String, dynamic>> _pendingtables = [];
    for(Transaction _transaction in filteredTransactions){
      if((_transaction.status).toLowerCase() == "print"){
        print_log("_transaction.total ${_transaction.total}");
        _pendingtables.add({'tableNumber': _transaction.tableNo, 'total': _transaction.total});
        print_log("_pendingtables $_pendingtables");
      }else if((_transaction.status).contains("settle")){
        _todaysTotal += _transaction.total;
      }
    }
    setState(() {
      pendingTables = _pendingtables;
      todaysTotal = _todaysTotal;
    });
  }

  void loadACsectionforACPrice() async {
    final _tablesList = _store.box<Active_Table_view>();
    final _tablesections = _tablesList.getAll();
    mapsection = {for (var table in _tablesections) table.number.toString(): table.paymentMethod};
  }

  void _loadMenuItems() async {
    try {
      final box = _store.box<MenuItem>();
      _menuItemNames = box.getAll();
    } catch (e) {
      print_log_red('Error loading menu items: $e');
    }
  }

  void _handleHardwareKeys(KeyEvent event) {
    if (event is KeyDownEvent){
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _handleSubmit();
      } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
        _handlePrint();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _handleClear();
        loadActiveTables();
        loadPendingTables();
      } else if (event.logicalKey == LogicalKeyboardKey.delete) {
        _deleteActivetable();
      }
    }
  }

  void _handleSubmit() {
    print("Submitting Bill for Table: ${_tableNoController.text}");
  }

  void _handlePrint() async {
    Map<String, dynamic> transection = {};
    transection['tableNo'] = int.tryParse(_tableNoController.text) ?? 0;
    transection['total'] = (double.tryParse(tabletotal) ?? 0).toInt();
    transection['time'] = AppConstants.businessDate!.toIso8601String();
    transection['udhari'] = false;
    // transection['orderType'] = 
    await printer.printCart(
      context:context,
      cart1:cart,
      total:(double.tryParse(tabletotal) ?? 0).toInt(),
      mode: 'print',
      payment_mode : "print",
      tableNo:int.tryParse(_tableNoController.text) ?? 0,
      transactionData: transection,
      isRapidMode: true,
    );
    _deleteActivetable();
    loadActiveTables();
    loadPendingTables();

  }

  void _handleClear() {
    setState(() {
      cart.clear();
      _tableNoController.clear();
      _searchController.clear();
      _priceController.clear();
      _nameController.clear();
      _qtyController.clear();
      tabletotal = '0';
    });
    _tableFocus.requestFocus();
  }

  void _clearItemSearch() {
    setState(() {
      _searchController.clear();
      _priceController.clear();
      _nameController.clear();
      _qtyController.clear();
      _selectedMenuItem = null;
    });
    _searchFocus.requestFocus();
  }

  void _deleteActivetable({int? tableNo}) {
      // 1. Get the value BEFORE clearing the controller
      final String tableText = _tableNoController.text;
      final int? tableNum = int.tryParse(tableText) ?? tableNo;

      if (tableNum == null) {
        // Optional: Show a message if user tries to delete without a table number
        print_log_red("No valid table number to delete");
        return;
      }

      setState(() {
        // 2. Clear UI list
        cart.clear();
        
        // 3. Remove from the side column list
        // Note: Ensure your activeTables list stores tableNumber as int or String consistently
        activeTables.removeWhere((item) => item['tableNumber'].toString() == tableText);
        
        // 4. Clear the controllers
        _tableNoController.clear();
        _searchController.clear();
        _nameController.clear();
        _qtyController.clear();
        _priceController.clear();
      });

      // 5. Reset focus
      _tableFocus.requestFocus();
      
      // 6. Delete from ObjectBox database so it doesn't come back on refresh
      _deleteFromDatabase(tableNum);
    }

  void _deleteFromDatabase(int tableNo) {
    final box = _store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
    query.remove();
    query.close();
    print_log("Deleted table $tableNo from ObjectBox");
  }


  void _showItemNotFound() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Item not found!"),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
    _searchController.clear();
    _searchFocus.requestFocus();
  }

  void _handleSearchSubmit(String query) {
    if (query == "+") {
      if (cart.isNotEmpty) {
        _selectedRow = 0;
        _selectedCol = 0;
        _getTableFocusNode(0, 0).requestFocus();
      }
      _hideOverlay();
      return;
    }

    if (_filteredItems.isNotEmpty) {
      // Select the first item from the suggestion list
      _selectItem(_filteredItems.first);
    } else {
      // Show "Item Not Found" if the list is empty
      _showItemNotFound();
    }
    _hideOverlay();
  }


  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      _hideOverlay();
      setState(() {
        _filteredItems = [];
      });
      return;
    }

    setState(() {
      // Filter items by name OR code to show in the suggestion list
      _filteredItems = _menuItemNames.where((item) {
        final matchName = item.name.toLowerCase().contains(query.toLowerCase());
        final matchCode = item.itemCode.toString() == query;
        return matchName || matchCode;
      }).toList();

      if (_filteredItems.isNotEmpty) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
  }

  void _showOverlay() {
      _hideOverlay();
      final overlay = Overlay.of(context);

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          width: 450, // Slightly wider for larger text
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 45), // Adjusted offset for tighter fit
            child: Material(
              elevation: 12, // Increased elevation for better visibility
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final isHighlighted = index == _highlightedIndex;

                    return Container(
                      // Reduced height container
                      height: 45, 
                      color: isHighlighted ? Colors.blue.shade100 : Colors.transparent,
                      child: ListTile(
                        dense: true, // Reduces standard height
                        visualDensity: const VisualDensity(vertical: -4, horizontal: -4), // Maximizes space
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: Text(
                          "#${item.itemCode}",
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        title: Text(
                          item.name.toUpperCase(), // Uppercase for rapid reading
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          "₹${item.f_price}",
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        onTap: () => _selectItem(item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(_overlayEntry!);
    }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectItem(MenuItem item) {
    setState(() {
      _selectedMenuItem = item;
      if(_selectedMenuItem!=null){
        _searchController.text = _selectedMenuItem?.itemCode ?? _selectedMenuItem?.id.toString() ?? ""; // Fill Code
        _nameController.text = _selectedMenuItem?.name ?? item.name;            // Fill Name
        _priceController.text = ((mapsection[_tableNoController] ?? "").toLowerCase()).contains('ac') ? _selectedMenuItem!.acSellPrice.toString() : _selectedMenuItem!.f_price.toString(); // Fill Price
        _qtyController.text = "1"; // Default Qty
      }
    });
    _qtyFocus.requestFocus(); // Focus Qty field as requested
    _hideOverlay();
  }


  ////////////////////////////////////////////////   table cart

  void loadcart(int tableNo) async {
    // final key = "tt$tableNo";
    final box = _store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
    tableCart? existingTableCart = await query.findFirst();
    query.close();
    // //debugPrint("✅ Updated cart for table #${existingTableCart!.tableNo} in ObjectBox. existingTableCart ${existingTableCart!.tCart}");
    String? _cart1;
    List<Map<String, dynamic>> existingCart = [];
    if (existingTableCart != null) {
      // 4a. If it exists, update it
      _cart1 = existingTableCart.tCart;
      tabletotal = existingTableCart.reserved_field ?? '0.0';
      
    } else{

      final box12 = _store.box<Transaction>();
      final all = box12.getAll();
      final now = DateTime.now();
      print_log("all ${all.length}");
      final filteredTransactions = all.where((tx) {
          final timeString = tx.time;
          return timeString.year == now.year &&
                timeString.month == now.month &&
                timeString.day == now.day;
        }).toList();
      
      for(Transaction _transaction in filteredTransactions){
        if((_transaction.status).toLowerCase() == "print" && _transaction.tableNo == tableNo){
          _cart1 = _transaction.cartData;
          print_log("_cart1 Transaction $_cart1");
        }
      }
    }
    
    if (_cart1 != null) {
      final decodedList = jsonDecode(_cart1) as List<dynamic>;
      existingCart = decodedList.map((item) => item as Map<String, dynamic>).toList();
    }
    setState(() {
      cart = existingCart;
      print_log("loaded in the tabletotal $tabletotal and cart $cart ");
    });
  }

  void addIteminCart(Map<String, dynamic> citem) async {
    int tableNo = int.tryParse(_tableNoController.text) ?? 0;
    if (tableNo == 0) {
      return;
    }
    final box = _store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
    tableCart? existingTableCart = query.findFirst();
    query.close();

    List<Map<String, dynamic>> existingCart = [];

    if (existingTableCart != null && existingTableCart.tCart != null && existingTableCart.tCart.isNotEmpty) {
      final decodedList = jsonDecode(existingTableCart.tCart) as List<dynamic>;
      
      // CRITICAL: Create a NEW Map for every item to avoid reference issues
      existingCart = decodedList.map((item) => Map<String, dynamic>.from(item)).toList();

      // Find the item by name
      int existingIndex = existingCart.indexWhere((item) => item['name'] == citem['name']);

      if (existingIndex != -1) {
        // 3. Update ONLY the matching item
        int currentQty = int.tryParse(existingCart[existingIndex]['qty'].toString()) ?? 0;
        int newQty = int.tryParse(citem['qty'].toString()) ?? 0;
        double sellPrice = double.tryParse(citem['sellPrice'].toString()) ?? 0.0;

        int updatedQty = currentQty + newQty;
        
        existingCart[existingIndex]['qty'] = updatedQty;
        existingCart[existingIndex]['sellPrice'] = sellPrice;
        existingCart[existingIndex]['total'] = updatedQty * sellPrice;
        
        print_log("Updated quantity for ${citem['name']} from $currentQty to $updatedQty");
      } else {
        // 4. Add as a new row if name not found
        existingCart.add(Map<String, dynamic>.from(citem));
      }
    } else {
      // 5. Create new table record
      existingCart.add(Map<String, dynamic>.from(citem));
      existingTableCart = tableCart(
        syid: ganarateID(), 
        tableNo: tableNo, 
        tCart: ''
      );
    }
    double total = 0;
    for (Map<String, dynamic> item in existingCart) {
      total += item['total'];
    }
      
    // 6. Save back
    existingTableCart.tCart = jsonEncode(existingCart);
    existingTableCart.reserved_field = total.toString();
    box.put(existingTableCart);

    // 7. Update UI with a fresh list reference
    setState(() {
      cart = List<Map<String, dynamic>>.from(existingCart);
    });
  }

  void deleteIteminCart(String item) async {
    int tableNo = int.tryParse(_tableNoController.text) ?? 0;
    if (tableNo == 0) {
      return;
    }
    print_log("updated cart ${item}");
    // final key = "tt$tableNo";
    final box = _store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
    tableCart? existingTableCart = await query.findFirst();
    query.close();
    List<Map<String, dynamic>> existingCart = [];
    String? _cart1;
    if (existingTableCart != null) {
      _cart1 = existingTableCart.tCart;
      if (_cart1 != null) {
        final decodedList = jsonDecode(_cart1) as List<dynamic>;
        existingCart = decodedList.map((item) => item as Map<String, dynamic>).toList();
        existingCart.removeWhere((element) => element['name'] == item);

        int total = 0;
        for (Map<String, dynamic> item in existingCart) {
          total += item['total'] as int;
        }
        existingTableCart.tCart = jsonEncode(existingCart);
        existingTableCart.reserved_field = total.toString();
        print_log("updated cart ${existingTableCart.tCart}");
        box.put(existingTableCart);
        setState(() {
          cart = existingCart;
        });
      }
    }
  }


  /////////  handle table movement
  KeyEventResult _handleTableNavigation(KeyEvent event, int row, int col) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    int nextRow = row;
    int nextCol = col;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      nextRow = (row + 1).clamp(0, cart.length - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      nextRow = (row - 1).clamp(0, cart.length - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      nextCol = 1; // Move to Price
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      nextCol = 0; // Move to Qty
    } else {
      return KeyEventResult.ignored;
    }

    setState(() {
      _selectedRow = nextRow;
      _selectedCol = nextCol;
    });

    _getTableFocusNode(nextRow, nextCol).requestFocus();
    return KeyEventResult.handled;
  }

  FocusNode _getTableFocusNode(int row, int col) {
    String key = "cell_${row}_$col";
    return _tableFocusNodes.putIfAbsent(key, () => FocusNode());
  }


  Future<Map<String, dynamic>> loadRecentTransactions(int tableNo) async {
    final box12 = _store.box<Transaction>();
    final prefs = await SharedPreferences.getInstance();

    // final int tableNo = tableNo;
    final key = "tt$tableNo";
    
    // 1. Get the ID from prefs. It might be null.
    final int? ttid = prefs.getInt(key);
    print_log("ttid $ttid");
    // 2. Check if the ID even exists. If not, return an empty map.
    if (ttid == null || ttid == 0) {
      return {};
    }

    // 3. Try to get the transaction from ObjectBox
    final Transaction? existingTx = box12.get(ttid);
    print_log("existingTx $existingTx");

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
  void _navigateToOrderPage(int tableNo,int total) async {
    // final int tableNo = table.number;
    // final key = "tt$tableNo";
    final prefs = await SharedPreferences.getInstance();
    final box = _store.box<tableCart>();
    final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
    tableCart? existingTableCart = await query.findFirst();
    query.close();
    // //debugPrint("✅ Updated cart for table #${existingTableCart!.tableNo} in ObjectBox. existingTableCart ${existingTableCart!.tCart}");
    String? _cart1;
    if (existingTableCart != null) {
      // 4a. If it exists, update it
      _cart1 = existingTableCart.tCart;
    }
    
    List<Map<String, dynamic>> existingCart = [];
    if (_cart1 != null) {
      final decodedList = jsonDecode(_cart1) as List<dynamic>;
      existingCart = decodedList.map((item) => item as Map<String, dynamic>).toList();
    }

    Map<String, dynamic> tt = await loadRecentTransactions(tableNo);
    print_log("table transections $tt ${tt['status']}");
    if(tt['status'] != null){
      final bool = await prefs.getBool('hide_edit') ?? true;
      if(tt['status'] == 'print' && bool){
        screen_massage(context, "${AppLocalizations.of(context)!.access_denied} Add note for this transaction");
        return;
      }
    }

    try{
      final carttt = await Navigator.push(context, MaterialPageRoute(builder: (context) => 
        DetailPage(
          cart1:existingCart,
          transaction: tt,
          mode:"edit",
          table:{'total':total, 'mode':"onlySettle", 'kot': tableNo},
        )));



      //delete the table cart from the table to make free table when the table is printed or setteled
      final box = _store.box<tableCart>();
      final query = box.query(tableCart_.tableNo.equals(tableNo)).build();
      tableCart? existingTableCart = query.findFirst();
      query.close();
      String? _cart2;
      if (existingTableCart != null) {
        _cart2 = existingTableCart.tCart;
      } else{
        _cart2 = null;
      }
      print_log("✅ updateTableTotal  cart for table #$tableNo in ObjectBox. existingTableCart ${carttt} $_cart2");
      print_log("table ${_cart2.runtimeType}");
      if ((_cart2 ?? '').isEmpty || _cart2 == null) {
        print_log("table updateTableTotal  _cart2 $_cart2");
        _deleteActivetable(tableNo: tableNo);
      }
      /////////////////////////////////////////////////////////////
    } catch (e) {
      print_log_red("Print error: $e");
    } 
    final _cartProvider = Provider.of<CartProvider>(context, listen: false);
    _cartProvider.clearCart();
    print_log("Waiting 2 seconds before refreshing tables...");
    await Future.delayed(Duration(seconds: 1));
    print_log("going to update the tables after settle");
    loadActiveTables();
    loadPendingTables();
  }



  @override
  Widget build(BuildContext context) {
    return KeyboardListener (
      focusNode: FocusNode(),
      onKeyEvent: _handleHardwareKeys,
      child: Scaffold(
        appBar: AppBar(title: const Text("Orbipay Rapid Bill")),
        // --- ADDED FLOATING ACTION BUTTON ---
      // Wrap the FAB in Padding to move it up
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40.0), // Adjust this value to move it higher or lower
        child: FloatingActionButton.extended(
          onPressed: () => {},
          backgroundColor: Colors.black87,
          icon: const Icon(Icons.analytics, color: Colors.greenAccent),
          label: Text(
            "TOTAL SALES: ₹$todaysTotal",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      
      // Ensure the location is set (default is endFloat, which is bottom right)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Column 1: Active Tables ---
                  _buildSideColumn("🔥 Active Tables", activeTables, Colors.orange.shade50),

                  // --- Column 2: Bill Editor (The Main Area) ---
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _tableNoController,
                            focusNode: _tableFocus,
                            decoration: const InputDecoration(labelText: "Table No", border: OutlineInputBorder()),
                            onSubmitted: (_) => {
                              loadcart(int.parse(_tableNoController.text)),
                              _searchFocus.requestFocus()
                              },
                          ),
                          const SizedBox(height: 10),
                          Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Search Item / Code (Normal space)
                            Expanded(
                              flex: 1,
                              child: CompositedTransformTarget(
                                link: _layerLink,
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  decoration: const InputDecoration(
                                    labelText: "Code/Name",
                                    border: OutlineInputBorder(),
                                  ),
                                  // 1. Show suggestions as user types
                                  onChanged: _onSearchChanged, 
                                  
                                  // 2. Select first item or show error on Enter
                                  onSubmitted: _handleSearchSubmit, 
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 2. Item Name (Large space - flex 3)
                            Expanded(
                              flex: 4, // This makes the name field 4x wider than the others
                              child: TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: "Item Name", 
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3. QTY (Small space)
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _qtyController,
                                focusNode: _qtyFocus,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "QTY", 
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                ),
                                onSubmitted: (value) { // Removed =>
                                  if (_selectedMenuItem != null) {
                                    // 1. Parse quantity safely (default to 1 if empty or invalid)
                                    int quantity = int.tryParse(_qtyController.text) ?? 1;
                                    
                                    // 2. Extract price safely
                                    double price = double.tryParse(_priceController.text ?? "0.0") ?? 1.0;

                                    // 3. Construct the cart item
                                    final cartItem = {
                                      'id': _selectedMenuItem?.id,
                                      'name': _selectedMenuItem?.name,
                                      'sellPrice': price,
                                      'qty': quantity, // Use the parsed quantity integer
                                      'portion': 'full',
                                      'total': quantity * price,
                                    };
                                    // 5. Add to cart and shift focus
                                    addIteminCart(cartItem);
                                    
                                    
                                    // 6. Clear inputs for the next entry (Optional but recommended for "Rapid" billing)
                                    _clearItemSearch();
                                    
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 4. Price (Small space)
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _priceController,
                                decoration: const InputDecoration(
                                  labelText: "Price", 
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                          const SizedBox(height: 20),
                          _buildCartTable(int.tryParse(_tableNoController.text) ?? 0),
                          const Spacer(),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),

                  // --- Column 3: Pending Tables ---
                  _buildSideColumn("🕒 Pending Bills", pendingTables, Colors.blue.shade50),
                ],
              ),
            ),
            _buildShortcutBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSideColumn(String title, List<Map<String, dynamic>> data, Color bgColor) {
    return Container(
      width: 250,
      decoration: BoxDecoration(color: bgColor, border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return ListTile(
                  title: Text("${item['section']} - ${item['tableNumber']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  trailing: Text("₹${item['total']}"),
                  onTap: () => {
                      _navigateToOrderPage(item['tableNumber'], (double.tryParse(item['total']) ?? 0).toInt()),
                      print_log("Loading table ${item['tableNumber']}")
                    },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartTable(int tableno) {
    bool isReadOnly = !activeTables.any((table) => table['tableNumber'] == tableno);
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: SingleChildScrollView(
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
            columnWidths: const {
              0: FlexColumnWidth(1),   // CODE
              1: FlexColumnWidth(4),   // ITEM
              2: FlexColumnWidth(1.2), // QTY (slightly wider for input)
              3: FlexColumnWidth(1.5), // PRICE
              4: FlexColumnWidth(1.5), // TOTAL
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Colors.grey),
                children: [
                  _buildHeaderCell('CODE'),
                  _buildHeaderCell('ITEM'),
                  _buildHeaderCell('QTY'),
                  _buildHeaderCell('PRICE'),
                  _buildHeaderCell('TOTAL'),
                ],
              ),
              ...cart.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                // print_log("cart item ${index} $item");
                String itemName = item['name'] ?? "";
                double qty = double.tryParse(item['qty'].toString()) ?? 0;
                double price = double.tryParse(item['sellPrice'].toString()) ?? 0;
                double total = qty * price;

                return TableRow(
                  children: [
                    _buildDataCell(item['id'].toString()), // Keep Code static
                    _buildDataCell(itemName, alignLeft: true), // Keep Name static
                    
                    // EDITABLE QTY
                    // QTY Cell
                    _buildEditableCell(
                      key: ValueKey("qty_${item['id']}_${item['qty']}"),
                      focusNode: _getTableFocusNode(index, 0),
                      onKey: (node, event) => _handleTableNavigation(event, index, 0),
                      initialValue: qty.toStringAsFixed(0),
                      readOnly: isReadOnly,
                      onFieldSubmitted: (val) {
                        if(int.tryParse(val) == 0){
                          deleteIteminCart(itemName);
                          setState(() {
                            cart.removeAt(index);
                          });
                        } else {
                          Map<String, Object?> cartItem = {
                            'id': item['id'],
                            'name': itemName,
                            'sellPrice': price,
                            'qty': val, // Use the parsed quantity integer
                            'portion': 'full',
                            'total': (double.tryParse(val) ?? 0.0) * price,
                          };
                          addIteminCart(cartItem);
                          setState(() => cart[index]['qty'] = val);
                        }
                        _searchFocus.requestFocus(); // Return to search after editing
                      },
                      
                    ),

                    // PRICE Cell
                    _buildEditableCell(
                      key: ValueKey("price_${item['id']}_${item['sellPrice']}"),
                      focusNode: _getTableFocusNode(index, 1),
                      onKey: (node, event) => _handleTableNavigation(event, index, 1),
                      initialValue: price.toStringAsFixed(0),
                      prefix: "₹",
                      readOnly: isReadOnly,
                      onFieldSubmitted: (val) {
                        if(int.tryParse(val) == 0){
                          deleteIteminCart(itemName);
                          setState(() {
                            cart.removeAt(index);
                          });
                        } else {
                          Map<String, Object?> cartItem = {
                            'id': item['id'],
                            'name': itemName,
                            'sellPrice': double.tryParse(val),
                            'qty': qty, // Use the parsed quantity integer
                            'portion': 'full',
                            'total': qty* (double.tryParse(val) ?? 0.0),
                          };
                          addIteminCart(cartItem);
                          setState(() => cart[index]['sellPrice'] = val);
                        }
                        _searchFocus.requestFocus();
                      },
                    ),

                    _buildDataCell("₹${total.toStringAsFixed(0)}"), // Total updates automatically
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Helper for Editable Cells
  Widget _buildEditableCell({
    Key? key,
    required FocusNode focusNode,
    required String initialValue,
    required Function(String) onFieldSubmitted,
    required KeyEventResult Function(FocusNode, KeyEvent) onKey,
    String prefix = "",
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Focus(
        onKeyEvent : onKey,
        child: TextFormField(
          key: key,
          focusNode: focusNode,
          initialValue: initialValue,
          readOnly: readOnly,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: prefix,
            border: InputBorder.none,
            isDense: true,
          ),
          onFieldSubmitted: onFieldSubmitted,
        ),
      ),
    );
  }


  // Helper for Header Cells
  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  // Helper for Data Cells
  Widget _buildDataCell(String text, {bool alignLeft = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(onPressed: _handleSubmit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("SUBMIT (F1)", style: TextStyle(color: Colors.white))),
        ElevatedButton(onPressed: _handleClear, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("CLEAR (DEL)", style: TextStyle(color: Colors.white))),
        ElevatedButton(onPressed: _handlePrint, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text("KOT (F8)", style: TextStyle(color: Colors.white))),
      ],
    );
  }

  Widget _buildShortcutBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.lightBlue.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _ShortcutKey(keyLabel: "F1", desc: "Order"),
          _ShortcutKey(keyLabel: "PgDn", desc: "Print"),
          _ShortcutKey(keyLabel: "PgUp", desc: "Settle"),
          _ShortcutKey(keyLabel: "Del", desc: "Clear"),
        ],
      ),
    );
  }












}

  class _ShortcutKey extends StatelessWidget {
  final String keyLabel;
  final String desc;
  const _ShortcutKey({required this.keyLabel, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
            child: Text(keyLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 4),
          Text(desc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}