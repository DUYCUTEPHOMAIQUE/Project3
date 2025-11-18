import 'package:flutter/material.dart';
import '../viewmodels/chat_view_model.dart';
import '../models/chat_message.dart';

/// Chat page view for bidirectional messaging
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatViewModel _viewModel = ChatViewModel();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('E2EE Chat - Alice & Bob'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _viewModel.isLoading
                ? null
                : () {
                    _viewModel.clearConversation();
                  },
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              // Status message
              if (_viewModel.statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: _viewModel.statusMessage.contains('Error')
                      ? Colors.red.shade100
                      : Colors.blue.shade50,
                  child: Text(
                    _viewModel.statusMessage,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

              // Setup section (collapsible)
              ExpansionTile(
                title: const Text('Setup (Keys & Sessions)'),
                initiallyExpanded: _viewModel.messages.isEmpty,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _viewModel.isLoading ||
                                        !_viewModel.canCreateAliceSession
                                    ? null
                                    : () => _viewModel.createAliceSession(),
                                child: const Text('Create Alice Session'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _viewModel.isLoading ||
                                        !_viewModel.canCreateBobSession
                                    ? null
                                    : () => _viewModel.createBobSession(),
                                child: const Text('Create Bob Session'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Chat messages list
              Expanded(
                child: _viewModel.messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet.\nStart chatting!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _viewModel.messages.length,
                        itemBuilder: (context, index) {
                          final message = _viewModel.messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
              ),

              // Input area
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) => _viewModel.updateInput(value),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _handleSend();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send as Alice button
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _viewModel.isLoading || !_viewModel.canSendAsAlice
                          ? null
                          : () => _handleSendAsAlice(),
                      tooltip: 'Send as Alice',
                    ),
                    // Send as Bob button
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.green),
                      onPressed: _viewModel.isLoading || !_viewModel.canSendAsBob
                          ? null
                          : () => _handleSendAsBob(),
                      tooltip: 'Send as Bob',
                    ),
                  ],
                ),
              ),

              // Loading indicator
              if (_viewModel.isLoading)
                const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isAlice = message.sender == 'alice';
    final isDecrypted = message.isDecrypted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isAlice ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAlice) ...[
            CircleAvatar(
              backgroundColor: Colors.green,
              radius: 16,
              child: Text(
                'B',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAlice ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isAlice ? Colors.blue.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isDecrypted && message.isEncrypted)
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Decrypting...',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _viewModel.decryptMessage(message),
                              child: const Text('Decrypt'),
                            ),
                          ],
                        )
                      else
                        Text(
                          isDecrypted
                              ? message.decryptedText ?? message.plaintext
                              : message.plaintext,
                          style: const TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${message.sender.toUpperCase()} • ${_formatTime(message.timestamp)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isAlice) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 16,
              child: const Text(
                'A',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _handleSend() {
    // Default: send as Alice if both sessions exist, otherwise use available session
    if (_viewModel.canSendAsAlice) {
      _handleSendAsAlice();
    } else if (_viewModel.canSendAsBob) {
      _handleSendAsBob();
    }
  }

  void _handleSendAsAlice() {
    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      _viewModel.sendMessageAsAlice(text);
      _inputController.clear();
      _scrollToBottom();
      // Auto-decrypt after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _viewModel.decryptAllPendingMessages();
      });
    }
  }

  void _handleSendAsBob() {
    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      _viewModel.sendMessageAsBob(text);
      _inputController.clear();
      _scrollToBottom();
      // Auto-decrypt after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _viewModel.decryptAllPendingMessages();
      });
    }
  }
}

