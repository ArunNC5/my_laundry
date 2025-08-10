import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;

  // 🔹 Fetch all orders
  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await supabase
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 🔹 Fetch a single order by ID
  Future<Map<String, dynamic>?> fetchOrderById(String id) async {
    final response = await supabase
        .from('orders')
        .select()
        .eq('id', id)
        .maybeSingle();
    return response;
  }

  // 🔹 Insert a new order and return its ID
  Future<String> insertOrder({ // Changed return type to int as id is typically int in Supabase
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required int totalPrice,
    String? agentName,
    String? userId,
    String status = 'pending',
    DateTime? pickupTime,
    DateTime? deliveryDueTime,
  }) async {
    final response = await supabase
        .from('orders')
        .insert({
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'total_price': totalPrice,
      'agent_name': agentName ?? '',
      'user_id': userId,
      'status': status,
      if (pickupTime != null) 'pickup_time': pickupTime.toIso8601String(),
      if (deliveryDueTime != null)
        'delivery_due_time': deliveryDueTime.toIso8601String(),
    })
        .select('id')
        .single();

    return response['id']; // Assuming id is returned as int
  }

  // 🔹 NEW: Update an existing order's main details
  Future<void> updateOrder({
    required String orderId, // Assuming orderId is int
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required int totalPrice,
    required String status,
    DateTime? pickupTime, // Allow updating these too
    DateTime? deliveryDueTime,
  }) async {
    final Map<String, dynamic> updateData = {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'total_price': totalPrice,
      'status': status,
      if (pickupTime != null) 'pickup_time': pickupTime.toIso8601String(),
      if (deliveryDueTime != null)
        'delivery_due_time': deliveryDueTime.toIso8601String(),
    };

    await supabase.from('orders').update(updateData).eq('id', orderId);
  }

  // 🔹 Update order status and timestamps (kept for specific status updates if needed elsewhere)
  Future<void> updateOrderStatus({
    required String orderId, // Still using String if your DB ID is UUID
    required String status,
    DateTime? pickupTime,
    DateTime? deliveryDueTime,
  }) async {
    final Map<String, dynamic> updateData = {
      'status': status,
      if (pickupTime != null) 'pickup_time': pickupTime.toIso8601String(),
      if (deliveryDueTime != null)
        'delivery_due_time': deliveryDueTime.toIso8601String(),
    };

    await supabase.from('orders').update(updateData).eq('id', orderId);
  }

  // 🔹 Insert an order item
  Future<void> insertOrderItem({
    required String orderId,
    required String itemType,
    required int itemPrice,
    required int quantity,
    String? notes,
    String? category, // Added category to item to match PickupScreen
  }) async {
    await supabase.from('order_items').insert({
      'order_id': orderId,
      'item_type': itemType,
      'item_price': itemPrice,
      'quantity': quantity,
      'notes': notes ?? '',
      'category': category,
    });
  }

  // 🔹 Fetch all items for an order
  Future<List<Map<String, dynamic>>> fetchOrderItems(String orderId) async {
    final response = await supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    return List<Map<String, dynamic>>.from(response);
  }

  // 🔹 NEW: Delete all items for a specific order
  Future<void> deleteOrderItems(String orderId) async { // Assuming orderId is int
    await supabase.from('order_items').delete().eq('order_id', orderId);
  }

  // 🔹 Insert a status update record
  Future<void> insertStatusUpdate({
    required String orderId, // Assuming orderId is int
    required String newStatus,
    String updatedBy = 'system',
    String? userId,
  }) async {
    await supabase.from('status_updates').insert({
      'order_id': orderId,
      'new_status': newStatus,
      'updated_by': updatedBy,
      'user_id': userId,
      // updated_at is auto-handled in DB
    });
  }

  // 🔹 Insert a payment
  Future<void> insertPayment({
    required String orderId, // Assuming orderId is int
    required double amount,
    String method = 'upi',
    String? userId,
  }) async {
    await supabase.from('payments').insert({
      'order_id': orderId,
      'amount': amount,
      'payment_method': method,
      'paid_at': DateTime.now().toIso8601String(),
      'user_id': userId,
    });
  }

  // 🔹 Fetch all payments for an order
  Future<List<Map<String, dynamic>>> fetchPayments(String orderId) async {
    final response = await supabase
        .from('payments')
        .select()
        .eq('order_id', orderId);
    return List<Map<String, dynamic>>.from(response);
  }

  // 🔹 Fetch most recent customer details by phone
  Future<Map<String, dynamic>?> fetchLatestCustomerByPhone(String phone) async {
    final response = await supabase
        .from('orders')
        .select('customer_name, customer_address')
        .eq('customer_phone', phone)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // 🔹 Fetch all services
  Future<List<Map<String, dynamic>>> fetchAllServices() async {
    final response = await supabase.from('services').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // 🔹 Fetch services by category
  Future<List<Map<String, dynamic>>> fetchServicesByCategory(
      String category,
      ) async {
    final response = await supabase
        .from('services')
        .select()
        .eq('category', category)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // 🔹 Insert a new service (admin use only)
  Future<void> insertService({
    required String name,
    required int price,
    required String category,
    String? iconUrl,
  }) async {
    await supabase.from('services').insert({
      'name': name,
      'price': price,
      'category': category,
      if (iconUrl != null) 'icon_url': iconUrl,
    });
  }

  Future<void> updateService({
    required String id,
    required String name,
    required int price,
    required String category,
    String? iconUrl,
  }) async {
    final updateData = {
      'name': name,
      'price': price,
      'category': category,
      if (iconUrl != null) 'icon_url': iconUrl,
    };

    await supabase.from('services').update(updateData).eq('id', id);
  }

  Future<void> deleteService(String id) async {
    await supabase.from('services').delete().eq('id', id);
  }

  // 🔹 Fetch UPI Details
  Future<Map<String, dynamic>?> fetchUPIDetails() async {
    final response = await supabase
        .from('upi_details')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .single();

    return response;
  }

  Future<bool> updateUPIDetailsWithPin({
    required String id,
    required String upiId,
    required String upiName,
    required String enteredPin,
  }) async {
    final existing = await supabase
        .from('upi_details')
        .select('pin')
        .eq('id', id)
        .single();

    if (existing == null || existing['pin'] != enteredPin) {
      return false;
    }

    await supabase
        .from('upi_details')
        .update({'upi_id': upiId, 'upi_name': upiName})
        .eq('id', id);

    return true;
  }

  Future<void> insertUPIDetails({
    required String upiId,
    required String upiName,
    required String pin,
  }) async {
    await supabase.from('upi_details').insert({
      'upi_id': upiId,
      'upi_name': upiName,
      'pin': pin,
    });
  }
}