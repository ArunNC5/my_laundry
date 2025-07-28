// Order model
class Order {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final int totalPrice;
  final String status;
  final DateTime pickupTime;
  final DateTime deliveryDueTime;

  Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.totalPrice,
    required this.status,
    required this.pickupTime,
    required this.deliveryDueTime,
  });

  Duration get timeLeft => deliveryDueTime.difference(DateTime.now());
}
