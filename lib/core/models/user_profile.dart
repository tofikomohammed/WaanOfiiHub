/// Immutable user profile representation with manual JSON serialization
class UserProfile {
  final String id;
  final String publicId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? about;
  final String? phoneE164;
  final String? phoneHash;
  final bool phoneVerified;
  final DateTime? lastSeenAt;
  final bool showLastSeen;
  final bool allowPhoneDiscovery;
  final bool isBanned;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.publicId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.about,
    this.phoneE164,
    this.phoneHash,
    this.phoneVerified = false,
    this.lastSeenAt,
    this.showLastSeen = true,
    this.allowPhoneDiscovery = true,
    this.isBanned = false,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      publicId: json['public_id'] as String? ?? 'WOH-UNKNOWN',
      displayName: json['display_name'] as String? ?? 'User',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      about: json['about'] as String?,
      phoneE164: json['phone_e164'] as String?,
      phoneHash: json['phone_hash'] as String?,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      showLastSeen: json['show_last_seen'] as bool? ?? true,
      allowPhoneDiscovery: json['allow_phone_discovery'] as bool? ?? true,
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'public_id': publicId,
      'display_name': displayName,
      'username': username,
      'avatar_url': avatarUrl,
      'about': about,
      'phone_e164': phoneE164,
      'phone_hash': phoneHash,
      'phone_verified': phoneVerified,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'show_last_seen': showLastSeen,
      'allow_phone_discovery': allowPhoneDiscovery,
      'is_banned': isBanned,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? about,
    String? phoneE164,
    String? phoneHash,
    bool? phoneVerified,
    DateTime? lastSeenAt,
    bool? showLastSeen,
    bool? allowPhoneDiscovery,
    bool? isBanned,
  }) {
    return UserProfile(
      id: id,
      publicId: publicId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      about: about ?? this.about,
      phoneE164: phoneE164 ?? this.phoneE164,
      phoneHash: phoneHash ?? this.phoneHash,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      showLastSeen: showLastSeen ?? this.showLastSeen,
      allowPhoneDiscovery: allowPhoneDiscovery ?? this.allowPhoneDiscovery,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt,
    );
  }
}
