import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data'; // Required for Int64List
import 'package:firebase_core/firebase_core.dart';
import './../firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:test1/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';


class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Initialize notifications
  static Future<void> initialize() async {
    await _createNotificationChannel();
    await _initializeLocalNotifications();
    await _setupFCM();
  }

  // Create Android notification channel with sound
  static Future<void> _createNotificationChannel() async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'kot_channel',
      'KOT Notifications',
      description: 'Notifications for kitchen orders',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 250, 500]),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    await _notificationsPlugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  // Setup FCM
  static Future<void> _setupFCM() async {
    // Request permissions
    await _firebaseMessaging.requestPermission(
      sound: true,
      badge: true,
      alert: true,
      announcement: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
    );

    final prefs = await SharedPreferences.getInstance();
    
    // Get device token
    print_log("FCM going to create Token in NotificationService ");
    String? token = await FirebaseMessaging.instance.getToken();
    print_log("FCM Token: $token");
    await prefs.setString('device_id', token ?? "");

    // Handle messages
    FirebaseMessaging.onMessage.listen(_showNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
  }

  // Show notification
  static Future<void> _showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _notificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'kot_channel',
            'KOT Notifications',
            channelDescription: 'Notifications for kitchen orders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([500, 250, 500]),
            icon: android.smallIcon,
            color: Colors.blue,
          ),
        ),
      );
    }
  }

  static void _onMessageOpened(RemoteMessage message) {
    print_log('FCM Notification opened: ${message.data}');
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    print_log('FCM Notification recived in background: ${message.data}');
    // await Firebase.initializeApp();
    // await initialize();
    // await _showNotification(message);
    
  }
}