class OrderItem {
  final String id;
  final String orderId;
  final String itemType;
  final String itemPrice;
  final int quantity;
  final String? notes;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.itemType,
    required this.itemPrice,
    required this.quantity,
    this.notes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      itemType: map['item_type'],
      itemPrice: map['item_price'],
      quantity: map['quantity'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'item_type': itemType,
      'item_price': itemPrice,
      'quantity': quantity,
      'notes': notes,
    };
  }
}
