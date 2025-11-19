import 'package:my_laundry/core/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;

  // Temporary storeId until JWT metadata is added
  String get storeId => AppConstants.storeId;

  // ---------------------------------------------------
  // ORDERS
  // ---------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await supabase
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchOrderById(String id) async {
    final response = await supabase
        .from('orders')
        .select()
        .eq('id', id)
        .eq('store_id', storeId)
        .maybeSingle();

    return response;
  }

  Future<String> insertOrder({
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
      'store_id': storeId,
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

    return response['id'];
  }

  Future<void> updateOrder({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required int totalPrice,
    required String status,
    DateTime? pickupTime,
    DateTime? deliveryDueTime,
  }) async {
    final updateData = {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'total_price': totalPrice,
      'status': status,
      if (pickupTime != null) 'pickup_time': pickupTime.toIso8601String(),
      if (deliveryDueTime != null)
        'delivery_due_time': deliveryDueTime.toIso8601String(),
    };

    await supabase
        .from('orders')
        .update(updateData)
        .eq('id', orderId)
        .eq('store_id', storeId);
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    DateTime? pickupTime,
    DateTime? deliveryDueTime,
  }) async {
    final updateData = {
      'status': status,
      if (pickupTime != null) 'pickup_time': pickupTime.toIso8601String(),
      if (deliveryDueTime != null)
        'delivery_due_time': deliveryDueTime.toIso8601String(),
    };

    await supabase
        .from('orders')
        .update(updateData)
        .eq('id', orderId)
        .eq('store_id', storeId);
  }

  // ---------------------------------------------------
  // ORDER ITEMS
  // ---------------------------------------------------

  Future<void> insertOrderItem({
    required String orderId,
    required String itemType,
    required int itemPrice,
    required int quantity,
    String? notes,
    String? category,
  }) async {
    await supabase.from('order_items').insert({
      'store_id': storeId,
      'order_id': orderId,
      'item_type': itemType,
      'item_price': itemPrice,
      'quantity': quantity,
      'notes': notes ?? '',
      'category': category,
    });
  }

  Future<List<Map<String, dynamic>>> fetchOrderItems(String orderId) async {
    final response = await supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId)
        .eq('store_id', storeId);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deleteOrderItems(String orderId) async {
    await supabase
        .from('order_items')
        .delete()
        .eq('order_id', orderId)
        .eq('store_id', storeId);
  }

  // ---------------------------------------------------
  // STATUS UPDATES
  // ---------------------------------------------------

  Future<void> insertStatusUpdate({
    required String orderId,
    required String newStatus,
    String updatedBy = 'system',
    String? userId,
  }) async {
    await supabase.from('status_updates').insert({
      'store_id': storeId,
      'order_id': orderId,
      'new_status': newStatus,
      'updated_by': updatedBy,
      'user_id': userId,
    });
  }

  // ---------------------------------------------------
  // PAYMENTS
  // ---------------------------------------------------

  Future<void> insertPayment({
    required String orderId,
    required double amount,
    String method = 'upi',
    String? userId,
  }) async {
    await supabase.from('payments').insert({
      'store_id': storeId,
      'order_id': orderId,
      'amount': amount,
      'payment_method': method,
      'paid_at': DateTime.now().toIso8601String(),
      'user_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> fetchPayments(String orderId) async {
    final response = await supabase
        .from('payments')
        .select()
        .eq('order_id', orderId)
        .eq('store_id', storeId);

    return List<Map<String, dynamic>>.from(response);
  }

  // ---------------------------------------------------
  // CUSTOMER LOOKUP
  // ---------------------------------------------------

  Future<Map<String, dynamic>?> fetchLatestCustomerByPhone(
      String phone) async {
    final response = await supabase
        .from('orders')
        .select('customer_name, customer_address')
        .eq('customer_phone', phone)
        .eq('store_id', storeId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // ---------------------------------------------------
  // SERVICES
  // ---------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchAllServices() async {
    final response = await supabase
        .from('services')
        .select()
        .eq('store_id', storeId);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchServicesByCategory(
      String category) async {
    final response = await supabase
        .from('services')
        .select()
        .eq('category', category)
        .eq('store_id', storeId)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> insertService({
    required String name,
    required int price,
    required String category,
    String? iconUrl,
  }) async {
    await supabase.from('services').insert({
      'store_id': storeId,
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

    await supabase
        .from('services')
        .update(updateData)
        .eq('id', id)
        .eq('store_id', storeId);
  }

  Future<void> deleteService(String id) async {
    await supabase
        .from('services')
        .delete()
        .eq('id', id)
        .eq('store_id', storeId);
  }

  // ---------------------------------------------------
  // UPI DETAILS
  // ---------------------------------------------------

  Future<Map<String, dynamic>?> fetchUPIDetails() async {
    final response = await supabase
        .from('upi_details')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

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
        .eq('store_id', storeId)
        .single();

    if (existing == null || existing['pin'] != enteredPin) {
      return false;
    }

    await supabase
        .from('upi_details')
        .update({'upi_id': upiId, 'upi_name': upiName})
        .eq('id', id)
        .eq('store_id', storeId);

    return true;
  }

  Future<void> insertUPIDetails({
    required String upiId,
    required String upiName,
    required String pin,
  }) async {
    await supabase.from('upi_details').insert({
      'store_id': storeId,
      'upi_id': upiId,
      'upi_name': upiName,
      'pin': pin,
    });
  }
}
