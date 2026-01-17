import 'package:flutter/material.dart';
import '../viewmodels/nakama_chat_view_model.dart';
import '../models/chat_message.dart';

/// Chat page view for real-time messaging via Nakama
class ChatPage extends StatefulWidget {
  final String friendId; // Key Service user ID
  final String? friendNakamaUserId; // Nakama user ID (optional, will try to get if null)
  const ChatPage({
    super.key,
    required this.friendId,
    this.friendNakamaUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final NakamaChatViewModel _viewModel;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = NakamaChatViewModel(
      friendUserId: widget.friendId,
      friendNakamaUserId: widget.friendNakamaUserId,
    );
  }

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
        title: Text(_viewModel.isConnected ? 'Chat' : 'Connecting...'),
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

              // Connection status
              if (!_viewModel.isConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.orange.shade50,
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Connecting to chat...'),
                    ],
                  ),
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
                    // Send button
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _viewModel.canSend
                          ? () => _handleSend()
                          : null,
                      tooltip: 'Send message',
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
    final isMe = message.sender == 'me';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 16,
              child: Text(
                message.sender[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.plaintext,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 16,
              child: const Text(
                'Me',
                style: TextStyle(color: Colors.white, fontSize: 10),
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
    final text = _inputController.text.trim();
    if (text.isNotEmpty && _viewModel.canSend) {
      _viewModel.sendMessage(text);
      _inputController.clear();
      _scrollToBottom();
    }
  }
}

