import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

import '../home/order_detail.dart';

class ChatScreen extends StatefulWidget {
  final String phone;

  const ChatScreen({super.key, required this.phone});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late RealtimeChannel _channel;
  List<Map<String, dynamic>> messages = [];

  // Media players
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    final response = await supabase
        .from('messages')
        .select('*')
        .eq('customer_phone', widget.phone)
        .order('created_at', ascending: true);

    setState(() {
      messages = List<Map<String, dynamic>>.from(response);
    });

    _scrollToBottom();
    await _markVisibleMessagesAsRead();
  }

  void _subscribeToMessages() {
    _channel = supabase.channel('messages_channel');

    _channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final newMsg = payload.newRecord;
        if (newMsg != null && newMsg['customer_phone'] == widget.phone) {
          setState(() {
            messages.add(newMsg);
          });
          _scrollToBottom();
          await _markVisibleMessagesAsRead();
        }
      },
    );

    _channel.subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    try {
      // 1️⃣ Send to WhatsApp (replace with your API logic)
      await sendTextMessageToWhatsApp(widget.phone, text);

      // 2️⃣ Insert into Supabase
      final newMsg = {
        'customer_phone': widget.phone,
        'msg_type': 'text',
        'message': text,
        'direction': 'outbound',
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('messages').insert(newMsg);
    } catch (e) {
      print('❌ Failed to send message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> sendTextMessageToWhatsApp(String phoneNumber, String message) async {

    final uri = Uri.parse('https://graph.facebook.com/v22.0/$phoneNumberId/messages');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "messaging_product": "whatsapp",
        "to": phoneNumber,
        "type": "text",
        "text": {"body": message},
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Text message sent successfully');
    } else {
      print('❌ Text send failed: ${response.body}');
    }
  }

  Future<void> _markVisibleMessagesAsRead() async {
    final unreadMessages = messages
        .where((msg) => msg['direction'] == 'inbound' && msg['is_read'] == false)
        .toList();

    if (unreadMessages.isEmpty) return;

    final ids = unreadMessages.map((msg) => msg['id']).toList();

    await supabase.from('messages').update({'is_read': true}).filter('id', 'in', ids);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  String formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return "Today";
    if (msgDate == yesterday) return "Yesterday";
    return DateFormat('MMM dd, yyyy').format(date);
  }

  // ------------------- Message Bubble Builders -------------------

  Widget _buildTextBubble(Map msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg['message'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _buildImageBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    if (url.isEmpty) return _buildTextBubble({'message': '[Image not available]'}, isMe);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () async {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade400,
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    final fileName = msg['file_name'] ?? 'Document';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                if (url.isNotEmpty) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    final fileName = msg['file_name'] ?? 'Audio';
    if (url.isEmpty) return _buildTextBubble({'message': '[Audio not available]'}, isMe);

    final player = _audioPlayers[msg['id']] ?? AudioPlayer();
    _audioPlayers[msg['id']] = player;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            onPressed: () async {
              try {
                await player.setUrl(url);
                player.play();
              } catch (e) {
                print('❌ Audio play error: $e');
              }
            },
          ),
          Flexible(child: Text(fileName)),
        ],
      ),
    );
  }

  Widget _buildVideoBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    final fileName = msg['file_name'] ?? 'Video';
    if (url.isEmpty) return _buildTextBubble({'message': '[Video not available]'}, isMe);

    final controller = _videoControllers[msg['id']] ??
        VideoPlayerController.network(url)..initialize().then((_) => setState(() {}));
    _videoControllers[msg['id']] = controller;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              if (!controller.value.isPlaying)
                const Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map msg, bool isMe) {
    final type = msg['msg_type'] ?? 'text';
    final content = msg['message'] ?? '';
    final fileName = msg['file_name'] ?? type;

    switch (type) {
      case 'text':
        return _buildTextBubble(msg, isMe);
      case 'image':
      case 'sticker':
        return _buildImageBubble(msg, isMe);
      case 'document':
        return _buildDocBubble(msg, isMe);
      case 'audio':
        return _buildAudioBubble(msg, isMe);
      case 'video':
        return _buildVideoBubble(msg, isMe);
      case 'location':
        final lat = msg['latitude']?.toString() ?? '';
        final long = msg['longitude']?.toString() ?? '';
        return _buildTextBubble({'message': content.isNotEmpty ? content : 'Location: $lat,$long'}, isMe);
      case 'contacts':
        return _buildTextBubble({'message': content.isNotEmpty ? content : (msg['contacts']?.toString() ?? '')}, isMe);
      case 'button':
        return _buildTextBubble({'message': content.isNotEmpty ? content : 'Button pressed'}, isMe);
      default:
        return _buildTextBubble({'message': content.isNotEmpty ? content : '[Unsupported message type]'}, isMe);
    }
  }

  List<Widget> _buildMessagesByDate() {
    if (messages.isEmpty) return [];
    List<Widget> widgets = [];
    String? lastDate;

    for (var msg in messages) {
      final createdAt = DateTime.parse(msg['created_at']);
      final dateStr = DateFormat('yyyy-MM-dd').format(createdAt);

      if (lastDate != dateStr) {
        lastDate = dateStr;
        widgets.add(
            Center(
                child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                        formatDateHeader(createdAt),
                        style                : const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                ),
            ),
        );
      }

      final isMe = msg['direction'] == 'outbound';
      widgets.add(_buildMessageBubble(msg, isMe));
    }

    return widgets;
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    _audioPlayers.values.forEach((p) => p.dispose());
    _videoControllers.values.forEach((v) => v.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.phone,
          style: const TextStyle(
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              children: _buildMessagesByDate(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                // // Optional: Attach button
                // IconButton(
                //   icon: const Icon(Icons.attach_file, color: Colors.grey),
                //   onPressed: () {
                //     // Handle file/media attachment
                //   },
                // ),

                // Message input
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6A11CB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

