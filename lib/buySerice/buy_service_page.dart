import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'api_service.dart';
import 'service_model.dart';
import 'package:test1/utilities.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'service_model.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';



class BuyServicePage extends StatefulWidget {
  const BuyServicePage({super.key});

  @override
  State<BuyServicePage> createState() => _BuyServicePageState();
}

class _BuyServicePageState extends State<BuyServicePage> {
  // Updated to handle a List of services
  late Future<List<ServiceModel>> futureServices;
  late Map<String, int> coupons = {};

  @override
  void initState() {
    super.initState();
    // Assuming you updated fetchService to return List<ServiceModel>
    futureServices = ApiService.fetchServices(); 
    futureServices.then((services) {
      if (services.isNotEmpty) {
        setState(() {
          coupons = services[0].coupons;
        });
      }
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 189, 130, 181), // Soft light background
      appBar: AppBar(
        title: const Text("Explore Services", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ServiceModel>>(
        future: futureServices,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final services = snapshot.data!;

          return Column(
            children: [
              const SizedBox(height: 5),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Choose a plan that fits your needs",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              
              // THE MAIN SLIDER
              Expanded(
                child: cs.CarouselSlider(
                  options: cs.CarouselOptions(
                    height: MediaQuery.of(context).size.height * 0.9,
                    enlargeCenterPage: true,
                    enableInfiniteScroll: false,
                    viewportFraction: 0.85,
                  ),
                  items: services.map((service) {
                    return _buildServiceCard(service);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

Widget _buildServiceCard(ServiceModel service) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          // --- ENLARGED IMAGE SECTION ---
          Stack(
            children: [
              Image.network(
                service.images.isNotEmpty ? service.images[0] : "",
                height: 250, // Increased height to occupy more of the card
                width: double.infinity,
                fit: BoxFit.cover, // Ensures the image fills the 320px height perfectly
              ),
              if (service.discount > 0)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      "${service.discount.toInt()}% OFF",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),

          // Content Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 1, 20, 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  Text(
                    service.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  // DESCRIPTION
                  Text(
                    service.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // FEATURES LIST
                  const Text(
                    "What's Included:",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      children: service.features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                feature.trim(),
                                style: const TextStyle(fontSize: 14, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),

                  const Divider(height: 30),

                  // PRICE & ACTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "₹${service.finalPrice.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          if (service.discount > 0)
                            Text(
                              "₹${service.price.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 14, 
                                decoration: TextDecoration.lineThrough, 
                                color: Colors.grey
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => _showPurchaseSheet(context, service),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        child: const Text("Buy Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  void _showPurchaseSheet(BuildContext context, ServiceModel service) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController _zomato = TextEditingController();
    final TextEditingController _swiggy = TextEditingController();
    final TextEditingController _note = TextEditingController();
    final TextEditingController couponController = TextEditingController();
    
    double currentFinalPrice = service.finalPrice;
    String appliedCoupon = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Register for ${service.title}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildField("Business Name*", nameController, Icons.business),
                  _buildField("Business Address*", addressController, Icons.location_on),
                  _buildField("Mobile Number*", phoneController, Icons.phone, inputType: TextInputType.phone),
                  _buildField("Zomato ID", _zomato, Icons.safety_divider_sharp, inputType: TextInputType.phone),
                  _buildField("Swiggy ID", _swiggy, Icons.safety_divider_sharp, inputType: TextInputType.phone),
                  _buildField("Note", _note, Icons.note_add,),
                  
                  // Coupon Section
                  Row(
                    children: [
                      Expanded(child: _buildField("Coupon Code", couponController, Icons.confirmation_number)),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          String code = couponController.text.trim().toUpperCase();
                          if (coupons.containsKey(code)) {
                            setSheetState(() {
                              appliedCoupon = code;
                              double discountAmount = (service.finalPrice * coupons[code]!) / 100;
                              currentFinalPrice = service.finalPrice - discountAmount;
                            });
                          }
                        },
                        child: const Text("Apply", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  if (appliedCoupon.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text("Coupon Applied! You saved ₹${(service.finalPrice - currentFinalPrice).toStringAsFixed(0)}", 
                        style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),

                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total to Pay:", style: TextStyle(color: Colors.grey.shade600)),
                      Text("₹${currentFinalPrice.toStringAsFixed(0)}", 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // PAY & QR BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () async {
                            if (nameController.text.isEmpty || phoneController.text.isEmpty || addressController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill required fields")));
                              return;
                            }

                            Map<String, dynamic> payload = {
                              "business_name": nameController.text,
                              "address": addressController.text,
                              "mobile": phoneController.text,
                              "service_id": service.title, // or service.id if you have it
                              "amount_paid": currentFinalPrice,
                              "zomato": _zomato.text,
                              "swiggy": _swiggy.text,
                              "note": _note.text,
                              "timestamp": DateTime.now().toIso8601String(),
                            };
                            final String payloadString = jsonEncode(payload);
                            
                            // 1. SEND PAYLOAD TO API
                            await _sendPayload(service, payload);
                            
                            _showUpiQr(currentFinalPrice, service.title, payloadString);
                            // 2. OPEN UPI
                            // _launchUPI(currentFinalPrice, service.title);
                          },
                          child: const Text("Confirm & Pay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      // const SizedBox(width: 10),
                      // Expanded(
                      //   child: OutlinedButton.icon(
                      //     style: OutlinedButton.styleFrom(
                      //       padding: const EdgeInsets.symmetric(vertical: 16),
                      //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      //       side: const BorderSide(color: Colors.deepPurple),
                      //     ),
                      //     icon: const Icon(Icons.qr_code, color: Colors.deepPurple),
                      //     label: const Text("Show QR", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                      //     onPressed: () {
                      //       _showUpiQr(currentFinalPrice, service.title);
                      //     },
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Future<void> _sendPayload(ServiceModel service, Map<String, dynamic> payload) async {
    try {
      final response = await apiCalls('gsp', "hotelname", payload,);
      if(response == null){
        return;
      }
      print_log("API Status: ${response.statusCode}");
    } catch (e) {
      print_log("API Error: $e");
    }
  }

  // void _launchUPI(double amount, String note) async {
  //   // Generate standard UPI String
  //   // Replace 'your-vpa@upi' with your actual NextOrbitals business VPA
  //   final String upiUrl = "upi://pay?pa=jadhav838@ptyes&pn=NextOrbitals&tn=${Uri.encodeComponent(note)}&am=${amount.toStringAsFixed(2)}&cu=INR";
    
  //   // You will need the 'url_launcher' package in pubspec.yaml
  //   if (await canLaunchUrl(Uri.parse(upiUrl))) {
  //     await launchUrl(Uri.parse(upiUrl));
  //   } else {
  //     print_log("Could not launch UPI app");
  //   }
  //   print_log("Intent Created: $upiUrl");
  // }



  Uri _buildUpiUri(double amount, String note) {
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': '9270182585-2@axl', // payee VPA (required)
        'pn': 'Nextorbitals', // payee name (required by many apps)
        'tr': 'TXN${DateTime.now().millisecondsSinceEpoch}', // unique order id
        'am': amount.toStringAsFixed(2), // amount as string
        'cu': 'INR', // currency
        'tn': note, // note / description
      },
    );
  }

  void _launchUPI(double amount, String note) async {
    try {
      final upiUri = _buildUpiUri(amount, note);
      if (await canLaunchUrl(upiUri)) {
        // Use external application mode so it opens the UPI app chooser directly
        final ok = await launchUrl(upiUri, mode: LaunchMode.externalApplication);
        if (!ok) throw 'Could not launch UPI intent';
      } else {
        throw 'No UPI handler found on this device';
      }
      
    } catch (e) {
      print_log_red('Error getting UPI apps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpiQr(double amount, String note , String details) {
    final upiUri = _buildUpiUri(amount, note);
    final upiString = upiUri.toString();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Scan to Pay via UPI",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              QrImageView(
                data: upiString,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                "Amount: \u20B9${amount.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Text(
                "SEND THE CONFIRMETION ON THE WHAT'SAPP",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text("Copy UPI ID"),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: "jadhav838@ptyes"));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("UPI link copied")),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text("SEND CONFIRMATION"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _openWhatsApp(details);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }


    // Add this new method for WhatsApp
  Future<void> _openWhatsApp( String note) async {
    const phoneNumber = "9403029424";
    // Remove any spaces or special characters
    // Clean phone number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Encode message for URL
    final encodedMessage = Uri.encodeComponent(note);

    // WhatsApp deep link (app)
    final whatsappApiUrl = "whatsapp://send?phone=$cleanNumber&text=$encodedMessage";

    // WhatsApp web fallback
    final whatsappWebUrl = "https://wa.me/$cleanNumber?text=$encodedMessage";
    
    try {
      // First try the whatsapp:// scheme
      if (await canLaunchUrl(Uri.parse(whatsappApiUrl))) {
        await launchUrl(Uri.parse(whatsappApiUrl));
      } 
      // If that fails, try the web URL
      else if (await canLaunchUrl(Uri.parse(whatsappWebUrl))) {
        await launchUrl(Uri.parse(whatsappWebUrl));
      } 
      else {
        // If WhatsApp is not installed, show dialog with options
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("WhatsApp Not Installed"),
              content: const Text(
                "WhatsApp is not installed on this device. Please install WhatsApp to contact support."
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print_log_red("Error opening WhatsApp: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening WhatsApp: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  












































  







































}
