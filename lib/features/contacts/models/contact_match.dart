class ContactMatch {
  final String id;
  final String publicId;
  final String displayName;
  final String? avatarUrl;
  final bool phoneVerified;
  final String phoneHash;

  const ContactMatch({
    required this.id,
    required this.publicId,
    required this.displayName,
    this.avatarUrl,
    required this.phoneVerified,
    required this.phoneHash,
  });

  factory ContactMatch.fromJson(Map<String, dynamic> json) {
    return ContactMatch(
      id: json['id'] as String,
      publicId: json['public_id'] as String? ?? 'WOH-UNKNOWN',
      displayName: json['display_name'] as String? ?? 'Contact',
      avatarUrl: json['avatar_url'] as String?,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      phoneHash: json['phone_hash'] as String? ?? '',
    );
  }
}
