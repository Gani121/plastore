import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../objectbox.g.dart';
import '../billnogenerator/BillCounter.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../cartprovier/cart_provider.dart';
import 'package:provider/provider.dart';
import '../cartprovier/ObjectBoxService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../NewOrderPage.dart';
import 'package:test1/MenuItemPage.dart' as gk;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:test1/l10n/app_localizations.dart';
import '../udhari/AddCustomerPage.dart';
import '../udhari/udharicustomer.dart';

class DetailPage extends StatefulWidget {
  final List<Map<String, dynamic>>? cart1;
  final String? mode;
  final Map<String, dynamic>? transaction;
  final Map<String, dynamic>? table;
  final int? hideadd;

  DetailPage({this.cart1,this.mode,this.transaction,this.table,this.hideadd,super.key,});

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  //late List<Map<String, dynamic>> cart;
  late Box<BillCounter> billCounterBox;
  late int billNo = 0;
  late final TextEditingController _customerNameController = TextEditingController();
  late final TextEditingController _customerAdreessController = TextEditingController();
  late final TextEditingController _discountPercentController = TextEditingController();
  late final TextEditingController _discountAmountController = TextEditingController();
  late final TextEditingController _serviceChargeAmountController = TextEditingController();
  late final TextEditingController _serviceChargePercentController = TextEditingController();
  late final TextEditingController _mobileNo = TextEditingController();
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _billNoController = TextEditingController();

  String someValueFromServer = "";
  String _name111 = '';
  double _discountPercentController1 = 0;
  double _discountAmountController1 = 0;
  double _serviceChargeAmountController1 = 0;
  double _serviceChargePercentController1 = 0;
  String _mobileNo1 = '';
  String adreess1 = '';

  late ValueNotifier<double> subtotalNotifier = ValueNotifier<double>(0);
  late ValueNotifier<double> discountNotifier = ValueNotifier<double>(0);
  late ValueNotifier<double> serviceChargeNotifier = ValueNotifier<double>(0);
    // Controller for the mobile number TextField
  final TextEditingController _mobileNoController = TextEditingController();

  // A map to hold transaction data, similar to your original code
  final Map<String, dynamic> _transaction = {'mobileNo': ''};

  Timer? _debounceTimer;
  final bool _isBoxReady = false;
  String selectedStyle = "List Style Half Full";
  late Map<String, dynamic> transaction = {};
  List<Map<String, dynamic>> existingcart = [];
  late bool industry;
  
  

  @override
  void initState() {
    super.initState();
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    billCounterBox = store.box<BillCounter>();
    loadSelectedStyle();
    existingcart = (widget.cart1 ?? []).map((item) => Map<String, dynamic>.from(item)).toList();

    // debugPrint("oldCartMap.containsKey(key) ${existingcart}");
    void _updateCalculations() {
    if (!mounted) return;
      // debugPrint(" widget.hideadd == null ${widget.table} ${widget.table == null } ${widget.table == null && widget.hideadd == null} ${widget.hideadd != null} ${widget.hideadd}");
      // This function will now be the single source of truth for all calculations
      // It should handle subtotal, apply discounts, apply service charges, and update the final total.
      // I'm assuming the logic is inside your listeners, so we can just call one of them
      // or a new, dedicated function.
      _calculateSubtotal(); // This likely updates the subtotal state
      _onDiscountChanged(); // This should now use the correct subtotal
      _onServiceChargeChanged(); // This will add the service charge on top
    }
    // Initialize controllers with listeners
    _discountPercentController.addListener(_onDiscountChanged);
    _discountAmountController.addListener(_onDiscountChanged);
    _serviceChargeAmountController.addListener(_onServiceChargeChanged);
    _serviceChargePercentController.addListener(_onServiceChargeChanged);

    // Use a single post-frame callback to set up the initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // 1. First, load the cart so the subtotal is available
      if (widget.mode == "edit") {
        cartProvider.cart.clear();
        debugPrint("set cart to the provider to the in neworderpage ${cartProvider.cart.isEmpty} ${cartProvider.cart}");
        cartProvider.setCart(widget.cart1 ?? []);
        debugPrint("set cart to the provider to the in neworderpage ${cartProvider.cart.isEmpty} ${cartProvider.cart}");
        // debugPrint("cartProvider.cart in editbill ${cartProvider.cart}");
        debugPrint("transaction in editbill ${widget.transaction}");
        if (widget.transaction != null && (widget.transaction ?? {}).isNotEmpty) {
          transaction = widget.transaction ?? {};

          // 2. Now, populate all the text fields
          final discount = (transaction['discount'] as num?)?.toDouble() ?? 0.0;
          fetchData(_discountAmountController, discount.toStringAsFixed(2));
          
          Future.delayed(const Duration(milliseconds: 1000), () {
            final serviceCharge = (transaction['serviceCharge'] as num?)?.toDouble() ?? 0.0;
            fetchData(_serviceChargeAmountController, serviceCharge.toStringAsFixed(2));
          });

          billNo = transaction['billNo'] ?? 0;
          fetchData(_billNoController, billNo.toString());

          final customerName = transaction['customerName'] ?? '';
          fetchData(_customerNameController, customerName);

          final customeradreess = transaction['reserved'] ?? '';
          fetchData(_customerAdreessController, customeradreess);

          final mobileNo = transaction['mobileNo'] ?? '';
          fetchData(_mobileNoController, mobileNo);

        } else {
          // Logic for a new bill
          billNo = getNextBillNo();
          fetchData(_billNoController, billNo.toString());
          transaction['billNo'] = billNo;
        }
      } else {
          // Logic for a new bill
          billNo = getNextBillNo();
          fetchData(_billNoController, billNo.toString());
          transaction['billNo'] = billNo;
        }

      // 3. ✅ Finally, run the complete calculation once everything is loaded.
      _updateCalculations();
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerAdreessController.dispose();
    _discountPercentController.dispose();
    _discountAmountController.dispose();
    _serviceChargeAmountController.dispose();
    _serviceChargePercentController.dispose();
    subtotalNotifier.dispose();
    discountNotifier.dispose();
    serviceChargeNotifier.dispose();
    _debounceTimer?.cancel();
    _billNoController.dispose(); // ✅ Dispose it
    super.dispose();
  }

  void fetchData(TextEditingController key, String value) {
    // Simulate fetching data from an API or database
    Future.delayed(const Duration(milliseconds: 4), () {
      setState(() {
        someValueFromServer = value; // New value received
        // 3. Update the controller's text. The UI will update automatically.
        key.text = someValueFromServer; 
        debugPrint("Controller text set to: ${key.text}");
      });
    });
  }

  /// Fetches the current bill counter, increments it, saves it, and returns the new bill number.
  int getNextBillNo() {
    // 2. Find the existing counter object. There should only be one.
    BillCounter counter;
    final existingCounters = billCounterBox.getAll();
    debugPrint("next bill number ${existingCounters}");
    int billNo = (existingCounters.isEmpty) ? 1 : existingCounters.first.lastBillNo;
    // if (existingCounters.isEmpty) {
    //   // 3a. If no counter exists (first time), create one starting at 1.
    //   counter = BillCounter(lastBillNo: 1);
    // } else {
    //   // 3b. If a counter exists, get it and increment the number.
     
    //   counter.lastBillNo++;
    // }
    // 5. Return the latest bill number.
    
    // int billNo = (existingCounters.isEmpty) ? 1 : counter.lastBillNo;
    debugPrint("next bill number ${billNo}");
    return billNo;
  }

  void _calculateSubtotal() {
    //var cart
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    // print("subtotalNotifier.value ${cart}");
    subtotalNotifier.value = cartProvider.total.toDouble();
    // print("subtotalNotifier.value ${subtotalNotifier.value}");
  }

  void _onDiscountChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_discountAmountController.text.isNotEmpty) {
        discountNotifier.value =double.tryParse(_discountAmountController.text) ?? 0;
        _discountPercentController.text = '';
      } else if (_discountPercentController.text.isNotEmpty) {
        final percent = double.tryParse(_discountPercentController.text) ?? 0;
        discountNotifier.value = (percent / 100) * subtotalNotifier.value;
      } else {
        discountNotifier.value = 0;
      }
      transaction['discount'] = discountNotifier.value;
    });
  }

  void _onServiceChargeChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_serviceChargeAmountController.text.isNotEmpty) {
        serviceChargeNotifier.value = double.tryParse(_serviceChargeAmountController.text) ?? 0;
        _serviceChargePercentController.text = '';
      } else if (_serviceChargePercentController.text.isNotEmpty) {
        final percent = double.tryParse(_serviceChargePercentController.text) ?? 0;
        serviceChargeNotifier.value = (percent / 100) * subtotalNotifier.value;
      } else {
        serviceChargeNotifier.value = 0;
      }
      transaction['serviceCharge'] = serviceChargeNotifier.value;
    });
  }

  Future<void> loadSelectedStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStyle = prefs.getString('selectedStyle') ?? "List Style Half Full";
      industry = prefs.getString('industry') == "Retail" ?? false;
    });

    print("selected style $selectedStyle");
  }

  void _showNoteDialog(BuildContext context, Map<String, dynamic> item,CartProvider cartProvider) {
  // Controller to manage the text in the dialog's TextField
  // Initialize it with the current note, if one exists
  final TextEditingController _noteController = TextEditingController(text: item['note'] ?? '');

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Add Note for ${item['name']}'),
        content: TextField(
          controller: _noteController,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter KOT note...'),
          maxLines: 3, // Allow for multi-line notes
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () {
              // Get the note from the controller
              String note = _noteController.text;

              // Call your updateNote method
              // Make sure 'id' and 'portion' exist in your 'item' map
              cartProvider.updateNote(
                item['id'],     // Or however you get the item ID
                item['portion'], // Or however you get the portion
                note,
              );

              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}


void addtablecart(CartProvider cartProvider) async {
    debugPrint("PrinterCart ${(cartProvider.cart).runtimeType} ${cartProvider.cart}");
  final prefs = await SharedPreferences.getInstance();
  final key = "table${widget.table!['kot']}";
  final stringcart = json.encode(cartProvider.cart);
  if(stringcart.isNotEmpty){
    await prefs.setString(key, stringcart);
    debugPrint("table is settle addtablecart : $key key ${await prefs.getString(key)}");
  }
}

  Widget _buildItemCards(CartProvider cartProvider) {
    // final cartProvider = Provider.of<CartProvider>(context);
    final cart = cartProvider.cart;
    // debugPrint("cart items _buildItemCards $cart");
    
    // addtablecart(cartProvider);
    
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            if (cart.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Your cart is empty',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else
              ...cart.map((item) {
                final qty = item['qty'] ?? 0;
                final price = item['sellPrice'] ?? 0;
                final portion = item['portion'] ?? 'Full';
                final id = item['id'];
                final name = item['name'];
                final total = item['total'].toString() is double
                    ? item['total'] as double
                    : double.tryParse(item['total']?.toString() ?? '0.0') ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Top Row: Item name + Total price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // This Expanded now holds a Row with the name and the icon
                          Expanded(
                            child: Row(
                              children: [
                                // Use Expanded on the Text so it takes available space
                                Expanded(
                                  child: Text(
                                    item['name'] ?? 'Unknown Item',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Your new Note Icon Button
                                IconButton(
                                  icon: Icon(Icons.note_add_sharp),
                                  iconSize: 20.0, // Smaller icon size
                                  color: (item["note"] == null )? Colors.blueGrey :const Color.fromARGB(255, 0, 17, 255), // Optional: style the icon
                                  padding: EdgeInsets.symmetric(horizontal: 8.0), // Add some spacing
                                  constraints: BoxConstraints(), // Removes default large padding
                                  onPressed: () {
                                    // This function will open the note dialog
                                    _showNoteDialog(context,item,cartProvider);
                                    // cartProvider.updateNote(context, item);
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          // This is your existing price Text
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // 🔹 Bottom Row: Portion + Quantity controls + Delete button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Portion
                          Text(
                            '$portion  ₹',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: TextFormField(
                              textAlign: TextAlign.center,
                              initialValue: (double.tryParse(price.toString()) ?? 0).toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              // onChanged: (val) {
                              //   final newPrice = int.tryParse(val) ?? price.toInt();
                              //   if (newPrice > 0 && newPrice != price.toInt()) {
                              //     cartProvider.updatePricePortion(id, newPrice, portion);
                              //   }
                              // },
                              onFieldSubmitted: (val) {
                                final newPrice = int.tryParse(val) ?? price.toInt();
                                if (newPrice > 0 && newPrice != price.toInt()) {
                                  cartProvider.updatePricePortion(id, newPrice, portion);
                                  addtablecart(cartProvider);
                                } else if( newPrice < 1 || newPrice.toString().isEmpty){
                                    cartProvider.removeFromCart(id, portion);
                                    addtablecart(cartProvider);
                                    setState(() { });
                                  }
                              },
                            ),
                          ),

                          // Quantity controls
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.blueGrey,
                                onPressed: qty > 1
                                    ? () {
                                        cartProvider.updateQuantity(
                                          id,
                                          qty - 1,
                                          price,
                                          name,
                                          portion,
                                        );
                                        addtablecart(cartProvider);
                                        setState(() { });
                                      }
                                    : null,
                              ),
                              SizedBox(
                                width: 35,
                                child: TextFormField(
                                  textAlign: TextAlign.center,
                                  controller: TextEditingController(text: qty.toString()),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  onFieldSubmitted: (val) {
                                      final newQty = int.tryParse(val ?? qty) ?? qty;
                                      if (newQty > 0 && newQty != qty) {
                                        cartProvider.updateQuantity(id, newQty, price, name, portion);
                                        addtablecart(cartProvider);
                                        setState(() { });
                                      } else if( newQty < 1 || newQty.toString().isEmpty){
                                        cartProvider.removeFromCart(id, portion);
                                        addtablecart(cartProvider);
                                        setState(() { });
                                      }
                                      
                                    },
                                      // onSubmitted: (val) {
                                      //   final newQty = int.tryParse(val) ?? qty;
                                      //   if (newQty > 0 && newQty != qty) {
                                      //     cartProvider.updateQuantity(id, newQty, portion);
                                      //   }
                                      // },
                                ),
                              ),
                              // SizedBox(
                              //   width: 40,
                              //   child: TextField(
                              //     textAlign: TextAlign.center,
                              //     controller: TextEditingController(text: qty.toString()),
                              //     keyboardType: TextInputType.number,
                              //     decoration: const InputDecoration(
                              //       isDense: true,
                              //       contentPadding: EdgeInsets.symmetric(vertical: 8),
                              //       border: OutlineInputBorder(),
                              //     ),
                              //     onChanged: (val) {
                              //       final newQty = int.tryParse(val) ?? qty;
                              //       if (newQty > 0 && newQty != qty) {
                              //         cartProvider.updateQuantity(id, newQty, portion);
                              //       }
                              //     },
                              //     // onSubmitted: (val) {
                              //     //   final newQty = int.tryParse(val) ?? qty;
                              //     //   if (newQty > 0 && newQty != qty) {
                              //     //     cartProvider.updateQuantity(id, newQty, portion);
                              //     //   }
                              //     // },
                              //   ),
                              // ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.blueGrey,
                                onPressed: () {
                                  cartProvider.updateQuantity(
                                    id,
                                    qty + 1,
                                    price,
                                    name,
                                    portion,
                                  );
                                  addtablecart(cartProvider);
                                  setState(() { });
                                },
                              ),
                            ],
                          ),

                          // Delete
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Remove Item',
                            onPressed: () => {_deleteItem(id, portion),
                            setState(() { })},
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              
              }).toList(),

            // 🔹 Total Section
            if (cart.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.green[50],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${cartProvider.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }


  void _deleteItem(int index,String portion) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.removeFromCart(index, portion); // Make sure this method exists in your provider
    setState(() { });
    _calculateSubtotal();
    // No need for setState if you're using Provider's notifyListeners
  }

  Widget _buildAdjustmentInputs(CartProvider cartProvider) {
    return Column(
      children: [
        _buildTextField(
          label: "Discount in %",
          controller: _discountPercentController,
          onChanged: (value) {
            setState(() {
              _discountPercentController1 = double.tryParse(value.toString()) ?? 0.0;
            });
          },
        ),
        _buildTextField(
          label: "Discount in ₹",
          controller: _discountAmountController,
          onChanged: (value) {
            setState(() {
              _discountAmountController1 =  double.tryParse(value.toString()) ?? 0;
            });
          },
        ),
        _buildTextField(
          label: "Service Charge in ₹",
          controller: _serviceChargeAmountController,
          onChanged: (value) {
            setState(() {
              _serviceChargeAmountController1 =  double.tryParse(value.toString()) ?? 0;
            });
          },
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: "Service Charge in %",
          controller: _serviceChargePercentController,
          onChanged: (value) {
            setState(() {
              _serviceChargePercentController1 =  double.tryParse(value.toString()) ?? 0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

    Widget _buildTextField_text({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextFieldNormal(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        readOnly: true,
      ),
    );
  }

  Widget _buildDropdown(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isDense: true,
            value: null,
            hint: Text("Select $label"),
            items: [],
            onChanged: (value) {},
          ),
        ),
      ),
    );
  }





  /// In your real app, you would generate this from your actual bill data.
  Future<String> _createBillString(CartProvider cartProvider) async {
    // Example bill number - you can make this dynamic
    final prefs = await SharedPreferences.getInstance();
    String businessName = prefs.getString('businessName') ?? 'Hotel Test';
    String contactPhone = prefs.getString('contactPhone') ?? '';
    String businessAddress = prefs.getString('businessAddress') ?? '';
    String _myUpiId = prefs.getString('upi') ?? '';

    int totalAmount =  (cartProvider.total ?? 0);
    final cartItems = (cartProvider.cart ?? []);
      // Replace these with your actual UPI details.
    final String upiPaymentLink = 'upi://pay?pa=$_myUpiId&am=${totalAmount.toStringAsFixed(2)}&cu=INR';

    // Use a StringBuffer for efficient string building in a loop
    final itemsBuffer = StringBuffer();

    for (var item in cartItems) {
      // Safely access data from the map
      final String name = item['name'] ?? 'Unknown Item';
      final int qty = item['qty'] ?? 0;
      final double total = item['total'] ?? 0.0;

      // Format each line item like: "1 x Coffee - $30.00"
      itemsBuffer.writeln('$qty x $name - ₹ ${total.toStringAsFixed(2)}');
    }

    return 
    '''
      *---------------------------------*
      *$businessName*
      Contact No. - $contactPhone

      *Bill Details*
      -----------------------------------
      *Bill No:* $billNo
      *Total Amount:* ₹ ${totalAmount.toStringAsFixed(2)}
      -----------------------------------
      *Items:*
      ${itemsBuffer.toString().trim()}
      -----------------------------------
      *Click here to pay using UPI:*
      $upiPaymentLink
      -----------------------------------
      Thank you for your business!
      *---------------------------------*
    ''';
    // '''
    //   *Bill Details*
    //   -----------------------------------
    //   *Bill No:* $billNumber
    //   *Total Amount:* \$${totalAmount.toStringAsFixed(2)}
    //   -----------------------------------
    //   *Items:*
    //   ${itemsBuffer.toString().trim()}
    //   -----------------------------------
    //   Thank you for your business!
    //   ''';
  }


  String extractLast10Digits(String phone) {
    // Remove all non-numeric characters
    String digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // If more than 10 digits, take the last 10
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }

    // Otherwise, return as is
    return digitsOnly;
  }


  /// Launches WhatsApp with a pre-filled message.
  Future<void> _shareOnWhatsApp(CartProvider cartProvider) async {
    // 1. Get the mobile number from the controller
    // Note: Ensure the number includes the country code (e.g., +91 for India)
    String mobileNumber = _mobileNoController.text.trim();

    if (mobileNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a mobile number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

     // --- EDITED: LOGIC TO ADD COUNTRY CODE ---
    // This logic prepares the number for the WhatsApp URL.
    // It assumes the target is an Indian mobile number.
    mobileNumber = extractLast10Digits(mobileNumber);
    if (mobileNumber.startsWith('+')) {
        mobileNumber = mobileNumber.substring(1); // Remove '+'
    }

    if (mobileNumber.length == 10) {
        // Standard 10-digit number, prepend India's country code
        mobileNumber = '91$mobileNumber';
    } else if (mobileNumber.length == 11 && mobileNumber.startsWith('0')) {
        // Number starts with a 0, replace it with the country code
        mobileNumber = '91${mobileNumber.substring(1)}';
    }
    
    // 2. Get the bill details string
    String billDetails = await _createBillString(cartProvider);

    // 3. URL-encode the message
    String encodedMessage = Uri.encodeComponent(billDetails);

    // 4. Create the WhatsApp URL
    // The wa.me URL is the recommended universal link for WhatsApp
    Uri whatsappUrl = Uri.parse("https://wa.me/$mobileNumber?text=$encodedMessage");


    // 5. Check if the URL can be launched and launch it
    try {
        if (await canLaunchUrl(whatsappUrl)) {
            await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        } else {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                content: Text('Could not launch WhatsApp. Is it installed?'),
                 backgroundColor: Colors.red,
                ),
            );
        }
    } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
            ),
        );
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





  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    if(cartProvider.cart.isEmpty && widget.table != null){
      cartProvider.loadCartIfEmpty("table${widget.table!['kot']}");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Bill"),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _billNoController, // Use the controller
                      readOnly: true,        // Make it non-editable
                      decoration: InputDecoration(
                        labelText: 'Bill No',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  _buildTextFieldNormal("Bill Date",DateFormat('dd/MMM/yyyy').format(getBusinessDate()),),
                  // _buildDropdown("Billing Term"),
                  // _buildTextFieldNormal("Bill Due Date", ""),
                  // _buildTextFieldNormal("Customer/Supplier Name", "Cash Sale"),
                  // _buildTextFieldNormal("Customer/Supplier Mobile no","0123456789"),
                  Column(
                    children: [



                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Autocomplete<udhariCustomer>(
                          // 1. The Logic: How to find suggestions
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<udhariCustomer>.empty();
                            }

                            // Get the box
                            final store = Provider.of<ObjectBoxService>(context, listen: false).store;
                            final box = store.box<udhariCustomer>();

                            // Query: Find names containing the text (Case Insensitive)
                            final query = box.query(
                              udhariCustomer_.name.contains(textEditingValue.text, caseSensitive: false)
                            ).build();
                            
                            final results = query.find();
                            query.close();
                            
                            return results;
                          },

                          // 2. How to display the selected object as text
                          displayStringForOption: (udhariCustomer option) => option.name,

                          // 3. What happens when the user TAPS a suggestion
                          onSelected: (udhariCustomer selection) {
                            debugPrint('You selected: ${selection.name}');
                            
                            // Update your transaction map and state
                            transaction['customerName'] = selection.name;
                            transaction['mobileNo'] = selection.phone; // Auto-fill phone if available
                            transaction['reserved'] = selection.adreess; // Auto-fill address if available
                            
                            setState(() {
                              _name111 = selection.name;
                              _mobileNo1 = selection.phone; // Update local state variables too
                              adreess1 = selection.adreess ?? "";
                              
                              // If you have controllers for phone/address, update them here too!
                              _mobileNoController.text = selection.phone;
                              _customerAdreessController.text = selection.adreess ?? '';
                            });
                          },

                          // 4. The UI: Ensure it looks exactly like your old TextFormField
                          fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
                            // Note: We use fieldTextEditingController provided by Autocomplete
                            // instead of your _customerNameController.
                            
                            // Sync initial value if needed (e.g. when editing an old bill)
                            if (_customerNameController.text.isNotEmpty && fieldTextEditingController.text.isEmpty) {
                              fieldTextEditingController.text = _customerNameController.text;
                            }

                            return TextFormField(
                              controller: fieldTextEditingController,
                              focusNode: fieldFocusNode,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                labelText: 'Customer/Supplier Name',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.search), // Optional: indicates it is searchable
                              ),
                              onChanged: (value) {
                                // This runs when typing (not selecting)
                                transaction['customerName'] = value;
                                // Update your external controller if you still use it elsewhere
                                _customerNameController.text = value; 
                                setState(() {
                                  _name111 = value;
                                });
                              },
                            );
                          },
                        ),
                      ),

                      
                      // _buildTextField_text(
                      //   label: 'Customer/Supplier Name',
                      //   controller: _customerNameController,
                      //   onChanged: (value) {
                      //     transaction['customerName'] =  value;
                      //     setState(() {
                      //       _name111 = value;
                      //     });
                      //   },
                      // ),
                      _buildTextField_text(
                        label: 'Customer/Supplier Adreess',
                        controller: _customerAdreessController,
                        onChanged: (value) {
                          transaction['reserved'] =  value;
                          setState(() {
                            adreess1 = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Use Expanded to allow the TextField to take up available space
                            Expanded(
                              child: _buildTextField(
                                label: "Customer/Supplier Mobile No",
                                controller: _mobileNoController,
                                onChanged: (value) {
                                  transaction['mobileNo'] =  value;
                                  setState(() {
                                    _transaction['mobileNo'] = value;
                                    _mobileNo1 = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // This is the button you wanted to add
                            ElevatedButton.icon(
                              onPressed:() => _shareOnWhatsApp(cartProvider),
                              icon: const FaIcon(FontAwesomeIcons.whatsapp,
                                                  color: Colors.white,
                                                  size: 20.0,),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, // WhatsApp color
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // _buildDropdown("Delivery States & U.T."),
                  const SizedBox(height: 20),
                  const Text(
                    "BILL ITEMS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if(widget.hideadd == null )
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 0, 164, 5),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.addMoreItems,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold, // Add this line
                          ),
                        ),
                        onPressed: () async {
                          await loadSelectedStyle();
                          
                          if (selectedStyle == "half-Full View") {
                            // Navigate and wait for result
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => gk.MenuItemPage(
                                  cart1: List.from(cartProvider.cart), // Create a copy
                                  mode: widget.mode,
                                ),
                              ),
                            );

                              debugPrint("return cart is $result, type: ${result.runtimeType}");

                            // Handle the returned cart
                            if (result != null && result is List<Map<String, dynamic>>) {
                              // cartProvider.clearCart();
                              cartProvider.setCart(result);
                              _calculateSubtotal();
                            }
                          } else {
                            final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => NewOrderPage(
                                  cart1: List.from(cartProvider.cart),
                                  mode: 'editpj',
                                )),
                              );
                              debugPrint("return cart is $result, type: ${result.runtimeType}");
                            // Handle the returned cart
                            if (result != null && result is List<Map<String, dynamic>>) {
                              // cartProvider.clearCart();
                              // cartProvider.setCart(result);
                              _calculateSubtotal();
                              if (widget.table != null){
                                debugPrint("PrinterCart ${(cartProvider.cart).runtimeType} ${cartProvider.cart}");
                                final prefs = await SharedPreferences.getInstance();
                                final key = "table${widget.table!['kot']}";
                                final stringcart = json.encode(cartProvider.cart);
                                if(stringcart.isNotEmpty){
                                  await prefs.setString(key, stringcart);
                                  debugPrint("table is settle back from neworderpage: $key key ${await prefs.getString(key)}");
                                }
                              }
                            }
                          }
                        },



                        // onPressed: () async{
                        //   await loadSelectedStyle();  // Navigator.pop(context);
                        //   if (selectedStyle == "half-Full View") {
                        //     Navigator.push( context,MaterialPageRoute(builder: (context) => MenuItemPage(cart1: widget.cart1, mode: widget.mode)),);
                        //   }
                        // },
                      ),
                    ),
                  const SizedBox(height: 10),
                  _buildItemCards(cartProvider),
                  const SizedBox(height: 20),
                  _buildAdjustmentInputs(cartProvider),
                ],
              ),
            ),
          ),
          // Use a Consumer for the bottom bar so it updates automatically too
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              // debugPrint("Transaction Data $_name111  ${(_discountAmountController1)} $_discountPercentController1 ${(_serviceChargeAmountController1)} ${(_serviceChargePercentController1)}  ${_mobileNo1}");
              return _BottomBar(
                subtotalNotifier: subtotalNotifier,
                discountNotifier: discountNotifier,
                serviceChargeNotifier: serviceChargeNotifier,
                cart: cartProvider.cart, // Pass the up-to-date cart
                transaction: transaction,
                mode:widget.mode,
                table:widget.table,
                discountAmount: _discountAmountController1,
                discountPercent: _discountPercentController1,
                serviceChargeAmount: _serviceChargeAmountController1,
                serviceChargePercent: _serviceChargePercentController1,
                name: _name111,        // Use .text
                mobileNo: _mobileNo1, // Use .text
                adreess:adreess1,
                billno: billNo,
                cartProvider:cartProvider,
                existingcart:existingcart,
              );
            }
          ),
        ],
      ),
    );
  }

}



class ItemCard extends StatelessWidget {
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const ItemCard({
    required this.index,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (index >= cartProvider.cart.length) {
          return const SizedBox.shrink();
        }

        final item = cartProvider.cart[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Unknown Item', // Use 'name' instead of 'displayName'
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Portion: ${item['portion'] ?? 'Full'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildIconButton(Icons.edit),
                      const SizedBox(width: 6),
                      _buildIconButton(Icons.delete, onPressed: onDelete),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildInputContainer(
                      label: "Price",
                      value: (item['sellPrice'] ?? 0.0).toString(),
                      onChanged: (val) {
                        final price = double.tryParse(val) ?? 0.0;
                        cartProvider.updatePrice(index, price);
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInputContainer(
                      label: "Qty",
                      value: (item['qty'] ?? 0).toString(),
                      onChanged: (val) {
                        final qty = int.tryParse(val) ?? 1;
                        cartProvider.updateQty(index, qty);
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Update the _buildInputContainer method
Widget _buildInputContainer({
  required String label,
  required String value,
  required Function(String) onChanged,
}) {
  final controller = TextEditingController(text: value);
  
  return Container(
    height: 36,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade400),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade400)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.only(bottom: 10),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}



Widget _buildIconButton(IconData icon, {VoidCallback? onPressed}) {
  return Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
    child: IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onPressed, // Update this line
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
  );
}

class _BottomBar extends StatefulWidget {
  final ValueNotifier<double> subtotalNotifier;
  final ValueNotifier<double> discountNotifier;
  final ValueNotifier<double> serviceChargeNotifier;
  final List<Map<String, dynamic>> cart;
  final Map<String, dynamic> transaction;
  final String? mode;
  final Map<String, dynamic>? table;
  final double? discountPercent;
  final double? discountAmount;
  final double? serviceChargeAmount;
  final double? serviceChargePercent;
  final String? mobileNo;
  final String? name;
  final String? adreess;
  final int? billno;
  final CartProvider? cartProvider;
  final List<Map<String, dynamic>> existingcart;

  const _BottomBar({
    required this.subtotalNotifier,
    required this.discountNotifier,
    required this.serviceChargeNotifier,
    required this.cart,
    required this.transaction,
    this.mode,
    this.table,
    this.discountPercent,
    this.discountAmount,
    this.serviceChargeAmount,
    this.serviceChargePercent,
    this.mobileNo,
    this.name,
    this.adreess,
    this.billno,
    this.cartProvider,
    required this.existingcart,
  });

  @override
  __BottomBarState createState() => __BottomBarState();
}

class __BottomBarState extends State<_BottomBar> {
  String? _selectedPayment; // Add state variable for payment selection
  bool _isPrinting = false; 
  bool _isChecked = true;   
  
  

  Future<String?> _showPaymentMethodDialog(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      // Add rounded corners to the top
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // This makes the sheet height fit its content
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // A small "grab handle" for visual flair
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.money_rounded, color: Colors.green.shade600, size: 30),
                title: const Text('Cash', style: TextStyle(fontSize: 16)),
                onTap: () => Navigator.pop(context, 'CASH'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.qr_code_scanner_rounded, color: Colors.deepPurple.shade400, size: 30),
                title: const Text('UPI / QR Code', style: TextStyle(fontSize: 16)),
                onTap: () => Navigator.pop(context, 'UPI'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }


  List<Map<String, dynamic>> getNewKotItems({
    required List<Map<String, dynamic>> oldCart,
    required List<Map<String, dynamic>> newCart,
  }) {
    
    final List<Map<String, dynamic>> kotItems = [];

    // 1. Create a Map of the old cart for fast lookup.
    // The key is a unique identifier: "id-portion"
    // The value is the quantity.
    final Map<String, int> oldCartMap = {};
    for (var item in oldCart) {
      String key = "${item['id']}-${item['portion']}";
      oldCartMap[key] = item['qty'] as int;
    }
    // debugPrint("oldCartMap.containsKey(key) ${oldCart}");
    // debugPrint("oldCartMap.containsKey(key) ${newCart}");
    // 2. Loop through the new cart and compare against the old map.
    for (var newItem in newCart) {
      String key = "${newItem['id']}-${newItem['portion']}";
      int newQty = newItem['qty'] as int;
      
      if (oldCartMap.containsKey(key)) {
        // Item existed before. Check if quantity increased.
        int oldQty = oldCartMap[key]!;
        // debugPrint("oldCartMap.containsKey(key) $newQty > $oldQty ${newQty > oldQty}");
        if (newQty > oldQty) {
          // Quantity increased. Send the difference to the KOT.
          int qtyToSend = newQty - oldQty;
          // debugPrint("oldCartMap.containsKey(key) ${qtyToSend}");

          // Create a copy of the item
          Map<String, dynamic> kotItem = Map.from(newItem);
          
          // Set the quantity to the *difference*
          kotItem['qty'] = qtyToSend;
          
          // Recalculate the total for the KOT
          kotItem['total'] = (kotItem['sellPrice'] as double) * qtyToSend;
          // debugPrint("oldCartMap.containsKey(key) ${kotItem}");
          kotItems.add(kotItem);
        }
        // If newQty <= oldQty, do nothing (item was not added or was removed)
        
      } else {
        // This is a brand new item (key didn't exist in old map).
        // Add the full item as-is.
        kotItems.add(Map.from(newItem));
      }
    }

    return (kotItems.isEmpty) ? oldCart : kotItems;
  }





  udhariCustomer _findOrCreateCustomer(Box<udhariCustomer> customerBox, String name, String phone,String adreess) {
    debugPrint("currentCustomer $name ");

    final query = customerBox.query(udhariCustomer_.name.equals(name.trim())).build();
    udhariCustomer? existingCustomer = query.findFirst();
    query.close(); // Always close your queries

    if (existingCustomer != null) {
      // Customer was found, return them
      debugPrint("currentCustomer Found existing customer: ${existingCustomer.name}");
      return existingCustomer;
    } else {
      // Customer not found, create a new one
      debugPrint("currentCustomer Creating new customer: $name");
      final newCustomer = udhariCustomer(
        name: name.trim(),
        phone: phone.isNotEmpty ? phone.trim() : '',
        adreess: adreess.isNotEmpty ? adreess.trim() : '',
      );
      
      // Save the new customer to the box and return them
      customerBox.put(newCustomer);
      return newCustomer;
    }
  }




  void saveEntry(String name, String phone,String adreess, String amountController, String descriptionController) {
    
    // Get the ObjectBox service and the customer box
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
    final customerBox = objectbox.store.box<udhariCustomer>();

    // This is the logic you wanted:
    // "i want to check the name is exist in the udhariCustomer if not create else assign to currentCustomer"
    final udhariCustomer currentCustomer = _findOrCreateCustomer(customerBox, name, phone, adreess);
    debugPrint("currentCustomer $currentCustomer");

    // Now the rest of your code will work, because 'currentCustomer' is set!
    final amount = double.parse(amountController); // You may want to use double.tryParse for safety
    final description = descriptionController.trim();

    final newTransaction = TransactionUdhari.create(
      amount: amount,
      type: TransactionType.gave,
      date: DateTime.now(),
      description: description.isEmpty ? '' : description,
    );


    debugPrint("currentCustomer $newTransaction");

    // Link the transaction to the customer
    newTransaction.customer.target = currentCustomer;

    // Save the transaction
    objectbox.store.box<TransactionUdhari>().put(newTransaction);
    
    // Save the customer to update their list of transactions
    // (This is from your original code and is correct for updating the relation)
    currentCustomer.transactions.add(newTransaction);
    objectbox.store.box<udhariCustomer>().put(currentCustomer);

    debugPrint("currentCustomer Transaction saved for customer: ${currentCustomer.name}");

    // Send SMS right after saving
    // _sendTransactionSms(currentCustomer, newTransaction);
  }









  @override
  Widget build(BuildContext context) {
    // debugPrint("!_isChecked && (widget.mobileNo ?? "").isEmpty && (widget.name ?? "").isEmpty ${!_isChecked} && ${(widget.mobileNo ?? "").isEmpty} && ${(widget.name ?? "").isEmpty}");
    final bool _forudhari = (!_isChecked && (widget.mobileNo ?? "").isEmpty && (widget.name ?? "").isEmpty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: widget.subtotalNotifier,
        builder: (context, subtotal, _) {
          return ValueListenableBuilder<double>(
            valueListenable: widget.discountNotifier,
            builder: (context, discount, _) {
              return ValueListenableBuilder<double>(
                valueListenable: widget.serviceChargeNotifier,
                builder: (context, serviceCharge, _) {
                  // final total = (cartProvider!.total + serviceCharge - discount).clamp(0,double.infinity,);
                  // debugPrint("Transaction Data to be sent:$total $subtotal + $serviceCharge - $discount ${widget.subtotalNotifier.value} ${widget.serviceChargeNotifier.value} ${widget.discountNotifier.value}");
                  final total = ((widget.cartProvider?.total ?? 0) + serviceCharge - discount).clamp(0,double.infinity,);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text("Total: ₹${total.toStringAsFixed(2)}"),
                          Checkbox(
                            value: _isChecked,
                            onChanged: (bool? newValue) {
                              setState(() {
                                _isChecked = newValue!;
                              });
                            },
                          ),
                          Text("Received: ₹${total.toStringAsFixed(2)}"),
                          if (_forudhari)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0, left: 4.0),
                              child: Wrap(
                                children: [
                                  Text(
                                    "Name and Mobile no is required",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5), // Adjust the value as needed
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                // ✅ 1. Disable the button when printing
                                onPressed: _isPrinting ? null : () async {
                                  List<Map<String, dynamic>> newItemsForKot = getNewKotItems(oldCart: widget.existingcart,newCart: widget.cart,);
                                  
                                  setState(() {
                                    _isPrinting = true;
                                  });
                                  try {
                                     if(widget.table != null && widget.table!['kot'] > 0){
                                        debugPrint("PrinterCart ${widget.table} and widget.transaction ${widget.transaction} newItemsForKot $newItemsForKot");
                                        await printer.printCart(
                                          context: context,
                                          cart1: newItemsForKot,
                                          total: total.toInt(),
                                          mode: "kot",
                                          payment_mode: "CASH",
                                          transactionData : widget.transaction,
                                          kot: widget.table!['kot'],
                                        ).then((value) async {
                                            debugPrint("PrinterCart ${widget.table}");
                                            final prefs = await SharedPreferences.getInstance();
                                            final key = "table${widget.table!['kot']}";
                                            final stringcart = json.encode(widget.cart);
                                            if(stringcart.isNotEmpty){
                                              await prefs.setString(key, stringcart);
                                              debugPrint("table is settle kot: $key key ${await prefs.getString(key)}");
                                            }
                                            Navigator.of(context).pop(context);
                                        });
                                      } else{
                                        debugPrint("PrinterCart ${widget.cart} and widget.transaction ${widget.transaction} ${widget.transaction['id']}");
                                        await printer.printCart(
                                          context: context,
                                          cart1: newItemsForKot,
                                          total: total.toInt(),
                                          mode: "kot",
                                          transactionData : widget.transaction,
                                          payment_mode: (widget.mode == 'edit') ? 'no_${widget.transaction['id']}' : 'KOT',
                                        );
                                      }
                                    
                                  } finally {
                                    // ✅ 4. Stop the loading indicator, even if an error occurs
                                    if (mounted) { // Check if the widget is still in the tree
                                      setState(() {
                                        _isPrinting = false;
                                      });
                                    }
                                  }
                                },
                                // ✅ 3. Show a loading indicator or text based on the state
                                child: _isPrinting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      " KOT",
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                // ✅ 1. Disable the button when printing
                                onPressed: _isPrinting ? null : () async {
                                  setState(() {
                                    _isPrinting = true;
                                  });
                                  final prefs = await SharedPreferences.getInstance();
                                  debugPrint(" ${(widget.table ?? {"kot":1})['kot']} PrinterCart ${widget.cart} and widget.transaction ${widget.transaction} ${widget.transaction['id']}");
                                  try {
                                    if(widget.table != null && (widget.table ?? {"kot":1})['kot'] > 0){
                                      final ttid = prefs.getInt("tt${(widget.table ?? {"kot":1})['kot']}");
                                      debugPrint("PrinterCart ${widget.table}");
                                      final key = "table${widget.table!['kot']}";
                                      final stringcart = json.encode(widget.cart);
                                      if(stringcart.isNotEmpty){
                                        await prefs.setString(key, stringcart);
                                        debugPrint("table is settle print : $key key ${await prefs.getString(key)}");
                                      }
                                      await printer.printCart(context: context,
                                                      cart1: widget.cart,
                                                      total:total.toInt(),
                                                      mode:"print",
                                                      payment_mode: (ttid != null) ? 'print_${widget.transaction['id']}' : 'print',
                                                      transactionData : widget.transaction,
                                                      kot: (widget.table ?? {"kot":1})['kot'],
                                                      );
                                      } else {
                                        debugPrint("PrinterCart ${widget.cart} and transaction ${widget.transaction}");
                                        await printer.printCart(
                                          context: context,
                                          cart1: widget.cart,
                                          total: total.toInt(),
                                          mode: "print",
                                          transactionData : widget.transaction,
                                          payment_mode: (widget.mode == 'edit') ? 'print_${widget.transaction['id']}' : 'print',
                                        );
                                      }
                                    
                                  } finally {
                                    // ✅ 4. Stop the loading indicator, even if an error occurs
                                    if (mounted) { // Check if the widget is still in the tree
                                      setState(() {
                                        _isPrinting = false;
                                      });
                                    }
                                  }
                                },
                                // ✅ 3. Show a loading indicator or text based on the state
                                child: _isPrinting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      "Print",
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                // ✅ 1. Disable the button when printing
                                onPressed: _isPrinting ? null : () async {
                                  // ✅ 2. Start the loading indicator
                                  setState(() {
                                    _isPrinting = true;
                                  });
                                  if(_forudhari){
                                    ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Customer Name and Mobile No is Required"),
                                              // backgroundColor: Colors.red,
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                          return;
                                  }

                                  try {
                                    String? paymentMode;
                                    final existingPaymentMode = widget.transaction['payment_mode'] as String?;

                                    if (existingPaymentMode != null && ['cash', 'upi'].contains(existingPaymentMode.toLowerCase())) {
                                      paymentMode = existingPaymentMode;
                                    } else {
                                      paymentMode = await _showPaymentMethodDialog(context);
                                    }

                                    debugPrint("Transaction Data to be sent: $subtotal + $serviceCharge - $discount ${widget.subtotalNotifier.value} ${widget.serviceChargeNotifier.value} ${widget.discountNotifier.value}");

                                    if (paymentMode != null && (widget.cart).isNotEmpty) {
                                      if(widget.table != null && widget.table!['kot'] > 0){
                                        debugPrint("PrinterCart ${widget.table} and widget.transaction ${widget.transaction}");
                                        await printer.printCart(
                                          context: context,
                                          cart1: widget.cart,
                                          total: total.toInt(),
                                          mode: 'onlySettle',
                                          payment_mode: paymentMode.toUpperCase(),
                                          transactionData : widget.transaction,
                                          kot:widget.table!['kot'],
                                        );

                                      } else{
                                        debugPrint("PrinterCart ${widget.cart} and transaction ${widget.transaction}");
                                        await printer.printCart(
                                          context: context,
                                          cart1: widget.cart,
                                          total: total.toInt(),
                                          mode: "settle1",
                                          payment_mode: (widget.mode == 'edit' && widget.transaction.isNotEmpty) ? '${paymentMode.toUpperCase()}_${widget.transaction['id']}' : paymentMode.toUpperCase(),
                                          transactionData : widget.transaction,
                                        );
                                      }
                                    } else {
                                      debugPrint("Payment selection canceled OR cart is empty");
                                    }

                                    String descriptionController = "Bill No- ${widget.billno} on date- ${DateTime.now()}";
                                    debugPrint("currentCustomer $descriptionController");
                                    saveEntry(widget.name ?? "" , widget.mobileNo ?? "" ,widget.adreess ?? "", total.toStringAsFixed(0), descriptionController);
                                    
                                  } finally {
                                    if (mounted) { 
                                      setState(() {
                                        _isPrinting = false;
                                      });
                                    }
                                  }
                                },
                                // ✅ 3. Show a loading indicator or text based on the state
                                child: _isPrinting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      (widget.table != null && widget.table!['kot'] > 0) ? "Settle" : "Print/Settle",
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                            const SizedBox(width: 6),
                            if (widget.table != null)
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  // ✅ 1. Disable the button when printing
                                  onPressed: _isPrinting ? null : () async {
                                    // ✅ 2. Start the loading indicator
                                    setState(() {
                                      _isPrinting = true;
                                    });

                                    try {
                                    if(widget.table != null && widget.table!['kot'] > 0){
                                        debugPrint("PrinterCart ${widget.table}");
                                        final prefs = await SharedPreferences.getInstance();
                                        final key = "table${widget.table!['kot']}";
                                        final stringcart = json.encode(widget.cart);
                                        if(stringcart.isNotEmpty){
                                          await prefs.setString(key, stringcart);
                                          debugPrint("table is settle add : $key key ${await prefs.getString(key)}");
                                        }
                                        Navigator.of(context).pop(context);
                                      }
                                      
                                    } finally {
                                      if (mounted) { 
                                        setState(() {
                                          _isPrinting = false;
                                        });
                                      }
                                    }
                                  },
                                  // ✅ 3. Show a loading indicator or text based on the state
                                  child: _isPrinting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        "ADD",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      )

                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Widget _buildPaymentButton(String text, {bool selected = false}) {
  //   // Use the state variable to determine selection
  //   final isSelected = _selectedPayment == text || selected;
    
  //   return SizedBox(
  //     width: 100,
  //     height: 30,
  //     child: ElevatedButton(
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: isSelected ? Colors.blue.shade100 : Colors.white,
  //         foregroundColor: Colors.black,
  //         elevation: 0,
  //         side: const BorderSide(color: Colors.grey),
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //       ),
  //       onPressed: () {
  //         setState(() {
  //           _selectedPayment = text;
  //         });
  //       },
  //       child: Text(text, style: const TextStyle(fontSize: 12)),
  //     ),
  //   );
  // }

  // Widget _buildActionButton(String text) {
  //   return ElevatedButton(
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: Colors.white,
  //       foregroundColor: Colors.black,
  //       side: const BorderSide(color: Colors.grey),
  //       padding: const EdgeInsets.symmetric(vertical: 14),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //     ),
  //     onPressed: () {},
  //     child: Text(text),
  //   );
  // }

}

