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

      if (!latestByPhone.containsKey(phone)) {
        latestByPhone[phone] = msg;
      }

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

  void _subscribeToRealtime() {
    _channel = supabase.channel('messages_channel');

    _channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) => _handleRealtime(payload.newRecord),
    );

    _channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (payload) => _handleRealtime(payload.newRecord),
    );

    _channel.subscribe();
  }

  void _handleRealtime(Map<String, dynamic>? newMsg) {
    if (newMsg == null) return;
    final phone = newMsg['customer_phone'] as String;

    setState(() {
      chats.removeWhere((chat) => chat['customer_phone'] == phone);
      chats.insert(0, newMsg);
      chats.sort((a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String));

      if (newMsg['direction'] == 'inbound' && newMsg['is_read'] == false) {
        _unreadCount[phone] = (_unreadCount[phone] ?? 0) + 1;
      } else if (newMsg['is_read'] == true) {
        _unreadCount[phone] = 0;
      }
    });
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  void _openChat(String phone) async {
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('customer_phone', phone)
        .eq('direction', 'inbound');

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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
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
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: InkWell(
              onTap: () => _openChat(phone),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFF0F0F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple.shade400,
                      child: Text(
                        phone.substring(phone.length - 2),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_unreadCount[phone] != null && _unreadCount[phone]! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(1, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _unreadCount[phone]!.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        else if (formattedTime.isNotEmpty)
                          Text(
                            formattedTime,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
