import 'package:flutter/material.dart';
import 'bridge_generated/frb_generated.dart';
import 'bridge_generated/ffi/api.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_rust_bridge
  if (Platform.isWindows) {
    // Load the Windows DLL from the Rust crate's target directory
    final lib = ExternalLibrary.open('core-rust/target/release/e2ee_core.dll');
    await E2EECore.init(externalLibrary: lib);
  } else {
    await E2EECore.init();
  }

  runApp(const E2EEDemoApp());
}

class E2EEDemoApp extends StatelessWidget {
  const E2EEDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2EE Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const E2EEDemoHomePage(),
    );
  }
}

class E2EEDemoHomePage extends StatefulWidget {
  const E2EEDemoHomePage({super.key});

  @override
  State<E2EEDemoHomePage> createState() => _E2EEDemoHomePageState();
}

class _E2EEDemoHomePageState extends State<E2EEDemoHomePage> {
  String _aliceIdentityJson = '';
  String _bobIdentityJson = '';
  String _bobPrekeyBundleJson = '';
  String _aliceSessionId = '';
  String _bobSessionId = '';
  String _alicePublicKey = '';
  String _bobPublicKey = '';
  String _messageText = '';
  String _encryptedMessage = '';
  String _decryptedMessage = '';
  String _aliceEphemeralPublicKeyHex = '';
  String _statusMessage = '';
  bool _isLoading = false;

  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _generateAliceKeys() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating Alice keys...';
    });

    try {
      final identityJson = generateIdentityKeyPair();
      setState(() {
        _aliceIdentityJson = identityJson;
        _alicePublicKey =
            getPublicKeyHexFromJson(identityBytesJson: identityJson);
        _statusMessage = 'Alice keys generated successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error generating Alice keys: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateBobKeys() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating Bob keys...';
    });

    try {
      final identityJson = generateIdentityKeyPair();
      setState(() {
        _bobIdentityJson = identityJson;
        _bobPublicKey =
            getPublicKeyHexFromJson(identityBytesJson: identityJson);
      });

      // Generate prekey bundle for Bob
      final bundleJson = generatePrekeyBundle(
        identityBytesJson: identityJson,
        signedPrekeyId: 1,
        oneTimePrekeyId: 1,
      );
      setState(() {
        _bobPrekeyBundleJson = bundleJson;
        _statusMessage = 'Bob keys and prekey bundle generated successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error generating Bob keys: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAliceSession() async {
    if (_aliceIdentityJson.isEmpty || _bobPrekeyBundleJson.isEmpty) {
      setState(() {
        _statusMessage = 'Please generate keys first!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating Alice session...';
    });

    try {
      final resultJson =
          E2EECore.instance.api.crateFfiApiCreateSessionInitiatorWithEphemeral(
        identityBytesJson: _aliceIdentityJson,
        prekeyBundleJson: _bobPrekeyBundleJson,
      );
      // Debug output to inspect what Rust returned
      // If bindings were regenerated to include JSON, this will be JSON string; otherwise plain session_id
      // ignore: avoid_print
      print('createSessionInitiator result (raw): $resultJson');
      // Try pretty-print when JSON
      try {
        final dynamic decoded = json.decode(resultJson);
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        // ignore: avoid_print
        print('createSessionInitiator result (pretty):\n$pretty');
      } catch (_) {
        // Not JSON, ignore
      }

      String sessionId = '';
      String eph = '';
      final trimmed = resultJson.trimLeft();
      if (trimmed.startsWith('{')) {
        try {
          final Map<String, dynamic> result =
              json.decode(resultJson) as Map<String, dynamic>;
          sessionId = result['session_id'] as String? ?? '';
          eph = result['alice_ephemeral_public_key_hex'] as String? ?? '';
        } catch (parseErr) {
          // ignore: avoid_print
          print('Failed to parse JSON from createSessionInitiator: $parseErr');
          sessionId = resultJson; // fallback
        }
      } else {
        // Old binding returns plain session id
        sessionId = resultJson;
      }

      // ignore: avoid_print
      print('Alice sessionId: $sessionId');
      // ignore: avoid_print
      print(
          'Alice eph pub key (hex): ${eph.isEmpty ? '<empty>' : eph.substring(0, eph.length.clamp(0, 16)) + '...'}');
      setState(() {
        _aliceSessionId = sessionId;
        _aliceEphemeralPublicKeyHex = eph;
        _statusMessage =
            'Alice session created: ${sessionId.substring(0, 8)}...';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating Alice session: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createBobSession() async {
    if (_bobIdentityJson.isEmpty ||
        _alicePublicKey.isEmpty ||
        _aliceEphemeralPublicKeyHex.isEmpty) {
      setState(() {
        _statusMessage = 'Please generate keys and create Alice session first!';
      });
      // Debug guidance if ephemeral key is missing
      if (_aliceEphemeralPublicKeyHex.isEmpty) {
        // ignore: avoid_print
        print('Bob session aborted: aliceEphemeralPublicKeyHex is empty.');
        // ignore: avoid_print
        print(
            'Hint: Regenerate FRB bindings to expose createSessionInitiatorWithEphemeral, or ensure Rust returns JSON.');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating Bob session...';
    });

    try {
      // Use Alice's ephemeral public key returned from initiator
      // ignore: avoid_print
      print('Creating Bob session with params:');
      // ignore: avoid_print
      print(
          '  aliceIdentityHex: ${_alicePublicKey.substring(0, _alicePublicKey.length.clamp(0, 16))}...');
      // ignore: avoid_print
      print(
          '  aliceEphemeralPublicKeyHex: ${_aliceEphemeralPublicKeyHex.substring(0, _aliceEphemeralPublicKeyHex.length.clamp(0, 16))}...');
      final sessionId = createSessionResponder(
        identityBytesJson: _bobIdentityJson,
        signedPrekeyId: 1,
        oneTimePrekeyId: 1,
        aliceIdentityHex: _alicePublicKey,
        aliceEphemeralPublicKeyHex: _aliceEphemeralPublicKeyHex,
      );
      setState(() {
        _bobSessionId = sessionId;
        _statusMessage = 'Bob session created: ${sessionId.substring(0, 8)}...';
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error creating Bob session: $e');
      setState(() {
        _statusMessage = 'Error creating Bob session: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _encryptMessage() async {
    if (_messageText.isEmpty || _aliceSessionId.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a message and create a session!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Encrypting message...';
    });

    try {
      final plaintextBytes = utf8.encode(_messageText);
      final encrypted = encryptMessage(
        sessionId: _aliceSessionId,
        plaintext: plaintextBytes,
      );
      setState(() {
        _encryptedMessage = encrypted;
        _statusMessage = 'Message encrypted successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error encrypting message: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _decryptMessage() async {
    if (_encryptedMessage.isEmpty || _bobSessionId.isEmpty) {
      setState(() {
        _statusMessage = 'Please encrypt a message and create Bob session!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Decrypting message...';
    });

    try {
      final decryptedBytes = decryptMessage(
        sessionId: _bobSessionId,
        envelopeBase64: _encryptedMessage,
      );
      final decryptedText = utf8.decode(decryptedBytes);
      setState(() {
        _decryptedMessage = decryptedText;
        _statusMessage = 'Message decrypted successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error decrypting message: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('E2EE Demo - Alice & Bob'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status message
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('Error')
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusMessage),
              ),

            // Generate Keys Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '1. Generate Keys',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _generateAliceKeys,
                            child: const Text('Generate Alice Keys'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _generateBobKeys,
                            child: const Text('Generate Bob Keys'),
                          ),
                        ),
                      ],
                    ),
                    if (_alicePublicKey.isNotEmpty || _bobPublicKey.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_alicePublicKey.isNotEmpty)
                              Text(
                                  'Alice Public Key: ${_alicePublicKey.substring(0, 16)}...'),
                            if (_bobPublicKey.isNotEmpty)
                              Text(
                                  'Bob Public Key: ${_bobPublicKey.substring(0, 16)}...'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Create Session Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '2. Create Sessions',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createAliceSession,
                            child: const Text('Create Alice Session'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createBobSession,
                            child: const Text('Create Bob Session'),
                          ),
                        ),
                      ],
                    ),
                    if (_aliceSessionId.isNotEmpty || _bobSessionId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_aliceSessionId.isNotEmpty)
                              Text('Alice Session: ${_aliceSessionId}'),
                            if (_bobSessionId.isNotEmpty)
                              Text('Bob Session: ${_bobSessionId}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Encrypt/Decrypt Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '3. Encrypt & Decrypt',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Enter message to encrypt',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _messageText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _encryptMessage,
                            child: const Text('Encrypt (Alice)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _decryptMessage,
                            child: const Text('Decrypt (Bob)'),
                          ),
                        ),
                      ],
                    ),
                    if (_encryptedMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Encrypted (Base64):'),
                            SelectableText(
                              _encryptedMessage.length > 100
                                  ? '${_encryptedMessage.substring(0, 100)}...'
                                  : _encryptedMessage,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    if (_decryptedMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Decrypted Message:'),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _decryptedMessage,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
