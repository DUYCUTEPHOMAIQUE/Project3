class Friend {
  final String ownerUserId;
  final String userId;
  final String username;
  final String? email;
  final String friendshipId;
  final int createdAt;

  Friend({
    required this.ownerUserId,
    required this.userId,
    required this.username,
    this.email,
    required this.friendshipId,
    required this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      ownerUserId: json['owner_user_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      friendshipId: json['friendship_id'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'owner_user_id': ownerUserId,
      'user_id': userId,
      'username': username,
      'email': email,
      'friendship_id': friendshipId,
      'created_at': createdAt,
    };
  }

  @override
  String toString() {
    return 'Friend(userId: $userId, username: $username, friendshipId: $friendshipId)';
  }
}
