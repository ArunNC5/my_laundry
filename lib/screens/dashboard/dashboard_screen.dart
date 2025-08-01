import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService supabaseService = SupabaseService();

  int totalOrders = 0;
  int pickedUpOrders = 0;
  int deliveredOrders = 0;
  double totalRevenue = 0;
  int totalServices = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    final orders = await supabaseService.fetchOrders();
    final payments = <Map<String, dynamic>>[];
    for (final order in orders) {
      final orderPayments = await supabaseService.fetchPayments(order['id']);
      payments.addAll(orderPayments);
    }
    final services = await supabaseService.fetchAllServices();

    setState(() {
      totalOrders = orders.length;
      pickedUpOrders = orders.where((o) => o['status'] == 'picked_up').length;
      deliveredOrders = orders.where((o) => o['status'] == 'delivered').length;
      totalRevenue = payments.fold(
        0.0,
        (sum, p) => sum + (p['amount'] as num).toDouble(),
      );
      totalServices = services.length;
      loading = false;
    });
  }

  Widget buildCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  buildCard(
                    'Total Orders',
                    '$totalOrders',
                    Icons.shopping_bag,
                    Colors.blue,
                  ),
                  buildCard(
                    'Picked Up Orders',
                    '$pickedUpOrders',
                    Icons.local_shipping,
                    Colors.orange,
                  ),
                  buildCard(
                    'Delivered Orders',
                    '$deliveredOrders',
                    Icons.done_all,
                    Colors.green,
                  ),
                  buildCard(
                    'Total Revenue',
                    '₹${totalRevenue.toStringAsFixed(2)}',
                    Icons.currency_rupee,
                    Colors.purple,
                  ),
                  buildCard(
                    'Total Services',
                    '$totalServices',
                    Icons.build,
                    Colors.teal,
                  ),
                ],
              ),
            ),
    );
  }
}
