import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderCard extends StatefulWidget {
  final Map order;
  final VoidCallback onViewDetails;

  const OrderCard({
    required this.order,
    required this.onViewDetails,
    Key? key,
  }) : super(key: key);

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  late Timer _timer;
  String _countdown = '';
  Color _countdownColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    if (widget.order['status'] == 'delivered') return;

    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final iso = widget.order['delivery_due_time'];
    if (iso == null) return;

    final due = DateTime.tryParse(iso)?.toLocal();
    if (due == null) return;

    final now = DateTime.now();
    final diff = due.difference(now);

    if (!mounted) return;

    setState(() {
      if (diff.isNegative) {
        _countdown = 'Overdue';
        _countdownColor = Colors.red;
      } else {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final mins = diff.inMinutes % 60;
        final secs = diff.inSeconds % 60;

        _countdown =
        '${days}d ${hours}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s left';

        if (diff.inMinutes < 60) {
          _countdownColor = Colors.deepOrange;
        } else {
          _countdownColor = Colors.grey[800]!;
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order['status'] ?? 'unknown';
    final isDelivered = status == 'delivered';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.grey[100]!,
          ],
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
          onTap: widget.onViewDetails,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and status
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
                          horizontal: 12, vertical: 6),
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
                if (order['pickup_time'] != null)
                  Row(
                    children: [
                      Icon(Icons.local_shipping,
                          color: Colors.grey[700], size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Pickup: ${formatDate(order['pickup_time'])}',
                        style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Countdown
                if (!isDelivered && _countdown.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          color: _countdownColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _countdown,
                        style: TextStyle(fontSize: 15, color: _countdownColor),
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
