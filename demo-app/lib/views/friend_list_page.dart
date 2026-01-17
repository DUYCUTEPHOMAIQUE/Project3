import 'package:flutter/material.dart';
import '../viewmodels/friend_view_model.dart';
import '../services/auth_service.dart';
import '../models/friend/friend.dart';
import '../models/friend/friend_request.dart';
import 'login_page.dart';
import 'chat_page.dart';

class FriendListPage extends StatefulWidget {
  const FriendListPage({super.key});

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _viewModel = FriendViewModel();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadAllData();
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addFriend() async {
    final queryController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: queryController,
          decoration: const InputDecoration(
            labelText: 'Username or Email',
            hintText: 'Enter username or email',
            helperText: 'You can search by username or email address',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (result == true && queryController.text.trim().isNotEmpty) {
      final query = queryController.text.trim();
      final success = await _viewModel.sendFriendRequest(query);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Friend request sent successfully!' 
                : (_viewModel.errorMessage ?? 'Failed to send request'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: Duration(seconds: success ? 2 : 3),
        ),
      );
    }
  }

  Future<void> _handleAcceptRequest(FriendRequest request) async {
    final success = await _viewModel.acceptFriendRequest(request.requestId);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success 
              ? 'Friend request accepted!' 
              : (_viewModel.errorMessage ?? 'Failed to accept request'),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: Duration(seconds: success ? 2 : 3),
      ),
    );
  }

  Future<void> _handleRejectRequest(FriendRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Text('Reject friend request from ${request.fromUsername}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _viewModel.rejectFriendRequest(request.requestId);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Friend request rejected' 
                : (_viewModel.errorMessage ?? 'Failed to reject request'),
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleRemoveFriend(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${friend.username} from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _viewModel.removeFriend(friend.userId);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Friend removed' 
                : (_viewModel.errorMessage ?? 'Failed to remove friend'),
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends', icon: Icon(Icons.people)),
            Tab(text: 'Requests', icon: Icon(Icons.notifications)),
            Tab(text: 'Sent', icon: Icon(Icons.send)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _addFriend,
            tooltip: 'Add Friend',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _viewModel.isLoading && _viewModel.friends.isEmpty && 
          _viewModel.pendingRequests.isEmpty && _viewModel.sentRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _viewModel.loadAllData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsTab(_viewModel),
                  _buildRequestsTab(_viewModel),
                  _buildSentTab(_viewModel),
                ],
              ),
            ),
    );
  }

  Widget _buildFriendsTab(FriendViewModel viewModel) {
    if (viewModel.friends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Add friends to start chatting',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: viewModel.friends.length,
      itemBuilder: (context, index) {
        final friend = viewModel.friends[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(friend.username[0].toUpperCase()),
          ),
          title: Text(friend.username),
          subtitle: friend.email != null ? Text(friend.email!) : null,
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.chat, size: 20),
                    SizedBox(width: 8),
                    Text('Chat'),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(friendId: friend.userId),
                    ),
                  );
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.person_remove, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remove', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onTap: () => _handleRemoveFriend(friend),
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(friendId: friend.userId),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab(FriendViewModel viewModel) {
    if (viewModel.pendingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: viewModel.pendingRequests.length,
      itemBuilder: (context, index) {
        final request = viewModel.pendingRequests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(request.fromUsername[0].toUpperCase()),
            ),
            title: Text(request.fromUsername),
            subtitle: request.fromEmail != null ? Text(request.fromEmail!) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => _handleAcceptRequest(request),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Accept'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _handleRejectRequest(request),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSentTab(FriendViewModel viewModel) {
    if (viewModel.sentRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No sent requests',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: viewModel.sentRequests.length,
      itemBuilder: (context, index) {
        final request = viewModel.sentRequests[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(request.toUsername[0].toUpperCase()),
          ),
          title: Text(request.toUsername),
          subtitle: Text(request.toUsername),
          trailing: Chip(
            label: Text(
              request.status.toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: request.status == 'pending' 
                ? Colors.orange.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
          ),
        );
      },
    );
  }
}
