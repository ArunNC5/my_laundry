import 'package:flutter/material.dart';
import 'package:my_laundry/screens/home/order_detail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'screens/delivery/delivery_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/pickup/pickup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://yrbmifjjqjvrrouefuqq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlyYm1pZmpqcWp2cnJvdWVmdXFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3MzIzMTgsImV4cCI6MjA2ODMwODMxOH0.Rg1mLB3WxiWNBoxaeBBQD1lx8G4fFtzE8-Puwhxn4pU',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyLaundry',
      theme: appTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
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
