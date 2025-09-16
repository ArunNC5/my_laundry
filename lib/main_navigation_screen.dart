import 'package:flutter/material.dart';
import 'package:my_laundry/screens/chat/chat_list_screen.dart';
import 'package:my_laundry/screens/dashboard/dashboard_screen.dart';
import 'package:my_laundry/screens/home/home_screen.dart';
import 'package:my_laundry/screens/services/service_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex; // Optional parameter

  const MainNavigationScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;

  final List<Widget> _screens = [
    DashboardScreen(), // Dashboard
    HomeScreen(), // Orders
    ServicesScreen(), // Services
    ChatListScreen(), // Chats
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // Use the passed index
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 10,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: theme.textTheme.labelLarge,
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.normal,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_laundry_service_outlined),
              activeIcon: Icon(Icons.local_laundry_service),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.design_services_outlined),
              activeIcon: Icon(Icons.design_services),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined),
              activeIcon: Icon(Icons.chat),
              label: 'Chats',
            ),
          ],
        ),
      ),
    );
  }
}
