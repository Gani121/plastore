// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
// import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
// import 'package:flutter_callkit_incoming/entities/android_params.dart';
// import 'package:flutter_callkit_incoming/entities/ios_params.dart';
// import 'package:flutter_callkit_incoming/entities/notification_params.dart';

// Future<void> showCallKit(RemoteMessage message) async {
//   final params = CallKitParams(
//     id: DateTime.now().millisecondsSinceEpoch.toString(),
//     nameCaller: "New Order Received",
//     appName: 'My App',
//     avatar: message.data['avatar'],
//     handle: message.data['handle'] ?? '0000000000',
//     type: 0, // 0 = audio, 1 = video
//     duration: 30000,
//     textAccept: 'Accept',
//     textDecline: 'Reject',
//     extra: {'userId': message.data['userId']},
//     callingNotification: const NotificationParams(
//       showNotification: true,
//       isShowCallback: true,
//       subtitle: 'Calling…',
//       callbackText: 'Hang Up',
//     ),
//     android: const AndroidParams(
//       isCustomNotification: true,
//       isShowLogo: false,
//       ringtonePath: 'test',
//       backgroundColor: '#0955fa',
//       actionColor: '#4CAF50',
//       textColor: '#ffffff',
//       incomingCallNotificationChannelName: 'Incoming Call',
//       missedCallNotificationChannelName: 'Missed Call',
//       isShowCallID: false,
//     ),
//     ios: const IOSParams(
//       iconName: 'CallKitLogo',
//       handleType: 'generic',
//       supportsVideo: true,
//       ringtonePath: 'system_ringtone_default',
//     ),
//   );

//   // Android 13+/14+ permissions (recommended)
//   await FlutterCallkitIncoming.requestNotificationPermission({
//     'title': 'Notification permission',
//     'rationaleMessagePermission':
//         'Notification permission is required to show the incoming call.',
//     'postNotificationMessageRequired':
//         'Please allow notifications in Settings to receive calls.',
//   });
//   await FlutterCallkitIncoming.requestFullIntentPermission();

//   await FlutterCallkitIncoming.showCallkitIncoming(params);
// }
