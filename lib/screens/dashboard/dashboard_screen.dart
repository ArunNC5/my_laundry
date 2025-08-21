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
  int pendingOrders = 0;
  int pickedUpOrders = 0;
  int deliveredOrders = 0;
  double totalRevenue = 0;

  bool loading = true;

  String selectedFilter = 'Today';
  DateTime? customStart;
  DateTime? customEnd;

  final filters = [
    'Today',
    'Yesterday',
    'This Week',
    'Last Week',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'This Year',
    'Last Year',
    'All Time',
    'Custom Range',
  ];

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    final orders = await supabaseService.fetchOrders();

    DateTime now = DateTime.now();
    Iterable<dynamic> filteredOrders;

    if (selectedFilter == 'Today') {
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.year == now.year && d.month == now.month && d.day == now.day;
      });
    } else if (selectedFilter == 'Yesterday') {
      final y = now.subtract(const Duration(days: 1));
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.year == y.year && d.month == y.month && d.day == y.day;
      });
    } else if (selectedFilter == 'This Week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            d.isBefore(now.add(const Duration(days: 1)));
      });
    } else if (selectedFilter == 'Last Week') {
      final startOfLastWeek = now.subtract(Duration(days: now.weekday + 6));
      final endOfLastWeek = startOfLastWeek.add(const Duration(days: 6));
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.isAfter(startOfLastWeek.subtract(const Duration(seconds: 1))) &&
            d.isBefore(endOfLastWeek.add(const Duration(days: 1)));
      });
    } else if (selectedFilter == 'Last 7 Days') {
      final lastWeek = now.subtract(const Duration(days: 7));
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.isAfter(lastWeek);
      });
    } else if (selectedFilter == 'Last 30 Days') {
      final lastMonth = now.subtract(const Duration(days: 30));
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.isAfter(lastMonth);
      });
    } else if (selectedFilter == 'This Month') {
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.year == now.year && d.month == now.month;
      });
    } else if (selectedFilter == 'Last Month') {
      final lastMonth = DateTime(now.year, now.month - 1);
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.year == lastMonth.year && d.month == lastMonth.month;
      });
    } else if (selectedFilter == 'This Year') {
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.year == now.year;
      });
    } else if (selectedFilter == 'Last Year') {
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.year == now.year - 1;
      });
    } else if (selectedFilter == 'Custom Range' &&
        customStart != null &&
        customEnd != null) {
      filteredOrders = orders.where((o) {
        final d = DateTime.parse(o['created_at']);
        return d.isAfter(customStart!.subtract(const Duration(days: 1))) &&
            d.isBefore(customEnd!.add(const Duration(days: 1)));
      });
    } else {
      // All Time
      filteredOrders = orders;
    }

    // Fetch payments for filtered orders
    final paymentFutures = filteredOrders
        .map((order) => supabaseService.fetchPayments(order['id']))
        .toList();
    final paymentResults = await Future.wait(paymentFutures);
    final payments = paymentResults.expand((pList) => pList).toList();

    setState(() {
      totalOrders = filteredOrders.length;
      pendingOrders =
          filteredOrders.where((o) => o['status'] == 'pending').length;
      pickedUpOrders =
          filteredOrders.where((o) => o['status'] == 'picked_up').length;
      deliveredOrders =
          filteredOrders.where((o) => o['status'] == 'delivered').length;
      totalRevenue = payments.fold(
        0.0,
            (sum, p) => sum + (p['amount'] as num).toDouble(),
      );
      loading = false;
    });
  }

  Widget buildStatCard(
      String title, String value, IconData icon, List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (range != null) {
      setState(() {
        customStart = range.start;
        customEnd = range.end;
        selectedFilter = 'Custom Range';
        loading = true;
      });
      await loadAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard - $selectedFilter',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
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
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'Custom Range') {
                await _pickCustomRange();
              } else {
                setState(() {
                  selectedFilter = value;
                  loading = true;
                });
                await loadAnalytics();
              }
            },
            itemBuilder: (context) {
              return filters
                  .map((f) => PopupMenuItem(value: f, child: Text(f)))
                  .toList();
            },
            icon: const Icon(Icons.filter_list, color: Colors.white),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadAnalytics,
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            buildStatCard(
              'Total Orders',
              '$totalOrders',
              Icons.shopping_bag,
              [Colors.blueAccent, Colors.lightBlue],
            ),
            buildStatCard(
              'Pending Orders',
              '$pendingOrders',
              Icons.pending_actions,
              [Colors.redAccent, Colors.red],
            ),
            buildStatCard(
              'Picked Up',
              '$pickedUpOrders',
              Icons.local_shipping,
              [Colors.orangeAccent, Colors.deepOrange],
            ),
            buildStatCard(
              'Delivered',
              '$deliveredOrders',
              Icons.done_all,
              [Colors.greenAccent, Colors.green],
            ),
            buildStatCard(
              'Revenue',
              '₹${totalRevenue.toStringAsFixed(2)}',
              Icons.currency_rupee,
              [Colors.purpleAccent, Colors.deepPurple],
            ),
          ],
        ),
      ),
    );
  }
}
