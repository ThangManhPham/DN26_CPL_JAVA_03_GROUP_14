/// DTO cho invite từ API.
class InviteCode {
  const InviteCode({
    required this.inviteCode,
    required this.expiresAt,
  });

  final String inviteCode;
  final DateTime expiresAt;

  factory InviteCode.fromJson(Map<String, dynamic> json) => InviteCode(
        inviteCode: json['inviteCode'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}
