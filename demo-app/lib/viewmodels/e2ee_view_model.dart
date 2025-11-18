import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../bridge_generated/frb_generated.dart';
import '../bridge_generated/ffi/api.dart' as api;
import '../models/identity.dart';
import '../models/session.dart';
import '../models/message.dart';
import 'dart:convert';

/// ViewModel for E2EE Demo App
/// Manages all business logic and state
class E2EEViewModel extends ChangeNotifier {
  // Identities
  Identity _aliceIdentity = Identity(identityJson: '', publicKeyHex: '');
  Identity _bobIdentity = Identity(identityJson: '', publicKeyHex: '');
  PrekeyBundle _bobPrekeyBundle = PrekeyBundle(bundleJson: '');

  // Sessions
  Session _aliceSession = Session(sessionId: '');
  Session _bobSession = Session(sessionId: '');

  // Message
  Message _message = Message(plaintext: '');

  // UI State
  String _statusMessage = '';
  bool _isLoading = false;

  // Getters
  Identity get aliceIdentity => _aliceIdentity;
  Identity get bobIdentity => _bobIdentity;
  PrekeyBundle get bobPrekeyBundle => _bobPrekeyBundle;
  Session get aliceSession => _aliceSession;
  Session get bobSession => _bobSession;
  Message get message => _message;
  String get statusMessage => _statusMessage;
  bool get isLoading => _isLoading;

  bool get canCreateAliceSession =>
      !_aliceIdentity.isEmpty && !_bobPrekeyBundle.isEmpty;

  bool get canCreateBobSession =>
      !_bobIdentity.isEmpty &&
      !_aliceIdentity.publicKeyHex.isEmpty &&
      (_aliceSession.ephemeralPublicKeyHex?.isNotEmpty ?? false);

  bool get canEncrypt =>
      _message.hasPlaintext && !_aliceSession.isEmpty;

  bool get canDecrypt =>
      _message.isEncrypted && !_bobSession.isEmpty;

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

  /// Encrypt message using Alice's session
  Future<void> encryptMessage(String plaintext) async {
    if (!canEncrypt) {
      _setStatus('Please enter a message and create a session!');
      return;
    }

    _setLoading(true);
    _setStatus('Encrypting message...');

    try {
      final plaintextBytes = utf8.encode(plaintext);
      final encrypted = api.encryptMessage(
        sessionId: _aliceSession.sessionId,
        plaintext: plaintextBytes,
      );

      _message = Message(
        plaintext: plaintext,
        encryptedBase64: encrypted,
      );

      _setStatus('Message encrypted successfully!');
      notifyListeners();
    } catch (e) {
      _setStatus('Error encrypting message: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Decrypt message using Bob's session
  Future<void> decryptMessage() async {
    if (!canDecrypt) {
      _setStatus('Please encrypt a message and create Bob session!');
      return;
    }

    _setLoading(true);
    _setStatus('Decrypting message...');

    try {
      final decryptedBytes = api.decryptMessage(
        sessionId: _bobSession.sessionId,
        envelopeBase64: _message.encryptedBase64!,
      );

      // Decode bytes thành string
      final decryptedText = utf8.decode(decryptedBytes);
      debugPrint('Decrypted message: $decryptedText');

      // Kiểm tra nếu là error message từ Rust
      if (decryptedText.startsWith('Error:')) {
        _setStatus(decryptedText);
        _message = Message(
          plaintext: _message.plaintext,
          encryptedBase64: _message.encryptedBase64,
        );
        return;
      }

      // Thành công - cập nhật message với decrypted text
      _message = Message(
        plaintext: _message.plaintext,
        encryptedBase64: _message.encryptedBase64,
        decryptedText: decryptedText,
      );

      _setStatus('Message decrypted successfully!');
      notifyListeners();
    } catch (e) {
      _setStatus('Error decrypting message: $e');
      debugPrint('Exception during decryption: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update message plaintext
  void updateMessageText(String text) {
    _message = Message(plaintext: text);
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

