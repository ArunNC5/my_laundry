import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../widgets/order_card.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService supabaseService = SupabaseService();
  List orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOrderList();
  }

  Future<void> fetchOrderList() async {
    final data = await supabaseService.fetchOrders();
    setState(() {
      orders = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'MyLaundry',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
            ? const Center(
                child: Text(
                  'No orders yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : RefreshIndicator(
                onRefresh: fetchOrderList,
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      order: order,
                      onViewDetails: () {
                        Navigator.pushNamed(
                          context,
                          '/order_detail',
                          arguments: order,
                        );
                      },
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/pickup');
          if (result == true) {
            fetchOrderList();
          }
        },
        backgroundColor: const Color(0xFF6A11CB),
        tooltip: 'Add Order',
        elevation: 6,
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }
}
