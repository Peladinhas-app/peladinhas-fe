class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.preferredLanguage,
    required this.capabilities,
    this.profileImageUrl,
  });

  final String id;
  final String email;
  final String name;
  final String preferredLanguage;
  final UserCapabilities capabilities;
  final String? profileImageUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'].toString(),
      email: json['email'].toString(),
      name: json['name'].toString(),
      preferredLanguage: json['preferredLanguage'].toString(),
      capabilities: UserCapabilities.fromJson(
        json['capabilities'] is Map
            ? Map<String, dynamic>.from(json['capabilities'] as Map)
            : const {},
      ),
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }
}

class UserCapabilities {
  const UserCapabilities({
    required this.player,
    required this.pitchOwner,
  });

  final bool player;
  final bool pitchOwner;

  factory UserCapabilities.fromJson(Map<String, dynamic> json) {
    return UserCapabilities(
      player: json['player'] != false,
      pitchOwner: json['pitchOwner'] == true,
    );
  }
}

enum AccountUseChoice {
  player('PLAYER'),
  pitchOwner('PITCH_OWNER');

  const AccountUseChoice(this.apiValue);

  final String apiValue;
}

class CreateProfileRequest {
  const CreateProfileRequest({
    required this.name,
    required this.preferredLanguage,
    required this.accountType,
    this.ownerInvitationCode,
  });

  final String name;
  final String preferredLanguage;
  final AccountUseChoice accountType;
  final String? ownerInvitationCode;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'preferredLanguage': preferredLanguage,
      'accountType': accountType.apiValue,
      if (accountType == AccountUseChoice.pitchOwner &&
          ownerInvitationCode != null &&
          ownerInvitationCode!.trim().isNotEmpty)
        'ownerInvitationCode': ownerInvitationCode!.trim(),
    };
  }
}
