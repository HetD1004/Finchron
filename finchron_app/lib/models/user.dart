class User {
  final String id;
  final String name;
  final String email;
  final String? profilePictureUrl;
  final String? googleId;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePictureUrl,
    this.googleId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profilePictureUrl: json['profilePictureUrl'],
      googleId: json['googleId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'googleId': googleId,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profilePictureUrl,
    String? googleId,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      googleId: googleId ?? this.googleId,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, profilePictureUrl: $profilePictureUrl, googleId: $googleId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && 
           other.id == id &&
           other.name == name &&
           other.email == email &&
           other.profilePictureUrl == profilePictureUrl &&
           other.googleId == googleId;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, profilePictureUrl, googleId);
  }
}
