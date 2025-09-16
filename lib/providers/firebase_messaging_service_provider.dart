import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../main.dart';

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((
    ref,
    ) {
  return FirebaseMessagingService();
});

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<String?> getDeviceToken() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await _messaging.getToken();
      print("✅ Device FCM Token: $token");
      return token;
    } catch (e) {
      if (e is FirebaseException) {
        print("FirebaseException in getDeviceToken: ${e.message}");
      } else {
        print("Error in getDeviceToken: $e");
      }
      return null;
    }
  }

  Future<void> setupInteractedMessage() async {
    // Handle notification when app is launched from terminated state
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessage(initialMessage);
    }

    // Handle notification when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message);
    });
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    final data = message.data;
    print("Notification clicked with message: ${message.messageId}");
  }
}
