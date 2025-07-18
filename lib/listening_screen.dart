import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'notes_screen.dart';
import 'notes_storage.dart';
import 'network_config.dart';
import 'database_helper.dart';

class Message {
  final String text;
  final String sender;
  final DateTime timestamp;

  Message({required this.text, required this.sender, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'text': text,
        'sender': sender,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        text: json['text'] ?? '',
        sender: json['sender'] ?? 'Unknown',
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      );
}

class Conversation {
  final String conversationId;
  final String title;
  final List<Message> messages;
  final bool pinned;

  Conversation({
    required this.conversationId,
    required this.title,
    required this.messages,
    this.pinned = false,
  });

  factory Conversation.fromDb(List<Map<String, dynamic>> messages) {
    return Conversation(
      conversationId: messages.first['conversation_id'],
      title: messages.first['title'] ?? 'Chat ${messages.first['timestamp']}',
      messages: messages.map((m) => Message.fromJson({
        'text': m['message_text'],
        'sender': m['sender'],
        'timestamp': m['timestamp'],
      })).toList(),
      pinned: messages.first['pinned'] == 1,
    );
  }
}

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  ListeningScreenState createState() => ListeningScreenState();
}

class ListeningScreenState extends State<ListeningScreen> with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _filePath;
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [
    Message(
      text: "Welcome to Notiva! Enter a topic or question to get started with your study notes.",
      sender: "Notiva",
      timestamp: DateTime.now(),
    ),
  ];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _currentConversationId = DateTime.now().toIso8601String();
  String _searchQuery = '';
  final NotesStorage _notesStorage = NotesStorage();
  static const int _maxMessages = 50;
  List<Conversation> _conversations = [];
  bool _isOnline = true;
  bool _isTypingMessage = false;
  String _typingMessage = '';
  Timer? _typingTimer;
  late AnimationController _glowController;
  late Animation<Color?> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadConversations();
    _checkNetworkAndSync();
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = TweenSequence<Color?>([
      TweenSequenceItem(tween: ColorTween(begin: Color(0xFF3700FF), end: Color(0xFF5A00FF)), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: Color(0xFF5A00FF), end: Color(0xFF7D00FF)), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: Color(0xFF7D00FF), end: Color(0xFF3700FF)), weight: 1),
    ]).animate(_glowController);
  }

  Future<void> _initRecorder() async {
    if (!(await Permission.microphone.request().isGranted)) {
      if (mounted) _showError('Microphone permission is required');
    }
  }

  Future<void> _checkNetworkAndSync() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() => _isOnline = !connectivityResult.contains(ConnectivityResult.none));
    if (_isOnline) {
      await _syncConversations();
      await _notesStorage.syncNotes(NetworkConfig.baseUrl, 1);
    }
  }

  Future<void> _syncConversations() async {
    final unsyncedMessages = await DatabaseHelper.instance.getUnsyncedMessages();
    for (var msg in unsyncedMessages) {
      try {
        final response = await http.post(
          Uri.parse('${NetworkConfig.baseUrl}/api/conversations'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'conversationId': msg['conversation_id'],
            'userId': msg['user_id'],
            'messageText': msg['message_text'],
            'sender': msg['sender'],
            'timestamp': msg['timestamp'],
          }),
        );
        if (response.statusCode == 200) {
          await DatabaseHelper.instance.markAsSynced('conversations', msg['id'].toString());
        }
      } catch (e) {
        // Keep unsynced if network fails
      }
    }
  }

  Future<void> _loadConversations() async {
    try {
      final allMessages = await DatabaseHelper.instance.getConversations(1);
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var msg in allMessages) {
        grouped.putIfAbsent(msg['conversation_id'], () => []).add(msg);
      }
      setState(() {
        _conversations = grouped.values.map((msgs) => Conversation.fromDb(msgs)).toList()
          ..sort((a, b) => b.pinned ? 1 : (a.pinned ? -1 : 0));
      });
    } catch (e) {
      if (mounted) _showError('Failed to load conversations: $e');
    }
  }

  Future<void> _loadConversation(String conversationId) async {
    try {
      final messages = await DatabaseHelper.instance.getConversationMessages(conversationId);
      setState(() {
        _currentConversationId = conversationId;
        _messages.clear();
        _messages.addAll(messages.map((m) => Message.fromJson({
          'text': m['message_text'],
          'sender': m['sender'],
          'timestamp': m['timestamp'],
        })).toList());
      });
      _scrollToBottom();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError('Failed to load conversation: $e');
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      await DatabaseHelper.instance.deleteConversation(conversationId);
      setState(() {
        _conversations.removeWhere((c) => c.conversationId == conversationId);
        if (conversationId == _currentConversationId) {
          _newConversation();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted', style: TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
            backgroundColor: Color(0xFF000A29),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to delete conversation: $e');
    }
  }

  Future<void> _renameConversation(String conversationId, String currentTitle) async {
    final TextEditingController controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation', style: TextStyle(fontFamily: 'Rethink Sans')),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontFamily: 'Rethink Sans'),
          decoration: const InputDecoration(
            hintText: 'Enter conversation title',
            hintStyle: TextStyle(fontFamily: 'Rethink Sans'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Rethink Sans')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(fontFamily: 'Rethink Sans')),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && newTitle != currentTitle) {
      try {
        await DatabaseHelper.instance.updateConversationTitle(conversationId, newTitle);
        setState(() {
          final index = _conversations.indexWhere((c) => c.conversationId == conversationId);
          if (index != -1) {
            _conversations[index] = Conversation(
              conversationId: conversationId,
              title: newTitle,
              messages: _conversations[index].messages,
              pinned: _conversations[index].pinned,
            );
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation renamed', style: TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
              backgroundColor: Color(0xFF000A29),
            ),
          );
        }
      } catch (e) {
        if (mounted) _showError('Failed to rename conversation: $e');
      }
    }
  }

  Future<void> _editMessage(Message oldMessage, String newText) async {
    try {
      await DatabaseHelper.instance.updateMessage(
        _currentConversationId,
        oldMessage.timestamp.toIso8601String(),
        newText,
      );
      setState(() {
        final index = _messages.indexWhere((m) => m.timestamp == oldMessage.timestamp);
        if (index != -1) {
          _messages[index] = Message(
            text: newText,
            sender: oldMessage.sender,
            timestamp: oldMessage.timestamp,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message updated', style: TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
            backgroundColor: Color(0xFF000A29),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to update message: $e');
    }
  }

  Future<void> _pinConversation(String conversationId, bool pin) async {
    try {
      await DatabaseHelper.instance.pinConversation(conversationId, pin);
      setState(() {
        final index = _conversations.indexWhere((c) => c.conversationId == conversationId);
        if (index != -1) {
          _conversations[index] = Conversation(
            conversationId: conversationId,
            title: _conversations[index].title,
            messages: _conversations[index].messages,
            pinned: pin,
          );
          _conversations.sort((a, b) => b.pinned ? 1 : (a.pinned ? -1 : 0));
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pin ? 'Conversation pinned' : 'Conversation unpinned', style: const TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
            backgroundColor: const Color(0xFF000A29),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to pin/unpin conversation: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!(await Permission.microphone.status.isGranted)) {
        if (!(await Permission.microphone.request().isGranted)) {
          if (mounted) _showError('Microphone permission is required');
          return;
        }
      }
      final tempDir = await getTemporaryDirectory();
      _filePath = '${tempDir.path}/audio.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: _filePath!,
      );
      setState(() {
        _isRecording = true;
        _messages.add(Message(text: "Recording...", sender: "You", timestamp: DateTime.now()));
        if (_messages.length > _maxMessages) _messages.removeAt(0);
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      if (_filePath == null || !await File(_filePath!).exists()) {
        if (mounted) _showError('Recording failed: File not found');
        setState(() {
          _isRecording = false;
          _messages.removeLast();
        });
        return;
      }
      final file = File(_filePath!);
      final fileSize = await file.length();
      if (fileSize <= 44) {
        if (mounted) _showError('No audio captured');
        setState(() {
          _isRecording = false;
          _messages.removeLast();
        });
        return;
      }
      setState(() {
        _isRecording = false;
        _messages.last = Message(text: "Audio sent", sender: "You", timestamp: DateTime.now());
      });
      _scrollToBottom();
      await _sendAudioToBackend();
    } catch (e) {
      if (mounted) _showError('Failed to stop recording: $e');
      setState(() {
        _isRecording = false;
        _messages.removeLast();
      });
    }
  }

  Future<void> _sendAudioToBackend() async {
    if (_filePath == null || !File(_filePath!).existsSync()) {
      if (mounted) _showError('No valid audio file found');
      setState(() {
        _isProcessing = false;
        _messages.removeLast();
      });
      return;
    }
    setState(() => _isProcessing = true);
    final conversationHistory = _messages
        .take(_maxMessages)
        .map((m) => "${m.sender}: ${m.text}")
        .join("\n");
    await _processBackendResponse(
      () async => await NetworkConfig.postAudio(
        _filePath!,
        conversationHistory: conversationHistory,
        conversationId: _currentConversationId,
        userId: 1,
      ),
      "Transcription failed. Please try a longer recording.",
    );
  }

  Future<void> _sendTextToBackend(String text) async {
    if (text.isEmpty) {
      if (mounted) _showError('Please enter a message');
      return;
    }
    setState(() {
      _isProcessing = true;
      _messages.add(Message(text: text, sender: "You", timestamp: DateTime.now()));
      _textController.clear();
      if (_messages.length > _maxMessages) _messages.removeAt(0);
    });
    _scrollToBottom();
    final conversationHistory = _messages
        .take(_maxMessages)
        .map((m) => "${m.sender}: ${m.text}")
        .join("\n");
    await _processBackendResponse(
      () async => await NetworkConfig.postText(
        text,
        userId: 1,
        conversationHistory: conversationHistory,
        conversationId: _currentConversationId,
      ),
      "Processing failed.",
    );
  }

  Future<void> _processBackendResponse(
    Future<http.Response> Function() request,
    String errorMessage,
  ) async {
    setState(() {
      _isProcessing = true;
      _messages.add(Message(text: "Processing...", sender: "System", timestamp: DateTime.now()));
    });
    try {
      final response = await request();
      if (response.statusCode == 200) {
        String formattedNotes = response.body;
        if (formattedNotes.isNotEmpty) {
          setState(() {
            _isProcessing = false;
            _isTypingMessage = true;
            _typingMessage = '';
            _messages.removeLast();
          });
          _startTypingAnimation(formattedNotes);
        } else {
          if (mounted) _showError('No notes available');
          setState(() {
            _isProcessing = false;
            _messages.removeLast();
          });
        }
      } else {
        if (mounted) _showError('$errorMessage: ${response.statusCode} - ${response.body}');
        setState(() {
          _isProcessing = false;
          _messages.removeLast();
        });
      }
    } catch (e) {
      if (mounted) _showError('Failed to connect to server: $e');
      setState(() {
        _isProcessing = false;
        _messages.removeLast();
      });
    }
  }

  void _startTypingAnimation(String fullMessage) {
    int charIndex = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (charIndex < fullMessage.length) {
        setState(() {
          _typingMessage += fullMessage[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
        setState(() {
          _isTypingMessage = false;
          _messages.add(Message(text: _typingMessage, sender: "Notiva", timestamp: DateTime.now()));
          _typingMessage = '';
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _saveMessages() async {
    try {
      for (var message in _messages) {
        await DatabaseHelper.instance.insertMessage({
          'conversation_id': _currentConversationId,
          'user_id': 1,
          'message_text': message.text,
          'sender': message.sender,
          'timestamp': message.timestamp.toIso8601String(),
          'pinned': 0,
          'is_synced': _isOnline ? 1 : 0,
          'title': 'Chat ${message.timestamp.toIso8601String()}',
        });
      }
      await _loadConversations();
    } catch (e) {
      if (mounted) _showError('Failed to save messages: $e');
    }
  }

  Future<void> _saveToNotes(String content) async {
    try {
      final notes = await _notesStorage.loadNotes();
      final note = Note(
        id: DateTime.now().toIso8601String(),
        title: "Note from Chat",
        content: content,
        timestamp: DateTime.now(),
        isSynced: false,
      );
      notes.add(note);
      await _notesStorage.saveNotes(notes);
      if (_isOnline) await _notesStorage.syncNotes(NetworkConfig.baseUrl, 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved successfully', style: TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
            backgroundColor: Color(0xFF000A29),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to save note: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard', style: TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
          backgroundColor: Color(0xFF000A29),
        ),
      );
    }
  }

  void _shareMessage(String text) {
    share_plus.Share.share(
      text,
      subject: 'Notiva Note',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message shared', style: TextStyle(color: Colors.white, fontFamily: 'Rethink Sans')),
          backgroundColor: Color(0xFF000A29),
        ),
      );
    }
  }

  void _newConversation() {
    setState(() {
      _currentConversationId = DateTime.now().toIso8601String();
      _messages.clear();
      _messages.add(Message(
        text: "Welcome to Notiva! Enter a topic or question to get started with your study notes.",
        sender: "Notiva",
        timestamp: DateTime.now(),
      ));
    });
    _saveMessages();
  }

  Widget _buildMathWidget(String mathText, bool isDisplay) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50, maxWidth: 300),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withAlpha(51)),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: TeXView(
        child: TeXViewDocument(
          mathText,
          style: TeXViewStyle(
            contentColor: Colors.white,
            fontStyle: TeXViewFontStyle(fontSize: isDisplay ? 18 : 15),
            backgroundColor: Colors.transparent,
            padding: const TeXViewPadding.all(8),
          ),
        ),
        style: TeXViewStyle(
          backgroundColor: Colors.transparent,
          border: TeXViewBorder.all(TeXViewBorderDecoration(
            borderWidth: 0,
            borderColor: Colors.transparent,
          )),
        ),
      ),
    );
  }

  Widget _buildMessageContent(String text, String sender) {
    final parts = _splitMarkdownAndMath(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part.isMath) {
          final regex = RegExp(r'^\$+|\$+$');
          final mathText = part.text.replaceAll(regex, '').trim();
          final isDisplay = part.text.startsWith(r'$$') && part.text.endsWith(r'$$');
          return _buildMathWidget(mathText, isDisplay);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: MarkdownBody(
            selectable: true,
            data: part.text.replaceAll(r'\*', '*'),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: Color(0xFF000A29), fontSize: 15, fontFamily: 'Rethink Sans', fontWeight: FontWeight.w600),
              h1: const TextStyle(color: Color(0xFF000A29), fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Rethink Sans'),
              h2: const TextStyle(color: Color(0xFF000A29), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rethink Sans'),
              strong: const TextStyle(color: Color(0xFF000A29), fontWeight: FontWeight.bold, fontFamily: 'Rethink Sans'),
              a: const TextStyle(color: Colors.blue, fontSize: 15, decoration: TextDecoration.underline, fontFamily: 'Rethink Sans'),
              code: const TextStyle(color: Color(0xFF000A29), fontSize: 14, backgroundColor: Colors.white70),
              listBullet: const TextStyle(color: Color(0xFF000A29), fontSize: 15, fontFamily: 'Rethink Sans', fontWeight: FontWeight.w600),
            ),
            onTapLink: (text, href, title) async {
              if (href != null && await canLaunchUrl(Uri.parse(href))) {
                await launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
              } else {
                if (mounted) _showError('Could not open link: $href');
              }
            },
          ),
        );
      }).toList(),
    );
  }

  List<TextPart> _splitMarkdownAndMath(String text) {
    final parts = <TextPart>[];
    final mathRegex = RegExp(r'\$\$[\s\S]*?\$\$|\$[^\$]*?\$', multiLine: true);
    int lastIndex = 0;
    for (final match in mathRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        parts.add(TextPart(text: text.substring(lastIndex, match.start), isMath: false));
      }
      parts.add(TextPart(text: match.group(0)!, isMath: true));
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      parts.add(TextPart(text: text.substring(lastIndex), isMath: false));
    }
    return parts;
  }

  Widget _buildMessageItem(Message message) {
    final isUser = message.sender == "You";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF000A29),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(isUser ? 'assets/user.png' : 'assets/ai.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.sender,
                  style: const TextStyle(
                    color: Color(0xFF000A29),
                    fontSize: 14,
                    fontFamily: 'Rethink Sans',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                _buildMessageContent(message.text, message.sender),
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: 0.7,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              image: DecorationImage(image: AssetImage('assets/share.png'), fit: BoxFit.cover),
                            ),
                          ),
                          onPressed: () => _shareMessage(message.text),
                        ),
                        IconButton(
                          icon: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              image: DecorationImage(image: AssetImage('assets/add-post.png'), fit: BoxFit.cover),
                            ),
                          ),
                          onPressed: () async {
                            final shouldSave = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Save Note', style: TextStyle(fontFamily: 'Rethink Sans')),
                                content: const Text('Do you want to save this note?', style: TextStyle(fontFamily: 'Rethink Sans')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Rethink Sans')),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Save', style: TextStyle(fontFamily: 'Rethink Sans')),
                                  ),
                                ],
                              ),
                            );
                            if (shouldSave == true) _saveToNotes(message.text);
                          },
                        ),
                        IconButton(
                          icon: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              image: DecorationImage(image: AssetImage('assets/copy-document.png'), fit: BoxFit.cover),
                            ),
                          ),
                          onPressed: () => _copyMessage(message.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 40, left: 32, right: 32),
                child: TextField(
                  style: const TextStyle(
                    color: Color(0xFF000A29),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Rethink Sans',
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search Notiva History",
                    hintStyle: TextStyle(color: Color.fromRGBO(0, 10, 41, 0.5), fontFamily: 'Rethink Sans'),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Image.asset('assets/search.png', width: 20, height: 20),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(65),
                      borderSide: const BorderSide(color: Color(0xFF000A29)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 32, top: 16),
                child: Text(
                  "CONVERSATIONS",
                  style: TextStyle(
                    color: Color(0xFF000A29),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Rethink Sans',
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    final timestamp = convo.messages.first.timestamp;
                    final timeStr = '${timestamp.day}-${timestamp.month}-${timestamp.year}';
                    if (_searchQuery.isNotEmpty && !convo.title.toLowerCase().contains(_searchQuery)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _loadConversation(convo.conversationId),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    convo.title,
                                    style: const TextStyle(
                                      color: Color(0xFF000A29),
                                      fontSize: 15,
                                      fontFamily: 'Rethink Sans',
                                    ),
                                  ),
                                  Text(
                                    "Last Modified: $timeStr",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontFamily: 'Rethink Sans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Image.asset('assets/more-vertical.png', width: 20, height: 20),
                            onSelected: (value) {
                              if (value == 'pin') {
                                _pinConversation(convo.conversationId, !convo.pinned);
                              } else if (value == 'delete') {
                                _deleteConversation(convo.conversationId);
                              } else if (value == 'rename') {
                                _renameConversation(convo.conversationId, convo.title);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(
                                  convo.pinned ? 'Unpin' : 'Pin',
                                  style: const TextStyle(fontFamily: 'Rethink Sans', color: Color(0xFF000A29)),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(fontFamily: 'Rethink Sans', color: Colors.redAccent),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text(
                                  'Rename',
                                  style: TextStyle(fontFamily: 'Rethink Sans', color: Color(0xFF000A29)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  children: [
                    IconButton(
                      icon: Image.asset('assets/edit.png', width: 24, height: 24),
                      onPressed: () => Navigator.pushNamed(context, '/notes'),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Image.asset('assets/home.png', width: 24, height: 24),
                      onPressed: () => Navigator.pushNamed(context, '/main_menu'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Chat Area
          ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(top: 80, bottom: 120 + MediaQuery.of(context).viewInsets.bottom),
            itemCount: _messages.length + (_isTypingMessage ? 1 : 0) + (_isProcessing ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isProcessing && index == _messages.length) {
                return Padding(
                  padding: const EdgeInsets.only(left: 68, bottom: 16),
                  child: Row(
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3700FF))),
                      const SizedBox(width: 8),
                      const Text(
                        "Notiva is thinking...",
                        style: TextStyle(color: Color(0xFF000A29), fontSize: 14, fontFamily: 'Rethink Sans'),
                      ),
                    ],
                  ),
                );
              } else if (_isTypingMessage && index == _messages.length) {
                return _buildMessageItem(Message(text: _typingMessage, sender: "Notiva", timestamp: DateTime.now()));
              }
              return _buildMessageItem(_messages[index]);
            },
          ),
          // App Bar
          Positioned(
            left: 0,
            top: MediaQuery.of(context).padding.top,
            child: Container(
              width: 392,
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        image: DecorationImage(image: AssetImage('assets/menu.png'), fit: BoxFit.cover),
                      ),
                    ),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const Text(
                    'Notiva',
                    style: TextStyle(
                      color: Color(0xFF000A29),
                      fontSize: 22,
                      fontFamily: 'Rethink Sans',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        image: DecorationImage(image: AssetImage('assets/plus.png'), fit: BoxFit.cover),
                      ),
                    ),
                    onPressed: _newConversation,
                  ),
                ],
              ),
            ),
          ),
          // Input Area
          Positioned(
            left: 13,
            bottom: 13,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 366,
                  height: 91,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000A29),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _glowAnimation.value!.withAlpha(127),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Rethink Sans',
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Cue your thoughts...',
                            hintStyle: TextStyle(
                              color: Color.fromRGBO(255, 255, 255, 0.56),
                              fontSize: 18,
                              fontFamily: 'Rethink Sans',
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            if (!_isProcessing) {
                              if (_textController.text.isNotEmpty) {
                                _sendTextToBackend(_textController.text);
                              } else {
                                _isRecording ? _stopRecording() : _startRecording();
                              }
                            }
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(255, 255, 255, 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                      _textController.text.isNotEmpty ? 'assets/send.png' : 'assets/voice.png',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _glowController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }
}

class TextPart {
  final String text;
  final bool isMath;

  TextPart({required this.text, required this.isMath});
}
