import 'package:flutter/material.dart';
import 'add_item_page.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'item_ledger_page.dart';
import 'dart:io';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../database_Module/menu_item.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:provider/provider.dart';
import '../theme_setting/theme_provider.dart';
import 'package:test1/l10n/app_localizations.dart';
import '../utilities.dart';

class InventoryPage extends StatefulWidget {
  //final Store store;

  const InventoryPage({super.key});

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final Box<MenuItem> _menuItemBox;
  List<MenuItem> _items = [];
  List<MenuItem> _filteredItems = []; // To hold search results
  final TextEditingController _searchController = TextEditingController();
  // Replace ScrollController with ItemScrollController and ItemPositionsListener
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  bool _isSearching = false;

  // For the alphabetical scrollbar
  final Map<String, int> _alphabetIndexMap = {};
  final List<String> _alphabets = [];
  String _currentAlphabet = '';
  int? totalItems;

  @override
  void initState() {
    super.initState();
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _menuItemBox = store.box<MenuItem>();
    _searchController.addListener(_filterItems);
    // Add a listener to update the active alphabet while scrolling
    _itemPositionsListener.itemPositions.addListener(_onScroll);
    // Load items after the first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItems());
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = _menuItemBox.getAll();
    // Sort items alphabetically by name (case-insensitive)
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _items = items;
      totalItems = items.length;
      _filterItems(); // This will also update the alphabet index
    });
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems =_items.where((item) => item.name.toLowerCase().contains(query)).toList();
      _updateAlphabetIndex();
    });
  }

  void _updateAlphabetIndex() {
    _alphabetIndexMap.clear();
    _alphabets.clear();
    for (int i = 0; i < _filteredItems.length; i++) {
      // Ensure item name is not empty to prevent errors
      if (_filteredItems[i].name.isNotEmpty) {
        String firstLetter = _filteredItems[i].name[0].toUpperCase();
        if (!_alphabetIndexMap.containsKey(firstLetter)) {
          _alphabetIndexMap[firstLetter] = i;
          _alphabets.add(firstLetter);
        }
      }
    }
    _alphabets.sort(); // Ensure alphabets are in order
  }

  void _onScroll() {
    // Get the index of the first visible item
    final firstVisibleItemIndex = _itemPositionsListener.itemPositions.value
        .where((position) => position.itemLeadingEdge < 1)
        .map((position) => position.index)
        .firstOrNull;

    if (firstVisibleItemIndex != null && firstVisibleItemIndex < _filteredItems.length) {
      // Ensure the name is not empty before accessing its first character
      if (_filteredItems[firstVisibleItemIndex].name.isNotEmpty) {
        final currentFirstLetter = _filteredItems[firstVisibleItemIndex].name[0].toUpperCase();
        if (_currentAlphabet != currentFirstLetter) {
          setState(() => _currentAlphabet = currentFirstLetter);
        }
      }
    }
  }

  void _scrollToIndex(String alphabet) {
    final index = _alphabetIndexMap[alphabet];
    if (index != null) {
      _itemScrollController.jumpTo(index: index,); // duration: const Duration(milliseconds: 100)
    }
  }


    Future<void> _showAdjustStockDialog(BuildContext context, MenuItem item) async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("${AppLocalizations.of(context)!.print} ${item.name}"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.enter_qty_add,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final store = Provider.of<ObjectBoxService>(context, listen: false).store;
                final Box<MenuItem> menuItemBox = store.box<MenuItem>();

                final int addValue = int.tryParse(controller.text) ?? 0;
                if (addValue <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.enter_valid_number)),
                  );
                  return;
                }

                // Update the stock
                int currentStock = item.adjustStock ?? 0;
                item.adjustStock = currentStock + addValue;

                // Save to database
                menuItemBox.put(item);
                print_log("✅ Stock updated in $item");

                Navigator.pop(context); // Close dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ Stock updated to ${item.adjustStock}")),
                );
                // _filteredItems
                setState(() {});
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final themeProvider = Provider.of<ThemeProvider>(context);
    //final box = store.box<YourModel>();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration:  InputDecoration(
                  hintText: '${AppLocalizations.of(context)!.searchItems}...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              )
            :  Text(AppLocalizations.of(context)!.itemList),
        backgroundColor: themeProvider.primaryColor, // Colors.purple.shade700,
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _isSearching = false;
                    });
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            "${AppLocalizations.of(context)!.inventoryHeader} (${_items.length})",
                            style: const TextStyle(color: Colors.purple),
                          ),
                        ),
                      ),
                      //   Expanded(
                      //     child: TextButton(
                      //       onPressed: () {},
                      //       child: const Text(
                      //         "CATEGORIES",
                      //         style: TextStyle(color: Colors.grey),
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          _filteredItems.isEmpty
              ? Center(
                  child: Text(
                    _isSearching
                        ? AppLocalizations.of(context)!.noItemMatch
                        : AppLocalizations.of(context)!.noItemFound,
                  ),
                ) // Use ScrollablePositionedList for precise scrolling
              : ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  itemCount: _filteredItems.length,
                  // Add padding to the right to avoid overlapping with the scrollbar
                  padding: const EdgeInsets.fromLTRB(12, 12, 30, 12),
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    // Determine if a header should be shown for a new letter
                    final bool showHeader = item.name.isNotEmpty && (index == 0 ||
                        // Also check if the previous item's name is not empty before comparing
                        (_filteredItems[index - 1].name.isEmpty ||
                            item.name[0].toUpperCase() !=
                                _filteredItems[index - 1].name[0].toUpperCase()));

                    String safeName = item.name;
                    String fileName = "$safeName.jpeg";
                    String imagePath =
                        "/storage/emulated/0/Android/data/${AppConstants.test_version}/files/pictures/menu_images/$fileName";
                    if (!File(imagePath).existsSync()) {
                      fileName = "$safeName.jpg";
                      imagePath =
                          "/storage/emulated/0/Android/data/${AppConstants.test_version}/files/pictures/menu_images/$fileName";
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              item.name[0].toUpperCase(),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.primaryColor),
                            ),
                          ),
                        GestureDetector(
                          onTap: () {
                            if (_isSearching) {
                              setState(() {
                                _searchController.clear();
                              });
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ItemLedgerPage(item: item, store: store),
                              ),
                            ).then((_) => _loadItems());
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  File(imagePath).existsSync()
                                      ? Image.file(File(imagePath),
                                          width: 60, height: 60, fit: BoxFit.fill)
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.image,
                                              color: Colors.grey),
                                        ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            "${AppLocalizations.of(context)!.barcode}: ${item.barCode ?? 'N/A'}",
                                            style: const TextStyle(fontSize: 12)),
                                        Text("₹ ${item.f_price}",
                                            style: const TextStyle(fontSize: 14)),
                                        Text(
                                            "${AppLocalizations.of(context)!.currentStock}: ${item.adjustStock}",
                                            style: const TextStyle(fontSize: 16)),
                                        const SizedBox(height: 6),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await _showAdjustStockDialog(
                                                context, item);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade600,
                                            minimumSize: const Size(100, 20),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                          ),
                                          child: Text(AppLocalizations.of(context)!
                                              .adjustStock),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check, color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
          // Alphabetical Scrollbar
          if (_alphabets.isNotEmpty && !_isSearching)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 28,
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _alphabets.map((alphabet) {
                      final bool isActive = _currentAlphabet == alphabet;
                      return GestureDetector(
                        onTap: () => _scrollToIndex(alphabet),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            alphabet,
                            style: TextStyle(
                              color: isActive ? Colors.white : themeProvider.primaryColor,
                              fontWeight: FontWeight.bold,
                              backgroundColor: isActive ? themeProvider.primaryColor : Colors.transparent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddItemPage(store: store,totalItems:totalItems)),
          );
          _loadItems(); // Refresh after adding new item
        },
        label: Text(AppLocalizations.of(context)!.newItem),
        icon: const Icon(Icons.add),
        backgroundColor: themeProvider.primaryColor, //Colors.purple.shade700,
      ),
    );
  }
}
