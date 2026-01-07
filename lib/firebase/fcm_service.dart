import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

// This must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print("Message Data: ${message.data}");
  }

  // Check if the message is a "Wake up" type
  if (message.data['type'] == 'wakeup') {
    try {
      final params = CallKitParams(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        nameCaller: message.data['title'] ?? 'Wake Up Alert',
        appName: 'Plastore',
        avatar: 'https://i.pravatar.cc/100', // Replace with your app icon URL
        handle: message.data['body'] ?? 'Incoming Alert',
        type: 0, // 0 - Audio Call, 1 - Video Call
        duration: 30000,
        textAccept: 'Open',
        textDecline: 'Dismiss',
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: false,
          subtitle: 'Missed Alert',
          callbackText: 'Call back',
        ),
        extra: <String, dynamic>{'userId': '1a2b3c4d'},
        headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          backgroundUrl: 'https://i.pravatar.cc/500',
          actionColor: '#4CAF50',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call",
        ),
        ios: const IOSParams(
          iconName: 'CallKitLogo',
          handleType: '',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      if (kDebugMode) {
        print("Error showing CallKit incoming: $e");
      }
    }
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Request Permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }

    // 2. Set Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Get Token
    try {
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      // Trigger wake up logic even in foreground if needed
      if (message.data['type'] == 'wakeup') {
        _firebaseMessagingBackgroundHandler(message);
      }
    });
  }
}
