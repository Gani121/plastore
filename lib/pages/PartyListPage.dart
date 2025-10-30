import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'NewPartyPage.dart';
import 'package:test1/NewOrderPage.dart';

// Define the Party model
class Party {
  final String name;
  final String phone;
  final String billingType;
  final bool isStarred;

  Party({
    required this.name,
    required this.phone,
    required this.billingType,
    required this.isStarred,
  });

  factory Party.fromJson(Map<String, dynamic> json) {
    return Party(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      billingType: json['billingType'] ?? '',
      isStarred: json['isStarred'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'billingType': billingType,
        'isStarred': isStarred,
      };
}

// Main PartyListPage
class PartyListPage extends StatefulWidget {
  const PartyListPage({super.key});

  @override
  State<PartyListPage> createState() => _PartyListPageState();
}

class _PartyListPageState extends State<PartyListPage> {
  List<Party> _partyList = [];

  @override
  void initState() {
    super.initState();
    _loadPartiesFromPrefs();
  }

Future<void> _loadPartiesFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final partyStrings = prefs.getStringList('parties') ?? [];

  setState(() {
    _partyList = partyStrings.map((jsonStr) {
      final map = jsonDecode(jsonStr);
      return Party.fromJson(map);
    }).toList();
  });

  // Debug print
  // for (var party in _partyList) {
  //   debugPrint('Loaded party: ${party.name}, ${party.phone}, ${party.billingType}');
  // }
}

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Party List', style: TextStyle(fontSize: 18)),
             
            ],
          ),
          actions: [
            IconButton(icon: Icon(Icons.search), onPressed: () {}),
            IconButton(icon: Icon(Icons.refresh), onPressed: _loadPartiesFromPrefs),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'PARTIES (${_partyList.length})'),
              Tab(text: 'CATEGORIES'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text('FILTER',
                          style: TextStyle(color: Colors.grey[700])),
                    ),
                  ),
                ],
              ),
            ),
  
Expanded(
  child: ListView.builder(
    itemCount: _partyList.length,
    itemBuilder: (context, index) {
      final party = _partyList[index];
      return _partyCard(
        title: party.name,
        subtitle: '${party.phone}\nBilling Type: ${party.billingType}',
        isStarred: party.isStarred,
        billingType: party.billingType,
        onEdit: () => _editParty(context, party, index),
        onDelete: () => _deleteParty(context, index),
      );
    },
  ),
),


          ]
  ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPartyPage()),
              );
              _loadPartiesFromPrefs(); // refresh list after adding
            },
            child: Text('ADD CUSTOMER/PARTY'),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

Widget _partyCard({
  required String title,
  required String subtitle,
  required String billingType, // New parameter
  bool isStarred = false,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: InkWell(
      onTap: () async {
        // Store billing type in SharedPreferences
        // final prefs = await SharedPreferences.getInstance();
        // await prefs.setString('selectedBillingType', billingType);
        // print('Saved billingType: $billingType');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewOrderPage(billingType:billingType,hideadd:1),
          ),
        ).then((_) async {
          // await prefs.setString('selectedBillingType', 'Regular');
        });


      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    if (onEdit != null)
                      IconButton(
                        icon: Icon(Icons.edit, size: 20),
                        color: Colors.blue,
                        onPressed: onEdit,
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        onPressed: onDelete,
                      ),
                    Icon(
                      isStarred ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.call, size: 20),
                      color: Colors.green,
                      onPressed: () {},
                    ),
                    SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.textsms_sharp, size: 20),
                      color: Colors.green,
                      onPressed: () {},
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('₹ 0',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(width: 6),
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
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


void _editParty(BuildContext context, Party par, int index) async {
  // In your list view where you want to edit a party
final prefs = await SharedPreferences.getInstance();
final partiesJson = prefs.getStringList('parties') ?? [];
final party11 = Party.fromJson(jsonDecode(partiesJson[index]));
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AddPartyPage(
        //partyToEdit: party11,  // This is fine now since party is non-null
        editIndex: index,
      ),
    ),
  ).then((_) => _loadPartiesFromPrefs());
}
Future<void> _deleteParty(BuildContext context, int index) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Party'),
      content: const Text('Are you sure you want to delete this party?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close the dialog first
            
            try {
              // Update local state
              setState(() {
                _partyList.removeAt(index);
              });
              
              // Update SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              final updatedList = _partyList.map((party) => jsonEncode(party.toJson())).toList();
              await prefs.setStringList('parties', updatedList);
              
              // Show confirmation
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Party deleted successfully')),
              );
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
}
