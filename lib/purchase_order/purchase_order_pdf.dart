// lib/purchase_order/purchase_order_pdf.dart
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'purchase_order_model.dart';
import 'package:test1/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

String formatAddressWithLineLength(String address, {int wordsPerLine = 4}) {
  if (address.isEmpty) return '';
  
  final words = address.split(" ");
  if (words.length <= wordsPerLine) return address;
  
  final lines = <String>[];
  for (int i = 0; i < words.length; i += wordsPerLine) {
    final end = (i + wordsPerLine) < words.length ? i + wordsPerLine : words.length;
    lines.add(words.sublist(i, end).join(" "));
  }
  
  return lines.join("\n");
}

class PurchaseOrderPDF {
  static Future<pw.Document> generate(PurchaseOrder order) async {
    final pdf = pw.Document();

    final prefs = await SharedPreferences.getInstance();
    
    final imagePath = await prefs.getString('imagePath');
    final businessName = await prefs.getString('businessName') ?? 'RESTAURANT NAME';
    final contactName = await prefs.getString('contactName');
    final contactPhone = await prefs.getString('contactPhone');
    final contactEmail = await prefs.getString('contactEmail');
    
    // Format address
    final businessAddress = await prefs.getString('businessAddress') ?? '';
    final formattedAddress = formatAddressWithLineLength(businessAddress, wordsPerLine: 4);
    final gst = await prefs.getString('gst');
    final upi = await prefs.getString('upi');
    
    // Load logo if exists
    pw.MemoryImage? logoImage;
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (e) {
        print_log('Error loading logo: $e');
      }
    }

    // Calculate totals from items
    double subtotal = 0;
    double totalDiscount = 0;
    double totalTax = 0;
    
    for (var item in order.items) {
      subtotal += item.subtotal;
      totalDiscount += item.discountAmount;
      totalTax += item.taxAmount;
    }
    
    final grandTotal = subtotal - totalDiscount + totalTax + order.shippingAmount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          left: 15,
          top: 20,
          right: 0,
          bottom: 20,
        ),
        build: (pw.Context context) {
          return [
            // Header with Logo
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Logo Section
                if (logoImage != null)
                  pw.Container(
                    width: 80,
                    height: 80,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                
                // Title Section
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
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
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),

            // Company & Supplier Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FROM',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.teal,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          businessName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        if (formattedAddress.isNotEmpty)
                          pw.Text(formattedAddress, style: const pw.TextStyle(fontSize: 10)),
                        if (gst != null && gst.isNotEmpty)
                          pw.Text('GST: $gst', style: const pw.TextStyle(fontSize: 10)),
                        if (contactPhone != null && contactPhone!.isNotEmpty)
                          pw.Text('Phone: $contactPhone', style: const pw.TextStyle(fontSize: 10)),
                        if (contactEmail != null && contactEmail!.isNotEmpty)
                          pw.Text('Email: $contactEmail', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TO',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.teal,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          order.supplierName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        if (order.supplierAddress != null && order.supplierAddress!.isNotEmpty)
                          pw.Text(order.supplierAddress!, style: const pw.TextStyle(fontSize: 10)),
                        if (order.supplierMobile != null && order.supplierMobile!.isNotEmpty)
                          pw.Text('Phone: ${order.supplierMobile}', style: const pw.TextStyle(fontSize: 10)),
                        if (order.supplierGst != null && order.supplierGst!.isNotEmpty)
                          pw.Text('GST: ${order.supplierGst}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // Order Details Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoColumn('Order Date', order.formattedOrderDate),
                  _buildInfoColumn('Expected Delivery', order.formattedExpectedDate),
                  if (order.dueDate != null)
                    _buildInfoColumn('Due Date', DateFormat('dd/MM/yyyy').format(order.dueDate!)),
                  _buildInfoColumn('Status', order.statusText, 
                      color: _getStatusColor(order.status)),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            // Items Table
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  // Table Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.teal100,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: 25, child: pw.Text('#', style: _headerStyle)),
                        pw.Expanded(flex: 3, child: pw.Text('Item', style: _headerStyle)),
                        pw.SizedBox(width: 40, child: pw.Text('Qty', style: _headerStyle, textAlign: pw.TextAlign.right)),
                        pw.SizedBox(width: 60, child: pw.Text('Unit Price', style: _headerStyle, textAlign: pw.TextAlign.right)),
                        pw.SizedBox(width: 50, child: pw.Text('Disc%', style: _headerStyle, textAlign: pw.TextAlign.right)),
                        // --- Added GST Column Header ---
                        pw.SizedBox(width: 60, child: pw.Text('GST', style: _headerStyle, textAlign: pw.TextAlign.right)),
                        // -------------------------------
                        pw.SizedBox(width: 80, child: pw.Text('Total', style: _headerStyle, textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ),
                  
                  // Table Rows
                  ...List.generate(order.items.length, (index) {
                    final item = order.items[index];
                    return pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.grey300),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 25, child: pw.Text('${index + 1}', style: _cellStyle)),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(item.name, style: _cellStyle),
                                if (item.description != null && item.description!.isNotEmpty)
                                  pw.Text(item.description!, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 40, child: pw.Text(item.formattedQuantity, style: _cellStyle, textAlign: pw.TextAlign.right)),
                          pw.SizedBox(width: 60, child: pw.Text('${item.unitPrice.toStringAsFixed(2)}', style: _cellStyle, textAlign: pw.TextAlign.right)),
                          pw.SizedBox(width: 50, child: pw.Text('${item.discount.toStringAsFixed(1)}%', style: _cellStyle, textAlign: pw.TextAlign.right)),
                          // --- Added GST Column Data ---
                          pw.SizedBox(
                            width: 60, 
                            child: pw.Text(
                              '${item.taxAmount.toStringAsFixed(2)}', 
                              style: _cellStyle, 
                              textAlign: pw.TextAlign.right
                            )
                          ),
                          // ------------------------------
                          pw.SizedBox(width: 80, child: pw.Text('${item.total.toStringAsFixed(2)}', style: _cellStyleBold, textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Totals Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Terms and Notes Section - flex 1.2 takes about 55% width
                pw.Expanded(
                  flex: 12, 
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (order.paymentTerms != null && order.paymentTerms!.isNotEmpty) ...[
                        pw.Text('Payment Terms', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(order.paymentTerms!, style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 8),
                      ],
                      if (order.termsAndConditions != null && order.termsAndConditions!.isNotEmpty) ...[
                        pw.Text('Terms & Conditions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(order.termsAndConditions!, style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 8),
                      ],
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(order.notes!, style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ],
                  ),
                ),
                
                pw.SizedBox(width: 10), // Gutter space

                // Totals Card - flex 8 takes about 40-45% width
                pw.Expanded(
                  flex: 8,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _buildTotalRow('Subtotal', subtotal),
                        if (totalDiscount > 0)
                          _buildTotalRow('Discount', -totalDiscount, color: PdfColors.red),
                        if (totalTax > 0)
                          _buildTotalRow('GST', totalTax, color: PdfColors.orange),
                        if (order.shippingAmount > 0)
                          _buildTotalRow('Shipping', order.shippingAmount),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        ),
                        _buildTotalRow('TOTAL', grandTotal, isBold: true, color: PdfColors.teal),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // Signature Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 200,
                      child: pw.Divider(thickness: 1),
                    ),
                    pw.Text('(Authorized Signatory)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  ],
                ),
                if (order.signaturePath != null && order.signaturePath!.isNotEmpty)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Supplier Signature', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 8),
                      pw.Image(
                        pw.MemoryImage(File(order.signaturePath!).readAsBytesSync()),
                        width: 150,
                        height: 50,
                        fit: pw.BoxFit.contain,
                      ),
                    ],
                  ),
              ],
            ),

            pw.SizedBox(height: 10),

            // Footer
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'This is a computer generated document. No signature is required.\n Powerd ORBIPAY by Nextorbitals',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
                // if (upi != null && upi!.isNotEmpty)
                //   pw.Text(
                //     'UPI: $upi',
                //     style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                //   ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }
  
  static pw.Widget _buildInfoColumn(String label, String value, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }
  
  static pw.Widget _buildTotalRow(String label, double amount, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isBold ? 14 : 11,
            ),
          ),
          pw.Text(
            'Rs.  ${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
              fontSize: isBold ? 14 : 11,
            ),
          ),
        ],
      ),
    );
  }
  
  static PdfColor _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft: return PdfColors.grey;
      case PurchaseOrderStatus.sent: return PdfColors.blue;
      case PurchaseOrderStatus.confirmed: return PdfColors.green;
      case PurchaseOrderStatus.received: return PdfColors.purple;
      case PurchaseOrderStatus.cancelled: return PdfColors.red;
    }
  }
}

final _headerStyle = pw.TextStyle(
  fontWeight: pw.FontWeight.bold,
  fontSize: 11,
  color: PdfColors.teal800,
);

final _cellStyle = pw.TextStyle(fontSize: 10);
final _cellStyleBold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);