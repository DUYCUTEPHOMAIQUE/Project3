import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import 'chat_page.dart';

class FriendListPage extends StatefulWidget {
  const FriendListPage({super.key});

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  final _apiService = ApiService();
  List<dynamic> _friends = [];
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final friends = await _apiService.getFriends();
      final requests = await _apiService.getFriendRequests();
      setState(() {
        _friends = friends;
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
      print('[UI] Add friend: $query');
      
      setState(() => _isLoading = true);
      
      try {
        final response = await _apiService.sendFriendRequest(query);
        if (!mounted) return;
        
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Friend request sent successfully!'),
            backgroundColor: response['error'] != null ? Colors.red : Colors.green,
            duration: Duration(seconds: response['error'] != null ? 3 : 2),
          ),
        );
        
        if (response['error'] == null) {
          _loadData();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    print('=== ACCEPT FRIEND REQUEST START ===');
    print('Request ID: $requestId');
    
    try {
      print('Calling API to accept friend request...');
      final response = await _apiService.acceptFriendRequest(requestId);
      
      print('=== API RESPONSE ===');
      print('Response: $response');
      
      if (!mounted) return;
      
      if (response['error'] != null) {
        print('ERROR: ${response['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error']),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        print('SUCCESS: Friend request accepted');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Friend request accepted!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadData();
      }
    } catch (e, stackTrace) {
      print('=== EXCEPTION ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    print('=== ACCEPT FRIEND REQUEST END ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _apiService.clearToken();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  if (_requests.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Friend Requests',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._requests.map((req) => ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(req['username'] ?? 'Unknown'),
                          subtitle: Text(req['email'] ?? ''),
                          trailing: ElevatedButton(
                            onPressed: () => _acceptRequest(req['request_id']),
                            child: const Text('Accept'),
                          ),
                        )),
                    const Divider(),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Friends',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          onPressed: _addFriend,
                        ),
                      ],
                    ),
                  ),
                  if (_friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No friends yet')),
                    )
                  else
                    ..._friends.map((friend) => ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(friend['username'] ?? 'Unknown'),
                          subtitle: Text(friend['email'] ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(friendId: friend['user_id'] ?? ''),
                              ),
                            );
                          },
                        )),
                ],
              ),
            ),
    );
  }
}
