import 'dart:async';
import 'package:flutter/material.dart';
import '../objectbox.g.dart';
import '../billnogenerator/BillCounter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:test1/checkout/CheckoutPage.dart';
import '../cartprovier/cart_provider.dart';
import 'package:provider/provider.dart';
import '../cartprovier/ObjectBoxService.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test1/MenuItemPage.dart';

class DetailPage extends StatefulWidget {
  final List<Map<String, dynamic>>? cart1;
  //final Store objectBox; // ✅ Move this inside the class

  //final Cart? cart;

  late String? mode;

  DetailPage({
    this.cart1,
    // this.objectBox,
    this.mode,
    super.key,
  });

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  //late List<Map<String, dynamic>> cart;
  late Box<BillCounter> billCounterBox;
  int? billNo;

  final _discountPercentController = TextEditingController();
  final _discountAmountController = TextEditingController();
  final _serviceChargeAmountController = TextEditingController();
  final _serviceChargePercentController = TextEditingController();

  final ValueNotifier<double> subtotalNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> discountNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> serviceChargeNotifier = ValueNotifier<double>(0);
  Timer? _debounceTimer;

  // In a StatefulWidget's initState:

  final bool _isBoxReady = false;
  String selectedStyle = "";

  @override
  void initState() {
    super.initState();
    // cart = List.from(widget.cart);
    _calculateSubtotal();
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;

    billCounterBox = store.box<BillCounter>();

    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (widget.mode == "edit") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        cartProvider.setCart(widget.cart1 ?? []);
      });
    }

    //cart = cartProvider.cart;

    // Initialize controllers with listeners
    _discountPercentController.addListener(_onDiscountChanged);
    _discountAmountController.addListener(_onDiscountChanged);
    _serviceChargeAmountController.addListener(_onServiceChargeChanged);
    _serviceChargePercentController.addListener(_onServiceChargeChanged);
  }

  @override
  void dispose() {
    _discountPercentController.dispose();
    _discountAmountController.dispose();
    _serviceChargeAmountController.dispose();
    _serviceChargePercentController.dispose();
    subtotalNotifier.dispose();
    discountNotifier.dispose();
    serviceChargeNotifier.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _calculateSubtotal() {
    //var cart
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cart = cartProvider.cart;
    // if (widget.mode == "edit") {
    //  cart = widget.cart1;
    // } else {

    //    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    //   cart = cartProvider.cart;
    // }

    subtotalNotifier.value = cart.fold(0.0, (sum, item) {
      double price = double.tryParse(item['sellPrice']?.toString() ?? '0') ?? 0;
      double qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
      return sum + (price * qty);
    });
  }

  void _onDiscountChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_discountAmountController.text.isNotEmpty) {
        discountNotifier.value =
            double.tryParse(_discountAmountController.text) ?? 0;
        _discountPercentController.text = '';
      } else if (_discountPercentController.text.isNotEmpty) {
        final percent = double.tryParse(_discountPercentController.text) ?? 0;
        discountNotifier.value = (percent / 100) * subtotalNotifier.value;
      } else {
        discountNotifier.value = 0;
      }
    });
  }

  void _onServiceChargeChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_serviceChargeAmountController.text.isNotEmpty) {
        serviceChargeNotifier.value =
            double.tryParse(_serviceChargeAmountController.text) ?? 0;
        _serviceChargePercentController.text = '';
      } else if (_serviceChargePercentController.text.isNotEmpty) {
        final percent =
            double.tryParse(_serviceChargePercentController.text) ?? 0;
        serviceChargeNotifier.value = (percent / 100) * subtotalNotifier.value;
      } else {
        serviceChargeNotifier.value = 0;
      }
    });
  }

    Future<void> loadSelectedStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStyle = prefs.getString('selectedStyle') ?? "Restaurant Style";
    });

    print("selected style $selectedStyle");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Sale"),
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
                  _buildTextFieldNormal(
                    "Bill No",
                    getCurrentBillNo().toString(),
                  ),
                  _buildTextFieldNormal(
                    "Bill Date",
                    DateFormat('dd/MMM/yyyy').format(DateTime.now()),
                  ),
                  _buildDropdown("Billing Term"),
                  _buildTextFieldNormal("Bill Due Date", ""),
                  _buildTextFieldNormal("Customer/Supplier Name", "Cash Sale"),
                  _buildDropdown("Delivery States & U.T."),
                  const SizedBox(height: 20),
                  const Text(
                    "BILL ITEMS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: () async{
                       // Navigator.pop(context);

                        await loadSelectedStyle();
                      if (selectedStyle == "half-Full View") {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => MenuItemPage()),
  );
}

                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text("ADD MORE ITEMS"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildItemCards(),
                  const SizedBox(height: 20),
                  _buildAdjustmentInputs(),
                ],
              ),
            ),
          ),
          _BottomBar(
            subtotalNotifier: subtotalNotifier,
            discountNotifier: discountNotifier,
            serviceChargeNotifier: serviceChargeNotifier,
            cart: Provider.of<CartProvider>(context).cart,
          ),
        ],
      ),
    );
  }

  int getCurrentBillNo() {
    BillCounter? counter = billCounterBox.get(1);
    return counter?.lastBillNo ?? 1;
  }

  int getNextBillNo() {
    final existing = billCounterBox.getAll();

    BillCounter counter;

    if (existing.isEmpty) {
      // First bill, start with 1
      counter = BillCounter(lastBillNo: 1);
      billCounterBox.put(counter);
      return 1;
    } else {
      counter = existing.first;
      counter.lastBillNo += 1;
      billCounterBox.put(counter);
      return counter.lastBillNo;
    }
  }

  Widget _buildItemCards() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cart = cartProvider.cart;
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: cart.asMap().entries.map((entry) {
            final index = entry.key;
            return ItemCard(
              key: ValueKey('item_$index'),
              index: index,
              onChanged: _calculateSubtotal,
              onDelete: () => _deleteItem(index),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _deleteItem(int index) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cart = cartProvider.cart;
    cartProvider.removeItem(index);
    setState(() {
      //cart.removeAt(index);
      _calculateSubtotal();
    });
  }

  Widget _buildAdjustmentInputs() {
    return Column(
      children: [
        _buildTextField(
          label: "Discount in %",
          controller: _discountPercentController,
        ),
        _buildTextField(
          label: "Discount in ₹",
          controller: _discountAmountController,
        ),
        _buildTextField(
          label: "Service Charge in ₹",
          controller: _serviceChargeAmountController,
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: "Service Charge in %",
          controller: _serviceChargePercentController,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
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
}

class ItemCard extends StatefulWidget {
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
  _ItemCardState createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  late TextEditingController _priceController;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final item = cartProvider.cart[widget.index];

    _priceController = TextEditingController(
      text: item['sellPrice'].toString(),
    );
    _qtyController = TextEditingController(text: item['qty'].toString());

    _priceController.addListener(() => _onPriceChanged(cartProvider));
    _qtyController.addListener(() => _onQtyChanged(cartProvider));
  }

  void _onPriceChanged(CartProvider provider) {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    provider.updatePrice(widget.index, price);
    widget.onChanged();
  }

  void _onQtyChanged(CartProvider provider) {
    final qty = int.tryParse(_qtyController.text) ?? 1;
    provider.updateQty(widget.index, qty);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CartProvider>(context);
    if (widget.index >= provider.cart.length) {
      return const SizedBox(); // or handle gracefully
    }

    final item = provider.cart[widget.index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            //offset: const Offset(0, 4),
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
                      item['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildIconButton(Icons.edit),
                  const SizedBox(width: 6),
                  _buildIconButton(Icons.delete, onPressed: widget.onDelete),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildInputContainer(
                  label: "Price",
                  controller: _priceController,
                  onChanged: (val) {
                    final price = double.tryParse(val);
                    if (price != null) {
                      provider.updatePrice(widget.index, price);
                    }
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInputContainer(
                  label: "Qty",
                  controller: _qtyController,
                  onChanged: (val) {
                    final qty = int.tryParse(val);
                    if (qty != null) {
                      provider.updateQty(widget.index, qty);
                    }
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   final item = Provider.of<CartProvider>(context).cart[widget.index];

  //   return ListTile(
  //     title: Text(item['name']),
  //     subtitle: Row(
  //       children: [
  //         SizedBox(
  //           width: 60,
  //           child: TextField(
  //             controller: _qtyController,
  //             decoration: InputDecoration(labelText: "Qty"),
  //             keyboardType: TextInputType.number,
  //           ),
  //         ),
  //         SizedBox(width: 10),
  //         SizedBox(
  //           width: 80,
  //           child: TextField(
  //             controller: _priceController,
  //             decoration: InputDecoration(labelText: "Price"),
  //             keyboardType: TextInputType.number,
  //           ),
  //         ),
  //       ],
  //     ),
  //     trailing: IconButton(
  //       icon: Icon(Icons.delete),
  //       onPressed: widget.onDelete,
  //     ),
  //   );
  // }

  @override
  void dispose() {
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }
}

// class _ItemCardState extends State<ItemCard> {
//   // late final TextEditingController _priceController;
//   // late final TextEditingController _qtyController;

// late List<Map<String, dynamic>> item; // ✅ Declare items
// late final TextEditingController _priceController;
//   late final TextEditingController _qtyController;
//   Timer? _debounceTimer;

//   @override
//   void initState() {
//     super.initState();
//     _priceController = TextEditingController(text: widget.item['sellPrice'].toString());
//     _qtyController = TextEditingController(text: widget.item['qty'].toString());

//     // Add listeners to both controllers
//     _priceController.addListener(_onPriceChanged);
//     _qtyController.addListener(_onQtyChanged);

//   final cartProvider = Provider.of<CartProvider>(context, listen: false);
//     final cart = cartProvider.cart;

//     item = List<Map<String, dynamic>>.from(cart); // ✅ Copy the cart into items

//   }

//   @override
//   void dispose() {
//     _priceController.dispose();
//     _qtyController.dispose();
//     _debounceTimer?.cancel();
//     super.dispose();
//   }

//   void _onPriceChanged() {

//     if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

//     _debounceTimer = Timer(const Duration(milliseconds: 300), () {
//       if (_priceController.text.isNotEmpty) {
//         widget.item['sellPrice'] = (_priceController.text) ?? widget.item['sellPrice'];
//         widget.onChanged();

//       }
//     });

//   }

//   void _onQtyChanged() {
//     if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

//     _debounceTimer = Timer(const Duration(milliseconds: 300), () {
//       if (_qtyController.text.isNotEmpty) {
//         widget.item['qty'] = int.tryParse(_qtyController.text) ?? widget.item['qty'];
//         widget.onChanged();
//       }
//     });
//   }

//   //final _discountPercentController = TextEditingController();
//   // @override
//   // void initState() {
//   //   super.initState();
//   //   _priceController = TextEditingController(text: widget.item['sellPrice'].toString());
//   //   _qtyController = TextEditingController(text: widget.item['qty'].toString());
//   // }

//   // @override
//   // void dispose() {
//   //   _priceController.dispose();
//   //   _qtyController.dispose();
//   //   super.dispose();
//   // }

// @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade50,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 4,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(widget.item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 4),
//                   ],
//                 ),
//               ),
//               Row(
//                 children: [
//                   _buildIconButton(Icons.edit),
//                   const SizedBox(width: 6),
//                   _buildIconButton(Icons.delete, onPressed: widget.onDelete)
//                 ],
//               ),
//             ],
//           ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: _buildInputContainer(
//                   label: "Price",
//                   controller: _priceController,
//                   otherController: _qtyController,
//                   onChanged: (val) {
//                     widget.item['sellPrice'] = double.tryParse(val) ?? widget.item['sellPrice'];
//                     widget.onChanged();
//                   },
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _buildInputContainer(
//                   label: "Qty",
//                   controller: _qtyController,
//                   otherController: _priceController,
//                   onChanged: (val) {
//                     widget.item['qty'] = int.tryParse(val) ?? widget.item['qty'];
//                     widget.onChanged();
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

Widget _buildInputContainer({
  required String label,
  required TextEditingController controller,
  required Function(String) onChanged,
}) {
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
            onChanged: (value) {
              onChanged(value);
            },
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

  const _BottomBar({
    required this.subtotalNotifier,
    required this.discountNotifier,
    required this.serviceChargeNotifier,
    required this.cart,
  });

  @override
  __BottomBarState createState() => __BottomBarState();
}

class __BottomBarState extends State<_BottomBar> {
  String? _selectedPayment; // Add state variable for payment selection

  @override
  Widget build(BuildContext context) {
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
                  final total = (subtotal + serviceCharge - discount).clamp(
                    0,
                    double.infinity,
                  );

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text("Total: ₹${total.toStringAsFixed(2)}"),
                          const Checkbox(value: true, onChanged: null),
                          Text("Received: ₹${total.toStringAsFixed(2)}"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Row(
                      //   children: [
                      //     _buildPaymentButton("UPI"),
                      //     const SizedBox(width: 6),
                      //     _buildPaymentButton("Cash"),
                      //     const SizedBox(width: 6),
                      //     _buildPaymentButton("Card"),
                      //   ],
                      // ),
                      // const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildActionButton("DETAILS")),
                          const SizedBox(width: 6),
                          Expanded(child: _buildActionButton("KOT")),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CheckoutPage(widget.cart, total),
                                  ),
                                );
                              },
                              child: Text(
                                "NEXT (₹${total.toStringAsFixed(2)})",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPaymentButton(String text, {bool selected = false}) {
    // Use the state variable to determine selection
    final isSelected = _selectedPayment == text || selected;
    
    return SizedBox(
      width: 100,
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue.shade100 : Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setState(() {
            _selectedPayment = text;
          });
        },
        child: Text(text, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildActionButton(String text) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        side: const BorderSide(color: Colors.grey),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {},
      child: Text(text),
    );
  }
}