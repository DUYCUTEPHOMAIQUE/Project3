class FriendRequest {
  final String requestId;
  final String fromUserId;
  final String fromUsername;
  final String? fromEmail;
  final String toUserId;
  final String toUsername;
  final String status; // "pending", "accepted", "rejected"
  final int createdAt;

  FriendRequest({
    required this.requestId,
    required this.fromUserId,
    required this.fromUsername,
    this.fromEmail,
    required this.toUserId,
    required this.toUsername,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      requestId: json['request_id'] as String? ?? '',
      fromUserId: json['from_user_id'] as String? ?? '',
      fromUsername: json['from_username'] as String? ?? '',
      fromEmail: json['from_email'] as String?,
      toUserId: json['to_user_id'] as String? ?? '',
      toUsername: json['to_username'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'from_user_id': fromUserId,
      'from_username': fromUsername,
      'from_email': fromEmail,
      'to_user_id': toUserId,
      'to_username': toUsername,
      'status': status,
      'created_at': createdAt,
    };
  }

  @override
  String toString() {
    return 'FriendRequest(requestId: $requestId, from: $fromUsername, to: $toUsername, status: $status)';
  }
}
