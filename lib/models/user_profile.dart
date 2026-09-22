class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.preferredLanguage,
    this.profileImageUrl,
  });

  final String id;
  final String email;
  final String name;
  final String preferredLanguage;
  final String? profileImageUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'].toString(),
      email: json['email'].toString(),
      name: json['name'].toString(),
      preferredLanguage: json['preferredLanguage'].toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }
}

class CreateProfileRequest {
  const CreateProfileRequest({
    required this.name,
    required this.preferredLanguage,
  });

  final String name;
  final String preferredLanguage;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'preferredLanguage': preferredLanguage,
    };
  }
}
