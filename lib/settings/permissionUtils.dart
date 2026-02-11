import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:test1/utilities.dart';

class PermissionUtils {

  
  // Request all necessary permissions
  static Future<bool> requestAllPermissions() async {
    
    // sleep(1,"s");
    final List<Permission> permissions = _getRequiredPermissions();
    final results = await permissions.request();
    
    // Check if all permissions are granted
    final allGranted = results.values.every((status) => status.isGranted);
    
    if (!allGranted) {
      // Some permissions are denied - show rationale
      final deniedPermissions = results.entries
          .where((entry) => !entry.value.isGranted)
          .map((entry) => entry.key)
          .toList();
      
      //debugPrint('Denied permissions: $deniedPermissions');
      
      // Show dialog to explain why permissions are needed
      await _showPermissionRationaleDialog(deniedPermissions);
    }
    
    return allGranted;
  }
  
  // Get list of required permissions based on platform
  static List<Permission> _getRequiredPermissions() {
    
    // Always required
    final List<Permission> permissions = [
      Permission.notification,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      // Permission.sms,
      // Permission.storage,
      // Permission.contacts,
      // Permission.manageExternalStorage,
      // Permission.photos,
    ];
    
    // Android-specific permissions
    if (Platform.isAndroid) {
      // Location is required for Bluetooth scanning on Android 12+
      permissions.add(Permission.locationWhenInUse);
      permissions.add(Permission.location);
    }
    
    return permissions;
  }
  
  // Check if all required permissions are granted
  static Future<bool> checkAllPermissions() async {
    final permissions = _getRequiredPermissions();
    for (var permission in permissions) {
      if (!await permission.isGranted) {
        return false;
      }
    }
    return true;
  }
  
  // Show permission rationale dialog
  static Future<void> _showPermissionRationaleDialog(List<Permission> deniedPermissions) async {
    // Implement your dialog logic here
    // You can use showDialog or any dialog package
    String message = 'This app requires the following permissions to function properly:\n\n';
    
    for (var permission in deniedPermissions) {
      message += '• ${_getPermissionDescription(permission)}\n';
    }
    
    message += '\nPlease grant these permissions in app settings.';
    
    // Show dialog using your preferred method
    // Example: showDialog(...)
  }
  
  // Get user-friendly permission descriptions
  static String _getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.bluetooth:
        return 'Bluetooth: To connect to printers';
      case Permission.bluetoothConnect:
        return 'Bluetooth Connect: To pair with devices';
      case Permission.bluetoothScan:
        return 'Bluetooth Scan: To discover nearby printers';
      case Permission.location:
      case Permission.locationWhenInUse:
        return 'Location: Required for Bluetooth device discovery';
      case Permission.notification:
        return 'Notifications: To show print status and alerts';
      default:
        return 'Required permission';
    }
  }
  
  // Open app settings
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}