import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:test1/utilities.dart';
import '../main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'Transctionreportpage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:test1/table_selection/table_view.dart';

//firebase
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:test1/settings/permissionUtils.dart';
import 'package:firebase_core/firebase_core.dart';
import './../firebase_options.dart';
import '../firebase/notification_service.dart';


import 'package:provider/provider.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/menu_item.dart';
import '../database_Module/transaction.dart';
import '../objectbox.g.dart';
import 'package:flutter/foundation.dart';
import 'package:test1/bill_printer.dart'; 
import 'package:test1/inventory/sync_service.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import
import 'package:test1/buySerice/buy_service_page.dart';

final printer = BillPrinter();

// Create a secure storage instance (you can make this global or in a service)
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  final Dio _dio = Dio();
  late Store _store;

  String app_version = 'v1.2';
  final String _downloadUrl = 'http://nextorbitals.in/images/app-release.zip';

  @override
  void initState() {
    super.initState();
    _loadLoginDetails();
    getmodeldata();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _store = Provider.of<ObjectBoxService>(context, listen: false).store;
      auto_login();
    });

  }
  

  Future<void> hasSmsPermission() async {
    if (!mounted) return;
    // Initialize permissions
    // await PermissionUtils.requestAllPermissions();
    // Check if permissions are granted before proceeding
    final hasPermissions = await PermissionUtils.checkAllPermissions();
    if (!hasPermissions) {
      // screen_massage(context, "Please ganter permissions to continue");
      await PermissionUtils.requestAllPermissions();
    }
  }

  Future<void> _initializeFirebase() async {
        // Initialize Firebase
    print_log("going to initialize Firebase FCM");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
    print_log("going to initializeApp Firebase FCM");
    await NotificationService.initialize();
    print_log("going to initialized Firebase FCM");
    FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);
    print_log("going to initialized backgroundHandler Firebase FCM");
    
  }

  Future<void> _loadLoginDetails() async {
    final savedEmail = await secureStorage.read(key: AppConstants.usernameKey);
    final savedPassword = await secureStorage.read(key: 'password');
    final rememberStr = await secureStorage.read(key: 'remember_me');
    final remember = rememberStr == 'true';
    print_log("_rememberMe _loadLoginDetails $_rememberMe");
    if (remember && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = remember;
        print_log("_rememberMe _loadLoginDetails $_rememberMe");
      });

      // Future.delayed(const Duration(seconds: 1), _login);
    }
  }

  // Add this new method for WhatsApp
  Future<void> _openWhatsApp() async {
    const phoneNumber = "+919403029424";
    // Remove any spaces or special characters
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Try different WhatsApp URL formats
    final whatsappUrl = "https://wa.me/$cleanNumber";
    final whatsappApiUrl = "whatsapp://send?phone=$cleanNumber";
    
    try {
      // First try the whatsapp:// scheme
      if (await canLaunchUrl(Uri.parse(whatsappApiUrl))) {
        await launchUrl(Uri.parse(whatsappApiUrl));
      } 
      // If that fails, try the web URL
      else if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
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



  Future<Map<String, dynamic>> getmodeldata() async {
    try{
      String deviceModel13 = Platform.isAndroid ? 'Android Device' : Platform.isIOS ? 'iOS Device' : 'Unknown Device';

      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      Map<String, dynamic> deviseInfo = {"androidVesion":androidInfo.version.release,
      "brand":androidInfo.brand,"id":androidInfo.id,"model":androidInfo.model,"manufacturer":androidInfo.manufacturer,
      "type":deviceModel13,"location":Platform.localeName,"numberOfProcessors":Platform.numberOfProcessors};
      // Print device details
      String deviceinfostring = jsonEncode(deviseInfo);
      //debugPrint('android version: $deviceinfostring');

      return deviseInfo;
      
    }catch(e){
      return {};
    }
  }


  Future<String?> readTokenFromJson() async {
    try {
      final dir = await getApplicationSupportDirectory();

      final file = File("${dir.path}/fcm_token.json");

      print_log("looking token $file");

      if (!file.existsSync()) {
        print_log("FCM token JSON file not found ❌");
        return null;
      }

      final text = await file.readAsString();
      final json = jsonDecode(text);

      return json["token"];
    } catch (e) {
      print_log("Error reading token from JSON: $e");
      return null;
    }
  }

  void loadToken() async {
    try {
        await Future.delayed(const Duration(milliseconds: 500));
        final prefs = await SharedPreferences.getInstance();
        
        // First check if we have stored device_id
        String? id = await prefs.getString('device_id');
        String? token;
        
        if (id != null && id.isNotEmpty) {
            token = id;
            print_log("🔥 Using stored device_id: $token");
        } else {
            // Get fresh token from Firebase
            token = await FirebaseMessaging.instance.getToken();
            print_log("🔥 Got fresh FCM Token: $token");
            
            // Store it for future use
            if (token != null) {
                await prefs.setString('device_id', token);
                print_log("🔥 Stored token in SharedPreferences");
            }
        }
        
        String? hotelname = prefs.getString('username');
        print_log("🔥 Hotel name: $hotelname");
        print_log("🔥 Token: $token");
        
        if (token != null && hotelname != null) {
            print_log("🔥 Attempting to save token to server...");
            
            final response = await apiCalls('st', hotelname, {}, token: token);
            
            if (response != null && response.statusCode == 200) {
                print_log('Token saved successfully ✅');
                print_log('Response: ${response.body}');
                // Don't show toast on every load, only show on first time
                // screen_massage(context, "Token saved successfully");
            } else {
                print_log('Failed to save token ❌');
                print_log('Status Code: ${response?.statusCode}');
                print_log('Response Body: ${response?.body}');
                screen_massage(context, "🔥 Failed to save token to server");
            }
        } else {
            print_log('❌ Missing data - Token: $token, Hotelname: $hotelname');
            screen_massage(context, "🔥 Token or Hotel name is null");
        }
    } catch (e) {
        print_log('Error while saving token: $e');
        screen_massage(context, "🔥 Error: $e");
    }
  }

  Future<void> downloadHotelZip(String hotelName) async {
    try {
      // 1️⃣ Fetch filename from your API
      // (Assuming your apiCalls still uses the http package for now)
      var apiResponse = await apiCalls("i", hotelName, {});
      if (apiResponse == null) return;

      if (apiResponse.statusCode != 200) {
        throw Exception("❌ Failed to fetch filename: ${apiResponse.statusCode}");
      }

      final data = jsonDecode(apiResponse.body);
      if (data['success'] != true || data['menu_filename'] == null) {
        throw Exception("❌ API error: ${data['message'] ?? 'Unknown error'}");
      }

      final fileId = data['menu_filename']; 
      final downloadUrl = "https://drive.google.com/uc?export=download&id=$fileId";
      //debugPrint("📥 Starting download for ID: $fileId");

      // 2️⃣ Download the ZIP using Dio
      // We use ResponseType.bytes to get the data for ZipDecoder
      final response = await _dio.get<List<int>>(
        downloadUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
          followRedirects: true,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            //debugPrint("Download Progress: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception("❌ HTTP Error: ${response.statusCode}");
      }

      final Uint8List bytes = Uint8List.fromList(response.data!);

      // 3️⃣ Prepare Directories
      final picturesDir = (await getExternalStorageDirectories(
        type: StorageDirectory.pictures,
      ))?.first;
      
      if (picturesDir == null) throw Exception("❌ Pictures directory unavailable");

      final extractDir = Directory("${picturesDir.path}/menu_images");

      // Clean up old files
      if (!await extractDir.exists()) {
        await extractDir.create(recursive: true);
      } else {
        final files = extractDir.listSync();
        for (var file in files) {
          if (file is File) await file.delete();
        }
      }

      // 4️⃣ Extract ZIP
      final archive = ZipDecoder().decodeBytes(bytes);
      int fileCount = 0;

      for (final file in archive) {
        if (file.isFile) {
          final outFile = File("${extractDir.path}/${file.name}");
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          fileCount++;
        }
      }

      //debugPrint("✅ Extracted $fileCount images to ${extractDir.path}");
    } catch (e) {
      //debugPrint("❌ Error while downloading images: $e");
    }
  }

  void saveMenuItemsReliably(List<MenuItem> menuItems,Box<MenuItem> menuItemBox) {
    // ❌ Remove all old items first
    if (menuItemBox != null) {
      menuItemBox.removeAll();
      }else{
      print_log("found menuItemBox is null in setting");
    }

    // ✅ Insert fresh items
    for (int i = 0; i < menuItems.length; i++) {
      final item = menuItems[i];
      item.synced = true;
      menuItemBox.put(item);
    }
    screen_massage(context, "Menu Updated Successfully");

  }


 void loadMenu() async {
    
    Box<MenuItem> menuItemBox = _store.box<MenuItem>();
    List<MenuItem> items_all = menuItemBox.getAll();
    
    if(items_all.isEmpty){
      print_log("menu Not found so download from server $items_all");
            // print("ApiCallPage started...");
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? "";
      final role = prefs.getString('role') ?? "";
      var hotelName='';
      if(role=="captain"){
        hotelName = getHotelIdentifier(username);
        // hotelName = username.split("_").sublist(0, username.split("_").length - 1).join("_");
        //debugPrint("hotelName $hotelName");
      }else{
         hotelName = username;
         //debugPrint("hotelName $hotelName");
      }

      try {
        http.Response? response = await apiCalls("m",hotelName, {});
        if (response == null) {
          return;
        }
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final dataList = jsonData['data'];

          print_log("server response $dataList");
          if (dataList is List) {
            List<MenuItem> menuItems = dataList.map((item) => MenuItem.fromJson(item)).toList();
            saveMenuItemsReliably(menuItems,menuItemBox);
            await downloadHotelZip(hotelName);
            
            print_log("✅ Menu loaded from server: ${menuItems.length} items");
          } else {
            screen_massage(context, "❌Error $jsonData");
          }
        } else {
          screen_massage(context, 'HTTP Error: ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (error) {
        if(mounted){
          screen_massage(context, "❌ Device Not Connected ${error}");
        }
        print_log_red("❌ Error in loadMenu: $error");
      }
    }
 }

  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return int.tryParse(value) ?? defaultValue;
    }
    if (value is num) return value.toInt();
    return defaultValue;
  }

  double _safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return double.tryParse(value) ?? defaultValue;
    }
    if (value is num) return value.toDouble();
    return defaultValue;
  }

  String _safeParseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  DateTime _safeParseDateTime(dynamic value, {DateTime? defaultValue}) {
    defaultValue ??= DateTime.now();
    
    if (value == null) return defaultValue;
    if (value is DateTime) return value;
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return DateTime.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }


  void auto_login() async{
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = await prefs.getBool('autoLogin') ?? true;
    print_log("autoLogin $autoLogin");
    if(autoLogin) {
      _autoLogin();
    }
  }


  void _login() async {
    await hasSmsPermission();
    print_log("_rememberMe  $_rememberMe");
    try{
    final email = (_emailController.text.trim()).toLowerCase();
    final password = _passwordController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.usernameKey, email);
    AppConstants.username = email;
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // ⏳ Start loading
      });

      try {
        final Map<String, dynamic> deviceinfo = await getmodeldata();
        // final Map<String, dynamic> deviceinfo = {};
        String deviceinfostring = jsonEncode(deviceinfo);
        //debugPrint('android version: $deviceinfostring');
        final payload = {
          "username": email,
          "password": password,
          "deviceinfo":deviceinfostring,
        };
        http.Response? response = await apiCalls("l", email, payload);
        if (response == null) {
          return;
        }
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print_log("Login response $data ");


          if (data["success"] == true) {

            final expiresAtStr = data['expires_at'];
            final app_Version = data['app_version'];
            final expiry_date1 = data['expiry_date'];
            final adminPanel = data['adminPanel'];
            final expiry_Date = DateTime.parse(expiry_date1);
            final allowedDeviceVal = int.tryParse(data['allowed_device']?.toString() ?? "0") ?? 0;
            final deviceCountVal = int.tryParse(data['device_count']?.toString() ?? "0") ?? 0;
            final now = DateTime.now();
            final role = data['role'];

            await prefs.setString('expiresAtStr', expiresAtStr);
            await prefs.setString('expiry_date', expiry_date1);
            await prefs.setString('adminPanel', adminPanel);
            await prefs.setString('role', role);
            await prefs.setBool('autoLogin',true);
            final autoLogin = await prefs.getBool('autoLogin') ?? true;
            print_log("autoLogin $autoLogin");
            await secureStorage.write(key: 'expiry_Date', value: expiry_date1);
            await secureStorage.write(key: 'expiresAtStr', value: expiresAtStr);

            // Create a date-only version of "today" by setting the time to midnight
            final today = DateTime(now.year, now.month, now.day);
            final expiryDateOnly = DateTime(expiry_Date.year, expiry_Date.month, expiry_Date.day);
            final bool isExpiryToday = expiryDateOnly.isBefore(today);

            if (isExpiryToday) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Your subscription has expired."),
                duration: Duration(minutes :1),),
              );
              _showExpiredSubscriptionDialog();
              return;
            }
             else if (allowedDeviceVal <= deviceCountVal) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Multiple devices Login not allowed."),
                duration: Duration(minutes :1),),
              );
              return;
            } 
            else {
              //debugPrint("Expiry remaining5 ");
              if (_rememberMe) {
                // await prefs.setString(AppConstants.usernameKey, email);
                await prefs.setString('password', password);
                await prefs.setBool('remember_me', true);

                // Instead of SharedPreferences:
                await secureStorage.write(key: AppConstants.usernameKey, value: email);
                await secureStorage.write(key: 'password', value: password);
                await secureStorage.write(key: 'remember_me',value: _rememberMe.toString(),);
                await secureStorage.write(key: 'expiresAtStr',value: expiresAtStr,);
                await secureStorage.write(key: 'expiry_Date',value: expiry_Date.toIso8601String(),);
              } else {
                // await prefs.remove('username');
                await prefs.remove('password');
                await prefs.setBool('remember_me', false);
                await secureStorage.delete(key: AppConstants.usernameKey);
                await secureStorage.delete(key: 'password');
                await secureStorage.delete(key: 'remember_me');
                await secureStorage.delete(key: 'expiresAtStr');
                await secureStorage.delete(key: 'expiry_Date');
              }
              
              if (role != 'captain') {
                final businessDate = (AppConstants.businessDate).toString().split(" ")[0];
                DateTime currentDate = DateTime.parse(businessDate);
                DateTime previousDate = currentDate.subtract(Duration(days: 1));
                String previousDateString = "${previousDate.year}-${previousDate.month.toString().padLeft(2, '0')}-${previousDate.day.toString().padLeft(2, '0')}";
                print_log("dates are $businessDate $previousDateString");
                final hotelname = email;
                http.Response? response = await apiCalls('get_t', hotelname, {}, start:previousDateString, end:businessDate);
                loadtransections(response,prefs,_store,context);
              }
              try{
              loadMenu();
              } catch(e){
                print_log_red("menu not found $e");
              }

              final captain = prefs.getBool('startcaptain') ?? false;
              print_log("Captain $captain");
              if(captain){
                await _initializeFirebase().then((value)=> loadToken());
              }
              if (role == 'captain') {
                print_log("role $role going to tableview ${AppConstants.username}");
                try{
                  await _initializeFirebase().then((value)=> loadToken());
                } catch(e){
                  print_log_red("firebase not found $e");
                }
                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TableView(),
                  ),
                );
              } else {
                //debugPrint("Expiry remaining6");
                Navigator.pushReplacement(context,
                  MaterialPageRoute(
                    builder: (context) => const DostiKitchenPage(),
                  ),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data["message"] ?? "Invalid credentials")),
            );
          }
        }
      } catch (e) {
        print_log_red("Login response error $e");
        final prefs = await SharedPreferences.getInstance();
        final expiresAtStr = prefs.getString('expiresAtStr');
        final expiry_Date =  prefs.getString('expiry_date');
        //debugPrint("Expiry remaining $expiry_Date expiresAtStr $expiresAtStr ");

        if (expiry_Date == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Please connect to Internet for Login $expiry_Date")),
          );
          return;
        }
        final now = DateTime.now();
        final expiryDate = DateTime.parse(expiry_Date);

        // Create a date-only version of "today" by setting the time to midnight
        final today = DateTime(now.year, now.month, now.day);

        // Create a date-only version of the expiry date
        final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

        // This will be TRUE if the expiry date is any day before today.
        final bool isExpiryToday = expiryDateOnly.isBefore(today);
        

        print_log("Expiry remaining $expiryDate  isExpiryToday $isExpiryToday");

        // final expiryDate1 = DateTime.parse(expiresAtStr!);
        // final extendedExpiry = expiryDate1.add(Duration(days: 365));
        // final difference = extendedExpiry.difference(now).inDays;
        //debugPrint("Expiry remaining $difference");
        
        if (isExpiryToday) {
          // ❌ Subscription expired
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Your subscription has expired."),
            duration: Duration(minutes :1),),
          );
          _showExpiredSubscriptionDialog();
          return;
        } else {
          //debugPrint("Expiry remaining7");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DostiKitchenPage()),
          );
        }
      } finally {
        setState(() {
          _isLoading = false; // ✅ Stop loading
        });
      }
    }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("error login $e"),
        duration: Duration(minutes :1),),
      );
    }
  }


  Future<void> _autoLogin() async {
    final savedEmail = await secureStorage.read(key: AppConstants.usernameKey);
    final savedPassword = await secureStorage.read(key: 'password');
    final rememberStr = await secureStorage.read(key: 'remember_me');
    final remember = rememberStr == 'true';
    final savedExpiryDate = await secureStorage.read(key: 'expiry_Date');
    final prefs = await SharedPreferences.getInstance();
    final email = await prefs.getString(AppConstants.usernameKey);
    AppConstants.username = email ?? savedEmail ?? '';
    if (remember && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = remember;
      });

      // Check if expiry date exists and is still valid
      if (savedExpiryDate != null) {
        try {
          final expiryDate = DateTime.parse(savedExpiryDate);
          final now = DateTime.now();
          
          // Create date-only versions for comparison
          final today = DateTime(now.year, now.month, now.day);
          final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          
          // Check if subscription is still valid (expiry date is today or in future)
          final bool isExpiryValid = !expiryDateOnly.isBefore(today);
          print_log("autoLogin $isExpiryValid");
          if (isExpiryValid) {
            print_log("✅ Auto-login: Valid expiry date found: $savedExpiryDate");
            
            // Load stored role
            final role = prefs.getString('role') ?? '';
            
            // Load menu and transactions
            // await _loadInitialData(prefs, savedEmail, role);
            final captain = prefs.getBool('startcaptain') ?? false;
            print_log("Captain FCM $captain");
            if(captain){
              await _initializeFirebase().then((value)=> loadToken());
            }
            // Navigate based on role
            if (role == 'captain') {
              await _initializeFirebase().then((value) => loadToken());
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TableView(),
                  ),
                );
              }
            } else {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DostiKitchenPage(),
                  ),
                );
              }
            }
          } else {
            print_log("⚠️ Auto-login: Subscription expired on: $savedExpiryDate");
            _showExpiredSubscriptionDialog();
          }
        } catch (e) {
          print_log_red("❌ Error parsing expiry date: $e");
        }
      } else {
        print_log("⚠️ Auto-login: No expiry date found");
      }
    }
  }



  void _showExpiredSubscriptionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Subscription Expired"),
          content: const Text(
            "Your subscription has expired. Please renew your subscription."
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
                      _openWhatsApp();
                    },
        icon: const Icon(Icons.help_outline),
        label: const Text("HELP"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "NEXTORBITALS",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    Text(
                      "Welcome You",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    Text(
                      "V-${AppConstants.app_version} B-${AppConstants.buildNumber}",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Username",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your username";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your password";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                        const Text("Remember Me"),
                      ],
                    ),

                    const SizedBox(height: 15),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Login"),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const BuyServicePage(),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("BUY Service"),
                      ),
                    ),
                    const SizedBox(height: 16),

                    
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}