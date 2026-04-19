// lib/services/pdf_bill_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:test1/utilities.dart';

class PdfBillService {
  static const String appFolderName = 'orbipay';
  static const String billPrefix = 'Orbipay_bill_';

  /// Generate PDF bill from cart data
  Future<Uint8List> generateBillPdf({
    required int billNo,
    required String businessName,
    required String businessAddress,
    required String contactPhone,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double discount,
    required double serviceCharge,
    required double total,
    required String customerName,
    required String customerMobile,
    required String orderType,
    String paymentMode = 'CASH',
  }) async {
    final pdf = pw.Document();

    // Format date
    // final dateFormat = '${billDate.day}/${billDate.month}/${billDate.year} ${billDate.hour}:${billDate.minute}';
  final dateFormat = 'ghjk';
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (businessAddress.isNotEmpty)
                    pw.Text(
                      businessAddress,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  pw.Text(
                    'Tel: $contactPhone',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'TAX INVOICE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Bill Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill No: $billNo'),
                    pw.Text('Date: $dateFormat'),
                    pw.Text('Order Type: $orderType'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Customer: ${customerName.isEmpty ? "Walk-in" : customerName}'),
                    pw.Text('Mobile: ${customerMobile.isEmpty ? "N/A" : customerMobile}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Items Table Header
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                color: PdfColors.grey300,
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 1, child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 1, child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
            ),

            // Items List
            ...cartItems.map((item) {
              final name = item['name'] ?? 'Unknown';
              final qty = item['qty'] ?? 0;
              final price = item['sellPrice'] ?? 0.0;
              final total = item['total'] ?? 0.0;
              final portion = item['portion'] ?? '';

              return pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(),
                    right: pw.BorderSide(),
                    bottom: pw.BorderSide(),
                  ),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(name),
                          if (portion.isNotEmpty)
                            pw.Text('($portion)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          if (item['note'] != null && item['note'].toString().isNotEmpty)
                            pw.Text('Note: ${item['note']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
                        ],
                      ),
                    ),
                    pw.Expanded(flex: 1, child: pw.Text(qty.toString(), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 1, child: pw.Text('₹ ${price.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 1, child: pw.Text('₹ ${total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                  ],
                ),
              );
            }).toList(),

            // Totals
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Container(
                        width: 150,
                        child: pw.Text('Subtotal:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(
                        width: 100,
                        child: pw.Text('₹ ${subtotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  if (discount > 0)
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 150,
                          child: pw.Text('Discount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Container(
                          width: 100,
                          child: pw.Text('- ₹ ${discount.toStringAsFixed(2)}', 
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(color: PdfColors.red),
                          ),
                        ),
                      ],
                    ),
                  if (serviceCharge > 0)
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 150,
                          child: pw.Text('Service Charge:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Container(
                          width: 100,
                          child: pw.Text('+ ₹ ${serviceCharge.toStringAsFixed(2)}', 
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(color: PdfColors.green),
                          ),
                        ),
                      ],
                    ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Container(
                        width: 150,
                        child: pw.Text('TOTAL AMOUNT:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      ),
                      pw.Container(
                        width: 100,
                        child: pw.Text('₹ ${total.toStringAsFixed(2)}', 
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Amount in words: ${_convertNumberToWords(total.toInt())} Rupees Only',
                    style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Payment Mode: $paymentMode'),
                    pw.SizedBox(height: 30),
                    pw.Text('Customer Signature'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('For $businessName'),
                    pw.SizedBox(height: 30),
                    pw.Text('Authorized Signatory'),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Thank You! Visit Again!',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'This is a computer generated invoice',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Save PDF to orbipay folder
  Future<String?> savePdfToStorage(Uint8List pdfBytes, int billNo) async {
    try {
      // Request storage permission
      if (await _requestStoragePermission()) {
        // Get the downloads directory
        Directory? downloadsDir;
        
        if (Platform.isAndroid) {
          // For Android 10 and above, use the Downloads folder
          downloadsDir = Directory('/storage/emulated/0/Download');
          
          // Create orbipay folder in Downloads
          final orbipayDir = Directory('${downloadsDir.path}/$appFolderName');
          
          if (!await orbipayDir.exists()) {
            await orbipayDir.create(recursive: true);
          }
          
          final fileName = '$billPrefix$billNo.pdf';
          final filePath = '${orbipayDir.path}/$fileName';
          final file = File(filePath);
          
          await file.writeAsBytes(pdfBytes);
          return filePath;
        } else {
          // For iOS, use the documents directory
          final dir = await getApplicationDocumentsDirectory();
          final orbipayDir = Directory('${dir.path}/$appFolderName');
          
          if (!await orbipayDir.exists()) {
            await orbipayDir.create(recursive: true);
          }
          
          final fileName = '$billPrefix$billNo.pdf';
          final filePath = '${orbipayDir.path}/$fileName';
          final file = File(filePath);
          
          await file.writeAsBytes(pdfBytes);
          return filePath;
        }
      }
    } catch (e) {
      print_log_red('Error saving PDF: $e');
    }
    return null;
  }

  /// Share PDF via WhatsApp
  Future<void> sharePdfViaWhatsApp(String filePath, String phoneNumber) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('PDF file not found');
      }

      // Extract last 10 digits for WhatsApp
      String mobileNumber = _extractLast10Digits(phoneNumber);
      
      // Add country code if needed
      if (mobileNumber.length == 10) {
        mobileNumber = '91$mobileNumber';
      } else if (mobileNumber.length == 11 && mobileNumber.startsWith('0')) {
        mobileNumber = '91${mobileNumber.substring(1)}';
      }

      // Share via WhatsApp using share_plus
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Your bill is attached below.',
      );
      
      // Note: For direct WhatsApp sharing with phone number, you might need additional setup
      // You can also use the existing whatsapp_share_plus package if already configured
      
    } catch (e) {
      print_log_red('Error sharing PDF via WhatsApp: $e');
      rethrow;
    }
  }

  /// Generate and save PDF, then optionally share
  Future<String?> generateAndSaveBill({
    required int billNo,
    required String businessName,
    required String businessAddress,
    required String contactPhone,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double discount,
    required double serviceCharge,
    required double total,
    required String customerName,
    required String customerMobile,
    required String orderType,
    String paymentMode = 'CASH',
    bool shareAfterSave = false,
  }) async {
    try {
      // Generate PDF
      final pdfBytes = await generateBillPdf(
        billNo: billNo,
        businessName: businessName,
        businessAddress: businessAddress,
        contactPhone: contactPhone,
        cartItems: cartItems,
        subtotal: subtotal,
        discount: discount,
        serviceCharge: serviceCharge,
        total: total,
        customerName: customerName,
        customerMobile: customerMobile,
        orderType: orderType,
        paymentMode: paymentMode,
      );

      // Save PDF
      final savedPath = await savePdfToStorage(pdfBytes, billNo);

      if (shareAfterSave && savedPath != null && customerMobile.isNotEmpty) {
        await sharePdfViaWhatsApp(savedPath, customerMobile);
      }

      return savedPath;
    } catch (e) {
      print_log_red('Error generating/saving PDF: $e');
      return null;
    }
  }

  /// Request storage permission
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // iOS doesn't need storage permission for app documents
  }

  /// Extract last 10 digits from phone number
  String _extractLast10Digits(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

  /// Convert number to words (simplified version)
  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';
    
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    final teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    
    String convertLessThanThousand(int n) {
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        return tens[n ~/ 10] + (n % 10 != 0 ? ' ' + units[n % 10] : '');
      }
      return units[n ~/ 100] + ' Hundred' + (n % 100 != 0 ? ' ' + convertLessThanThousand(n % 100) : '');
    }
    
    if (number < 1000) return convertLessThanThousand(number);
    
    String result = '';
    int thousands = number ~/ 1000;
    int remainder = number % 1000;
    
    if (thousands > 0) {
      result = convertLessThanThousand(thousands) + ' Thousand';
    }
    
    if (remainder > 0) {
      result += (result.isNotEmpty ? ' ' : '') + convertLessThanThousand(remainder);
    }
    
    return result;
  }
}