enum UserTier { free, vip, admin, ceo }

class UserSession {
  final String userId;
  final String username;
  final String email;
  final String token;
  final UserTier tier;
  final bool discordStatusEnabled;

  UserSession({
    required this.userId,
    required this.username,
    required this.email,
    required this.token,
    required this.tier,
    this.discordStatusEnabled = true,
  });

  bool get isVipOrHigher =>
      tier == UserTier.vip || tier == UserTier.admin || tier == UserTier.ceo;
  bool get isAdminOrCeo => tier == UserTier.admin || tier == UserTier.ceo;
  bool get isCeo => tier == UserTier.ceo;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'email': email,
        'token': token,
        'tier': tier.name,
        'discordStatusEnabled': discordStatusEnabled ? 1 : 0,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        userId: json['userId'] ?? '',
        username: json['username'] ?? '',
        email: json['email'] ?? '',
        token: json['token'] ?? '',
        tier: UserTier.values.firstWhere(
          (e) => e.name == json['tier'],
          orElse: () => UserTier.free,
        ),
        discordStatusEnabled: (json['discordStatusEnabled'] ?? 1) == 1,
      );
}