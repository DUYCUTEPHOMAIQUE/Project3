import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../bridge_generated/frb_generated.dart';
import '../bridge_generated/ffi/api.dart' as api;
import '../models/identity.dart';
import '../models/session.dart';
import '../models/chat_message.dart';
import '../services/mock_backend_service.dart';
import 'dart:convert';
import 'dart:async';

/// ViewModel for Chat with Backend Integration
/// 
/// This demonstrates how to integrate E2EE with a backend:
/// - Backend only sees ciphertext (encrypted messages)
/// - Backend cannot decrypt messages
/// - Client encrypts before sending, decrypts after receiving
class ChatWithBackendViewModel extends ChangeNotifier {
  // User IDs
  static const String aliceId = 'alice';
  static const String bobId = 'bob';

  // Identities
  Identity _aliceIdentity = Identity(identityJson: '', publicKeyHex: '');
  Identity _bobIdentity = Identity(identityJson: '', publicKeyHex: '');
  PrekeyBundle _bobPrekeyBundle = PrekeyBundle(bundleJson: '');

  // Sessions
  Session _aliceSession = Session(sessionId: '');
  Session _bobSession = Session(sessionId: '');

  // Conversation messages
  final List<ChatMessage> _messages = [];

  // Current input
  String _currentInput = '';

  // UI State
  String _statusMessage = '';
  bool _isLoading = false;
  bool _isPolling = false;

  // Polling subscription
  StreamSubscription<List<BackendMessage>>? _pollingSubscription;

  // Getters
  Identity get aliceIdentity => _aliceIdentity;
  Identity get bobIdentity => _bobIdentity;
  PrekeyBundle get bobPrekeyBundle => _bobPrekeyBundle;
  Session get aliceSession => _aliceSession;
  Session get bobSession => _bobSession;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String get currentInput => _currentInput;
  String get statusMessage => _statusMessage;
  bool get isLoading => _isLoading;
  bool get isPolling => _isPolling;

  bool get canCreateAliceSession =>
      !_aliceIdentity.isEmpty && !_bobPrekeyBundle.isEmpty;

  bool get canCreateBobSession =>
      !_bobIdentity.isEmpty &&
      !_aliceIdentity.publicKeyHex.isEmpty &&
      (_aliceSession.ephemeralPublicKeyHex?.isNotEmpty ?? false);

  bool get canSendAsAlice =>
      _currentInput.isNotEmpty && !_aliceSession.isEmpty;

  bool get canSendAsBob =>
      _currentInput.isNotEmpty && !_bobSession.isEmpty;

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  /// Generate Alice's identity key pair
  Future<void> generateAliceKeys() async {
    _setLoading(true);
    _setStatus('Generating Alice keys...');

    try {
      final identityJson = api.generateIdentityKeyPair();
      final publicKeyHex = api.getPublicKeyHexFromJson(identityBytesJson: identityJson);

      _aliceIdentity = Identity(
        identityJson: identityJson,
        publicKeyHex: publicKeyHex,
      );

      _setStatus('Alice keys generated successfully!');
      notifyListeners();
    } catch (e) {
      _setStatus('Error generating Alice keys: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Generate Bob's identity key pair and prekey bundle
  Future<void> generateBobKeys() async {
    _setLoading(true);
    _setStatus('Generating Bob keys...');

    try {
      final identityJson = api.generateIdentityKeyPair();
      final publicKeyHex = api.getPublicKeyHexFromJson(identityBytesJson: identityJson);

      _bobIdentity = Identity(
        identityJson: identityJson,
        publicKeyHex: publicKeyHex,
      );

      // Generate prekey bundle
      final bundleJson = api.generatePrekeyBundle(
        identityBytesJson: identityJson,
        signedPrekeyId: 1,
        oneTimePrekeyId: 1,
      );

      _bobPrekeyBundle = PrekeyBundle(bundleJson: bundleJson);

      _setStatus('Bob keys and prekey bundle generated successfully!');
      notifyListeners();
    } catch (e) {
      _setStatus('Error generating Bob keys: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create Alice session (initiator)
  Future<void> createAliceSession() async {
    if (!canCreateAliceSession) {
      _setStatus('Please generate keys first!');
      return;
    }

    _setLoading(true);
    _setStatus('Creating Alice session...');

    try {
      final resultJson = E2EECore.instance.api.crateFfiApiCreateSessionInitiatorWithEphemeral(
        identityBytesJson: _aliceIdentity.identityJson,
        prekeyBundleJson: _bobPrekeyBundle.bundleJson,
      );

      // Parse JSON response
      String sessionId = '';
      String ephemeralKey = '';

      if (resultJson.trimLeft().startsWith('{')) {
        try {
          final Map<String, dynamic> result =
              json.decode(resultJson) as Map<String, dynamic>;
          sessionId = result['session_id'] as String? ?? '';
          ephemeralKey = result['alice_ephemeral_public_key_hex'] as String? ?? '';
        } catch (parseErr) {
          debugPrint('Failed to parse JSON: $parseErr');
          sessionId = resultJson;
        }
      } else {
        sessionId = resultJson;
      }

      _aliceSession = Session(
        sessionId: sessionId,
        ephemeralPublicKeyHex: ephemeralKey.isNotEmpty ? ephemeralKey : null,
      );

      _setStatus('Alice session created: ${sessionId.substring(0, 8)}...');
      notifyListeners();
    } catch (e) {
      _setStatus('Error creating Alice session: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create Bob session (responder)
  Future<void> createBobSession() async {
    if (!canCreateBobSession) {
      _setStatus('Please generate keys and create Alice session first!');
      return;
    }

    _setLoading(true);
    _setStatus('Creating Bob session...');

    try {
      final ephemeralKey = _aliceSession.ephemeralPublicKeyHex ?? '';
      if (ephemeralKey.isEmpty) {
        _setStatus('Error: Alice ephemeral key is missing!');
        return;
      }

      final sessionId = api.createSessionResponder(
        identityBytesJson: _bobIdentity.identityJson,
        signedPrekeyId: 1,
        oneTimePrekeyId: 1,
        aliceIdentityHex: _aliceIdentity.publicKeyHex,
        aliceEphemeralPublicKeyHex: ephemeralKey,
      );

      _bobSession = Session(sessionId: sessionId);
      _setStatus('Bob session created: ${sessionId.substring(0, 8)}...');
      notifyListeners();
    } catch (e) {
      _setStatus('Error creating Bob session: $e');
      debugPrint('Error creating Bob session: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Send message as Alice through backend
  /// 
  /// Flow:
  /// 1. Encrypt message locally using Alice's session
  /// 2. Send ciphertext (base64) to backend
  /// 3. Backend stores and forwards to Bob
  /// 4. Backend CANNOT decrypt - only sees ciphertext
  Future<void> sendMessageAsAlice(String plaintext) async {
    if (!canSendAsAlice) {
      _setStatus('Please enter a message and create Alice session!');
      return;
    }

    _setLoading(true);
    _setStatus('Encrypting and sending message...');

    try {
      // Step 1: Encrypt locally (client-side only)
      final plaintextBytes = utf8.encode(plaintext);
      final encryptedBase64 = api.encryptMessage(
        sessionId: _aliceSession.sessionId,
        plaintext: plaintextBytes,
      );

      // Step 2: Send ciphertext to backend
      // Backend only sees encrypted data, cannot decrypt
      await MockBackendService.sendMessage(
        senderId: aliceId,
        recipientId: bobId,
        ciphertextBase64: encryptedBase64,
      );

      // Step 3: Add to local conversation (for UI)
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'alice',
        plaintext: plaintext,
        encryptedBase64: encryptedBase64,
        timestamp: DateTime.now(),
        isEncrypted: true,
      );

      _messages.add(message);
      _currentInput = '';
      _setStatus('Message sent! (Backend received ciphertext only)');
      notifyListeners();
    } catch (e) {
      _setStatus('Error sending message: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Send message as Bob through backend
  Future<void> sendMessageAsBob(String plaintext) async {
    if (!canSendAsBob) {
      _setStatus('Please enter a message and create Bob session!');
      return;
    }

    _setLoading(true);
    _setStatus('Encrypting and sending message...');

    try {
      // Encrypt locally
      final plaintextBytes = utf8.encode(plaintext);
      final encryptedBase64 = api.encryptMessage(
        sessionId: _bobSession.sessionId,
        plaintext: plaintextBytes,
      );

      // Send ciphertext to backend
      await MockBackendService.sendMessage(
        senderId: bobId,
        recipientId: aliceId,
        ciphertextBase64: encryptedBase64,
      );

      // Add to local conversation
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'bob',
        plaintext: plaintext,
        encryptedBase64: encryptedBase64,
        timestamp: DateTime.now(),
        isEncrypted: true,
      );

      _messages.add(message);
      _currentInput = '';
      _setStatus('Message sent! (Backend received ciphertext only)');
      notifyListeners();
    } catch (e) {
      _setStatus('Error sending message: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Receive and decrypt messages from backend
  /// 
  /// Flow:
  /// 1. Fetch encrypted messages from backend
  /// 2. Decrypt locally using recipient's session
  /// 3. Backend never sees plaintext
  Future<void> receiveAndDecryptMessages(String userId) async {
    _setLoading(true);
    _setStatus('Receiving messages from backend...');

    try {
      // Step 1: Fetch encrypted messages from backend
      final backendMessages = await MockBackendService.receiveMessages(userId);

      if (backendMessages.isEmpty) {
        _setStatus('No new messages');
        return;
      }

      debugPrint('[Backend] Received ${backendMessages.length} encrypted messages');

      // Step 2: Decrypt each message locally
      for (final backendMsg in backendMessages) {
        // Determine which session to use
        final sessionId = userId == bobId
            ? _bobSession.sessionId
            : _aliceSession.sessionId;

        if (sessionId.isEmpty) {
          debugPrint('[Backend] No session found for decryption');
          continue;
        }

        // Decrypt locally (backend never sees plaintext)
        final decryptedBytes = api.decryptMessage(
          sessionId: sessionId,
          envelopeBase64: backendMsg.ciphertextBase64,
        );

        final decryptedText = utf8.decode(decryptedBytes);

        // Check for errors
        if (decryptedText.startsWith('Error:')) {
          debugPrint('[Backend] Decryption error: $decryptedText');
          continue;
        }

        // Add decrypted message to conversation
        final message = ChatMessage(
          id: backendMsg.id,
          sender: backendMsg.senderId,
          plaintext: decryptedText, // Plaintext only available after decryption
          encryptedBase64: backendMsg.ciphertextBase64,
          decryptedText: decryptedText,
          timestamp: backendMsg.timestamp,
          isEncrypted: true,
          isDecrypted: true,
        );

        _messages.add(message);
        debugPrint('[Backend] Decrypted message from ${backendMsg.senderId}');
      }

      _setStatus('Received and decrypted ${backendMessages.length} message(s)');
      notifyListeners();
    } catch (e) {
      _setStatus('Error receiving messages: $e');
      debugPrint('Exception during receive: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Start polling for new messages
  void startPolling(String userId) {
    if (_isPolling) return;

    _isPolling = true;
    _setStatus('Polling for messages...');
    notifyListeners();

    _pollingSubscription = MockBackendService.pollMessages(userId).listen(
      (backendMessages) {
        if (backendMessages.isNotEmpty) {
          receiveAndDecryptMessages(userId);
        }
      },
      onError: (error) {
        debugPrint('Polling error: $error');
        _setStatus('Polling error: $error');
      },
    );
  }

  /// Stop polling
  void stopPolling() {
    _pollingSubscription?.cancel();
    _pollingSubscription = null;
    _isPolling = false;
    notifyListeners();
  }

  /// Update current input text
  void updateInput(String text) {
    _currentInput = text;
    notifyListeners();
  }

  /// Clear conversation
  void clearConversation() {
    _messages.clear();
    _currentInput = '';
    MockBackendService.clearAll();
    notifyListeners();
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

