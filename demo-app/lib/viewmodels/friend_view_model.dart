import 'package:flutter/foundation.dart';
import '../models/friend/friend.dart';
import '../models/friend/friend_request.dart';
import '../services/friend_service.dart';

class FriendViewModel extends ChangeNotifier {
  final FriendService _friendService = FriendService();

  List<Friend> _friends = [];
  List<FriendRequest> _pendingRequests = [];
  List<FriendRequest> _sentRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Friend> get friends => _friends;
  List<FriendRequest> get pendingRequests => _pendingRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load all friend data (friends, pending requests, sent requests)
  Future<void> loadAllData() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final friends = await _friendService.getFriends();
      final pendingRequests = await _friendService.getFriendRequests();
      final sentRequests = await _friendService.getSentFriendRequests();

      _friends = friends;
      _pendingRequests = pendingRequests;
      _sentRequests = sentRequests;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      print('[FriendViewModel] ❌ Error loading data: $e');
      _errorMessage = 'Failed to load data: $e';
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(String query) async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _friendService.sendFriendRequest(query);
      
      if (result['error'] != null) {
        _errorMessage = result['error'] as String;
        _setLoading(false);
        notifyListeners();
        return false;
      }

      await loadAllData();
      return true;
    } catch (e) {
      print('[FriendViewModel] ❌ Error: $e');
      _errorMessage = 'Failed to send request: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _friendService.acceptFriendRequest(requestId);
      
      if (result['error'] != null) {
        _errorMessage = result['error'] as String;
        _setLoading(false);
        notifyListeners();
        return false;
      }

      await loadAllData();
      return true;
    } catch (e) {
      print('[FriendViewModel] ❌ Error: $e');
      _errorMessage = 'Failed to accept request: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _friendService.rejectFriendRequest(requestId);
      
      if (result['error'] != null) {
        _errorMessage = result['error'] as String;
        _setLoading(false);
        notifyListeners();
        return false;
      }

      await loadAllData();
      return true;
    } catch (e) {
      print('[FriendViewModel] ❌ Error: $e');
      _errorMessage = 'Failed to reject request: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(String friendUserId) async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _friendService.removeFriend(friendUserId);
      
      if (result['error'] != null) {
        _errorMessage = result['error'] as String;
        _setLoading(false);
        notifyListeners();
        return false;
      }

      await loadAllData();
      return true;
    } catch (e) {
      print('[FriendViewModel] ❌ Error: $e');
      _errorMessage = 'Failed to remove friend: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
