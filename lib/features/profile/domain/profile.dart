class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.lastSeenAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    lastSeenAt: parseTime(json['last_seen_at']),
  );

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime? lastSeenAt;

  Profile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
  }) => Profile(
    id: id,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    lastSeenAt: lastSeenAt,
  );
}

/// Parses a Postgres timestamp (or null) to local time.
DateTime? parseTime(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
