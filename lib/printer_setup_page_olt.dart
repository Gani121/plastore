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
  String? _savedDeviceName;
  bool _isScanning = false;
  bool _isConnected = false;

  // Bluetooth state
  bool _isBluetoothOn = false;
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;

  // Printer settings
  bool _printQR = true;
  bool _printQRlogo = true;
  bool miniPrinter = false;
  double _fontSize = 1; // 1 = small, 2 = medium, 3 = large
  int _charsPerLine = 32; // default width
  String _qrSize = "Medium"; // Small / Medium / Large

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
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ Printer saved: ${device.name}")));
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedDeviceName = prefs.getString('savedDeviceName');
      _printQR = prefs.getBool('printQR') ?? true;
      _printQRlogo = prefs.getBool('printQRlogo') ?? true;
      _fontSize = prefs.getDouble('fontSize') ?? 1;
      _charsPerLine = prefs.getInt('charsPerLine') ?? 32;
      _qrSize = prefs.getString('qrSize') ?? "Medium";
      miniPrinter = prefs.getBool('miniPrinter') ?? false;
    });
  }

  // Auto-save settings whenever they change
  Future<void> _autoSaveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printQR', _printQR);
    await prefs.setBool('printQRlogo', _printQRlogo);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('charsPerLine', _charsPerLine);
    await prefs.setString('qrSize', _qrSize);
    await prefs.setBool('miniPrinter', miniPrinter);

    // Show a subtle feedback that settings are saved
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("💾 Settings auto-saved"),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printQR', _printQR);
    await prefs.setBool('printQRlogo', _printQRlogo);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('charsPerLine', _charsPerLine);
    await prefs.setString('qrSize', _qrSize);
    await prefs.setBool('miniPrinter', miniPrinter);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("💾 Printer settings saved")));
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
      ).showSnackBar(SnackBar(content: Text("⚠️ Select a printer first")));
      return;
    }

    try {
      // 1️⃣ Connect
      await printer.connect(_selectedDevice!);
      setState(() {
        _isConnected = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🔌 Connected to ${_selectedDevice!.name}")),
      );

      // 2️⃣ Wait 2 seconds
      await Future.delayed(Duration(seconds: 2));

      printer.printNewLine();
      printer.printCustom("✅ Test Print Successful", 1, 1);
      printer.printNewLine();
      printer.printNewLine();
      printer.printNewLine();
      printer.printNewLine();
      await printer.disconnect();
      _saveSettings();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("🖨️ Test print sent")));
    } catch (e) {
      print("❌ Connection/Print error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

  Future<void> _disconnectPrinter() async {
    await printer.disconnect();
    setState(() {
      _isConnected = false;
    });
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

            if (_savedDeviceName != null)
              Card(
                color: Colors.green[100],
                child: ListTile(
                  title: Text("✅ Saved Printer: $_savedDeviceName"),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('saved_printer_address');
                      await prefs.remove('savedDeviceName');
                      setState(() {
                        _savedDeviceName = null;
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

            // Printer List
            if (_isBluetoothOn)
              ..._devices.map((device) {
                final isSelected = _selectedDevice?.address == device.address;
                return Card(
                  color: isSelected ? Colors.green[100] : null,
                  child: ListTile(
                    leading: isSelected
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : Icon(Icons.print),
                    title: Text(device.name ?? "Unknown"),
                    subtitle: Text(device.address ?? "Unknown Address"),
                    trailing: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDevice = device;
                        });
                        _saveSelectedDevice(device);
                      },
                      child: Text("Select"),
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

            // Print QR Toggle with ON/OFF labels
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
            ListTile(
              title: Text("Characters Per Line"),
              subtitle: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "e.g. 32",
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _charsPerLine = int.tryParse(val) ?? 32;
                  });
                  _autoSaveSettings(); // Auto-save when changed
                },
              ),
            ),
            ListTile(
              title: Text("QR Size"),
              subtitle: DropdownButton<String>(
                value: _qrSize,
                isExpanded: true,
                onChanged: (val) {
                  setState(() {
                    _qrSize = val!;
                  });
                  _autoSaveSettings(); // Auto-save when changed
                },
                items: ["Small", "Medium", "Large"]
                    .map(
                      (size) =>
                          DropdownMenuItem(value: size, child: Text(size)),
                    )
                    .toList(),
              ),
            ),
            Divider(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.usb),
                    label: Text("Test Connection"),
                    onPressed: _connectPrinter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBluetoothOn ? null : Colors.grey,
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
