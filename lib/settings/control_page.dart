// pages/control_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/utilities.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({Key? key}) : super(key: key);

  @override
  _ControlPageState createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  bool _isOn = false;
  bool _isLoading = true;
  final String _prefsKey = 'demo';

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  // Load saved state from SharedPreferences
  Future<void> _loadInitialState() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _isOn = prefs.getBool(_prefsKey) ?? false;
        _isLoading = false;
      });
    } catch (e) {
      print_log('Error loading state: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save state to SharedPreferences
  Future<void> _saveButtonState(bool value) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
      setState(() {
        _isOn = value;
      });
      
      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Button turned ON' : 'Button turned OFF'),
          duration: Duration(seconds: 1),
          backgroundColor: value ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      print_log('Error saving state: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving state'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control Panel'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  _buildStatusCard(),
                  SizedBox(height: 24),
                  
                  // Control Section
                  _buildControlSection(),
                ],
              ),
            ),
    );
  }

  // Build status card
  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              _isOn ? Icons.power : Icons.power_off,
              size: 60,
              color: _isOn ? Colors.green : Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              _isOn ? 'System is ON' : 'System is OFF',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isOn ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Default state is OFF. Toggle to enable API calls.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build control section
  Widget _buildControlSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Demo Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'OFF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: !_isOn ? Colors.red : Colors.grey,
                    ),
                  ),
                  Switch(
                    value: _isOn,
                    onChanged: _saveButtonState,
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red[100],
                  ),
                  Text(
                    'ON',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isOn ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Current State: ${_isOn ? 'Enabled' : 'Disabled'}',
              style: TextStyle(
                fontSize: 16,
                color: _isOn ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }





}
