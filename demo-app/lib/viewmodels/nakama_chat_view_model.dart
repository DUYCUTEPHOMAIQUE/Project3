import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';
import '../services/nakama_service.dart';
import '../services/token_storage.dart';
import '../models/chat_message.dart';
import 'dart:async';
import 'dart:convert';

/// ViewModel for real chat conversation via Nakama
/// Manages messaging between current user and a friend
class NakamaChatViewModel extends ChangeNotifier {
  final ChatService _chatService;
  final NakamaService _nakamaService;
  final TokenStorage _tokenStorage = TokenStorage();
  
  final String friendUserId; // Key Service user ID
  final String? friendNakamaUserId; // Nakama user ID (optional)
  String? _friendNakamaUserId; // Resolved Nakama user ID
  
  // Conversation messages
  final List<ChatMessage> _messages = [];
  
  // Current input
  String _currentInput = '';
  
  // UI State
  String _statusMessage = '';
  bool _isLoading = false;
  bool _isConnected = false;
  StreamSubscription? _messageSubscription;

  NakamaChatViewModel({
    required this.friendUserId,
    this.friendNakamaUserId,
    ChatService? chatService,
    NakamaService? nakamaService,
  })  : _chatService = chatService ?? ChatService(),
        _nakamaService = nakamaService ?? NakamaService() {
    _initialize();
  }

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String get currentInput => _currentInput;
  String get statusMessage => _statusMessage;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get canSend => _currentInput.isNotEmpty && _isConnected && !_isLoading;

  /// Initialize chat: authenticate, connect socket, join channel
  Future<void> _initialize() async {
    _setLoading(true);
    _setStatus('Initializing chat...');

    try {
      // 1. Authenticate và connect socket
      final authenticated = await _nakamaService.authenticate();
      if (!authenticated) {
        _setStatus('Error: Failed to authenticate with Nakama');
        return;
      }

      final socketConnected = await _nakamaService.connectSocket();
      if (!socketConnected) {
        _setStatus('Error: Failed to connect socket');
        return;
      }

      // 2. Get friend's Nakama user ID
      if (friendNakamaUserId != null && friendNakamaUserId!.isNotEmpty) {
        _friendNakamaUserId = friendNakamaUserId;
        print('[NakamaChatViewModel] ✅ Using provided Nakama user ID: $_friendNakamaUserId');
      } else {
        // Fallback: try to get from Nakama API or use Key Service user ID
        print('[NakamaChatViewModel] ⚠️  No Nakama user ID provided, using Key Service user ID as fallback');
        print('[NakamaChatViewModel] ⚠️  This may fail if Nakama user ID != Key Service user ID');
        _friendNakamaUserId = friendUserId;
      }

      // 3. Join DM channel (pass friendUserId for session management)
      final channelId = await _chatService.joinDirectMessageChannel(
        _friendNakamaUserId!,
        friendUserId: friendUserId,
      );
      if (channelId == null) {
        _setStatus('Error: Failed to join chat channel');
        return;
      }

      _isConnected = true;
      _setStatus('Connected to chat');

      // 4. Setup message listener
      _setupMessageListener();

      // 5. Load message history từ local storage (Signal-style)
      // Không load từ Nakama vì Nakama chỉ là transport layer
      await _loadLocalMessageHistory();

      _setStatus('');
    } catch (e) {
      _setStatus('Error initializing chat: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Setup listener for incoming messages
  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = _chatService.messageStream.listen((nakamaMessage) {
      // Convert Nakama ChannelMessage to ChatMessage
      _convertToChatMessage(nakamaMessage).then((chatMessage) {
        _messages.add(chatMessage);
        notifyListeners();
      });
    });
  }

  /// Convert Nakama ChannelMessage to ChatMessage
  Future<ChatMessage> _convertToChatMessage(dynamic nakamaMessage) async {
    // Parse content (JSON string)
    Map<String, dynamic> contentMap = {};
    try {
      contentMap = jsonDecode(nakamaMessage.content) as Map<String, dynamic>;
    } catch (_) {
      // If not JSON, use as plain text
      contentMap = {'message': nakamaMessage.content};
    }

    final messageText = contentMap['message'] as String? ?? nakamaMessage.content;
    final myNakamaUserId = await _tokenStorage.getNakamaUserID();
    final isFromMe = nakamaMessage.senderId == myNakamaUserId;

    return ChatMessage(
      id: nakamaMessage.messageId,
      sender: isFromMe ? 'me' : 'friend',
      plaintext: messageText,
      timestamp: nakamaMessage.createTime,
      isEncrypted: false, // Messages from Nakama are plaintext (will encrypt later)
    );
  }

  /// Load message history từ local storage (Signal-style)
  /// Nakama chỉ là transport, không lưu message history
  Future<void> _loadLocalMessageHistory() async {
    try {
      // TODO: Load messages từ local database/storage
      // Hiện tại chỉ load từ memory (_messages đã được populate từ real-time messages)
      print('[NakamaChatViewModel] 📦 Loading local message history (Signal-style)');
      // Messages sẽ được lưu local khi nhận/gửi qua _setupMessageListener
      notifyListeners();
    } catch (e) {
      print('[NakamaChatViewModel] Error loading local history: $e');
    }
  }

  /// Send message
  Future<void> sendMessage(String text) async {
    if (!canSend) return;

    final textToSend = text.trim();
    if (textToSend.isEmpty) return;

    _setLoading(true);
    _setStatus('Sending message...');

    try {
      final success = await _chatService.sendMessage(textToSend);
      if (success) {
        _currentInput = '';
        _setStatus('');
        notifyListeners();
      } else {
        _setStatus('Error: Failed to send message');
      }
    } catch (e) {
      _setStatus('Error sending message: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update current input text
  void updateInput(String text) {
    _currentInput = text;
    notifyListeners();
  }

  /// Clear conversation (local only)
  void clearConversation() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }
}
