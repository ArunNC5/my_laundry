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

    _channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'messages',
      callback: (payload) => _handleDeleteRealtime(payload.oldRecord),
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

  void _handleDeleteRealtime(Map<String, dynamic>? oldMsg) {
    if (oldMsg == null) return;
    final phone = oldMsg['customer_phone'] as String?;
    if (phone == null) return;

    setState(() {
      chats.removeWhere((chat) => chat['customer_phone'] == phone);
      _unreadCount.remove(phone);
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
      backgroundColor: const Color(0xFFF0F2F5), // WhatsApp BG
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54), // WhatsApp Green
        elevation: 0,
        title: const Text(
          'WhatsApp Chats',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 0.3,
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
        padding: EdgeInsets.zero,
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          final phone = chat['customer_phone'];
          final message = chat['message'] ?? '';
          final createdAtUtc =
          DateTime.tryParse(chat['created_at'] ?? '');
          final createdAtLocal = createdAtUtc?.toLocal();
          final formattedTime = createdAtLocal != null
              ? DateFormat('hh:mm a').format(createdAtLocal)
              : '';

          final bool hasUnread =
              _unreadCount[phone] != null && _unreadCount[phone]! > 0;

          return InkWell(
            onTap: () => _openChat(phone),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // 🟢 Avatar
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF25D366),
                          child: Text(
                            (phone != null && phone.length >= 2)
                                ? phone.substring(phone.length - 2)
                                : (phone ?? '?'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 💬 Chat preview
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Phone (or name)
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      phone,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: hasUnread
                                          ? const Color(0xFF25D366)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // Last message + unread badge
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      message,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: hasUnread
                                            ? Colors.black
                                            : Colors.grey.shade700,
                                        fontWeight: hasUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (hasUnread)
                                    Container(
                                      margin:
                                      const EdgeInsets.only(left: 6),
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF25D366),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _unreadCount[phone]!.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 70,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
