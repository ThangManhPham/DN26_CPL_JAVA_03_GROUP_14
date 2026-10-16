/// Thông tin user profile từ API.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) =>
      UserProfile(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}

/// Couple information từ API.
class CoupleInfo {
  const CoupleInfo({
    required this.id,
    required this.status,
    this.anniversaryDate,
    required this.members,
  });

  final String id;
  final String status; // ACTIVE, INACTIVE
  final DateTime? anniversaryDate;
  final List<CoupleMember> members;

  factory CoupleInfo.fromJson(Map<String, dynamic> json) => CoupleInfo(
        id: json['id'] as String,
        status: json['status'] as String,
        anniversaryDate: json['anniversaryDate'] != null
            ? DateTime.parse(json['anniversaryDate'] as String)
            : null,
        members: (json['members'] as List<dynamic>)
            .map((e) => CoupleMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CoupleMember {
  const CoupleMember({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  factory CoupleMember.fromJson(Map<String, dynamic> json) => CoupleMember(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}
