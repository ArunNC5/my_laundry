import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onViewDetails;

  const OrderCard({required this.order, required this.onViewDetails, Key? key})
    : super(key: key);

  String formatDate(String? iso) {
    try {
      final dt = DateTime.parse(iso ?? '').toLocal();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  bool isOverdue(String? iso) {
    try {
      final due = DateTime.parse(iso ?? '').toLocal();
      return DateTime.now().isAfter(due);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'unknown';
    final isDelivered = status == 'delivered';
    final pickupTime = order['pickup_time'] as String?;
    final dueTime = order['delivery_due_time'] as String?;
    final overdue = !isDelivered && isOverdue(dueTime);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.8), Colors.grey[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onViewDetails,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order['customer_name'] ?? 'Unnamed',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDelivered
                              ? [Colors.green[400]!, Colors.green[700]!]
                              : [Colors.orange[300]!, Colors.deepOrange[400]!],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Phone
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.grey[700], size: 18),
                    const SizedBox(width: 6),
                    Text(
                      order['customer_phone'] ?? '',
                      style: TextStyle(color: Colors.grey[800], fontSize: 15),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Pickup Time
                if (pickupTime != null && pickupTime.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        color: Colors.grey[700],
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pickup: ${formatDate(pickupTime)}',
                        style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                      ),
                    ],
                  ),

                if (pickupTime != null && pickupTime.isNotEmpty)
                  const SizedBox(height: 8),

                // Due Time / Overdue
                if (!isDelivered && dueTime != null && dueTime.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        overdue
                            ? Icons.warning_amber_rounded
                            : Icons.calendar_today_outlined,
                        color: overdue ? Colors.red : Colors.blueGrey[700],
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        overdue
                            ? 'Overdue since: ${formatDate(dueTime)}'
                            : 'Due by: ${formatDate(dueTime)}',
                        style: TextStyle(
                          fontSize: 15,
                          color: overdue ? Colors.red : Colors.black87,
                          fontWeight: overdue
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
