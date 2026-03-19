import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/utilities.dart';
import 'NewPartyPage.dart'; 
import 'package:test1/NewOrderPage.dart'; 
import 'package:test1/database_Module/party_database.dart'; 
import 'package:test1/udhari/SupplierListPage.dart'; // Add this import
import 'package:test1/udhari/AddSupplierPage.dart'; // Add this import
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../database_Module/ObjectBoxService.dart'; 
import 'package:provider/provider.dart';

class PartyListPage extends StatefulWidget {
  const PartyListPage({super.key});

  @override
  State<PartyListPage> createState() => _PartyListPageState();
}

class _PartyListPageState extends State<PartyListPage> with SingleTickerProviderStateMixin {
  List<Parties> _allParties = [];
  List<Parties> _displayList = [];
  
  late Store store = Provider.of<ObjectBoxService>(context, listen: false).store;

  // Tab Controller for Customer/Supplier tabs
  late TabController _tabController = TabController(length: 2, vsync: this); // Declare as late but initialize in initState
  int _selectedTabIndex = 0; // 0 = Customers, 1 = Suppliers

  // Filter State Variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedMainFilter = 'All'; 
  String? _selectedSubFilter; 
  
  final List<String> _mainFilterOptions = [
    'All',
    'Category',
    'Billing Term',
    'Visiting Day'
  ];

  final List<String> _fixedDays = [
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "No Fixed Day"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // Load saved filter preferences
    _loadFilterPreferences().then((_) async {
      _loadPartiesFromObjectBox();
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
        // Clear search when switching tabs
        _searchController.clear();
        _isSearching = false;
      });
    }
  }
  

  // --- PREFERENCES LOGIC ---

  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMainFilter = prefs.getString('party_main_filter') ?? 'All';
      _selectedSubFilter = prefs.getString('party_sub_filter');
    });
  }

  Future<void> _saveFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('party_main_filter', _selectedMainFilter);
    
    if (_selectedSubFilter != null) {
      await prefs.setString('party_sub_filter', _selectedSubFilter!);
    } else {
      await prefs.remove('party_sub_filter');
    }
  }

  // --- DATA LOGIC ---

  Future<void> _resetCompletionStatusIfNeeded() async {
    final box = store.box<Parties>();
    final partiesToUpdate = <Parties>[];
    final allParties = box.getAll();

    final now = DateTime.now();
    final today = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    final startOfBusinessDay = DateTime(today.year, today.month, today.day, 4);

    for (final party in allParties) {
      if (party.isCompleted && party.completionDate != null) {
        if (party.completionDate!.isBefore(startOfBusinessDay)) {
          party.isCompleted = false;
          party.completionDate = null;
          partiesToUpdate.add(party);
        }
      }
    }

    if (partiesToUpdate.isNotEmpty) {
      box.putMany(partiesToUpdate);
      print_log("Reset completion status for ${partiesToUpdate.length} parties.");
    }
  }

  Future<void> _togglePartyCompletion(Parties party) async {
    final box = store.box<Parties>();
    party.isCompleted = !party.isCompleted;
    party.completionDate = party.isCompleted ? DateTime.now() : null;
    box.put(party);
    _applyFilters();
  }

  Future<void> _loadPartiesFromObjectBox() async {
    await _resetCompletionStatusIfNeeded();
    final box = store.box<Parties>();
    final allData = box.getAll();
    setState(() {
      _allParties = allData;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      List<Parties> tempParties;
      if (_selectedMainFilter == 'All') {
        tempParties = List.from(_allParties);
      } else if (_selectedSubFilter == null) {
        tempParties = List.from(_allParties); 
      } else {
        tempParties = _allParties.where((party) {
          switch (_selectedMainFilter) {
            case 'Category':
              return party.category == _selectedSubFilter;
            case 'Billing Term':
              return party.billingterm == _selectedSubFilter;
            case 'Visiting Day':
              return party.visitingday == _selectedSubFilter;
            default:
              return true;
          }
        }).toList();
      }

      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        tempParties = tempParties.where((party) {
          final name = party.customername.toLowerCase();
          final mobile = party.mobilenumber?.toLowerCase() ?? '';
          return name.contains(query) || mobile.contains(query);
        }).toList();
      }

      _displayList = tempParties;
    });
  }

  List<String> _getUniqueValuesFor(String property) {
    Set<String> uniqueValues = {};
    for (var party in _allParties) {
      if (property == 'Category' && party.category != null && party.category!.isNotEmpty) {
        uniqueValues.add(party.category!);
      } else if (property == 'Billing Term' && party.billingterm != null && party.billingterm!.isNotEmpty) {
        uniqueValues.add(party.billingterm!);
      }
    }
    return uniqueValues.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 255, 255, 255),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                cursorColor: const Color.fromARGB(255, 0, 0, 0),
                decoration: const InputDecoration(
                  hintText: 'Search Name or Mobile...',
                  hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
                  border: InputBorder.none,
                ),
                onChanged: (val) => _applyFilters(),
              )
            : const Text('Customers & Suppliers', style: TextStyle(fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'CUSTOMERS', icon: Icon(Icons.people)),
            Tab(text: 'SUPPLIERS', icon: Icon(Icons.business)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _applyFilters();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _selectedTabIndex == 0 
                  ? _loadPartiesFromObjectBox 
                  : null, // Refresh for suppliers handled separately
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          // Customers Tab Content
          Column(
            children: [
              _buildFilterSection(),
              Expanded(
                child: _displayList.isEmpty 
                  ? const Center(child: Text("No customers found matching filter."))
                  : ListView.builder(
                      itemCount: _displayList.length,
                      itemBuilder: (context, index) {
                        final party = _displayList[index];
                        return _partyCard(
                          title: party.customername,
                          subtitle: '${party.mobilenumber}\nBilling Type: ${party.billingtype}\nAdress: ${party.adreess ?? 'N/A'}',
                          billingType: party.billingtype ?? "",
                          isCompleted: party.isCompleted,
                          onEdit: () => _editParty(context, party, party.id),
                          onDelete: () => _deleteParty(context, party.id),
                        );
                      },
                    ),
              ),
            ],
          ),
          
          // Suppliers Tab Content
          const SupplierListPage(),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddPartyPage()),
                  );
                  _loadPartiesFromObjectBox(); 
                },
                child: const Text('ADD CUSTOMER'),
              ),
            )
          : 
          Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.orange,
          ),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddSupplierPage()),
            );

            print_log("new supplier created $result");
              
            if (result == true) {
              print_log("new supplier created");

              if (mounted) {
                // Navigator.pop(context);
                setState(() {});
                
              }
            }
          },
          child: const Text('ADD SUPPLIER', style: TextStyle(color: Colors.white)),
        ),
      ), // Suppliers have their own FAB
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFilterSection() {
    // Only show filter section for customers tab
    if (_selectedTabIndex != 0) return const SizedBox.shrink();

    List<String> subOptions = [];
    if (_selectedMainFilter == 'Visiting Day') {
      subOptions = _fixedDays;
    } else if (_selectedMainFilter == 'Category') {
      subOptions = _getUniqueValuesFor('Category');
    } else if (_selectedMainFilter == 'Billing Term') {
      subOptions = _getUniqueValuesFor('Billing Term');
    }

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildStyledDropdown(
              value: _selectedMainFilter,
              items: _mainFilterOptions,
              onChanged: (val) {
                setState(() {
                  _selectedMainFilter = val!;
                  _selectedSubFilter = null; 
                  _applyFilters();
                  _saveFilterPreferences();
                });
              },
            ),
          ),
          
          if (_selectedMainFilter != 'All') ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _buildStyledDropdown(
                value: _selectedSubFilter,
                hint: "Select $_selectedMainFilter",
                items: subOptions,
                onChanged: (val) {
                  setState(() {
                    _selectedSubFilter = val;
                    _applyFilters();
                    _saveFilterPreferences();
                  });
                },
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? hint,
  }) {
    String? effectiveValue = items.contains(value) ? value : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue, 
          hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 13, color: Colors.grey)) : null,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
          items: items.map((opt) {
            return DropdownMenuItem(value: opt, child: Text(opt));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _partyCard({
    required String title,
    required String subtitle,
    required String billingType,
    required bool isCompleted,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewOrderPage(billingType: billingType, hideadd: 1),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      if (onEdit != null)
                        IconButton(icon: const Icon(Icons.edit, size: 20), color: Colors.blue, onPressed: onEdit),
                      if (onDelete != null)
                        IconButton(icon: const Icon(Icons.delete, size: 20), color: Colors.red, onPressed: onDelete),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.call, size: 20), 
                        color: Colors.green, 
                        onPressed: () {
                          // Add call functionality
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.textsms_sharp, size: 20), 
                        color: Colors.green, 
                        onPressed: () {
                          // Add SMS functionality
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('₹ 0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _togglePartyCompletion(_displayList[_displayList.indexWhere((p) => p.customername == title)]),
                        child: Icon(
                          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isCompleted ? Colors.green : Colors.grey, 
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editParty(BuildContext context, Parties party, int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPartyPage(partyToEdit: party, editIndex: id),
      ),
    ).then((_) => _loadPartiesFromObjectBox());
  }

  Future<void> _deleteParty(BuildContext context, int partyId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Party'),
        content: const Text('Are you sure you want to delete this party?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); 
              try {
                final box = store.box<Parties>();
                bool success = box.remove(partyId);
                if (success) {
                  _loadPartiesFromObjectBox();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Party deleted successfully')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting party: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}