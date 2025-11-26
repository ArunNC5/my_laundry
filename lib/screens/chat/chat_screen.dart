import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants.dart';

class ChatScreen extends StatefulWidget {
  final String phone;
  final String displayName; // NEW

  const ChatScreen({super.key, required this.phone, required this.displayName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  late RealtimeChannel _channel;
  List<Map<String, dynamic>> messages = [];
  bool _isUploading = false;

  // Media players
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, VideoPlayerController> _videoControllers = {};

  final String backendBaseUrl = "https://ayaning-kadai-wa-bot.onrender.com";

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
        .eq('store_id', AppConstants.storeId)
        .order('created_at', ascending: true);

    setState(() {
      messages = List<Map<String, dynamic>>.from(response);
    });

    _scrollToBottom();
    await _markVisibleMessagesAsRead();
  }

  void _subscribeToMessages() {
    _channel = supabase.channel('messages_${AppConstants.storeId}');

    _channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final newMsg = payload.newRecord;
        if (newMsg != null &&
            newMsg['customer_phone'] == widget.phone &&
            newMsg['store_id'] == AppConstants.storeId) {
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

  Future<void> _sendMessage({
    String? text,
    String? mediaUrl,
    String? mediaType,
    String? fileName,
    String? mimeType,
    String? caption,
    double? latitude,
    double? longitude,
  }) async {
    // Prevent empty messages
    if ((text == null || text.isEmpty) &&
        mediaUrl == null &&
        (latitude == null || longitude == null)) {
      print("❌ No valid message to send");
      return;
    }

    _controller.clear();

    try {
      final uri = Uri.parse(
        'https://graph.facebook.com/v22.0/${AppConstants.phoneNumberId}/messages',
      );

      Map<String, dynamic> body;
      String msgTypeForSupabase;

      // Handle Location
      if (latitude != null && longitude != null) {
        body = {
          "messaging_product": "whatsapp",
          "to": widget.phone,
          "type": "location",
          "location": {"latitude": latitude, "longitude": longitude},
        };
        msgTypeForSupabase = "location";
      }
      // Handle Text
      else if (text != null && mediaUrl == null) {
        body = {
          "messaging_product": "whatsapp",
          "to": widget.phone,
          "type": "text",
          "text": {"body": text},
        };
        msgTypeForSupabase = "text";
      }
      // Handle Media
      else if (mediaUrl != null && mediaType != null) {
        Map<String, dynamic> mediaPayload = {"link": mediaUrl};
        if (caption != null && caption.isNotEmpty) {
          mediaPayload["caption"] = caption;
        }
        if (mediaType == "document" &&
            fileName != null &&
            fileName.isNotEmpty) {
          mediaPayload["filename"] = fileName;
        }

        body = {
          "messaging_product": "whatsapp",
          "to": widget.phone,
          "type": mediaType,
          mediaType: mediaPayload,
        };
        msgTypeForSupabase = mediaType;
      } else {
        print("❌ Invalid message parameters.");
        return;
      }

      // Send message via WhatsApp API
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${AppConstants.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final newMsg = {
          'customer_phone': widget.phone,
          'msg_type': msgTypeForSupabase,
          'message': msgTypeForSupabase == "location"
              ? "Location: $latitude,$longitude"
              : (caption ?? text ?? mediaUrl),
          'file_name': fileName,
          'mime_type': mimeType,
          'latitude': latitude,
          'longitude': longitude,
          'direction': 'outbound',
          'raw_payload': body,
          'is_read': true,
          'store_id': AppConstants.storeId,
        };

        await supabase.from('messages').insert(newMsg);
        print("✅ Message sent and saved successfully.");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  Future<void> _markVisibleMessagesAsRead() async {
    final unreadMessages = messages
        .where(
          (msg) => msg['direction'] == 'inbound' && msg['is_read'] == false,
        )
        .toList();

    if (unreadMessages.isEmpty) return;

    final ids = unreadMessages.map((msg) => msg['id']).toList();

    await supabase
        .from('messages')
        .update({'is_read': true})
        .filter('id', 'in', ids);
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

  Future<String?> _uploadFileToSupabase(
    File file,
    String bucketName,
    String folder,
  ) async {
    setState(() => _isUploading = true);
    try {
      final String fileExtension = p.extension(file.path);
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final String filePath = '$folder/$fileName';

      final response = await supabase.storage
          .from(bucketName)
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      if (response.isEmpty) return null;
      final String publicUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload file: $e')));
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ------------------- Media Picking Functions -------------------
  Future<void> _pickAndSendImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    final publicUrl = await _uploadFileToSupabase(
      file,
      'media',
      'whatsapp_media',
    );
    if (publicUrl != null) {
      await _sendMessage(
        mediaUrl: publicUrl,
        mediaType: 'image',
        fileName: p.basename(file.path),
        mimeType: lookupMimeType(file.path),
      );
    }
  }

  Future<void> _pickAndSendVideo() async {
    final pickedFile = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    final publicUrl = await _uploadFileToSupabase(
      file,
      'media',
      'whatsapp_media',
    );
    if (publicUrl != null) {
      await _sendMessage(
        mediaUrl: publicUrl,
        mediaType: 'video',
        fileName: p.basename(file.path),
        mimeType: lookupMimeType(file.path),
      );
    }
  }

  Future<void> _pickAndSendDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final publicUrl = await _uploadFileToSupabase(
      file,
      'media',
      'whatsapp_media',
    );
    if (publicUrl != null) {
      await _sendMessage(
        mediaUrl: publicUrl,
        mediaType: 'document',
        fileName: result.files.single.name,
        mimeType: lookupMimeType(file.path),
      );
    }
  }

  Future<void> _pickAndSendAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final publicUrl = await _uploadFileToSupabase(
      file,
      'media',
      'whatsapp_media',
    );
    if (publicUrl != null) {
      await _sendMessage(
        mediaUrl: publicUrl,
        mediaType: 'audio',
        fileName: result.files.single.name,
        mimeType: lookupMimeType(file.path),
      );
    }
  }

  Future<void> _pickAndSendLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send location properly
      await _sendMessage(
        mediaType: 'location',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  // ------------------- Attachment Sheet -------------------
  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: 'Image',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendVideo();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendDocument();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.audiotrack,
                  label: 'Audio',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendAudio();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendLocation();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ------------------- Resolve Chat -------------------
  Future<void> _resolveChat() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resolve Chat?"),
        content: const Text("Are you sure you want to resolve this chat?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Resolve"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final uri = Uri.parse('$backendBaseUrl/api/resolve-agent-chat');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"phone": widget.phone}),
        );
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Chat resolved.')));
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: ${response.body}')));
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ------------------- Message Bubbles -------------------
  Widget _buildMessageBubble(Map msg, bool isMe) {
    final type = msg['msg_type'] ?? 'text';

    switch (type) {
      case 'text':
        return _buildTextBubble(msg, isMe);
      case 'image':
      case 'sticker':
        return _buildImageBubble(msg, isMe);
      case 'video':
        return _buildVideoBubble(msg, isMe);
      case 'audio':
        return _buildAudioBubble(msg, isMe);
      case 'document':
        return _buildDocBubble(msg, isMe);
      case 'location':
        return _buildLocationBubble(msg, isMe);
      default:
        return _buildTextBubble({
          'message': '[Unsupported message type]',
        }, isMe);
    }
  }

  // ------------------- Text Bubble -------------------
  Widget _buildTextBubble(Map msg, bool isMe) {
    final rawText = msg['message'] ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final formattedTime = createdAt != null
        ? DateFormat('hh:mm a').format(createdAt.toLocal())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isMe ? 40 : 8,
          right: isMe ? 8 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE1FFC7) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 👉 Markdown + Linkify together
            _buildRichMessage(rawText),

            const SizedBox(height: 4),

            Text(
              formattedTime,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichMessage(String rawText) {
    return MarkdownBody(
      data: rawText,
      selectable: false,
      onTapLink: (text, href, title) async {
        if (href != null) {
          await launchUrl(
            Uri.parse(href),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, color: Colors.black87),
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        a: const TextStyle(color: Colors.blue),
      ),
    );
  }

  // ------------------- Image Bubble -------------------
  Widget _buildImageBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final formattedTime = createdAt != null
        ? DateFormat('hh:mm a').format(createdAt.toLocal())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FullImageView(url: url)),
          );
        },
        child: Container(
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isMe ? 50 : 8,
            right: isMe ? 8 : 50,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width * 0.65,
                  height: MediaQuery.of(context).size.width * 0.65,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(6),
                child: Text(
                  formattedTime,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Video Bubble -------------------
  Widget _buildVideoBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final formattedTime = createdAt != null
        ? DateFormat('hh:mm a').format(createdAt.toLocal())
        : '';

    if (!_videoControllers.containsKey(url)) {
      _videoControllers[url] = VideoPlayerController.network(url)
        ..initialize().then((_) => setState(() {}));
    }
    final controller = _videoControllers[url]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 50 : 8,
          right: isMe ? 8 : 50,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 3,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    )
                  : const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
            IconButton(
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                color: Colors.white,
                size: 48,
              ),
              onPressed: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formattedTime,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Audio Bubble -------------------
  Widget _buildAudioBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final formattedTime = createdAt != null
        ? DateFormat('hh:mm a').format(createdAt.toLocal())
        : '';

    if (!_audioPlayers.containsKey(url)) {
      _audioPlayers[url] = AudioPlayer()..setUrl(url);
    }
    final player = _audioPlayers[url]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 50 : 8,
          right: isMe ? 8 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE1FFC7) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final processingState = state?.processingState;
                final isPlaying = state?.playing ?? false;
                final isCompleted =
                    processingState == ProcessingState.completed;

                return IconButton(
                  icon: Icon(
                    isPlaying && !isCompleted
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 34,
                    color: Colors.teal,
                  ),
                  onPressed: () async {
                    // Pause all others
                    for (final entry in _audioPlayers.entries) {
                      final p = entry.value;
                      if (p != player) {
                        await p.pause();
                        await p.seek(Duration.zero);
                      }
                    }

                    if (isCompleted) {
                      await player.seek(Duration.zero);
                      await player.play();
                      return;
                    }

                    if (player.playing) {
                      await player.pause();
                    } else {
                      await player.play();
                    }
                  },
                );
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? Duration.zero;
                        final total = player.duration ?? Duration.zero;
                        double progress = 0;
                        if (total.inMilliseconds > 0) {
                          progress = pos.inMilliseconds / total.inMilliseconds;
                          if (progress > 1.0) progress = 1.0;
                        }

                        return LinearProgressIndicator(
                          value: progress,
                          color: Colors.teal,
                          backgroundColor: Colors.grey.shade300,
                          minHeight: 2.2,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Document Bubble -------------------
  Widget _buildDocBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    final name = msg['file_name'] ?? 'Document';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final formattedTime = createdAt != null
        ? DateFormat('hh:mm a').format(createdAt.toLocal())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () async {
          if (await canLaunchUrlString(url)) {
            launchUrlString(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isMe ? 50 : 8,
            right: isMe ? 8 : 50,
          ),
          padding: const EdgeInsets.all(10),
          width: MediaQuery.of(context).size.width * 0.65,
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE1FFC7) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file, color: Colors.teal, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Location Bubble -------------------
  Widget _buildLocationBubble(Map msg, bool isMe) {
    final double? lat = msg['latitude'];
    final double? lng = msg['longitude'];
    if (lat == null || lng == null) {
      return _buildTextBubble({'message': 'Location unavailable'}, isMe);
    }

    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
    final formattedTime = createdAt != null
        ? DateFormat('hh:mm a').format(createdAt.toLocal())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          final googleMapsUrl =
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
          launchUrlString(googleMapsUrl, mode: LaunchMode.externalApplication);
        },
        child: Container(
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isMe ? 50 : 8,
            right: isMe ? 8 : 50,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  "https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=600x400&markers=color:red%7C$lat,$lng&key=YOUR_GOOGLE_MAPS_API_KEY",
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width * 0.65,
                  height: 200,
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formattedTime,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Messages by Date -------------------
  List<Widget> _buildMessagesByDate() {
    if (messages.isEmpty) return [];
    List<Widget> widgets = [];
    String? lastDate;

    for (var msg in messages) {
      final createdAt = DateTime.parse(msg['created_at']);
      final dateStr = DateFormat('yyyy-MM-dd').format(createdAt);

      // Date header ("Today", "Yesterday")
      if (lastDate != dateStr) {
        lastDate = dateStr;
        widgets.add(
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                formatDateHeader(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
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

  Future<void> _addToContacts({
    required String name,
    required String phone,
  }) async {
    try {
      String normalized = phone.replaceAll(RegExp(r'\D'), '');
      if (normalized.length == 10) normalized = "91$normalized";

      final granted = await FlutterContacts.requestPermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contacts permission denied")),
        );
        return;
      }

      final existing = await FlutterContacts.getContacts(withProperties: true);
      final alreadyExists = existing.any((c) {
        return c.phones.any(
          (p) => p.number.replaceAll(RegExp(r'\D'), '') == normalized,
        );
      });

      if (alreadyExists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Contact already exists")));
        return;
      }

      final contact = Contact()
        ..name = _buildName(name)
        ..phones = [Phone(normalized)];

      await contact.insert();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact saved successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving contact: $e")));
    }
  }

  Name _buildName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) {
      return Name(first: parts[0]);
    } else {
      return Name(first: parts.first, last: parts.sublist(1).join(' '));
    }
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
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFF075E54),
        // WhatsApp green
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),

            // ✅ Profile avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade300,
              child: Text(
                widget.phone.substring(widget.phone.length - 2),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ✅ Contact name / number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.phone, // optional: make dynamic later
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ✅ Keep your resolve icon here
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
            onPressed: _resolveChat,
            tooltip: "Resolve Chat",
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () {
              _addToContacts(name: widget.displayName, phone: widget.phone);
            },
          ),
        ],
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
          if (_isUploading) const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: const Color(0xFFEDEDED), // WhatsApp background grey
            child: SafeArea(
              child: Row(
                children: [
                  // Emoji button (optional placeholder)
                  IconButton(
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {},
                  ),

                  // Text input area
                  // 💬 Text input area — clean WhatsApp style
                  Expanded(
                    child: Container(
                      height: 45, // fixed height gives perfect alignment
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: "Message",
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                fillColor: Colors.transparent,
                              ),
                              onSubmitted: (value) => _sendMessage(text: value),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.attach_file,
                              color: Colors.grey,
                            ),
                            splashRadius: 22,
                            onPressed: () => _showAttachmentOptions(context),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.grey,
                            ),
                            splashRadius: 22,
                            onPressed: _pickAndSendImage,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ✅ Send button
                  GestureDetector(
                    onTap: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        _sendMessage(text: text);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366), // WhatsApp green
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullImageView extends StatelessWidget {
  final String url;

  const FullImageView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
