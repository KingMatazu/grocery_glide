class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isAnonymous;
  final DateTime createdAt;
  final String accountType; // 'free' or 'premium'

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.isAnonymous,
    required this.createdAt,
    this.accountType = 'free',
  });

  // Create from Firebase User
  factory AppUser.fromFirebaseUser(dynamic firebaseUser) {
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoURL: firebaseUser.photoURL,
      isAnonymous: firebaseUser.isAnonymous,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isAnonymous': isAnonymous,
      'createdAt': createdAt.toIso8601String(),
      'accountType': accountType,
    };
  }

  // Create from JSON
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'],
      email: json['email'],
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      isAnonymous: json['isAnonymous'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      accountType: json['accountType'] ?? 'free',
    );
  }

  // Copy with method for updates
  AppUser copyWith({
    String? displayName,
    String? photoURL,
    String? accountType,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isAnonymous: isAnonymous,
      createdAt: createdAt,
      accountType: accountType ?? this.accountType,
    );
  }

  bool get isPremium => accountType == 'premium';
  bool get isFree => accountType == 'free';
}