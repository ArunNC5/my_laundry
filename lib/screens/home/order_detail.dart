import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/order.dart';
import '../../services/supabase_service.dart';
import '../pickup/pickup_screen.dart'; // Ensure this path is correct

// const phoneNumberId = '784090628116998';
const phoneNumberId = '912562591937026';
const accessToken =
    'EAAQzmZAIQO8wBPXVeKJJ1vwRIEPOjus4eqZCzLnTZAs7AsZBWrTZAlUeMPftALFGIgin45fydHT1jBLZACzuCZB7eixv77A6EkMgmZBTEP8V0ymO17ThLsXBjHsPSGnVVmaBeUc8bZChsNWN7IliaEqBj1zo8mw4VBzWzFGZCG9qAyhjJKwCWyLikQ7dEcnmZB5ZBylEWQZDZD';

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
  bool isLoadingPayments = true;
  String? _upiUrl;

  String _currentOrderStatus = '';

  @override
  void initState() {
    super.initState();
    _currentOrderStatus = widget.order['status'] ?? 'pending';
    _loadOrderItems();
    _loadPayments();
    // Ensure the initial amount controller text is a valid number string
    _amountController.text = (widget.order['total_price'] is num)
        ? widget.order['total_price'].toString()
        : (int.tryParse(widget.order['total_price']?.toString() ?? '0') ?? 0)
              .toString();
    _loadUpiDetailsFromSupabase();
  }

  Future<void> _loadUpiDetailsFromSupabase() async {
    try {
      final upiData = await supabaseService.fetchUPIDetails();
      setState(() {
        _upiIdController.text = upiData?['upi_id'] ?? '9962661626@upi';
        _upiNameController.text = upiData?['upi_name'] ?? 'Satish V';
      });
    } catch (e) {
      print('Error fetching UPI details: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading UPI details: $e')));
    }
  }

  Future<void> _loadOrderItems() async {
    final id = widget.order['id'].toString();
    final items = await supabaseService.fetchOrderItems(id);
    setState(() {
      // Ensure item_price and quantity are parsed to numbers if they come as strings
      orderItems = items
          .map(
            (item) => {
              'item_type': item['item_type'],
              'quantity':
                  int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
              'item_price':
                  int.tryParse(item['item_price']?.toString() ?? '0') ?? 0,
              // Add other fields as necessary
            },
          )
          .toList();
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

  void _generateQr() {
    final amount = _amountController.text.trim();
    final upiId = _upiIdController.text.trim();
    final upiName = _upiNameController.text.trim();

    if (amount.isEmpty || upiId.isEmpty || upiName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'UPI ID, Name, or Amount cannot be empty to generate QR.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

      setState(() {
        _currentOrderStatus = 'delivered';
      });
      final deliveryMessage =
          '''
✅ Order Delivered

Hi ${widget.order['customer_name']}, 👋, your order has been successfully delivered. 
Thank you for choosing Ayaning Kadai! 🧺
''';

      try {
        await sendTextMessageToWhatsApp(
          widget.order['customer_phone'],
          deliveryMessage,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order delivered message sent via WhatsApp'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to send WhatsApp message: $e')),
        );
      }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPI ID: ${_upiIdController.text.isNotEmpty ? _upiIdController.text : 'Loading...'}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Name: ${_upiNameController.text.isNotEmpty ? _upiNameController.text : 'Loading...'}',
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
      // Ensure totalPrice is a number (int or double)
      totalPrice: (order['total_price'] is num)
          ? order['total_price']
          : int.tryParse(order['total_price']?.toString() ?? '0') ?? 0,
      status: _currentOrderStatus,
      pickupTime:
          DateTime.tryParse(order['pickup_time'] ?? '') ?? DateTime.now(),
      deliveryDueTime:
          DateTime.tryParse(order['delivery_due_time'] ?? '') ??
          DateTime.now().add(const Duration(days: 1)),
    );

    final createdAt =
        DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    final isDelivered = orderObj.status.toLowerCase() == 'delivered';
    final isPending = orderObj.status.toLowerCase() == 'pending';
    final isPickedUpOrInProcess =
        orderObj.status.toLowerCase() == 'picked_up' ||
        orderObj.status.toLowerCase() == 'in_process';

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
                    isDelivered
                        ? 'Delivered ✅'
                        : '${orderObj.status.substring(0, 1).toUpperCase()}${orderObj.status.substring(1).replaceAll('_', ' ')} ❌',
                  ),
                  _infoRow('Total Price', orderObj.totalPrice.toString()),
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

            if (isPending) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Action: Pending Pickup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This order is currently pending and awaiting pickup. Tap the button below to proceed with pickup.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PickupScreen(order: widget.order),
                              ),
                            );
                            if (result is bool && result) {
                              _loadOrderItems();
                              _loadPayments();
                              setState(() {
                                _currentOrderStatus = 'picked_up';
                              });
                            }
                          },
                          icon: const Icon(Icons.delivery_dining),
                          label: const Text('Initiate Pickup'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isPickedUpOrInProcess) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Payment Collection & Delivery',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildUPICard(),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
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
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                                onPressed: () {
                                  final amount = _amountController.text.trim();
                                  final upiId = _upiIdController.text.trim();
                                  final upiName = _upiNameController.text
                                      .trim();

                                  bool isValid = validateRequiredFields(
                                    context: context,
                                    fields: [amount, upiId, upiName],
                                    fieldNames: [
                                      'total amount',
                                      'UPI ID',
                                      'UPI name',
                                    ],
                                  );

                                  if (!isValid) return;
                                  _generateQr();
                                },
                                icon: const Icon(Icons.qr_code),
                                label: const Text('Generate UPI QR'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ElevatedButton.icon(
                                      icon: const Icon(Icons.done_all),
                                      label: const Text('Mark as Delivered'),
                                      onPressed: _markAsDelivered,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final amount = _amountController.text.trim();
                                  final upiId = _upiIdController.text.trim();
                                  final upiName = _upiNameController.text
                                      .trim();

                                  bool isValid = validateRequiredFields(
                                    context: context,
                                    fields: [amount, upiId, upiName],
                                    fieldNames: [
                                      'total amount',
                                      'UPI ID',
                                      'UPI name',
                                    ],
                                  );

                                  if (!isValid) return;

                                  _sharePdfBill();
                                },
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Share Bill PDF'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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

  bool validateRequiredFields({
    required BuildContext context,
    required List<String> fields,
    required List<String> fieldNames,
  }) {
    for (int i = 0; i < fields.length; i++) {
      if (fields[i].trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter ${fieldNames[i]}.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _sharePdfBill() async {
    setState(() => _isLoading = true);
    try {
      // 1️⃣ Generate PDF
      final pdf = pw.Document();
      final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));

      final customer = widget.order['customer_name'];
      final phone = widget.order['customer_phone'];
      final address = widget.order['customer_address'];
      final amount = _amountController.text;
      final date = DateFormat('dd MMM yyyy, hh:mm a').format(
        DateTime.tryParse(widget.order['created_at'] ?? '') ?? DateTime.now(),
      );

      final upiId = _upiIdController.text.trim();
      final upiName = _upiNameController.text.trim();
      final upiUrl = 'upi://pay?pa=$upiId&pn=$upiName&am=$amount&cu=INR';
      final destinationUrl =
          'https://pay.highonswift.com?pa=$upiId&pn=$upiName&am=$amount&cu=INR';

      // Generate QR Code for UPI link
      final qrValidationResult = QrValidator.validate(
        data: upiUrl,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );
      final qrCode = qrValidationResult.qrCode;
      final painter = QrPainter.withQr(
        qr: qrCode!,
        color: const ui.Color(0xFF000000),
        emptyColor: const ui.Color(0xFFFFFFFF),
        gapless: true,
      );
      final picData = await painter.toImageData(200);
      final qrImage = pw.MemoryImage(picData!.buffer.asUint8List());

      // Build PDF layout
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Laundry Bill',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      font: font,
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text('Customer Name: $customer', style: pw.TextStyle(font: font)),
                pw.Text('Phone: $phone', style: pw.TextStyle(font: font)),
                pw.Text('Address: $address', style: pw.TextStyle(font: font)),
                pw.Text('Order Date: $date', style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 24),
                pw.Text('Items', style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                )),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: ['Item Type', 'Qty', 'Price (₹)'],
                  data: orderItems.map((item) => [
                    item['item_type'] ?? '',
                    '${item['quantity']}',
                    '${item['item_price'] ?? 0}',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
                  cellStyle: pw.TextStyle(font: font),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Total Amount: ₹$amount',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      font: font,
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Center(
                  child: pw.UrlLink(
                    destination: destinationUrl,
                    child: pw.Text(
                      'Tap to Pay via UPI',
                      style: pw.TextStyle(
                        decoration: pw.TextDecoration.underline,
                        color: PdfColors.blue,
                        font: font,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Center(child: pw.Image(qrImage, width: 100, height: 100)),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Thank you for choosing Ayaning Kadai!',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontStyle: pw.FontStyle.italic,
                      font: font,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Save PDF
      final Uint8List bytes = await pdf.save();
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/laundry_bill.pdf');
      await file.writeAsBytes(bytes);
      final pdfUrl = await uploadPdfAndGetPublicUrl(file);

      // 2️⃣ Try sending via WhatsApp Template first
      try {
        await sendBillTemplateWithPdf(
          phoneNumber: phone,
          customerName: customer,
          amount: amount,
          date: date,
          pdfUrl: pdfUrl,
          payUrl: destinationUrl,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Template sent successfully via WhatsApp')),
        );
      } catch (e) {
        // ⚠️ Fallback: send plain PDF + text
        debugPrint('Template failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Template failed. Sending regular PDF instead...')),
        );

        final billMessage = '''
🧾 Laundry Bill

Hi 👋, thanks for choosing us!

Name: $customer  
Amount: ₹$amount  
Date: $date  

— Ayaning Kadai
''';

        try {
          await sendPdfToWhatsApp(phone, pdfUrl);
          await sendTextMessageToWhatsApp(phone, billMessage);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Fallback PDF & text sent successfully')),
          );
        } catch (fallbackError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Fallback also failed: $fallbackError')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error generating PDF: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // WhatsApp helpers
  Future<void> sendPdfToWhatsApp(String phoneNumber, String pdfUrl) async {
    final uri = Uri.parse(
      'https://graph.facebook.com/v22.0/$phoneNumberId/messages',
    );

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "messaging_product": "whatsapp",
        "to": phoneNumber,
        "type": "document",
        "document": {"link": pdfUrl, "filename": "invoice.pdf"},
      }),
    );

    if (response.statusCode == 200) {
      // Insert into Supabase messages table
      final newMsg = {
        'customer_phone': phoneNumber,
        'msg_type': 'document',
        'message': pdfUrl,
        'direction': 'outbound',
        'raw_payload': {'filename': 'invoice.pdf', 'link': pdfUrl},
      };
      await Supabase.instance.client.from('messages').insert(newMsg);
    } else {
      throw Exception('WhatsApp PDF send failed: ${response.body}');
    }
  }

  Future<void> sendTextMessageToWhatsApp(
    String phoneNumber,
    String message,
  ) async {
    final uri = Uri.parse(
      'https://graph.facebook.com/v22.0/$phoneNumberId/messages',
    );

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "messaging_product": "whatsapp",
        "to": phoneNumber,
        "type": "text",
        "text": {"body": message},
      }),
    );

    if (response.statusCode == 200) {
      final newMsg = {
        'customer_phone': phoneNumber,
        'msg_type': 'text',
        'message': message,
        'direction': 'outbound',
      };
      await Supabase.instance.client.from('messages').insert(newMsg);
    } else {
      throw Exception('WhatsApp text send failed: ${response.body}');
    }
  }

  Future<void> sendBillTemplateWithPdf({
    required String phoneNumber,
    required String customerName,
    required String amount,
    required String date,
    required String pdfUrl,
    String? payUrl,
  }) async {
    final uri = Uri.parse(
      'https://graph.facebook.com/v22.0/$phoneNumberId/messages',
    );

    const templateName = "laundry_invoice_v1";

    final body = {
      "messaging_product": "whatsapp",
      "to": phoneNumber,
      "type": "template",
      "template": {
        "name": templateName,
        "language": {"code": "en_US"},
        "components": [
          {
            "type": "header",
            "parameters": [
              {
                "type": "document",
                "document": {"link": pdfUrl, "filename": "Laundry_Bill.pdf"},
              },
            ],
          },
          {
            "type": "body",
            "parameters": [
              {"type": "text", "text": customerName},
              {"type": "text", "text": amount},
              {"type": "text", "text": date},
            ],
          },
          // if (payUrl != null)
          //   {
          //     "type": "button",
          //     "sub_type": "url",
          //     "index": "0",
          //     "parameters": [
          //       {"type": "text", "text": payUrl},
          //     ],
          //   },
        ],
      },
    };

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      // ✅ Log it in Supabase messages
      await Supabase.instance.client.from('messages').insert({
        'customer_phone': phoneNumber,
        'msg_type': 'text',
        'message': 'Laundry Bill Template sent successfully',
        'direction': 'outbound',
        'raw_payload': body,
      });
    } else {
      throw Exception('Template send failed: ${response.body}');
    }
  }

  Future<String> uploadPdfAndGetPublicUrl(File file) async {
    final storage = Supabase.instance.client.storage;
    final bucket = storage.from('invoices');
    final filePath = 'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final response = await bucket.upload(filePath, file);
    if (response.isEmpty) {
      throw Exception('File upload failed');
    }
    final publicUrl = bucket.getPublicUrl(filePath);
    return publicUrl;
  }
}
