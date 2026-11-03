class CoupleMember {
  const CoupleMember({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String displayName;
  final String email;
  final String role;
  final DateTime? joinedAt;

  factory CoupleMember.fromJson(Map<String, dynamic> json) => CoupleMember(
    id: json['id'] as String,
    displayName: json['displayName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'MEMBER',
    joinedAt: _parseDate(json['joinedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'email': email,
    'role': role,
    'joinedAt': joinedAt?.toIso8601String(),
  };
}

class Couple {
  const Couple({
    required this.id,
    required this.status,
    required this.members,
    this.anniversaryDate,
    this.createdAt,
  });

  final String id;
  final String status;
  final List<CoupleMember> members;
  final DateTime? anniversaryDate;
  final DateTime? createdAt;

  bool get isActive => status == 'ACTIVE';

  /// Người còn lại trong cặp đôi (dùng để hiển thị Couple Home).
  CoupleMember? partnerOf(String userId) {
    for (final member in members) {
      if (member.id != userId) return member;
    }
    return null;
  }

  CoupleMember? memberById(String userId) {
    for (final member in members) {
      if (member.id == userId) return member;
    }
    return null;
  }

  factory Couple.fromJson(Map<String, dynamic> json) => Couple(
    id: json['id'] as String,
    status: json['status'] as String? ?? 'ACTIVE',
    anniversaryDate: _parseDate(json['anniversaryDate']),
    createdAt: _parseDate(json['createdAt']),
    members: (json['members'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => CoupleMember.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'anniversaryDate': anniversaryDate?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'members': members.map((member) => member.toJson()).toList(),
  };
}

class CoupleInvite {
  const CoupleInvite({required this.inviteCode, required this.expiresAt});

  final String inviteCode;
  final DateTime expiresAt;

  factory CoupleInvite.fromJson(Map<String, dynamic> json) => CoupleInvite(
    inviteCode: json['inviteCode'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}

DateTime? _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
