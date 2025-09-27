import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';

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
      final uri = Uri.parse('https://graph.facebook.com/v22.0/$phoneNumberId/messages');

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
        if (mediaType == "document" && fileName != null && fileName.isNotEmpty) {
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
          'Authorization': 'Bearer $accessToken',
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
        };

        await supabase.from('messages').insert(newMsg);
        print("✅ Message sent and saved successfully.");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
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
  Widget _buildTextBubble(Map msg, bool isMe) => Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.deepPurple.shade400 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        msg['message'] ?? '',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
      ),
    ),
  );

  // ------------------- Image Bubble -------------------
  Widget _buildImageBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (url.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  body: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Center(child: Image.network(url)),
                  ),
                ),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.width * 0.6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(url, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  // ------------------- Video Bubble -------------------
  Widget _buildVideoBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    if (!_videoControllers.containsKey(url)) {
      _videoControllers[url] = VideoPlayerController.network(url)
        ..initialize().then((_) => setState(() {}));
    }
    final controller = _videoControllers[url]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        width: MediaQuery.of(context).size.width * 0.6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black12,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: controller.value.isInitialized
                    ? controller.value.aspectRatio
                    : 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    controller.value.isInitialized
                        ? VideoPlayer(controller)
                        : const Center(child: CircularProgressIndicator()),
                    if (controller.value.isInitialized)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Play/Pause button
                            IconButton(
                              icon: Icon(
                                controller.value.isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () {
                                setState(() {
                                  controller.value.isPlaying
                                      ? controller.pause()
                                      : controller.play();
                                });
                              },
                            ),
                            // Forward 10 seconds
                            IconButton(
                              icon: const Icon(
                                Icons.forward_10,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () {
                                final newPosition =
                                    controller.value.position + const Duration(seconds: 10);
                                controller.seekTo(
                                  newPosition < controller.value.duration
                                      ? newPosition
                                      : controller.value.duration,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Progress bar
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Colors.deepPurple,
                  backgroundColor: Colors.grey.shade400,
                  bufferedColor: Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Audio Bubble -------------------
  Widget _buildAudioBubble(Map msg, bool isMe) {
    final url = msg['message'] ?? '';
    if (!_audioPlayers.containsKey(url)) {
      _audioPlayers[url] = AudioPlayer()..setUrl(url);
    }
    final player = _audioPlayers[url]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        width: MediaQuery.of(context).size.width * 0.65,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
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
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    size: 32,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () async {
                    // Stop all other players
                    for (final entry in _audioPlayers.entries) {
                      final p = entry.value;
                      if (p != player) {
                        await p.pause();
                        await p.seek(Duration.zero);
                      }
                    }

                    // If completed, reset to start and play immediately
                    if (isCompleted) {
                      await player.seek(Duration.zero);
                      await player.play();
                      return; // exit so we don't toggle again
                    }

                    // Normal toggle
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
              child: StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  final total = player.duration ?? Duration.zero;

                  double progress = 0;
                  if (total.inMilliseconds > 0) {
                    progress = pos.inMilliseconds / total.inMilliseconds;
                    if (progress > 1.0) progress = 1.0;
                  }

                  return StreamBuilder<ProcessingState>(
                    stream: player.processingStateStream,
                    builder: (context, psSnapshot) {
                      final processingState = psSnapshot.data;
                      final isCompleted =
                          processingState == ProcessingState.completed;
                      return LinearProgressIndicator(
                        value: isCompleted ? 0 : progress,
                        color: Colors.deepPurple,
                        backgroundColor: Colors.grey.shade400,
                      );
                    },
                  );
                },
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
    final ext = name.split('.').last.toUpperCase();
    final size = msg['file_size'] != null
        ? '${(msg['file_size'] / 1024).toStringAsFixed(1)} KB'
        : '';

    // Optional: choose icon based on file type
    IconData fileIcon;
    Color bgColor;
    switch (ext) {
      case 'PDF':
        fileIcon = Icons.picture_as_pdf;
        bgColor = Colors.red.shade100;
        break;
      case 'DOC':
      case 'DOCX':
        fileIcon = Icons.description;
        bgColor = Colors.blue.shade100;
        break;
      case 'XLS':
      case 'XLSX':
        fileIcon = Icons.grid_on;
        bgColor = Colors.green.shade100;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        bgColor = Colors.grey.shade300;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (url.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: Text(name),
                    backgroundColor: Colors.deepPurple,
                  ),
                  body: SfPdfViewer.network(url),
                ),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          width: MediaQuery.of(context).size.width * 0.65,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                fileIcon,
                size: 40,
                color: Colors.grey.shade800,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$ext • $size',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_circle_down, color: Colors.grey),
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          final googleMapsUrl =
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
          launchUrlString(googleMapsUrl, mode: LaunchMode.externalApplication);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          width: MediaQuery.of(context).size.width * 0.65,
          height: MediaQuery.of(context).size.width * 0.45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.grey.shade200, Colors.grey.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white70,
                    child: const Icon(
                      Icons.location_on,
                      size: 40,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.65,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
      if (lastDate != dateStr) {
        lastDate = dateStr;
        widgets.add(
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatDateHeader(createdAt),
                style: const TextStyle(color: Colors.white, fontSize: 12),
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
        title: Text(widget.phone),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_turned_in),
            onPressed: _resolveChat,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () => _showAttachmentOptions(context),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (value) => _sendMessage(text: value),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(text: _controller.text.trim()),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6A11CB),
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
        ],
      ),
    );
  }
}
