// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import '../firebase/call_service.dart';

// class SimpleFCMHandler {
//   static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

//   static Future<void> initialize() async {
//     await Firebase.initializeApp();
    
//     // Request permissions
//     await _messaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
    
//     // Get token
//     String? token = await _messaging.getToken();
//     print('FCM Token: $token');
    
//     // Setup handlers
//     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
//     FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    
//     // Handle initial message (app was terminated)
//     RemoteMessage? initialMessage = await _messaging.getInitialMessage();
//     if (initialMessage != null) {
//       _handleMessage(initialMessage);
//     }
//   }

//   static void _handleForegroundMessage(RemoteMessage message) {
//     print('Foreground message: ${message.notification?.title}');
//      _handleMessage(message);
//     // Firebase handles notification display automatically
//   }

//   static void _handleBackgroundMessage(RemoteMessage message) {
//     print('Background message opened: ${message.notification?.title}');
//     _handleMessage(message);
//   }

//   static void _handleMessage(RemoteMessage message) async {
//     // Handle your message logic here
//     print('Message data: ${message.data}');
//     await showCallKit(message);
  
//   }

//   static Future<void> subscribeToTopics() async {
//     await _messaging.subscribeToTopic('all_users');
//     await _messaging.subscribeToTopic('orders');
//   }
// }