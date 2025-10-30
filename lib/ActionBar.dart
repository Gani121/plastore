import 'package:flutter/material.dart';
import 'package:test1/NewOrderPage.dart';
import './cartprovier/cartProvider.dart';

class ActionBar extends StatelessWidget {
  final List<dynamic> cart;
  final int total;
  final VoidCallback onDetailsPressed;
  final VoidCallback onKotPressed;
  final VoidCallback onSavePressed;
  final VoidCallback onAddPressed; // 🆕 Callback for the new button
  final int? tableno;             // 🆕 Made nullable to represent "no table"
  final String? mode;

  const ActionBar({
    Key? key,
    required this.cart,
    required this.total,
    required this.onDetailsPressed,
    required this.onKotPressed,
    required this.onSavePressed,
    required this.onAddPressed, // 🆕 Added required callback
    this.tableno,              // 🆕 No longer required
    this.mode, 
  }) : super(key: key);




  @override
  Widget build(BuildContext context) {
    bool isCartNotEmpty = cart.isNotEmpty && total > 0;

    return BottomAppBar(
      color: Colors.grey[300],
      elevation: 0, // No shadow
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      // 🔽--- Conditional Logic Starts Here ---🔽
      child: (tableno != null)
          // IF table number exists, show the ADD button
          ? Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add),
                label: const Text('ADD Items'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          // ELSE, show the original three buttons
          : Padding( 
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: (mode != null)
                        ? ElevatedButton(
                          onPressed: isCartNotEmpty
                              ? () {
                                  // ✅ POP THE PAGE AND RETURN THE FINAL CART AS THE RESULT
                                  Navigator.pop(context, cart);
                                }
                              : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCartNotEmpty ? Colors.green : Colors.grey[400],
                              foregroundColor: isCartNotEmpty ? Colors.white : Colors.grey[700],
                              disabledBackgroundColor: Colors.grey[400],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              "ADD ITEMS (₹ ${total.toStringAsFixed(2)})",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : ElevatedButton(
                          onPressed: isCartNotEmpty ? onDetailsPressed : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isCartNotEmpty ? Colors.blue : Colors.grey[400],
                            foregroundColor:
                                isCartNotEmpty ? Colors.white : Colors.grey[700],
                            disabledBackgroundColor: Colors.grey[400],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            "NEXT (₹ ${total.toStringAsFixed(2)})",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}