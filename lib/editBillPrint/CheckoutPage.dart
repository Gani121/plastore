import 'package:flutter/material.dart';
import 'package:test1/bill_printer.dart';
import 'package:test1/editBillPrint/editBill.dart';

import '../objectbox.g.dart';

//late final Store objectboxStore;

final bill_Printer = BillPrinter();

class CheckoutPage extends StatefulWidget {
  //final Store objectboxStore; // ✅ Move this inside the class

  final List<Map<String, dynamic>>? cart;
  final num total;
  const CheckoutPage(this.cart, this.total, {super.key});

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool received = true;
  String selectedPayment = 'Cash';

  // late final Store objectboxStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout Page"),
        backgroundColor: Colors.deepPurple,
        leading: Icon(Icons.arrow_back),
        actions: [
          Icon(Icons.search),
          SizedBox(width: 8),
          Icon(Icons.qr_code),
          SizedBox(width: 8),
          Icon(Icons.grid_view),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(20),
          child: Padding(padding: const EdgeInsets.only(bottom: 6.0)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Party phone',
                      suffixIcon: Icon(Icons.mic),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'DOB',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Customer/Supplier Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Billing Address',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        subtotalNotifier: ValueNotifier<double>(widget.total.toDouble()),
        discountNotifier: ValueNotifier<double>(10.0),
        serviceChargeNotifier: ValueNotifier<double>(10.0),
        cart: widget.cart ?? [],

        //objectBox: objectboxStore,
      ),
    );
  }
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
                      Row(
                        children: [
                          _buildPaymentButton("UPI"),
                          const SizedBox(width: 6),
                          _buildPaymentButton("Cash"),
                          const SizedBox(width: 6),
                          _buildPaymentButton("Card"),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                bill_Printer.printCart(
                                  context: context,
                                  cart1: widget.cart, // Fixed: use widget.cart
                                  total: total.toInt(), // Fixed: use local total variable
                                  mode: "settle",
                                  payment_mode: _selectedPayment ?? "Cash", // Use selected payment
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