import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../bridge_generated/frb_generated.dart';
import '../bridge_generated/ffi/api.dart' as api;
import '../models/identity.dart';
import '../models/session.dart';
import '../models/chat_message.dart';
import 'dart:convert';
import 'dart:async';

/// ViewModel for Chat Conversation
/// Manages bidirectional messaging between Alice and Bob
class ChatViewModel extends ChangeNotifier {
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

  bool get canCreateAliceSession =>
      !_aliceIdentity.isEmpty && !_bobPrekeyBundle.isEmpty;

  bool get canCreateBobSession =>
      !_bobIdentity.isEmpty &&
      !_aliceIdentity.publicKeyHex.isEmpty &&
      (_aliceSession.ephemeralPublicKeyHex?.isNotEmpty ?? false);

  bool get canSendAsAlice => _currentInput.isNotEmpty && !_aliceSession.isEmpty;

  bool get canSendAsBob => _currentInput.isNotEmpty && !_bobSession.isEmpty;

  /// Generate Alice's identity key pair
  Future<void> generateAliceKeys() async {
    _setLoading(true);
    _setStatus('Generating Alice keys...');

    try {
      final identityJson = api.generateIdentityKeyPair();
      final publicKeyHex =
          api.getPublicKeyHexFromJson(identityBytesJson: identityJson);

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
      final publicKeyHex =
          api.getPublicKeyHexFromJson(identityBytesJson: identityJson);

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
      final resultJson =
          E2EECore.instance.api.crateFfiApiCreateSessionInitiatorWithEphemeral(
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
          ephemeralKey =
              result['alice_ephemeral_public_key_hex'] as String? ?? '';
        } catch (parseErr) {
          debugPrint('Failed to parse JSON: $parseErr');
          sessionId = resultJson; // fallback
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
    debugPrint('🔑 [SESSION BOB] Starting create Bob session');

    if (!canCreateBobSession) {
      debugPrint('❌ [SESSION BOB] Cannot create - validation failed');
      _setStatus('Please generate keys and create Alice session first!');
      return;
    }

    debugPrint(
        '🔑 [SESSION BOB] Bob identity public key: ${_bobIdentity.publicKeyHex.substring(0, 16)}...');
    debugPrint(
        '🔑 [SESSION BOB] Alice identity public key: ${_aliceIdentity.publicKeyHex.substring(0, 16)}...');

    _setLoading(true);
    _setStatus('Creating Bob session...');

    try {
      final ephemeralKey = _aliceSession.ephemeralPublicKeyHex ?? '';
      debugPrint(
          '🔑 [SESSION BOB] Alice ephemeral key: ${ephemeralKey.isNotEmpty ? ephemeralKey.substring(0, 16) + '...' : 'missing'}');

      if (ephemeralKey.isEmpty) {
        debugPrint('❌ [SESSION BOB] Alice ephemeral key is missing!');
        _setStatus('Error: Alice ephemeral key is missing!');
        return;
      }

      debugPrint('🔑 [SESSION BOB] Calling X3DH responder API...');
      debugPrint('🔑 [SESSION BOB] Signed prekey ID: 1');
      debugPrint('🔑 [SESSION BOB] One-time prekey ID: 1');

      final sessionId = api.createSessionResponder(
        identityBytesJson: _bobIdentity.identityJson,
        signedPrekeyId: 1,
        oneTimePrekeyId: 1,
        aliceIdentityHex: _aliceIdentity.publicKeyHex,
        aliceEphemeralPublicKeyHex: ephemeralKey,
      );

      debugPrint('🔑 [SESSION BOB] API response received');
      debugPrint('🔑 [SESSION BOB] Session ID: $sessionId');

      _bobSession = Session(sessionId: sessionId);
      debugPrint('✅ [SESSION BOB] Session created successfully');

      _setStatus('Bob session created: ${sessionId.substring(0, 8)}...');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [SESSION BOB] Error: $e');
      debugPrint('❌ [SESSION BOB] Stack trace: ${StackTrace.current}');
      _setStatus('Error creating Bob session: $e');
    } finally {
      _setLoading(false);
      debugPrint('🔑 [SESSION BOB] Finished create session operation');
    }
  }

  /// Send message as Alice
  Future<void> sendMessageAsAlice(String plaintext) async {
    debugPrint('📤 [SEND ALICE] Starting send message as Alice');
    debugPrint('📤 [SEND ALICE] Plaintext: "$plaintext"');
    debugPrint('📤 [SEND ALICE] Plaintext length: ${plaintext.length} bytes');

    if (!canSendAsAlice) {
      debugPrint('❌ [SEND ALICE] Cannot send - validation failed');
      _setStatus('Please enter a message and create Alice session!');
      return;
    }

    debugPrint('📤 [SEND ALICE] Session ID: ${_aliceSession.sessionId}');
    _setLoading(true);
    _setStatus('Encrypting and sending message...');

    try {
      debugPrint('📤 [SEND ALICE] Encoding plaintext to UTF-8 bytes...');
      final plaintextBytes = utf8.encode(plaintext);
      debugPrint(
          '📤 [SEND ALICE] Plaintext bytes length: ${plaintextBytes.length}');

      debugPrint('📤 [SEND ALICE] Calling encryptMessage API...');
      final encrypted = api.encryptMessage(
        sessionId: _aliceSession.sessionId,
        plaintext: plaintextBytes,
      );
      debugPrint('📤 [SEND ALICE] Encryption successful!');
      debugPrint(
          '📤 [SEND ALICE] Ciphertext (base64) length: ${encrypted.length} chars');
      debugPrint(
          '📤 [SEND ALICE] Ciphertext preview: ${encrypted.substring(0, encrypted.length > 50 ? 50 : encrypted.length)}...');

      // Add message to conversation
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('📤 [SEND ALICE] Creating ChatMessage with ID: $messageId');

      final message = ChatMessage(
        id: messageId,
        sender: 'alice',
        plaintext: plaintext,
        encryptedBase64: encrypted,
        timestamp: DateTime.now(),
        isEncrypted: true,
      );

      _messages.add(message);
      debugPrint(
          '📤 [SEND ALICE] Message added to conversation. Total messages: ${_messages.length}');
      _currentInput = '';
      _setStatus('Message sent successfully!');
      debugPrint('✅ [SEND ALICE] Send completed successfully!');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [SEND ALICE] Error: $e');
      _setStatus('Error sending message: $e');
    } finally {
      _setLoading(false);
      debugPrint('📤 [SEND ALICE] Finished send operation');
    }
  }

  /// Send message as Bob
  Future<void> sendMessageAsBob(String plaintext) async {
    debugPrint('📤 [SEND BOB] Starting send message as Bob');
    debugPrint('📤 [SEND BOB] Plaintext: "$plaintext"');
    debugPrint('📤 [SEND BOB] Plaintext length: ${plaintext.length} bytes');

    if (!canSendAsBob) {
      debugPrint('❌ [SEND BOB] Cannot send - validation failed');
      _setStatus('Please enter a message and create Bob session!');
      return;
    }

    debugPrint('📤 [SEND BOB] Session ID: ${_bobSession.sessionId}');
    _setLoading(true);
    _setStatus('Encrypting and sending message...');

    try {
      debugPrint('📤 [SEND BOB] Encoding plaintext to UTF-8 bytes...');
      final plaintextBytes = utf8.encode(plaintext);
      debugPrint(
          '📤 [SEND BOB] Plaintext bytes length: ${plaintextBytes.length}');

      debugPrint('📤 [SEND BOB] Calling encryptMessage API...');
      final encrypted = api.encryptMessage(
        sessionId: _bobSession.sessionId,
        plaintext: plaintextBytes,
      );
      debugPrint('📤 [SEND BOB] Encryption successful!');
      debugPrint(
          '📤 [SEND BOB] Ciphertext (base64) length: ${encrypted.length} chars');
      debugPrint(
          '📤 [SEND BOB] Ciphertext preview: ${encrypted.substring(0, encrypted.length > 50 ? 50 : encrypted.length)}...');

      // Add message to conversation
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('📤 [SEND BOB] Creating ChatMessage with ID: $messageId');

      final message = ChatMessage(
        id: messageId,
        sender: 'bob',
        plaintext: plaintext,
        encryptedBase64: encrypted,
        timestamp: DateTime.now(),
        isEncrypted: true,
      );

      _messages.add(message);
      debugPrint(
          '📤 [SEND BOB] Message added to conversation. Total messages: ${_messages.length}');
      _currentInput = '';
      _setStatus('Message sent successfully!');
      debugPrint('✅ [SEND BOB] Send completed successfully!');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [SEND BOB] Error: $e');
      _setStatus('Error sending message: $e');
    } finally {
      _setLoading(false);
      debugPrint('📤 [SEND BOB] Finished send operation');
    }
  }

  /// Decrypt received message (for Bob when receiving from Alice, or vice versa)
  Future<void> decryptMessage(ChatMessage message) async {
    if (message.isDecrypted) {
      return; // Already decrypted
    }

    _setLoading(true);
    _setStatus('Decrypting message...');

    try {
      // Determine which session to use based on sender
      final sessionId = message.sender == 'alice'
          ? _bobSession.sessionId
          : _aliceSession.sessionId;

      if (sessionId.isEmpty) {
        _setStatus('Error: Session not found for decryption!');
        return;
      }

      final decryptedBytes = api.decryptMessage(
        sessionId: sessionId,
        envelopeBase64: message.encryptedBase64!,
      );

      // Decode bytes thành string
      final decryptedText = utf8.decode(decryptedBytes);
      debugPrint('Decrypted message: $decryptedText');

      // Kiểm tra nếu là error message từ Rust
      if (decryptedText.startsWith('Error:')) {
        _setStatus(decryptedText);
        return;
      }

      // Update message with decrypted text
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = message.copyWith(
          decryptedText: decryptedText,
          isDecrypted: true,
        );
        _setStatus('Message decrypted successfully!');
        notifyListeners();
      }
    } catch (e) {
      _setStatus('Error decrypting message: $e');
      debugPrint('Exception during decryption: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Auto-decrypt all pending encrypted messages
  Future<void> decryptAllPendingMessages() async {
    debugPrint('🔄 [AUTO-DECRYPT] Starting auto-decrypt all pending messages');
    final pendingCount =
        _messages.where((m) => m.isEncrypted && !m.isDecrypted).length;
    debugPrint('🔄 [AUTO-DECRYPT] Found $pendingCount pending messages');

    int decryptedCount = 0;
    for (final message in _messages) {
      if (message.isEncrypted && !message.isDecrypted) {
        debugPrint('🔄 [AUTO-DECRYPT] Decrypting message ID: ${message.id}');
        await decryptMessage(message);
        decryptedCount++;
      }
    }

    debugPrint(
        '✅ [AUTO-DECRYPT] Completed. Decrypted $decryptedCount messages');
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
