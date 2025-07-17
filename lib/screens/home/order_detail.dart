import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/order.dart';
import '../../services/supabase_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final SupabaseService supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _upiNameController = TextEditingController();

  List<Map<String, dynamic>> orderItems = [];
  List<Map<String, dynamic>> payments = [];
  bool isLoadingItems = true;
  bool _isLoading = false;
  bool _editUPI = false;
  bool isLoadingPayments = true;
  String? _upiUrl;

  @override
  void initState() {
    super.initState();
    _loadOrderItems();
    _loadUPIPreferences();
    _loadPayments();
    _amountController.text = widget.order['amount']?.toString() ?? '';
  }

  Future<void> _loadOrderItems() async {
    final id = widget.order['id'].toString();
    final items = await supabaseService.fetchOrderItems(id);
    setState(() {
      orderItems = items;
      isLoadingItems = false;
    });
  }

  Future<void> _loadPayments() async {
    final id = widget.order['id'].toString();
    final paymentData = await supabaseService.fetchPayments(id);
    setState(() {
      payments = paymentData;
      isLoadingPayments = false;
    });
  }

  Future<void> _loadUPIPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _upiIdController.text = prefs.getString('upi_id') ?? '';
    _upiNameController.text = prefs.getString('upi_name') ?? '';
    setState(() {});
  }

  void _generateQr() {
    final amount = _amountController.text.trim();
    final upiId = _upiIdController.text.trim();
    final upiName = _upiNameController.text.trim();

    if (amount.isEmpty || upiId.isEmpty || upiName.isEmpty) return;

    final url = 'upi://pay?pa=$upiId&pn=$upiName&am=$amount&cu=INR';
    setState(() => _upiUrl = url);
  }

  Future<void> _markAsDelivered() async {
    if (!_formKey.currentState!.validate()) return;

    final orderId = widget.order['id'];
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0;

    setState(() => _isLoading = true);

    try {
      await supabaseService.updateOrderStatus(
        orderId: orderId,
        status: 'delivered',
      );
      await supabaseService.insertStatusUpdate(
        orderId: orderId,
        newStatus: 'delivered',
        updatedBy: 'agent',
      );
      await supabaseService.insertPayment(
        orderId: orderId,
        amount: amount,
        method: 'upi',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as delivered')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildUPICard() {
    return _editUPI
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _upiIdController,
          decoration: const InputDecoration(
            labelText: 'UPI ID',
            border: OutlineInputBorder(),
          ),
          validator: (val) => val!.isEmpty ? 'Enter UPI ID' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _upiNameController,
          decoration: const InputDecoration(
            labelText: 'UPI Name',
            border: OutlineInputBorder(),
          ),
          validator: (val) => val!.isEmpty ? 'Enter name' : null,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'upi_id', _upiIdController.text.trim());
              await prefs.setString(
                  'upi_name', _upiNameController.text.trim());
              setState(() => _editUPI = false);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    )
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'UPI ID: ${_upiIdController.text}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _editUPI = true),
              child: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Name: ${_upiNameController.text}',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final Order orderObj = Order(
      id: order['id'].toString(),
      customerName: order['customer_name'] ?? '',
      customerPhone: order['customer_phone'] ?? '',
      customerAddress: order['customer_address'] ?? '',
      status: order['status'] ?? '',
      pickupTime:
          DateTime.tryParse(order['pickup_time'] ?? '') ?? DateTime.now(),
      deliveryDueTime:
          DateTime.tryParse(order['delivery_due_time'] ?? '') ??
          DateTime.now().add(const Duration(days: 1)),
    );

    final createdAt =
        DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    final isDelivered = orderObj.status.toLowerCase() == 'delivered';
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _luxuryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Customer Name', orderObj.customerName),
                  _infoRow('Phone Number', orderObj.customerPhone),
                  _infoRow('Address', orderObj.customerAddress),
                  _infoRow('Created At', dateFormat.format(createdAt)),
                  _infoRow(
                    'Pickup Time',
                    dateFormat.format(orderObj.pickupTime),
                  ),
                  _infoRow(
                    'Delivery Due',
                    dateFormat.format(orderObj.deliveryDueTime),
                  ),
                  _infoRow(
                    'Delivery Status',
                    isDelivered ? 'Delivered ✅' : 'Pending ❌',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _luxuryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items in this order',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (isLoadingItems)
                    const Center(child: CircularProgressIndicator())
                  else if (orderItems.isEmpty)
                    const Text('No items found.')
                  else
                    ...orderItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['item_type'] ?? '-',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              '${item['quantity']} pcs',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),

            if (!isDelivered) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Payment Collection',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildUPICard(),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Enter payment amount (₹)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter an amount';
                                }
                                if (double.tryParse(value.trim()) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            if (_upiUrl != null) ...[
                              const SizedBox(height: 20),
                              Center(
                                child: Column(
                                  children: [
                                    const Text(
                                      'Scan to Pay',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    QrImageView(data: _upiUrl!, size: 200),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _generateQr,
                                icon: const Icon(Icons.qr_code),
                                label: const Text('Generate UPI QR'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton.icon(
                                icon: const Icon(Icons.done_all),
                                label: const Text('Mark as Delivered'),
                                onPressed: _markAsDelivered,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            if (payments.isNotEmpty)
              _luxuryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment History',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...payments.map((p) {
                      final paidOn = DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(DateTime.parse(p['paid_at']));
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${p['amount']} via ${p['payment_method']}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              paidOn,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _luxuryCard({required Widget child}) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
