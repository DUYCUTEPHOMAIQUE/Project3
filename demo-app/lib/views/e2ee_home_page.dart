import 'package:flutter/material.dart';
import '../viewmodels/e2ee_view_model.dart';

/// Home page view for E2EE Demo
class E2EEHomePage extends StatefulWidget {
  const E2EEHomePage({super.key});

  @override
  State<E2EEHomePage> createState() => _E2EEHomePageState();
}

class _E2EEHomePageState extends State<E2EEHomePage> {
  final E2EEViewModel _viewModel = E2EEViewModel();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('E2EE Demo - Alice & Bob'),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusMessage(),
                const SizedBox(height: 16),
                _buildGenerateKeysSection(),
                const SizedBox(height: 16),
                _buildCreateSessionsSection(),
                const SizedBox(height: 16),
                _buildEncryptDecryptSection(),
                if (_viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusMessage() {
    if (_viewModel.statusMessage.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _viewModel.statusMessage.contains('Error')
            ? Colors.red.shade100
            : Colors.green.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_viewModel.statusMessage),
    );
  }

  Widget _buildGenerateKeysSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Generate Keys',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () => _viewModel.generateAliceKeys(),
                    child: const Text('Generate Alice Keys'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () => _viewModel.generateBobKeys(),
                    child: const Text('Generate Bob Keys'),
                  ),
                ),
              ],
            ),
            if (_viewModel.aliceIdentity.publicKeyHex.isNotEmpty ||
                _viewModel.bobIdentity.publicKeyHex.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_viewModel.aliceIdentity.publicKeyHex.isNotEmpty)
                      Text(
                        'Alice Public Key: ${_viewModel.aliceIdentity.publicKeyHex.substring(0, 16)}...',
                      ),
                    if (_viewModel.bobIdentity.publicKeyHex.isNotEmpty)
                      Text(
                        'Bob Public Key: ${_viewModel.bobIdentity.publicKeyHex.substring(0, 16)}...',
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateSessionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '2. Create Sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _viewModel.isLoading || !_viewModel.canCreateAliceSession
                        ? null
                        : () => _viewModel.createAliceSession(),
                    child: const Text('Create Alice Session'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _viewModel.isLoading || !_viewModel.canCreateBobSession
                        ? null
                        : () => _viewModel.createBobSession(),
                    child: const Text('Create Bob Session'),
                  ),
                ),
              ],
            ),
            if (_viewModel.aliceSession.sessionId.isNotEmpty ||
                _viewModel.bobSession.sessionId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_viewModel.aliceSession.sessionId.isNotEmpty)
                      Text('Alice Session: ${_viewModel.aliceSession.sessionId}'),
                    if (_viewModel.bobSession.sessionId.isNotEmpty)
                      Text('Bob Session: ${_viewModel.bobSession.sessionId}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEncryptDecryptSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '3. Encrypt & Decrypt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Enter message to encrypt',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _viewModel.updateMessageText(value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _viewModel.isLoading || !_viewModel.canEncrypt
                        ? null
                        : () => _viewModel.encryptMessage(_messageController.text),
                    child: const Text('Encrypt (Alice)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _viewModel.isLoading || !_viewModel.canDecrypt
                        ? null
                        : () => _viewModel.decryptMessage(),
                    child: const Text('Decrypt (Bob)'),
                  ),
                ),
              ],
            ),
            if (_viewModel.message.isEncrypted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Encrypted (Base64):'),
                    SelectableText(
                      _viewModel.message.encryptedBase64!.length > 100
                          ? '${_viewModel.message.encryptedBase64!.substring(0, 100)}...'
                          : _viewModel.message.encryptedBase64!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (_viewModel.message.isDecrypted)
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
                        _viewModel.message.decryptedText!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

