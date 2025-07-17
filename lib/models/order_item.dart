class OrderItem {
  final String id;
  final String orderId;
  final String itemType;
  final int quantity;
  final String? notes;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.itemType,
    required this.quantity,
    this.notes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      itemType: map['item_type'],
      quantity: map['quantity'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'item_type': itemType,
      'quantity': quantity,
      'notes': notes,
    };
  }
}
