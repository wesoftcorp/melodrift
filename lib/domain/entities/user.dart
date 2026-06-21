class UserModel {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;

  const UserModel({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
  });

  /// Convert a UserModel to a JSON Map
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
    };
  }

  /// Create a UserModel from a JSON Map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
