/// User model từ Key Service
class User {
  final String userId;
  final String username;
  final String? email;
  final int? createdAt;

  User({
    required this.userId,
    required this.username,
    this.email,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      createdAt: json['created_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      if (email != null) 'email': email,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}
