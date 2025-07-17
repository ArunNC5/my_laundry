import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/supabase_service.dart';

class DeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DeliveryScreen({required this.order});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final SupabaseService supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _upiNameController = TextEditingController();

  bool _editUPI = false;
  bool _isLoading = false;
  String? _upiUrl;

  @override
  void initState() {
    super.initState();
    _loadUPIPreferences();
    _amountController.text = widget.order['amount']?.toString() ?? '';
  }

  Future<void> _loadUPIPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _upiIdController.text = prefs.getString('upi_id') ?? '';
    _upiNameController.text = prefs.getString('upi_name') ?? '';
    setState(() {});
  }

  Future<void> _saveUPIPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('upi_id', _upiIdController.text.trim());
    await prefs.setString('upi_name', _upiNameController.text.trim());

    setState(() {
      _editUPI = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('UPI details saved!')));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order marked as delivered')));
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
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _editUPI
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _upiIdController,
              decoration: InputDecoration(
                labelText: 'UPI ID',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val!.isEmpty ? 'Enter UPI ID' : null,
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _upiNameController,
              decoration: InputDecoration(
                labelText: 'UPI Name',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val!.isEmpty ? 'Enter name' : null,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveUPIPreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2575FC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.save),
              label: Text('Save'),
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
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _editUPI = true),
                  child: Text('Edit'),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Name: ${_upiNameController.text}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.order['customer_name'] ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Delivery & Payment',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white), // Make back icon white
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
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivering to:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(customerName, style: TextStyle(fontSize: 16)),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) =>
                        val!.isEmpty ? 'Enter amount' : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildUPICard(),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generateQr,
                icon: Icon(Icons.qr_code),
                label: Text('Generate QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_upiUrl != null) ...[
                SizedBox(height: 24),
                Center(
                  child: Text(
                    'Scan to Pay',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Center(
                  child: QrImageView(
                    data: _upiUrl!,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
              ],
              SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _markAsDelivered,
                icon: Icon(Icons.check),
                label: Text(
                  'Mark as Delivered',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
