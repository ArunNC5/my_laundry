import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_laundry/providers/firebase_messaging_service_provider.dart';
import 'package:my_laundry/screens/home/order_detail.dart';
import 'package:my_laundry/screens/pickup/pickup_screen.dart';
import 'package:my_laundry/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'main_navigation_screen.dart';
import 'screens/delivery/delivery_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local notification setup
  LocalNotificationService.initialize();

  // Firebase init (for FCM)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔹 iOS: request push permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Supabase.initialize(
    url: 'https://yrbmifjjqjvrrouefuqq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlyYm1pZmpqcWp2cnJvdWVmdXFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3MzIzMTgsImV4cCI6MjA2ODMwODMxOH0.Rg1mLB3WxiWNBoxaeBBQD1lx8G4fFtzE8-Puwhxn4pU',
  );

  runApp(MyApp());

  await FirebaseMessaging.instance.subscribeToTopic("all");

  // FCM setup in background
  unawaited(_initFCM());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyLaundry',
      theme: appTheme,
      home: MainNavigationScreen(),
      routes: {
        '/pickup': (context) => PickupScreen(),
        '/delivery': (context) {
          final order =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return DeliveryScreen(order: order);
        },
        '/order_detail': (context) {
          final order =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return OrderDetailScreen(order: order);
        },
      },
    );
  }
}

Future<void> _initFCM() async {
  final messagingService = FirebaseMessagingService();
  await messagingService.setupInteractedMessage();
  await messagingService.getDeviceToken();
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      LocalNotificationService.showNotification(
        message.notification!.title ?? '',
        message.notification!.body ?? '',
      );
    }
  });
}
