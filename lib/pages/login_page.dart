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
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'Transctionreportpage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:test1/table_selection/table_view.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:test1/settings/permissionUtils.dart';
import 'package:firebase_core/firebase_core.dart';
import './../firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  String app_version = 'v1.2';
  final String _downloadUrl = 'http://nextorbitals.in/images/app-release.zip';

  @override
  void initState() {
    super.initState();
    _loadLoginDetails();
    getmodeldata();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionUtils.requestsmsPermissions();
    });

  }

  Future<void> hasSmsPermission() async {
    if (!mounted) return;
    
    // Initialize permissions
    await PermissionUtils.requestAllPermissions();
    
    // Check if permissions are granted before proceeding
    final hasPermissions = await PermissionUtils.checkAllPermissions();
    
    if (!hasPermissions) {
      screen_massage(context, "Please ganter permissions to continue");
      // await PermissionUtils.requestAllPermissions();
    }
  }

  Future<void> _initializeFirebase() async {
    final prefs = await SharedPreferences.getInstance();

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Request permission (iOS/macOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,  // For provisional authorization
    );
    
    // Get device token
    String? token = await FirebaseMessaging.instance.getToken();
    print_log("FCM Token: $token");
    await prefs.setString('device_id', token ?? "");
    
  }

  Future<void> _loadLoginDetails() async {
    final savedEmail = await secureStorage.read(key: AppConstants.usernameKey);
    final savedPassword = await secureStorage.read(key: 'password');
    final rememberStr = await secureStorage.read(key: 'remember_me');
    final remember = rememberStr == 'true';

    if (remember && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = remember;
      });

      // Future.delayed(const Duration(seconds: 1), _login);
    }
  }

  // Check and request storage permissions
  Future<void> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      try {
        // Check current permission status
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          // Request permission
          status = await Permission.storage.request();
        }
        var status1 = await Permission.requestInstallPackages.status;
        if (!status1.isGranted) {
          status1 = await Permission.requestInstallPackages.request();
        }
        if (!status.isGranted || !status1.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "❌ permission of storage ${status.isGranted} and installer ${status1.isGranted}",
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ permission of storage and installer $e ")),
        );
      }
    }
  }

  Future<void> _downloadNewApp(String id) async {
    double downloadProgress = 0.0;
    StateSetter? dialogSetState;
    int? bytes = 0;
    int? totalB = 0;

    final downloadsDir1 = await getDownloadsDirectory();
    if (downloadsDir1 != null) {
      await _deleteDirectory(downloadsDir1);
    }

    // Show the dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss the dialog
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState; // Store setState function for later use
            return AlertDialog(
              title: const Text("Downloading Update"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: downloadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${((bytes ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB / ${((totalB ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB and ${(downloadProgress * 100).toStringAsFixed(0)}%",
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      // ✅ 1. Check and request permissions
      _checkAndRequestPermissions();

      // ✅ 2. Extract the actual ID from the string
      final nameId = id.split(":");
      final version = nameId.isNotEmpty? nameId[0].replaceAll('{', ''): nameId;
      final fileId = nameId.length > 1 ? nameId[1].replaceAll('}', '') : nameId;

      // ✅ 4. Get a reliable downloads directory path
      final downloadsDir = await getDownloadsDirectory();

      if (downloadsDir == null) {
        throw Exception("❌ Could not get downloads directory");
      }
      // Orbipay_$version
      final savePath = '${downloadsDir.path}/Orbipay_$version.zip';
      // await _extractZip (savePath, downloadsDir);

      // Download using Dio
      final dio = Dio();
      await dio.download(
        _downloadUrl,
        savePath,
        onReceiveProgress: (receivedBytes, totalBytes) {
          if (totalBytes != -1) {
            setState(() {
              // debugPrint( 'receivedBytes $receivedBytes and totalBytes $totalBytes and ${downloadProgress*100}');
              dialogSetState?.call(() {
                downloadProgress = receivedBytes / totalBytes;
              });
              bytes = receivedBytes;
              totalB = totalBytes;
            });
          }
        },
        deleteOnError: true,
        options: Options(
          receiveTimeout: Duration(minutes: 5),
          sendTimeout: Duration(minutes: 5),
        ),
      );

      debugPrint("✅ File saved to: $savePath");

      // Close the dialog and immediately start the installation
      // if (mounted) Navigator.of(context).pop();
      await _extractZip(savePath, downloadsDir);
    } catch (e) {
      debugPrint("❌ Error during download/install: $e");
      // if (mounted) Navigator.of(context).pop(); // Close dialog on error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
      }
    }
  }

  // Extract ZIP file
  Future<void> _extractZip(String zipPath, Directory destinationDir) async {
    try {
      debugPrint("zipPath $zipPath");

      // Use the archive package to extract
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeStream(inputStream);
      extractArchiveToDisk(archive, destinationDir.path);

      debugPrint("✅ ZIP extracted successfully to ${destinationDir.path}");

      // ⭐ FIX: Safely find the .apk file instead of assuming the first file
      String apkPath = '${destinationDir.path}/app-release.apk';
      final entities = destinationDir.listSync(recursive: true);
      for (var i in [1, 2, 3]) {
        for (var entity in entities) {
          if (entity is File) {
            var pp = entity.path;
            debugPrint("$i entity.path ${entity.path}");
            if (pp.contains('apk') || pp.contains('APK')) {
              apkPath = entity.path;
              break;
            }
          }
        }
      }

      if (apkPath != null) {
        await _installApp(apkPath, zipPath); // Pass zipPath for deletion
      } else {
        throw Exception(
          "No .apk file found in the extracted contents. $apkPath",
        );
      }
    } catch (e) {
      throw Exception('Failed to extract ZIP file: $e');
    }
  }

  Future<void> _installApp(String apkPath, String zipPathToDelete) async {
    debugPrint("Installer opening for: $apkPath");
    // var toDelete = false;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // User must interact with the dialog
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Ready to Install"),
            content: SingleChildScrollView(
              // Prevents overflow if path is long
              child: Text(
                "The update has been downloaded.\n\nThe latest version includes performance improvements, bug fixes, and new features. Tap ‘Install Now’ to complete the update.",
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text("CLOSE"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: const Text("INSTALL NOW"),
                onPressed: () {
                  // Manually trigger the installer again
                  OpenFile.open(apkPath);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  /// Deletes a directory and all its contents if it exists.
  Future<void> _deleteDirectory(Directory directory) async {
    debugPrint("Attempting to delete directory: ${directory.path}");
    try {
      // 1. Check if the directory exists.
      if (await directory.exists()) {
        // 2. Delete the directory and all its contents.
        await directory.delete(recursive: true);
        if (mounted) {
          debugPrint('🗑️ Directory cleaned up successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Directory cleaned up successfully'),
            ),
          );
        }
      } else {
        // 3. Show a message if it doesn't exist.
        if (mounted) {
          debugPrint('Directory not found, nothing to delete.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Directory not found, nothing to delete.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete directory: $e')),
        );
      }
    }
  }

  Future<void> _showDownloadsFiles() async {
    try {
      final downloadsDir = await getApplicationDocumentsDirectory();

      if (downloadsDir != null && await downloadsDir.exists()) {
        final List<FileSystemEntity> files = downloadsDir.listSync();
        final fileList = files.whereType<File>().toList();
        debugPrint("fileList $fileList");

        if (fileList.isNotEmpty) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Select a file to open"),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: fileList.length,
                    itemBuilder: (BuildContext context, int index) {
                      final file = fileList[index];
                      final fileName = file.path.split('/').last;

                      return ListTile(
                        title: Text(fileName),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await OpenFile.open(file.path);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No files found in downloads directory"),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Downloads directory not found")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error accessing downloads: $e")));
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
      debugPrint('android version: $deviceinfostring');

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
    final prefs = await SharedPreferences.getInstance();
      String? id = await prefs.getString('device_id');
      String? token = id ?? await FirebaseMessaging.instance.getToken();
      print_log("🔥 Loaded FCM Token from JSON: $token");
      String? hotelname = prefs.getString('username');

      if (token != null && hotelname != null) {
        try {
          
          final response = await apiCalls('st',hotelname,{},token:token);

          if (response!.statusCode == 200) {
            print_log('Token saved successfully ✅');
            print_log('Response: ${response.body}');
          } else {
            print_log('Failed to save token ❌');
            print_log('Status Code: ${response.statusCode}');
          }
        } catch (e) {
          print_log('Error while saving token: $e');
          }
      } else {
        print_log('FCM token is null ❌');
      }
  }



  void _login() async {
    await hasSmsPermission();
    try{
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.usernameKey, email);
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // ⏳ Start loading
      });

      try {
        final Map<String, dynamic> deviceinfo = await getmodeldata();
        // final Map<String, dynamic> deviceinfo = {};
        String deviceinfostring = jsonEncode(deviceinfo);
        debugPrint('android version: $deviceinfostring');
        final payload = {
          "username": email,
          "password": password,
          "deviceinfo":deviceinfostring,
        };
        http.Response? response = await apiCalls("l", email, payload);
        if (response == null) {
          return;
        }
        debugPrint("server response ${response.statusCode} ${response.body} ");
        if (response.statusCode == 200) {
          debugPrint("Expiry remaining11 ");
          final data = jsonDecode(response.body);
          debugPrint("Expiry remaining12 ");
          debugPrint("server response $data");
          debugPrint("Expiry remaining13 ${data["success"] == true}");
          if (data["success"] == true) {
            debugPrint("Expiry remaining1 ");
            final expiresAtStr = data['expires_at'];
            final app_Version = data['app_version'];
            final expiry_date1 = data['expiry_date'];

            // 2. Parse allowed_device (Fixing the key if you meant 'allowed_device' instead of 'allowed_hotel')
            // If you actually meant to check 'allowed_hotel', keep it as is.
            final allowedDeviceVal = int.tryParse(data['allowed_device']?.toString() ?? "0") ?? 0;

            // 3. Parse device_count
            final deviceCountVal = int.tryParse(data['device_count']?.toString() ?? "0") ?? 0;

            // 4. Print
            debugPrint("--- DEBUGGING ---");
            debugPrint("Allowed: $allowedDeviceVal (${allowedDeviceVal.runtimeType})");
            debugPrint("Count: $deviceCountVal (${deviceCountVal.runtimeType})");
            debugPrint("-----------------");

            final expiryDate = DateTime.parse(expiresAtStr);
            await prefs.setString('expiresAtStr', expiresAtStr);
            final expiry_Date = DateTime.parse(expiry_date1);
            await prefs.setString('expiry_date', expiry_date1);
            final extendedExpiry = expiryDate.add(Duration(days: 365));
            final now = DateTime.now();
            final difference = extendedExpiry.difference(now).inDays;
            final role = data['role'];
            debugPrint("Expiry remaining3 ");
            await prefs.setString('role', role);

            // Create a date-only version of "today" by setting the time to midnight
            final today = DateTime(now.year, now.month, now.day);

            // Create a date-only version of the expiry date
            final expiryDateOnly = DateTime(expiry_Date.year, expiry_Date.month, expiry_Date.day);

            // This will be TRUE if the expiry date is any day before today.
            final bool isExpiryToday = expiryDateOnly.isBefore(today);
            debugPrint("Expiry remaining4 ");
            debugPrint("Expiry remaining $difference");
            debugPrint("Expiry remaining ${prefs.getString('expiry_date')}  isExpiryToday $isExpiryToday");
            debugPrint("Check to download ${(app_Version != app_version)}");
            debugPrint("Check to download $app_Version == $app_version");
            // try{
            debugPrint("Check to allowed_device $deviceCountVal ${allowedDeviceVal <= deviceCountVal} == ${allowedDeviceVal}");
            // }catch(e){
            //   debugPrint("🔴 RAW RESPONSE: $e");
            //   debugPrint("Expiry remaining1 $e");
            // }
            if (app_Version != app_version) {
              debugPrint("app_Version $app_Version");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("App version mismatch. Please update your app.",),
                ),
              );
              // _downloadFile();
              _downloadNewApp(app_Version);
            } else if (isExpiryToday) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Your subscription has expired."),
                duration: Duration(minutes :1),),
              );
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
              debugPrint("Expiry remaining5 ");
              if (_rememberMe) {
                debugPrint("Expiry remaining5 ");
                await prefs.setString(AppConstants.usernameKey, email);
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
              // final prefs = await SharedPreferences.getInstance();
              final captain = prefs.getBool('startcaptain') ?? false;
              print_log("Captain $captain");
              if(captain){
                await _initializeFirebase().then((value)=> loadToken());
                // loadToken();
              }
              if (role == 'captain') {
                // final allowedHotelStr =data['allowed_hotel']; // "gk,pradeep,tk,etc"
                // final allowedHotels = allowedHotelStr.split(',',); // ['gk', 'pradeep', 'tk', 'etc']
                await _initializeFirebase().then((value)=> loadToken());
                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                       TableView()
                  ),
                );
              } else {
                debugPrint("Expiry remaining6");
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
        debugPrint("🔴 RAW RESPONSE: $e");
        
        final prefs = await SharedPreferences.getInstance();
        final expiresAtStr = prefs.getString('expiresAtStr');
        final expiry_Date =  prefs.getString('expiry_date');
        debugPrint("Expiry remaining $expiry_Date expiresAtStr $expiresAtStr ");

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
        

        debugPrint("Expiry remaining $expiryDate  isExpiryToday $isExpiryToday");

        final expiryDate1 = DateTime.parse(expiresAtStr!);
        final extendedExpiry = expiryDate1.add(Duration(days: 365));
        final difference = extendedExpiry.difference(now).inDays;
        debugPrint("Expiry remaining $difference");
        

        if (isExpiryToday) {
          // ❌ Subscription expired
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Your subscription has expired."),
            duration: Duration(minutes :1),),
          );
        } else {
          debugPrint("Expiry remaining7");
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
      debugPrint("🔴 RAW RESPONSE: $e");
      // ❌ Subscription expired
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("exception login $e"),
        duration: Duration(minutes :1),),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
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
                    Icon(Icons.lock, size: 80, color: Colors.green.shade700),
                    const SizedBox(height: 16),
                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    Text(
                      app_version,
                      style: TextStyle(
                        fontSize: 22,
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
                    const SizedBox(height: 24),

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

                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _login, // disable when loading
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to signup/forgot password
                      },
                      child: const Text("Forgot Password?"),
                    ),
                    
                    TextButton(
                      onPressed: _showDownloadsFiles,
                      child: Text(
                        "Open Downloads Folder",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
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
