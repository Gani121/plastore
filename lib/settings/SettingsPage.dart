import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test1/settings/bill_settings_page.dart';
import 'package:test1/settings/profilepage.dart';
import 'printer_setup_page.dart';
import 'LanguageSelectionPage.dart';
import 'BulkUploadPage.dart';
import '../theme_setting/theme_selector.dart';
import '../theme_setting/theme_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/ReceiptPrintPage.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart';
import 'dart:io';
import 'dart:async';
import 'package:objectbox/objectbox.dart';
import '../database_Module/menu_item.dart';
import 'package:archive/archive.dart';
import 'package:test1/utilities.dart';
import 'package:test1/settings/hideData.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:test1/settings/control_page.dart';



class SettingsPage extends StatelessWidget {
  final Box<MenuItem> menuItemBox;

  SettingsPage({Key? key, required Box<MenuItem> menuItemBox})
      : menuItemBox = menuItemBox,
        super(key: key);
        
  final List<String> settings = [
    "PROFILE SETTINGS",
    "BILLING SETTINGS",
    "PRINT SETTINGS",
    "LOYALTY DISCOUNT SETTINGS",
    "GET MORE CUSTOMERS SETTING",
    "STAFF SETTING",
    "DATABASE MANAGEMENT",
    "UPLOAD PARTIES",
    "START APP SETUP",
    "SELECT LANGUAGE",
    "DEMO MODE",
    "SYNC MENU",
    "APP PASSWORD SETUP",
    "PAGES",
  ];

  final Dio _dio = Dio();


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

  void saveMenuItemsReliably(List<MenuItem> menuItems,BuildContext context) {
    // ❌ Remove all old items first
    if (menuItemBox != null) {
      menuItemBox.removeAll();
      }else{
      print_log("found menuItemBox is null in setting");
    }

    // ✅ Insert fresh items
    for (int i = 0; i < menuItems.length; i++) {
      final item = menuItems[i];
      menuItemBox.put(item);
    }
    screen_massage(context, "Menu Updated Successfully");
  
  }


 Future<void> ApiCallPage(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // force choice
      builder: (ctx) {
        return AlertDialog(
          title: const Text("⚠️ Caution"),
          content: const Text(
            "Syncing with server will delete some entries not updated at the server.\n\n"
            "Do you want to continue?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // ❌ Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // warning color
              ),
              onPressed: () => Navigator.pop(ctx, true), // ✅ Proceed
              child: const Text("Proceed"),
            ),
          ],
        );
      },
    );

    if (proceed != true) {
      //debugPrint("❌ User cancelled sync");
      return;
    }

    // final isVerified = await _askPassword(context);

    if (proceed!) {
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
            saveMenuItemsReliably(menuItems,context);
            downloadHotelZip(hotelName);
            
            print_log("✅ Menu loaded from server: ${menuItems.length} items");
          } else {
            screen_massage(context, "$jsonData");
          }
        } else {
          screen_massage(context, 'HTTP Error: ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (error) {
          screen_massage(context, "Device Not Connected ${error}");
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            themeProvider.primaryColor, //Color.fromARGB(255, 92, 84, 247),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orbipay',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey[200],
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          padding: EdgeInsets.only(top: 20), // 👈 Top margin
          itemCount: settings.length,
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.center, // or Alignment.centerLeft

              child: Container(
                margin: EdgeInsets.only(
                  bottom: 25,
                ), // 👈 spacing between buttons
                child: SizedBox(
                  width: 330,
                  height: 35,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 135, 243),
                      //padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () async {
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(content: Text('Selected: ${index}')),
                      // );

                      //profile setting
                      if (index == 0) {
                       await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfilePage(),
                          ),
                        );
                      }
                      //billing setting
                      if (index == 1) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => billSettingsPage()),
                        );
                      }

                      //printer setting
                      if (index == 2) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PrinterSetupPage()),
                        );
                      }

                      if (index == 6) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BulkUploadPage(),
                          ),
                        );
                      }

                      if (index == 8) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ThemeSelectorPage(),
                          ),
                        );
                      }

                      if (index == 9) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LanguageSelectionPage(),
                          ),
                        );
                      }

                      if (index == 10) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ControlPage(),
                          ),
                        );
                      }
                      
                      if (index == 11) {
                        //debugPrint("going to apicall");
                        await ApiCallPage(context);
                      }

                      if (index == 12) {
                        //debugPrint("going to showChangePasswordDialog");
                        showChangePasswordDialog(context);
                      }

                      if (index == 13) {
                        final bool verifyed = await askPassword(context);
                        // print_log(  "verifyed in setting $verifyed");
                        if (verifyed) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => hideData(),
                            ),
                          );
                        }
                      }


                      if (index == 14) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReceiptPage(),
                          ),
                        );
                      }

                      
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${index+1}. ${settings[index]}',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void showChangePasswordDialog(BuildContext context) {
  final TextEditingController _oldPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      String? errorMsg;

      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text("Change Password"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _oldPwdController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Old Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _newPwdController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "New Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(errorMsg!, style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final savedPwd = prefs.getString(AppConstants.appPasswordKey) ?? "1234";

                  if (_oldPwdController.text != savedPwd) {
                    setState(() {
                      errorMsg = "❌ Old password is incorrect";
                    });
                    return;
                  }

                  if (_newPwdController.text.trim().isEmpty) {
                    setState(() {
                      errorMsg = "❌ New password cannot be empty";
                    });
                    return;
                  }

                  await prefs.setString(AppConstants.appPasswordKey,_newPwdController.text.trim(),);

                  Navigator.pop(context); // close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ Password updated successfully!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text("Save"),
              ),
            ],
          );
        },
      );
    },
  );
}

void Askforpasword(BuildContext context) {
  final TextEditingController _oldPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      String? errorMsg;

      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text("Enter Password"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TextField(
                //   controller: _oldPwdController,
                //   obscureText: true,
                //   keyboardType: TextInputType.number,
                //   decoration: InputDecoration(
                //     labelText: "Old Password",
                //     border: OutlineInputBorder(),
                //   ),
                // ),
                // SizedBox(height: 10),
                TextField(
                  controller: _newPwdController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Enter Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(errorMsg!, style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final savedPwd = prefs.getString(AppConstants.appPasswordKey) ?? "1234";

                  if (_oldPwdController.text != savedPwd) {
                    setState(() {
                      errorMsg = "❌ Old password is incorrect";
                    });
                    return;
                  }

                  if (_newPwdController.text.trim().isEmpty) {
                    setState(() {
                      errorMsg = "❌ New password cannot be empty";
                    });
                    return;
                  }

                  await prefs.setString(AppConstants.appPasswordKey,_newPwdController.text.trim(),);

                  Navigator.pop(context); // close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ Password updated successfully!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text("Save"),
              ),
            ],
          );
        },
      );
    },
  );
}


