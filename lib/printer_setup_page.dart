import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as thermal;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class PrinterSetupPage extends StatefulWidget {
  const PrinterSetupPage({super.key});

  @override
  _PrinterSetupPageState createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage>
    with WidgetsBindingObserver {
  List<thermal.BluetoothDevice> _devices = [];
  thermal.BluetoothDevice? _selectedDevice;
  thermal.BluetoothDevice? _selectedKOTDevice;
  String? _savedDeviceName;
  String? _savedKOTDeviceName;
  String? _savedDeviceAddress;
  String? _savedKOTDeviceAddress;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isTesting = false; // ✨ ADD This

  // Bluetooth state
  bool _isBluetoothOn = false;
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;

  // Printer settings
  bool _printQR = true;
  bool _printlogo = true;
  bool _printQRlogo = true;
  bool _printName = true;
  bool miniPrinter = false;
  bool miniPrinterKOT = false;
  bool marathi = false;
  bool _customerName = false;
  double _fontSize = 1; // 1 = small, 2 = medium, 3 = large
  int _charsPerLine = 32; // default width
  int _logoWidth = 200; // default width
  int _logoheight = 200; // default width
  String _qrSize = "5";
  String _paperSize = "2";
  final List<String> _qrSizes = ["1", "2", "3", "4", "5", "6", "7", "8"];
  final List<String> _paperSizes = ["2", "3","4"];
  late TextEditingController _footerController = TextEditingController();

  thermal.BlueThermalPrinter printer = thermal.BlueThermalPrinter.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBluetooth();
    _loadSavedSettings();
    _getBondedDevices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bluetoothStateSubscription?.cancel();
    _footerController.dispose();
    super.dispose();
  }


  // Initialize Bluetooth state monitoring
  void _initializeBluetooth() async {
    // Get initial state
    BluetoothAdapterState initialState =
        await FlutterBluePlus.adapterState.first;
    setState(() {
      _isBluetoothOn = initialState == BluetoothAdapterState.on;
    });

    // Listen for state changes
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _isBluetoothOn = state == BluetoothAdapterState.on;
      });

      // If Bluetooth was turned on, refresh devices
      if (state == BluetoothAdapterState.on) {
        _getBondedDevices();
      }
    });
  }

  // Toggle Bluetooth on/off
  Future<void> _toggleBluetooth() async {
    try {
      if (_isBluetoothOn) {
        await FlutterBluePlus.turnOff();
      } else {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      print("❌ Error toggling Bluetooth: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error toggling Bluetooth: $e")));
    }
  }

  // Detect when app comes to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh bonded devices automatically
      _getBondedDevices();
    }
  }

  // Open Android Bluetooth Settings for pairing
  void openBluetoothSettings() {
    final intent = AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS');
    intent.launch();
  }

  Future<void> _getBondedDevices() async {
    if (!_isBluetoothOn) return;

    setState(() {
      _isScanning = true;
    });

    try {
      _devices = await printer.getBondedDevices();
    } catch (e) {
      print("❌ Error getting devices: $e");
    }

    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _saveSelectedDevice(thermal.BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_printer_address', device.address ?? '');
    await prefs.setString('savedDeviceName', device.name ?? "Unknown");

    setState(() {
      _savedDeviceName = device.name;
      _selectedDevice = device;
      _savedDeviceAddress = device.address; // ✨ NEW: Save address to state
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ Printer saved: ${device.name}")));
  }

// 🛠️ MODIFIED: CRITICAL FIX - Use unique keys for KOT printer
  Future<void> _saveSelectedKOTDevice(thermal.BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    // ✨ NEW: Use KOT-specific keys
    await prefs.setString('saved_KOT_printer_address', device.address ?? '');
    await prefs.setString('savedKOTDeviceName', device.name ?? "Unknown");

    setState(() {
      _selectedKOTDevice = device; // Set the active KOT device
      _savedKOTDeviceName = device.name;
      _savedKOTDeviceAddress = device.address; // ✨ NEW: Save address to state
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ KOT Printer saved: ${device.name}")));
  }
  
  
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedDeviceName = prefs.getString('savedDeviceName');
      _savedDeviceAddress = prefs.getString('saved_printer_address');
      
      _savedKOTDeviceName = prefs.getString('savedKOTDeviceName');
      _savedKOTDeviceAddress = prefs.getString('saved_KOT_printer_address');

      _printQR = prefs.getBool('printQR') ?? true;
      _printlogo = prefs.getBool('printLogo') ?? true;
      _printQRlogo = prefs.getBool('printQRlogo') ?? true;
      _printName = prefs.getBool('printName') ?? true;
      _fontSize = prefs.getDouble('fontSize') ?? 1;
      _charsPerLine = prefs.getInt('charsPerLine') ?? 32;
      _qrSize = prefs.getString('qrSize') ?? "5";
      _paperSize = prefs.getString('paperSize') ?? "2";
      miniPrinter = prefs.getBool('miniPrinter') ?? false;
      miniPrinterKOT = prefs.getBool('miniPrinterKOT') ?? false;
      marathi = prefs.getBool('marathi') ?? false;
      _customerName = prefs.getBool('customerName') ?? false;
      _logoWidth =  prefs.getInt('logoWidth')?? 200;
      _logoheight =  prefs.getInt('logoheight')?? 200;
       _footerController = TextEditingController(text: prefs.getString('footerText')?? "** thank you **");
    });
  }

  // Auto-save settings whenever they change
  Future<void> _autoSaveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printQR', _printQR);
    await prefs.setBool('printLogo', _printlogo);
    await prefs.setBool('printQRlogo', _printQRlogo);
    await prefs.setBool('printName', _printName);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('charsPerLine', _charsPerLine);
    await prefs.setString('qrSize', _qrSize);
    await prefs.setBool('miniPrinter', miniPrinter);
    await prefs.setBool('miniPrinterKOT', miniPrinterKOT);
    await prefs.setBool('marathi', marathi);
    await prefs.setBool('customerName', _customerName);
    await prefs.setInt('logoWidth', _logoWidth);
    await prefs.setInt('logoheight', _logoheight);
    await prefs.setString('paperSize', _paperSize);
    

    // Show a subtle feedback that settings are saved
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text("💾 Settings auto-saved"),
    //     duration: Duration(seconds: 1),
    //     behavior: SnackBarBehavior.floating,
    //   ),
    // );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printQR', _printQR);
    await prefs.setBool('printLogo', _printlogo);
    await prefs.setBool('printQRlogo', _printQRlogo);
    await prefs.setBool('printName', _printName);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('charsPerLine', _charsPerLine);
    await prefs.setString('qrSize', _qrSize);
    await prefs.setString('paperSize', _paperSize);
    await prefs.setBool('miniPrinter', miniPrinter);
    await prefs.setBool('miniPrinterKOT', miniPrinterKOT);
    await prefs.setBool('marathi', marathi);
    await prefs.setBool('customerName', _customerName);
    await prefs.setString('footerText', _footerController.text);
    await prefs.setInt('logoWidth', _logoWidth);
    await prefs.setInt('logoheight', _logoheight);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("💾 Printer settings saved")));
  }

  // Future<void> _connectPrinter() async {
  //   if (!_isBluetoothOn) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("⚠️ Please turn on Bluetooth first")),
  //     );
  //     return;
  //   }

  //   if (_selectedDevice == null) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("⚠️ Select a printer first")));
  //     return;
  //   }

  //   try {
  //     // 1️⃣ Connect
  //     await printer.connect(_selectedDevice!);
  //     setState(() {
  //       _isConnected = true;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("🔌 Connected to ${_selectedDevice!.name}")),
  //     );

  //     // 2️⃣ Wait 2 seconds
  //     await Future.delayed(Duration(seconds: 2));

  //     printer.printNewLine();
  //     printer.printCustom("✅ Test Print Successful", 1, 1);
  //     printer.printNewLine();
  //     printer.printNewLine();
  //     printer.printNewLine();
  //     printer.printNewLine();
  //     await printer.disconnect();
  //     _saveSettings();

  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("🖨️ Test print sent")));
  //   } catch (e) {
  //     print("❌ Connection/Print error: $e");
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
  //   }
  // }

  Future<void> _disconnectPrinter() async {
    await printer.disconnect();
    setState(() {
      _isConnected = false;
    });
  }


Future<void> _connectPrinter() async {
    if (!_isBluetoothOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Please turn on Bluetooth first")),
      );
      return;
    }

    if (_selectedDevice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ Select a Bill printer first")));
      return;
    }

    // ✨ NEW: Check if already testing
    if (_isTesting) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⏳ Test already in progress...")));
      return;
    }

    // ✨ NEW: Set testing flag
    setState(() {
      _isTesting = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⏳ Test Print in progress..."),
      duration: Duration(seconds :10),));
    });

    try {
      // 1️⃣ Connect
      await printer.connect(_selectedDevice!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🔌 Connected to ${_selectedDevice!.name}")),
      );

      // 2️⃣ Wait for connection to be stable
      await Future.delayed(Duration(seconds: 2));

      printer.printNewLine();
      printer.printCustom("✅ BILL PRINTER Test", 1, 1);
      printer.printNewLine();
      printer.printNewLine();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("🖨️ Test print sent")));
    } catch (e) {
      print("❌ Connection/Print error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    } finally {
      // ✨ NEW: Always disconnect and reset the flag
      await printer.disconnect();
      setState(() {
        _isTesting = false;
      });
    }
  }

// ✨ NEW: Test connection for KOT printer
Future<void> _connectKOTPrinter() async {
    if (!_isBluetoothOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Please turn on Bluetooth first")),
      );
      return;
    }

    if (_selectedKOTDevice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ Select a KOT printer first")));
      return;
    }

    // ✨ NEW: Check if already testing
    if (_isTesting) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⏳ Test already in progress...")));
      return;
    }

    // ✨ NEW: Set testing flag
    setState(() {
      _isTesting = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⏳ Test Print in progress..."),
      duration: Duration(seconds :10),));
    });

    try {
      await printer.connect(_selectedKOTDevice!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🔌 Connected to ${_selectedKOTDevice!.name}")),
      );

      await Future.delayed(Duration(seconds: 2));

      printer.printNewLine();
      printer.printCustom("🔥 KOT PRINTER Test", 1, 1);
      printer.printNewLine();
      printer.printNewLine();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("🖨️ KOT Test print sent")));
    } catch (e) {
      print("❌ Connection/Print error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    } finally {
      // ✨ NEW: Always disconnect and reset the flag
      await printer.disconnect();
      setState(() {
        _isTesting = false;
      });
    }
  }


@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🔧 Printer Setup"),
        actions: [IconButton(icon: Icon(Icons.save), onPressed: _saveSettings)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Bluetooth Toggle Card
            Card(
              color: _isBluetoothOn ? Colors.green[50] : Colors.red[50],
              child: ListTile(
                leading: Icon(
                  _isBluetoothOn
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _isBluetoothOn ? Colors.green : Colors.red,
                ),
                title: Text(
                  _isBluetoothOn ? "Bluetooth is ON" : "Bluetooth is OFF",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isBluetoothOn ? Colors.green : Colors.red,
                  ),
                ),
                subtitle: Text(
                  _isBluetoothOn ? "Tap to turn off" : "Tap to turn on",
                ),
                trailing: Switch(
                  value: _isBluetoothOn,
                  onChanged: (value) => _toggleBluetooth(),
                  activeColor: Colors.green,
                ),
                onTap: _toggleBluetooth,
              ),
            ),

            SizedBox(height: 16),

            // 🛠️ MODIFIED: Main Saved Printer Card
            if (_savedDeviceName != null)
              Card(
                color: Colors.green[100],
                child: ListTile(
                  leading: Icon(Icons.print, color: Colors.green[800]),
                  title: Text("✅ Saved Bill Printer: $_savedDeviceName"),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('saved_printer_address');
                      await prefs.remove('savedDeviceName');
                      setState(() {
                        _savedDeviceName = null;
                        // _savedDeviceAddress = null;
                        _selectedDevice = null; // Clear active selection
                      });
                    },
                  ),
                ),
              ),

            // ✨ NEW: KOT Saved Printer Card
            if (_savedKOTDeviceName != null)
              Card(
                color: Colors.red[100], // Red as requested
                child: ListTile(
                  leading: Icon(Icons.kitchen, color: Colors.red[800]),
                  title: Text("🔥 Saved KOT Printer: $_savedKOTDeviceName"),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('saved_KOT_printer_address');
                      await prefs.remove('savedKOTDeviceName');
                      setState(() {
                        _savedKOTDeviceName = null;
                        // _savedKOTDeviceAddress = null;
                        _selectedKOTDevice = null; // Clear active selection
                      });
                    },
                  ),
                ),
              ),

            SizedBox(height: 16),

            Row(
              children: [
                Text(
                  "📡 Paired Printers",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                if (!_isBluetoothOn)
                  Text("Bluetooth Off", style: TextStyle(color: Colors.red))
                else if (_isScanning)
                  CircularProgressIndicator(strokeWidth: 2)
                else
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _getBondedDevices,
                  ),
              ],
            ),

            SizedBox(height: 8),

            // Open Android Bluetooth Settings
            if (_isBluetoothOn)
              ElevatedButton.icon(
                onPressed: openBluetoothSettings,
                icon: Icon(Icons.bluetooth_searching),
                label: Text("Scan / Pair New Devices"),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("⚠️ Please turn on Bluetooth first"),
                    ),
                  );
                },
                icon: Icon(Icons.bluetooth_disabled),
                label: Text("Bluetooth is Off"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              ),

            SizedBox(height: 8),

            // 🛠️ MODIFIED: Printer List
            if (_isBluetoothOn)
              ..._devices.map((device) {
                // Check selection status for both types
                final isSelected = _selectedDevice?.address == device.address;
                final isKOTSelected = _selectedKOTDevice?.address == device.address;
                // final isSelected = _savedDeviceAddress == device.address;
                // final isKOTSelected = _savedKOTDeviceAddress == device.address;
                debugPrint("isSelected $isSelected  ${_selectedDevice?.address} == ${device.address} isKOTSelected} $isKOTSelected");

                // Determine card color
                Color? cardColor;
                if (isKOTSelected) {
                  cardColor = Colors.red[100]; // KOT selection is red
                } else if (isSelected) {
                  cardColor = Colors.green[100]; // Bill selection is green
                }

                return Card(
                  color: cardColor,
                  child: ListTile(
                    // Determine leading icon
                    leading: isKOTSelected
                        ? Icon(Icons.kitchen, color: Colors.red)
                        : (isSelected
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : Icon(Icons.print_outlined)),
                    title: Text(device.name ?? "Unknown"),
                    subtitle: Text(device.address ?? "Unknown Address"),
                    
                    // ✨ NEW: Trailing buttons
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bill Printer Button
                        ElevatedButton(
                          onPressed: () {
                            _saveSelectedDevice(device);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isSelected ? Colors.green : Colors.grey[300],
                            foregroundColor:
                                isSelected ? Colors.white : Colors.black,
                          ),
                          child: Text("Bill"),
                        ),
                        SizedBox(width: 8),
                        // KOT Printer Button
                        ElevatedButton(
                          onPressed: () {
                            _saveSelectedKOTDevice(device);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isKOTSelected ? Colors.red : Colors.grey[300],
                            foregroundColor:
                                isKOTSelected ? Colors.white : Colors.black,
                          ),
                          child: Text("KOT"),
                        ),
                      ],
                    ),
                  ),
                );
              })
            else
              Card(
                child: ListTile(
                  leading: Icon(Icons.bluetooth_disabled, color: Colors.grey),
                  title: Text("Bluetooth is turned off"),
                  subtitle: Text("Turn on Bluetooth to see paired printers"),
                ),
              ),

            SizedBox(height: 20),
            Divider(),
            Text("⚙️ Printer Settings", style: TextStyle(fontSize: 16)),

            // ... (All your settings Toggles, Sliders, and TextFields remain here)
            // ... (Card for "Print QR Code")
            // ... (Card for "Print LOGO")
            // ... (Card for "Print Business Name")
            // ... (SwitchListTile for "print logo in QR")
            // ... (SwitchListTile for "Mini Printer")
            // ... (SwitchListTile for "Marathi Bill")
            // ... (SwitchListTile for "customer name on print")
            // ... (Padding for "QR Size")
            // ... (Padding for "Paper Size in inch")
            // ... (Padding for "Characters Per Line")
            // ... (Padding for "LOGO Width")
            // ... (Padding for "LOGO Height")
            // ... (Padding for "Footer")
            // ... (ListTile for "Font Size")
            Card(
              child: ListTile(
                title: Text("Print QR Code"),
                subtitle: Text(
                  _printQR
                      ? "ON - QR codes will be printed"
                      : "OFF - QR codes will be skipped",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _printQR ? "ON" : "OFF",
                      style: TextStyle(
                        color: _printQR ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Switch(
                      value: _printQR,
                      onChanged: (val) {
                        setState(() {
                          _printQR = val;
                        });
                        _autoSaveSettings(); // Auto-save when changed
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
             // Print LOGO Toggle with ON/OFF labels
            Card(
              child: ListTile(
                title: Text("Print LOGO"),
                subtitle: Text(
                  _printlogo
                      ? "ON - LOGO will be printed"
                      : "OFF - LOGO will be skipped",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _printlogo ? "ON" : "OFF",
                      style: TextStyle(
                        color: _printlogo ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Switch(
                      value: _printlogo,
                      onChanged: (val) {
                        setState(() {
                          _printlogo = val;
                        });
                        _autoSaveSettings(); // Auto-save when changed
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            // Print QR Toggle with ON/OFF labels
            Card(
              child: ListTile(
                title: Text("Print Business Name"),
                subtitle: Text(
                  _printName
                      ? "ON - Business Name will be printed"
                      : "OFF - Business Name will be skipped",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _printName ? "ON" : "OFF",
                      style: TextStyle(
                        color: _printName ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Switch(
                      value: _printName,
                      onChanged: (val) {
                        setState(() {
                          _printName = val;
                        });
                        _autoSaveSettings(); // Auto-save when changed
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            SwitchListTile(
              title: Text("print logo in QR"),
              value: _printQRlogo,
              onChanged: (val) {
                setState(() {
                  _printQRlogo = val;
                });
                _autoSaveSettings(); // Auto-save when changed
              },
            ),

            SwitchListTile(
              title: Text("Mini Printer"),
              value: miniPrinter,
              onChanged: (val) {
                setState(() {
                  miniPrinter = val;
                });
                _autoSaveSettings(); // Auto-save when changed
              },
            ),
            SwitchListTile(
              title: Text("KOT Mini Printer"),
              value: miniPrinterKOT,
              onChanged: (val) {
                setState(() {
                  miniPrinterKOT = val;
                });
                _autoSaveSettings(); // Auto-save when changed
              },
            ),
            SwitchListTile(
              title: Text("Marathi Bill"),
              value: marathi,
              onChanged: (val) {
                setState(() {
                  marathi = val;
                });
                _autoSaveSettings(); // Auto-save when changed
              },
            ),
            //customer name on print
            SwitchListTile(
              title: Text("customer name on print"),
              value: _customerName,
              onChanged: (val) {
                setState(() {
                  _customerName = val;
                });
                _autoSaveSettings(); // Auto-save when changed
              },
            ),
            //selection
            Padding(
              // Add padding to mimic the spacing of a ListTile
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), 
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Vertically center the text and field
                children: [
                  // The "name" or label
                  Expanded(
                    child: Text(
                      "QR Size",
                      style: TextStyle(fontSize: 16.0), // Optional: style to match title
                    ),
                  ),
                  SizedBox(width: 16.0), // Add some spacing
                  
                  // The "selection type" or input field
                  // Wrap in a Container to get the border effect like OutlineInputBorder
                  Container(
                    width: 120.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0), // Padding inside the border
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.0), // Matches border radius
                      border: Border.all(color: Colors.grey.shade600, width: 1.0), // Mimics OutlineInputBorder
                    ),
                    child: DropdownButtonHideUnderline( // Hides the default underline
                      child: DropdownButton<String>(
                        value: _qrSizes.contains(_qrSize) ? _qrSize : "5",
                        isExpanded: true, // Expands to fill the Container's width
                        isDense: true, // Makes it vertically compact
                        onChanged: (val) {
                          setState(() => _qrSize = val ?? "5");
                          _autoSaveSettings();
                        },
                        items: _qrSizes.map((size) => DropdownMenuItem(value: size,child: Text(size),)).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            //selection
            Padding(
              // Add padding to mimic the spacing of a ListTile
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), 
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Vertically center the text and field
                children: [
                  // The "name" or label
                  Expanded(
                    child: Text(
                      "Paper Size in inch",
                      style: TextStyle(fontSize: 16.0), // Optional: style to match title
                    ),
                  ),
                  SizedBox(width: 16.0), // Add some spacing
                  
                  // The "selection type" or input field
                  // Wrap in a Container to get the border effect like OutlineInputBorder
                  Container(
                    width: 120.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0), // Padding inside the border
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.0), // Matches border radius
                      border: Border.all(color: Colors.grey.shade600, width: 1.0), // Mimics OutlineInputBorder
                    ),
                    child: DropdownButtonHideUnderline( // Hides the default underline
                      child: DropdownButton<String>(
                        value: _paperSizes.contains(_paperSize) ? _paperSize : "2",
                        isExpanded: true, // Expands to fill the Container's width
                        isDense: true, // Makes it vertically compact
                        onChanged: (val) {
                          setState(() => _paperSize = val ?? "2");
                          _autoSaveSettings();
                        },
                        items: _paperSizes.map((size) => DropdownMenuItem(value: size,child: Text(size),)).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            //input
            Padding(
              // Add padding to mimic the spacing of a ListTile
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Vertically center the text and field
                children: [
                  // The "name" or label
                  Expanded(
                    child: Text(
                      "Characters Per Line",
                      style: TextStyle(fontSize: 16.0), // Optional: style to match title
                    ),
                  ),
                  SizedBox(width: 16.0), // Add some spacing
                  
                  // The "selection type" or input field
                  SizedBox(
                    width: 100.0, // Give the TextField a fixed width
                    child: TextField(
                      // ✨ NEW: Set controller to display the loaded value
                      controller: TextEditingController(text: _charsPerLine.toString()),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center, // Center the number
                      decoration: InputDecoration(
                        hintText: "e.g. 32",
                        border: OutlineInputBorder(),
                        isDense: true, // Makes the field more compact
                        contentPadding: EdgeInsets.all(12.0), // Adjust internal padding
                      ),
                      onChanged: (val) {
                        setState(() {
                          _charsPerLine = int.tryParse(val) ?? 32;
                        });
                        _autoSaveSettings(); // Auto-save when changed
                      },
                    ),
                  ),
                ],
              ),
            ),
                        //input
            Padding(
              // Add padding to mimic the spacing of a ListTile
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Vertically center the text and field
                children: [
                  // The "name" or label
                  Expanded(
                    child: Text(
                      "LOGO Width",
                      style: TextStyle(fontSize: 16.0), // Optional: style to match title
                    ),
                  ),
                  SizedBox(width: 16.0), // Add some spacing
                  
                  // The "selection type" or input field
                  SizedBox(
                    width: 100.0, // Give the TextField a fixed width
                    child: TextField(
                      // ✨ NEW: Set controller to display the loaded value
                      controller: TextEditingController(text: _logoWidth.toString()),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center, // Center the number
                      decoration: InputDecoration(
                        hintText: "e.g. 200 - 800",
                        border: OutlineInputBorder(),
                        isDense: true, // Makes the field more compact
                        contentPadding: EdgeInsets.all(12.0), // Adjust internal padding
                      ),
                      onChanged: (val) {
                        setState(() {
                          _logoWidth = int.tryParse(val) ?? 200;
                        });
                        _autoSaveSettings(); // Auto-save when changed
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              // Add padding to mimic the spacing of a ListTile
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Vertically center the text and field
                children: [
                  // The "name" or label
                  Expanded(
                    child: Text(
                      "LOGO Height",
                      style: TextStyle(fontSize: 16.0), // Optional: style to match title
                    ),
                  ),
                  SizedBox(width: 16.0), // Add some spacing
                  
                  // The "selection type" or input field
                  SizedBox(
                    width: 100.0, // Give the TextField a fixed width
                    child: TextField(
                       // ✨ NEW: Set controller to display the loaded value
                      controller: TextEditingController(text: _logoheight.toString()),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center, // Center the number
                      decoration: InputDecoration(
                        hintText: "e.g. 200 - 800",
                        border: OutlineInputBorder(),
                        isDense: true, // Makes the field more compact
                        contentPadding: EdgeInsets.all(12.0), // Adjust internal padding
                      ),
                      onChanged: (val) {
                        setState(() {
                          _logoheight = int.tryParse(val) ?? 200;
                        });
                        _autoSaveSettings(); // Auto-save when changed
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      "Footer",
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  SizedBox(
                    width: 250.0,
                    child: TextField(
                      controller: _footerController,
                      keyboardType: TextInputType.text,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: "e.g. Thank You",
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.all(12.0),
                      ),
                      onChanged: (val) {
                         // ✨ NEW: Auto-save on change for text field
                         _autoSaveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            ListTile(
              title: Text("Font Size"),
              subtitle: Slider(
                value: _fontSize,
                min: 1,
                max: 3,
                divisions: 2,
                label: _fontSize == 1
                    ? "Small"
                    : _fontSize == 2
                    ? "Medium"
                    : "Large",
                onChanged: (val) {
                  setState(() {
                    _fontSize = val;
                  });
                  _autoSaveSettings(); // Auto-save when changed
                },
              ),
            ),


            Divider(),
            // 🛠️ MODIFIED: Test Buttons in a Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.receipt_long),
                    label: Text("Test Bill Printer"),
                    onPressed: _connectPrinter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBluetoothOn ? Colors.green[600] : Colors.grey,
                      foregroundColor: Colors.white
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.kitchen),
                    label: Text("Test KOT Printer"),
                    onPressed: _connectKOTPrinter, // ✨ NEW function call
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBluetoothOn ? Colors.red[600] : Colors.grey,
                      foregroundColor: Colors.white
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


}
