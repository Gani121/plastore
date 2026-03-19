// lib/quotation/quotation_pdf.dart
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'quotation_model.dart';


class QuotationPDF {
  static Future<pw.Document> generate(Quotation quotation) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header with logo space
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RESTAURANT NAME',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple,
                      ),
                    ),
                    pw.Text('Your Address Line 1'),
                    pw.Text('City, State - PIN'),
                    pw.Text('GST: XX-XXXXX'),
                    pw.Text('Phone: +91 98765 43210'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'QUOTATION',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('No: ${quotation.quotationNumber}'),
                    pw.Text('Date: ${quotation.formattedQuotationDate}'),
                    pw.Text('Valid Until: ${quotation.formattedValidUntil}'),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),

            // Party Details
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Party Details',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Name: ${quotation.partyName}'),
                            if (quotation.partyMobile != null)
                              pw.Text('Mobile: ${quotation.partyMobile}'),
                            if (quotation.partyEmail != null)
                              pw.Text('Email: ${quotation.partyEmail}'),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (quotation.partyAddress != null)
                              pw.Text('Address: ${quotation.partyAddress}'),
                            if (quotation.partyGst != null)
                              pw.Text('GST: ${quotation.partyGst}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Event Details
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Event Details',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (quotation.eventName != null)
                              pw.Text('Event: ${quotation.eventName}'),
                            if (quotation.eventDate != null)
                              pw.Text('Date: ${quotation.formattedEventDate}'),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (quotation.eventVenue != null)
                              pw.Text('Venue: ${quotation.eventVenue}'),
                            if (quotation.expectedGuests != null)
                              pw.Text('Expected Guests: ${quotation.expectedGuests}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Plates Section
            if (quotation.plates.isNotEmpty) ...[
              pw.Text(
                'Food Packages',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple,
                ),
              ),
              pw.SizedBox(height: 10),
              ...quotation.plates.map((plate) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    color: PdfColors.grey200,
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            plate.name,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: _getPlateColor(plate.type),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            plate.typeName,
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: plate.items.map((item) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Row(
                              children: [
                                // pw.Icon(
                                //   item.included ? Icons.check : Icons.close,
                                //   size: 10,
                                //   color: item.included ? PdfColors.green : PdfColors.red,
                                // ),
                                pw.SizedBox(width: 4),
                                pw.Expanded(
                                  child: pw.Text(
                                    item.name,
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      decoration: item.included 
                                          ? pw.TextDecoration.none 
                                          : pw.TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Qty: ${plate.quantity}'),
                            pw.Text('Price: ${plate.formattedPrice}'),
                            pw.Text(
                              'Total: ${plate.formattedTotal}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (plate.description != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Note: ${plate.description}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                    ),
                  ],
                  pw.SizedBox(height: 12),
                ],
              )),
            ],

            // Banquet Section
            if (quotation.banquetItems.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Banquet Hall',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Hours', 'Rate', 'Total'],
                data: quotation.banquetItems.map((item) => [
                  item.name,
                  '${item.hours} hrs',
                  item.formattedPrice,
                  item.formattedTotal,
                ]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
              
              // Inclusions
              pw.SizedBox(height: 8),
              pw.Text(
                'Inclusions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              ...quotation.banquetItems.expand((item) => item.inclusions).toSet().map((inc) => pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20),
                child: pw.Row(
                  children: [
                    // pw.Icon(Icons.check, size: 10, color: PdfColors.green),
                    pw.SizedBox(width: 4),
                    pw.Text(inc),
                  ],
                ),
              )),
            ],

            // Additional Items
            if (quotation.additionalItems.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Additional Items',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Qty', 'Unit Price', 'Total'],
                data: quotation.additionalItems.map((item) => [
                  item.name,
                  item.formattedQuantity,
                  item.formattedPrice,
                  item.formattedTotal,
                ]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
            ],

            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (quotation.platesSubtotal > 0)
                    _buildSummaryRow('Plates Subtotal', quotation.platesSubtotal),
                  if (quotation.banquetSubtotal > 0)
                    _buildSummaryRow('Banquet Subtotal', quotation.banquetSubtotal),
                  if (quotation.additionalSubtotal > 0)
                    _buildSummaryRow('Additional Subtotal', quotation.additionalSubtotal),
                  pw.SizedBox(height: 4),
                  _buildSummaryRow('Subtotal', 
                      quotation.platesSubtotal + 
                      quotation.banquetSubtotal + 
                      quotation.additionalSubtotal),
                  if (quotation.discountAmount > 0)
                    _buildSummaryRow('Discount', -quotation.discountAmount, isNegative: true),
                  if (quotation.taxAmount > 0)
                    _buildSummaryRow('Tax', quotation.taxAmount),
                  if (quotation.serviceCharge != null)
                    _buildSummaryRow('Service Charge', quotation.serviceCharge!),
                  if (quotation.packagingCharge != null)
                    _buildSummaryRow('Packaging', quotation.packagingCharge!),
                  if (quotation.deliveryCharge != null)
                    _buildSummaryRow('Delivery', quotation.deliveryCharge!),
                  pw.Divider(),
                  _buildSummaryRow('TOTAL', quotation.grandTotal, isBold: true, color: PdfColors.purple),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Terms & Conditions
            if (quotation.termsAndConditions != null) ...[
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Terms & Conditions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(quotation.termsAndConditions!),
            ],

            if (quotation.cancellationPolicy != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Cancellation Policy:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(quotation.cancellationPolicy!),
            ],

            if (quotation.paymentTerms != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Payment Terms:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(quotation.paymentTerms!),
            ],

            if (quotation.specialInstructions != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Special Instructions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(quotation.specialInstructions!),
            ],

            pw.SizedBox(height: 30),

            // Signature
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Authorized Signatory'),
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
                    pw.Text('Customer Signature'),
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
              'This is a computer generated quotation. Valid until ${quotation.formattedValidUntil}.',
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

  static pw.Widget _buildSummaryRow(String label, double amount, 
      {bool isBold = false, bool isNegative = false, PdfColor? color}) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          width: 150,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.SizedBox(width: 20),
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            '${isNegative ? '-' : ''}₹ ${amount.abs().toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? (isNegative ? PdfColors.red : null),
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static PdfColor _getPlateColor(PlateType type) {
    switch (type) {
      case PlateType.vegetarian: return PdfColors.green;
      case PlateType.nonVegetarian: return PdfColors.red;
      case PlateType.jain: return PdfColors.orange;
      case PlateType.vegan: return PdfColors.teal;
    }
  }
}