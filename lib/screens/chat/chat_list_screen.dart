import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
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
  Map<String, String> _contactNames = {}; // normalized phone -> name
  late RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    Future(() async {
      await _loadContacts(); // wait for contact sync first
      await _loadChats(); // now load chats with mapped names
      _subscribeToRealtime();
    });
  }

  // 🔥 Normalizes phone formats
  String normalize(String phone) {
    phone = phone.replaceAll(RegExp(r'\D'), "");
    if (phone.length == 10) return "91$phone";
    if (phone.length == 11 && phone.startsWith("0"))
      return "91${phone.substring(1)}";
    if (phone.startsWith("91") && phone.length == 12) return phone;
    return phone;
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString("device_contacts");

    // load cached names immediately
    if (cached != null) {
      _contactNames = Map<String, String>.from(jsonDecode(cached));
    }

    // if permission denied earlier – ask user to enable manually
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      setState(() {}); // still rebuild so cached names apply
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);

    for (final c in contacts) {
      if (c.phones.isNotEmpty) {
        final normalized = normalize(c.phones.first.number);
        print(
          "📱 CONTACT → ${c.displayName} | RAW: ${c.phones.first.number} | NORMALIZED: $normalized",
        );
        if (normalized.isEmpty) continue;
        _contactNames[normalized] = c.displayName.isNotEmpty
            ? c.displayName
            : normalized;
      }
    }

    await prefs.setString("device_contacts", jsonEncode(_contactNames));
    setState(() {}); // update UI instantly
  }

  Future<void> _loadChats() async {
    final response = await supabase
        .from('messages')
        .select('customer_phone, message, created_at, is_read, direction')
        .eq('store_id', AppConstants.storeId)
        .order('created_at', ascending: false);

    final data = List<Map<String, dynamic>>.from(response);
    final Map<String, Map<String, dynamic>> latestByPhone = {};
    final Map<String, int> unreadCount = {};

    for (final msg in data) {
      final normalizedPhone = normalize(msg['customer_phone']);
      print(
        "💬 DB MSG → ${msg['customer_phone']} | NORMALIZED: $normalizedPhone",
      );
      if (!latestByPhone.containsKey(normalizedPhone)) {
        latestByPhone[normalizedPhone] = msg;
      }
      if (msg['direction'] == 'inbound' && msg['is_read'] == false) {
        unreadCount[normalizedPhone] = (unreadCount[normalizedPhone] ?? 0) + 1;
      }
    }

    setState(() {
      chats = latestByPhone.values.toList()
        ..sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
      _unreadCount = unreadCount;
    });
  }

  void _subscribeToRealtime() {
    _channel = supabase.channel('messages_${AppConstants.storeId}');

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

  void _handleRealtime(Map<String, dynamic>? newMsg) async {
    if (newMsg == null) return;
    if (newMsg['store_id'] != AppConstants.storeId) return;

    final normalizedPhone = normalize(newMsg['customer_phone']);

    setState(() {
      chats.removeWhere(
        (chat) => normalize(chat['customer_phone']) == normalizedPhone,
      );
      chats.insert(0, newMsg);

      if (newMsg['direction'] == 'inbound' && newMsg['is_read'] == false) {
        _unreadCount[normalizedPhone] =
            (_unreadCount[normalizedPhone] ?? 0) + 1;
      } else if (newMsg['is_read'] == true) {
        _unreadCount[normalizedPhone] = 0;
      }
    });
  }

  void _handleDeleteRealtime(Map<String, dynamic>? oldMsg) {
    if (oldMsg == null) return;
    if (oldMsg['store_id'] != AppConstants.storeId) return;

    final normalizedPhone = normalize(oldMsg['customer_phone']);
    setState(() {
      chats.removeWhere(
        (chat) => normalize(chat['customer_phone']) == normalizedPhone,
      );
      _unreadCount.remove(normalizedPhone);
    });
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  Future<void> _openChat(String rawPhone) async {
    final normalizedPhone = normalize(rawPhone);

    // mark read for both possible DB versions
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('store_id', AppConstants.storeId)
        .eq('direction', 'inbound')
        .filter('customer_phone', 'in', [rawPhone, normalizedPhone]);

    setState(() => _unreadCount[normalizedPhone] = 0);

    final name = _contactNames[rawPhone] ?? rawPhone;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          phone: rawPhone,
          displayName: name, // << NEW
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadContacts();
              await _loadChats();
            },
          ),
        ],
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
                final rawPhone = chat['customer_phone'];
                final phone = normalize(rawPhone);
                final name = _contactNames[phone] ?? phone;
                final message = chat['message'] ?? '';

                final createdAtUtc = DateTime.tryParse(
                  chat['created_at'] ?? '',
                );
                final createdAtLocal = createdAtUtc?.toLocal();
                final formattedTime = createdAtLocal != null
                    ? DateFormat('hh:mm a').format(createdAtLocal)
                    : '';

                final hasUnread =
                    _unreadCount[phone] != null && _unreadCount[phone]! > 0;

                return InkWell(
                  onTap: () => _openChat(rawPhone),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFF25D366),
                                child: Text(
                                  name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
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
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            message,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: hasUnread
                                                  ? Colors.black
                                                  : Colors.grey.shade700,
                                              fontWeight: hasUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (hasUnread)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 6,
                                            ),
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF25D366),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                _unreadCount[phone]!.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                        const Divider(height: 1, thickness: 0.5, indent: 70),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
