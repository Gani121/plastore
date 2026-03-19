// lib/purchase_order/purchase_order_pdf.dart
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'purchase_order_model.dart';
import 'package:test1/utilities.dart';

class PurchaseOrderPDF {
  static Future<pw.Document> generate(PurchaseOrder order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PURCHASE ORDER',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      order.orderNumber,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: ${order.formattedOrderDate}'),
                    pw.Text('Status: ${order.statusText}'),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),

            // Company & Supplier Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'From:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Your Company Name'),
                      pw.Text('Your Address'),
                      pw.Text('GST: XX-XXXXX'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'To:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(order.supplierName),
                      if (order.supplierAddress != null) pw.Text(order.supplierAddress!),
                      if (order.supplierMobile != null) pw.Text('Mob: ${order.supplierMobile}'),
                      if (order.supplierGst != null) pw.Text('GST: ${order.supplierGst}'),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Order Details
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Order Date:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(order.formattedOrderDate),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Expected Delivery:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(order.formattedExpectedDate),
                    ],
                  ),
                ),
                if (order.dueDate != null)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Due Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(DateFormat('dd/MM/yyyy').format(order.dueDate!)),
                      ],
                    ),
                  ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Items Table
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Item', 'Qty', 'Unit', 'Unit Price', 'Discount', 'Total'],
              data: List<List<String>>.generate(order.items.length, (i) {
                final item = order.items[i];
                return [
                  '${i + 1}',
                  item.name,
                  item.formattedQuantity,
                  item.unit,
                  '₹ ${item.unitPrice.toStringAsFixed(2)}',
                  '${item.discount.toStringAsFixed(1)}%',
                  '₹ ${item.total.toStringAsFixed(2)}',
                ];
              }),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
              },
            ),

            pw.SizedBox(height: 20),

            // Totals
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('Subtotal:', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('₹ ${order.subtotal.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('Tax:', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('₹ ${order.taxAmount.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('Discount:', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('₹ ${order.discountAmount.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('Shipping:', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('₹ ${order.shippingAmount.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('TOTAL:', 
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                            )),
                      ),
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text('₹ ${order.totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                              color: PdfColors.teal,
                            ),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Payment Terms
            if (order.paymentTerms != null) ...[
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Payment Terms:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(order.paymentTerms!),
            ],

            // Terms & Conditions
            if (order.termsAndConditions != null) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'Terms & Conditions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(order.termsAndConditions!),
            ],

            // Notes
            if (order.notes != null) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'Notes:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(order.notes!),
            ],

            pw.SizedBox(height: 30),

            // Signature
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Authorized Signature'),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      width: 200,
                      child: pw.Divider(),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Supplier Signature'),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      width: 200,
                      child: pw.Divider(),
                    ),
                  ],
                ),
              ],
            ),

            // Footer
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'This is a computer generated document. No signature is required.',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    return pdf;
  }
}