import 'dart:async';
import 'dart:convert';
import 'package:nakama/nakama.dart';
import 'package:nakama/src/api/api.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';
import '../bridge_generated/ffi/api.dart' as rust_api;
import 'nakama_service.dart';
import 'chat_session_manager.dart';
import 'token_storage.dart';

/// Service để handle chat operations với Nakama
class ChatService {
  final NakamaService _nakamaService;
  final ChatSessionManager _sessionManager;
  StreamSubscription<api.ChannelMessage>? _messageSubscription;
  String? _currentChannelId;
  String? _currentFriendUserId; // For session management
  final StreamController<ChannelMessage> _messageController = StreamController<ChannelMessage>.broadcast();

  ChatService({
    NakamaService? nakamaService,
    ChatSessionManager? sessionManager,
  })  : _nakamaService = nakamaService ?? NakamaService(),
        _sessionManager = sessionManager ?? ChatSessionManager();

  /// Stream để listen messages
  Stream<ChannelMessage> get messageStream => _messageController.stream;

  /// Join direct message channel với một user
  /// [otherUserId] là Nakama user ID của user kia
  /// [friendUserId] là Key Service user ID (để quản lý session)
  /// Returns channel ID nếu thành công
  Future<String?> joinDirectMessageChannel(String otherUserId, {String? friendUserId}) async {
    try {
      // Ensure socket is connected
      if (!_nakamaService.isSocketConnected()) {
        final connected = await _nakamaService.connectSocket();
        if (!connected) {
          print('[ChatService] ❌ Failed to connect socket');
          return null;
        }
      }

      final socket = _nakamaService.getSocket();
      if (socket == null) {
        print('[ChatService] ❌ Socket is null');
        return null;
      }

      // Check if we have saved channel ID for this friend
      String? savedChannelId;
      if (friendUserId != null) {
        final tokenStorage = TokenStorage();
        savedChannelId = await tokenStorage.getChannelId(friendUserId);
        if (savedChannelId != null && savedChannelId.isNotEmpty) {
          print('[ChatService] 🔍 Found saved channel ID: $savedChannelId');
        }
      }

      // Join DM channel
      print('[ChatService] 🔍 Joining DM channel with user ID: $otherUserId');
      final channel = await socket.joinChannel(
        target: otherUserId,
        type: ChannelType.directMessage,
        persistence: true,
        hidden: false,
      );

      print('[ChatService] 🔍 Channel response: id=${channel.id}, userIdOne=${channel.userIdOne}, userIdTwo=${channel.userIdTwo}');
      
      if (channel.id.isEmpty) {
        print('[ChatService] ❌ Channel ID is empty!');
        print('[ChatService] 🔍 Channel details: presences=${channel.presences.length}, self=${channel.self.userId}');
        // Try to use saved channel ID as fallback
        if (savedChannelId != null && savedChannelId.isNotEmpty) {
          print('[ChatService] 🔍 Using saved channel ID as fallback: $savedChannelId');
          _currentChannelId = savedChannelId;
          _currentFriendUserId = friendUserId;
          return savedChannelId;
        }
        return null;
      }

      // Verify channel ID matches saved one (if exists)
      if (savedChannelId != null && savedChannelId != channel.id) {
        print('[ChatService] ⚠️  Channel ID mismatch! Saved: $savedChannelId, Got: ${channel.id}');
        print('[ChatService] 🔍 Updating saved channel ID to: ${channel.id}');
        if (friendUserId != null) {
          final tokenStorage = TokenStorage();
          await tokenStorage.saveChannelId(friendUserId, channel.id);
        }
      } else if (savedChannelId == null && friendUserId != null) {
        // Save channel ID for future use
        print('[ChatService] 💾 Saving channel ID for future use: ${channel.id}');
        final tokenStorage = TokenStorage();
        await tokenStorage.saveChannelId(friendUserId, channel.id);
      }

      _currentChannelId = channel.id;
      _currentFriendUserId = friendUserId;
      print('[ChatService] ✅ Joined DM channel: ${channel.id}');

      // DON'T create session when joining channel
      // Session will be created when:
      // 1. Sending first message → create initiator session
      // 2. Receiving first message with ephemeral key → create responder session
      // This ensures only one side creates initiator session
      print('[ChatService] 🔐 Session will be created on first message send/receive');

      // Listen to channel messages
      _setupMessageListener();

      return channel.id;
    } catch (e) {
      print('[ChatService] ❌ Error joining channel: $e');
      return null;
    }
  }

  /// Setup listener cho messages
  void _setupMessageListener() {
    final socket = _nakamaService.getSocket();
    if (socket == null) return;

    _messageSubscription?.cancel();
    _messageSubscription = socket.onChannelMessage.listen((apiMessage) async {
      if (apiMessage.channelId == _currentChannelId) {
        print('[ChatService] 📨 Received message from: ${apiMessage.senderId}');
        
        // Convert và decrypt message
        final message = await _processReceivedMessage(apiMessage);
        _messageController.add(message);
      }
    });
  }

  /// Process received message: convert và decrypt nếu cần
  /// Returns ChannelMessage với decrypted content (nếu encrypted)
  Future<ChannelMessage> _processReceivedMessage(api.ChannelMessage apiMessage) async {
    // Parse content (JSON string)
    Map<String, dynamic> contentMap = {};
    try {
      contentMap = jsonDecode(apiMessage.content) as Map<String, dynamic>;
    } catch (_) {
      // If not JSON, use as plain text
      contentMap = {'message': apiMessage.content};
    }

    String messageText = contentMap['message'] as String? ?? apiMessage.content;
    final isEncryptedStr = contentMap['encrypted'] as String? ?? 'false';
    final isEncrypted = isEncryptedStr.toLowerCase() == 'true';

    // Decrypt nếu message được encrypt
    if (isEncrypted && _currentFriendUserId != null) {
      print('[ChatService] 🔓 Decrypting message...');
      print('[ChatService] 🔍 Content keys: ${contentMap.keys.toList()}');
      print('[ChatService] 🔍 Has ephemeral_key: ${contentMap.containsKey('ephemeral_key')}');
      print('[ChatService] 🔍 Has alice_identity: ${contentMap.containsKey('alice_identity')}');
      
      try {
        var sessionId = await _sessionManager.getSessionId(_currentFriendUserId!);
        print('[ChatService] 🔍 Current session ID: ${sessionId != null ? sessionId.substring(0, 8) + '...' : 'null'}');
        
        // If message has ephemeral key, this is the first message from sender
        // We MUST create responder session to decrypt it (even if we have an initiator session)
        if (contentMap.containsKey('ephemeral_key') && contentMap.containsKey('alice_identity')) {
          print('[ChatService] 🔐 Message has ephemeral key - this is first message from sender');
          final ephemeralKeyHex = contentMap['ephemeral_key'] as String?;
          final aliceIdentityHex = contentMap['alice_identity'] as String?;
          
          print('[ChatService] 🔍 Ephemeral key: ${ephemeralKeyHex != null ? ephemeralKeyHex.substring(0, 16) + '...' : 'null'}');
          print('[ChatService] 🔍 Alice identity: ${aliceIdentityHex != null ? aliceIdentityHex.substring(0, 16) + '...' : 'null'}');
          
          if (ephemeralKeyHex != null && aliceIdentityHex != null) {
            // Clear any existing session (might be wrong type)
            if (sessionId != null && !sessionId.startsWith('Error:')) {
              print('[ChatService] 🔐 Clearing existing session (might be wrong type)...');
              await _sessionManager.clearSession(_currentFriendUserId!);
            }
            
            // Create responder session
            sessionId = await _sessionManager.createResponderSession(
              _currentFriendUserId!,
              aliceIdentityHex,
              ephemeralKeyHex,
            );
            
            if (sessionId == null) {
              print('[ChatService] ❌ Failed to create responder session');
            } else {
              print('[ChatService] ✅ Responder session created: ${sessionId.substring(0, 8)}..., ready to decrypt...');
            }
          } else {
            print('[ChatService] ⚠️  Ephemeral key or identity is null');
          }
        } else if (sessionId != null && !sessionId.startsWith('Error:')) {
          // Session exists - try to decrypt first
          print('[ChatService] 🔍 Session exists, trying to decrypt with existing session...');
          try {
            final decryptedBytes = rust_api.decryptMessage(
              sessionId: sessionId,
              envelopeBase64: messageText,
            );
            
            if (decryptedBytes.isNotEmpty && !utf8.decode(decryptedBytes).startsWith('Error:')) {
              // Success! Use existing session
              messageText = utf8.decode(decryptedBytes);
              print('[ChatService] ✅ Message decrypted successfully with existing session');
              contentMap['message'] = messageText;
              contentMap['encrypted'] = 'false';
              return ChannelMessage.fromDto(apiMessage);
            } else {
              // Decryption failed - might be wrong session type
              final errorMsg = decryptedBytes.isNotEmpty ? utf8.decode(decryptedBytes) : 'Empty response';
              print('[ChatService] ⚠️  Decryption failed with existing session: $errorMsg');
              
              // If message has ephemeral key, recreate as responder session
              if (contentMap.containsKey('ephemeral_key') && contentMap.containsKey('alice_identity')) {
                print('[ChatService] 🔐 Message has ephemeral key, recreating as responder session...');
                await _sessionManager.clearSession(_currentFriendUserId!);
                
                final ephemeralKeyHex = contentMap['ephemeral_key'] as String?;
                final aliceIdentityHex = contentMap['alice_identity'] as String?;
                
                if (ephemeralKeyHex != null && aliceIdentityHex != null) {
                  sessionId = await _sessionManager.createResponderSession(
                    _currentFriendUserId!,
                    aliceIdentityHex,
                    ephemeralKeyHex,
                  );
                  
                  if (sessionId != null) {
                    print('[ChatService] ✅ Recreated as responder session: ${sessionId.substring(0, 8)}...');
                    // Retry decryption with new session
                    final retryDecryptedBytes = rust_api.decryptMessage(
                      sessionId: sessionId,
                      envelopeBase64: messageText,
                    );
                    
                    if (retryDecryptedBytes.isNotEmpty && !utf8.decode(retryDecryptedBytes).startsWith('Error:')) {
                      messageText = utf8.decode(retryDecryptedBytes);
                      print('[ChatService] ✅ Message decrypted successfully with responder session');
                      contentMap['message'] = messageText;
                      contentMap['encrypted'] = 'false';
                      return ChannelMessage.fromDto(apiMessage);
                    } else {
                      final retryError = retryDecryptedBytes.isNotEmpty ? utf8.decode(retryDecryptedBytes) : 'Empty';
                      print('[ChatService] ⚠️  Decryption still failed with responder session: $retryError');
                    }
                  }
                }
              }
            }
          } catch (e) {
            print('[ChatService] ⚠️  Decryption error with existing session: $e');
          }
        }
        
        // Final decryption attempt if we have a session
        if (sessionId != null && !sessionId.startsWith('Error:')) {
          try {
            // Decrypt với Rust core
            final decryptedBytes = rust_api.decryptMessage(
              sessionId: sessionId,
              envelopeBase64: messageText,
            );
            
            if (decryptedBytes.isNotEmpty && !utf8.decode(decryptedBytes).startsWith('Error:')) {
              messageText = utf8.decode(decryptedBytes);
              print('[ChatService] ✅ Message decrypted successfully');
              
              // Update contentMap với decrypted text
              contentMap['message'] = messageText;
              contentMap['encrypted'] = 'false';
            } else {
              final errorMsg = decryptedBytes.isNotEmpty ? utf8.decode(decryptedBytes) : 'Empty response';
              print('[ChatService] ⚠️  Decryption failed: $errorMsg');
            }
          } catch (e) {
            print('[ChatService] ⚠️  Decryption error: $e');
            // Keep encrypted text if decryption fails
          }
        } else {
          print('[ChatService] ⚠️  No session found for decryption');
        }
      } catch (e) {
        print('[ChatService] ⚠️  Decryption error: $e');
      }
    }

    // Update content của apiMessage với decrypted text
    // ChannelMessage.fromDto sẽ sử dụng content này
    final updatedContent = jsonEncode(contentMap);
    
    // Create a new api.ChannelMessage với updated content
    // We'll modify the content directly since ChannelMessage.fromDto reads from apiMessage.content
    final updatedApiMessage = api.ChannelMessage(
      channelId: apiMessage.channelId,
      messageId: apiMessage.messageId,
      code: apiMessage.code,
      username: apiMessage.username,
      senderId: apiMessage.senderId,
      content: updatedContent, // Use updated content with decrypted text
      createTime: apiMessage.createTime,
      updateTime: apiMessage.updateTime,
      persistent: apiMessage.persistent,
      roomName: apiMessage.roomName,
      groupId: apiMessage.groupId,
      userIdOne: apiMessage.userIdOne,
      userIdTwo: apiMessage.userIdTwo,
    );

    return ChannelMessage.fromDto(updatedApiMessage);
  }

  /// Send message trong channel hiện tại
  /// [content] là nội dung message (sẽ được encrypt nếu có session)
  Future<bool> sendMessage(String content) async {
    try {
      if (_currentChannelId == null) {
        print('[ChatService] ❌ No channel joined');
        return false;
      }

      final socket = _nakamaService.getSocket();
      if (socket == null) {
        print('[ChatService] ❌ Socket is null');
        return false;
      }

      // Encrypt message nếu có session
      String messageToSend = content;
      bool isEncrypted = false;
      String? ephemeralKey;
      String? aliceIdentityHex;
      
      if (_currentFriendUserId != null) {
        print('[ChatService] 🔐 Encrypting message...');
        var sessionId = await _sessionManager.getSessionId(_currentFriendUserId!);
        
        // If no session, create initiator session (for first message)
        if (sessionId == null || sessionId.startsWith('Error:')) {
          print('[ChatService] 🔐 No session found, creating initiator session for first message...');
          sessionId = await _sessionManager.getOrCreateSession(_currentFriendUserId!, '');
          if (sessionId == null || sessionId.startsWith('Error:')) {
            print('[ChatService] ⚠️  Failed to create session, sending plaintext');
            sessionId = null;
          } else {
            print('[ChatService] ✅ Initiator session created: ${sessionId.substring(0, 8)}...');
          }
        }
        
        if (sessionId != null && !sessionId.startsWith('Error:')) {
          try {
            // Check if this is first message (has ephemeral key)
            ephemeralKey = await _sessionManager.getEphemeralKey(_currentFriendUserId!);
            
            // Encrypt với Rust core
            final plaintextBytes = utf8.encode(content);
            final encryptedBase64 = rust_api.encryptMessage(
              sessionId: sessionId,
              plaintext: plaintextBytes,
            );
            
            if (!encryptedBase64.startsWith('Error:')) {
              messageToSend = encryptedBase64;
              isEncrypted = true;
              print('[ChatService] ✅ Message encrypted successfully');
              
              // If this is first message, include ephemeral key and identity
              if (ephemeralKey != null && ephemeralKey.isNotEmpty) {
                print('[ChatService] 🔐 Including ephemeral key for first message');
                // Get Alice's identity from storage
                final prefs = await SharedPreferences.getInstance();
                aliceIdentityHex = prefs.getString('chat_session_alice_identity_$_currentFriendUserId');
              }
            } else {
              print('[ChatService] ⚠️  Encryption failed: $encryptedBase64, sending plaintext');
            }
          } catch (e) {
            print('[ChatService] ⚠️  Encryption error: $e, sending plaintext');
          }
        } else {
          print('[ChatService] ⚠️  No session found, sending plaintext');
        }
      }

      // Prepare message content
      final messageContent = <String, dynamic>{
        'message': messageToSend,
        'encrypted': isEncrypted.toString(),
      };
      
      // Include ephemeral key and identity for first message (so receiver can create responder session)
      if (isEncrypted && ephemeralKey != null && ephemeralKey.isNotEmpty) {
        messageContent['ephemeral_key'] = ephemeralKey;
        if (aliceIdentityHex != null && aliceIdentityHex.isNotEmpty) {
          messageContent['alice_identity'] = aliceIdentityHex;
        }
        print('[ChatService] 🔐 Added ephemeral key (${ephemeralKey.substring(0, 16)}...) and identity to message');
        
        // Clear ephemeral key after first message (so we don't send it again)
        await _sessionManager.clearEphemeralKey(_currentFriendUserId!);
        print('[ChatService] 🔐 Cleared ephemeral key after sending first message');
      } else {
        print('[ChatService] 🔍 No ephemeral key to include (ephemeralKey: ${ephemeralKey != null ? ephemeralKey.substring(0, 16) + '...' : 'null'})');
      }

      await socket.sendMessage(
        channelId: _currentChannelId!,
        content: messageContent.map((k, v) => MapEntry(k, v.toString())),
      );

      print('[ChatService] ✅ Message sent (encrypted: $isEncrypted)');
      return true;
    } catch (e) {
      print('[ChatService] ❌ Error sending message: $e');
      return false;
    }
  }

  /// Load message history từ local storage (Signal-style: no server-side history)
  /// Nakama chỉ là transport layer, không lưu message history
  /// Returns empty list - messages chỉ được lưu local
  Future<List<ChannelMessage>> loadMessageHistory({int limit = 50}) async {
    // Signal-style: Không load message history từ server
    // Messages chỉ được lưu local và sync qua Nakama như transport
    print('[ChatService] 📦 Signal-style: No server-side history. Messages are stored locally only.');
    return [];
  }

  /// Leave current channel
  Future<void> leaveChannel() async {
    try {
      if (_currentChannelId == null) return;

      final socket = _nakamaService.getSocket();
      if (socket != null) {
        await socket.leaveChannel(channelId: _currentChannelId!);
        print('[ChatService] ✅ Left channel: $_currentChannelId');
      }

      _messageSubscription?.cancel();
      _currentChannelId = null;
    } catch (e) {
      print('[ChatService] ❌ Error leaving channel: $e');
    }
  }

  /// Get current channel ID
  String? getCurrentChannelId() => _currentChannelId;

  /// Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.close();
  }
}
