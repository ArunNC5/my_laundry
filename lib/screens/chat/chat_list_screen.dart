import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> chats = [];
  Map<String, int> _unreadCount = {};
  late RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToRealtime();
  }

  // Load initial chats and unread counts
  Future<void> _loadChats() async {
    final response = await supabase
        .from('messages')
        .select('customer_phone, message, created_at, is_read, direction')
        .order('created_at', ascending: false);

    final data = List<Map<String, dynamic>>.from(response);

    final Map<String, Map<String, dynamic>> latestByPhone = {};
    final Map<String, int> unreadCount = {};

    for (final msg in data) {
      final phone = msg['customer_phone'] as String;

      // Keep only the latest message per phone
      if (!latestByPhone.containsKey(phone)) {
        latestByPhone[phone] = msg;
      }

      // Count unread inbound messages
      if (msg['direction'] == 'inbound' && msg['is_read'] == false) {
        unreadCount[phone] = (unreadCount[phone] ?? 0) + 1;
      }
    }

    setState(() {
      chats = latestByPhone.values.toList()
        ..sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
      _unreadCount = unreadCount;
    });
  }

  // Subscribe to Supabase realtime for INSERT and UPDATE
  void _subscribeToRealtime() {
    _channel = supabase.channel('messages_channel');

    // Insert event
    _channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) => _handleRealtime(payload.newRecord),
    );

    // Update event (read status changes)
    _channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (payload) => _handleRealtime(payload.newRecord),
    );

    _channel.subscribe();
  }

  // Handle realtime updates
  void _handleRealtime(Map<String, dynamic>? newMsg) {
    if (newMsg == null) return;

    final phone = newMsg['customer_phone'] as String;

    setState(() {
      // Remove old chat entry
      chats.removeWhere((chat) => chat['customer_phone'] == phone);

      // Insert new/updated chat at top
      chats.insert(0, newMsg);

      // Keep sorted by latest message
      chats.sort((a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String));

      // Update unread badge
      if (newMsg['direction'] == 'inbound' && newMsg['is_read'] == false) {
        _unreadCount[phone] = (_unreadCount[phone] ?? 0) + 1;
      } else if (newMsg['is_read'] == true) {
        _unreadCount[phone] = 0; // reset badge in real-time
      }
    });
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  // Open chat and mark messages as read
  void _openChat(String phone) async {
    // Mark all inbound messages as read in Supabase
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('customer_phone', phone)
        .eq('direction', 'inbound');

    // Reset badge locally
    setState(() {
      _unreadCount[phone] = 0;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(phone: phone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
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
      body: chats.isEmpty
          ? const Center(
        child: Text(
          'No chats yet',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          final phone = chat['customer_phone'];
          final message = chat['message'] ?? '';
          final createdAtUtc = DateTime.tryParse(chat['created_at'] ?? '');
          final createdAtLocal = createdAtUtc?.toLocal();
          final formattedTime = createdAtLocal != null
              ? DateFormat('hh:mm a').format(createdAtLocal)
              : '';

          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(phone),
            subtitle: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _unreadCount[phone] != null && _unreadCount[phone]! > 0
                ? CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Text(
                _unreadCount[phone]!.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
                : formattedTime.isNotEmpty
                ? Text(
              formattedTime,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
                : null,
            onTap: () => _openChat(phone),
          );
        },
      ),
    );
  }
}
