import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Lỗi nghiệp vụ trả về theo contract `{ code, message, details, requestId }`.
class ApiFailure implements Exception {
  ApiFailure(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;
}

class MockUser {
  MockUser({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String id;
  final String email;
  String password;
  String displayName;
}

class MockCouple {
  MockCouple({
    required this.id,
    required this.memberIds,
    required this.joinedAt,
    required this.createdAt,
  });

  final String id;
  final List<String> memberIds;
  final Map<String, DateTime> joinedAt;
  final DateTime createdAt;
  String status = 'ACTIVE';
}

class MockPhoto {
  MockPhoto({
    required this.id,
    required this.sequence,
    required this.coupleId,
    required this.senderId,
    required this.requestId,
    required this.mimeType,
    required this.bytes,
    required this.createdAt,
  });

  final String id;

  /// Số thứ tự tăng dần: ảnh mới luôn đứng trước khi `createdAt` trùng nhau.
  final int sequence;
  final String coupleId;
  final String senderId;
  final String requestId;
  final String mimeType;
  final Uint8List bytes;
  final DateTime createdAt;
}

class MockInvite {
  MockInvite({
    required this.code,
    required this.ownerId,
    required this.expiresAt,
  });

  final String code;
  final String ownerId;
  final DateTime expiresAt;
  bool consumed = false;
}

/// Kho dữ liệu trong bộ nhớ của dev server: mọi thiết bị dùng chung một nguồn.
class MockStore {
  MockStore({Random? random}) : _random = random ?? Random();

  static const int maxPhotoBytes = 10 * 1024 * 1024;
  static const Duration inviteTtl = Duration(hours: 24);
  static const String _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  final Random _random;
  final Map<String, MockUser> _usersById = <String, MockUser>{};
  final Map<String, String> _userIdByEmail = <String, String>{};
  final Map<String, MockCouple> _couplesById = <String, MockCouple>{};
  final Map<String, MockInvite> _invitesByCode = <String, MockInvite>{};
  final Map<String, MockPhoto> _photosById = <String, MockPhoto>{};

  /// `photoId -> userId -> reactionType` (mỗi người tối đa 1 reaction/ảnh).
  final Map<String, Map<String, String>> _reactions = <String, Map<String, String>>{};

  int _idSeed = 0;
  int _photoSequence = 0;

  String nextId() => 'mock-${++_idSeed}';

  String nextUserId() => 'user-${++_idSeed}';

  String nextCoupleId() => 'couple-${++_idSeed}';

  /// Dùng cho test: thêm nhanh tài khoản demo.
  MockUser seedUser({
    required String email,
    required String password,
    required String displayName,
  }) {
    final normalized = email.trim().toLowerCase();
    final user = MockUser(
      id: nextUserId(),
      email: normalized,
      password: password,
      displayName: displayName,
    );
    _usersById[user.id] = user;
    _userIdByEmail[normalized] = user.id;
    return user;
  }

  MockUser? userById(String? id) => id == null ? null : _usersById[id];

  MockUser? userByEmail(String email) =>
      _usersById[_userIdByEmail[email.trim().toLowerCase()]];

  MockUser register({
    required String email,
    required String password,
    required String displayName,
  }) {
    final normalized = email.trim().toLowerCase();
    if (_userIdByEmail.containsKey(normalized)) {
      throw ApiFailure(409, 'EMAIL_ALREADY_EXISTS', 'Email is already registered.');
    }
    final user = MockUser(
      id: nextUserId(),
      email: normalized,
      password: password,
      displayName: displayName.trim(),
    );
    _usersById[user.id] = user;
    _userIdByEmail[normalized] = user.id;
    return user;
  }

  /// JWT giả: header.payload.signature, `sub` là user id.
  String issueToken(MockUser user) {
    String encode(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final header = encode({'alg': 'none', 'typ': 'JWT'});
    final payload = encode({
      'sub': user.id,
      'email': user.email,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return '$header.$payload.mock-signature';
  }

  String? userIdFromToken(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (decoded is! Map) return null;
      final subject = decoded['sub'];
      return subject is String && _usersById.containsKey(subject)
          ? subject
          : null;
    } on FormatException {
      return null;
    }
  }

  MockCouple coupleOf(String userId) {
    for (final couple in _couplesById.values) {
      if (couple.memberIds.contains(userId) && couple.status == 'ACTIVE') {
        return couple;
      }
    }
    throw ApiFailure(
      404,
      'COUPLE_NOT_FOUND',
      'User is not currently in an active couple.',
    );
  }

  MockCouple? activeCoupleOrNull(String userId) {
    for (final couple in _couplesById.values) {
      if (couple.memberIds.contains(userId) && couple.status == 'ACTIVE') {
        return couple;
      }
    }
    return null;
  }

  Map<String, dynamic> coupleJson(MockCouple couple) => <String, dynamic>{
    'id': couple.id,
    'status': couple.status,
    'anniversaryDate': null,
    'createdAt': couple.createdAt.toUtc().toIso8601String(),
    'members': [
      for (final memberId in couple.memberIds)
        <String, dynamic>{
          'id': memberId,
          'displayName': _usersById[memberId]?.displayName ?? '',
          'email': _usersById[memberId]?.email ?? '',
          'role': 'MEMBER',
          'joinedAt': (couple.joinedAt[memberId] ?? couple.createdAt)
              .toUtc()
              .toIso8601String(),
        },
    ],
  };

  Map<String, dynamic> userJson(MockUser user) => <String, dynamic>{
    'id': user.id,
    'email': user.email,
    'displayName': user.displayName,
    'avatarKey': null,
  };

  MockInvite createInvite(String ownerId, {Duration? ttl}) {
    if (activeCoupleOrNull(ownerId) != null) {
      throw ApiFailure(
        409,
        'ALREADY_PAIRED',
        'You already belong to an active couple.',
      );
    }
    String code;
    do {
      code = List<String>.generate(
        6,
        (_) => _alphabet[_random.nextInt(_alphabet.length)],
      ).join();
    } while (_invitesByCode.containsKey(code));
    final invite = MockInvite(
      code: code,
      ownerId: ownerId,
      expiresAt: DateTime.now().toUtc().add(ttl ?? inviteTtl),
    );
    _invitesByCode[code] = invite;
    return invite;
  }

  MockCouple join(String joinerId, String rawCode) {
    if (activeCoupleOrNull(joinerId) != null) {
      throw ApiFailure(
        409,
        'ALREADY_PAIRED',
        'You already belong to an active couple.',
      );
    }
    final code = rawCode.trim().toUpperCase();
    final invite = _invitesByCode[code];
    if (invite == null || invite.consumed) {
      throw ApiFailure(
        400,
        'INVALID_INVITE_CODE',
        'Invite code is invalid or already used.',
      );
    }
    if (invite.expiresAt.isBefore(DateTime.now().toUtc())) {
      invite.consumed = true;
      throw ApiFailure(400, 'INVITE_EXPIRED', 'Invite code has expired.');
    }
    if (invite.ownerId == joinerId) {
      throw ApiFailure(
        400,
        'CANNOT_PAIR_SELF',
        'You cannot pair with yourself.',
      );
    }
    if (activeCoupleOrNull(invite.ownerId) != null) {
      throw ApiFailure(
        409,
        'INVITER_ALREADY_PAIRED',
        'The inviter already belongs to another couple.',
      );
    }
    final now = DateTime.now().toUtc();
    final couple = MockCouple(
      id: nextCoupleId(),
      memberIds: [invite.ownerId, joinerId],
      joinedAt: {invite.ownerId: now, joinerId: now},
      createdAt: now,
    );
    _couplesById[couple.id] = couple;
    invite.consumed = true;
    return couple;
  }

  void unpair(String userId) {
    final couple = coupleOf(userId);
    _couplesById.remove(couple.id);
  }

  MockPhoto addPhoto({
    required String coupleId,
    required String senderId,
    required String requestId,
    required String mimeType,
    required Uint8List bytes,
  }) {
    final existing = findPhotoByRequestId(senderId, requestId);
    if (existing != null) {
      if (existing.coupleId != coupleId) {
        throw ApiFailure(
          409,
          'PHOTO_REQUEST_REUSED',
          'This upload request was used in another couple.',
        );
      }
      return existing;
    }
    final photo = MockPhoto(
      id: 'photo-${++_idSeed}',
      sequence: ++_photoSequence,
      coupleId: coupleId,
      senderId: senderId,
      requestId: requestId,
      mimeType: mimeType,
      bytes: bytes,
      createdAt: DateTime.now().toUtc(),
    );
    _photosById[photo.id] = photo;
    return photo;
  }

  MockPhoto? findPhotoByRequestId(String senderId, String requestId) {
    for (final photo in _photosById.values) {
      if (photo.senderId == senderId && photo.requestId == requestId) {
        return photo;
      }
    }
    return null;
  }

  /// Ảnh mới nhất đứng trước; `sequence` phá thế khi `createdAt` trùng nhau.
  List<MockPhoto> photosOf(String coupleId) {
    final photos = _photosById.values
        .where((photo) => photo.coupleId == coupleId)
        .toList();
    photos.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.sequence.compareTo(a.sequence);
    });
    return photos;
  }

  /// Ảnh phải thuộc couple của người đang xem, nếu không coi như không tồn tại.
  MockPhoto photoForViewer(String viewerId, String photoId) {
    final couple = coupleOf(viewerId);
    final photo = _photosById[photoId];
    if (photo == null || photo.coupleId != couple.id) {
      throw ApiFailure(404, 'PHOTO_NOT_FOUND', 'No photo found.');
    }
    return photo;
  }

  Map<String, dynamic> photoJson(MockPhoto photo) => <String, dynamic>{
    'id': photo.id,
    'coupleId': photo.coupleId,
    'senderId': photo.senderId,
    // Trường bổ sung cho UI timeline (contract gốc có `senderId`).
    'senderDisplayName': _usersById[photo.senderId]?.displayName ?? '',
    'mimeType': photo.mimeType,
    'sizeBytes': photo.bytes.length,
    'createdAt': photo.createdAt.toUtc().toIso8601String(),
    'imagePath': '/api/v1/photos/${photo.id}/image',
    'reactions': reactionsJson(photo.id),
  };

  List<Map<String, dynamic>> reactionsJson(String photoId) => [
    for (final entry in (_reactions[photoId] ?? const {}).entries)
      <String, dynamic>{'userId': entry.key, 'type': entry.value},
  ];

  void setReaction({
    required String viewerId,
    required String photoId,
    required String type,
  }) {
    photoForViewer(viewerId, photoId);
    _reactions.putIfAbsent(photoId, () => <String, String>{})[viewerId] = type;
  }

  void clearReaction({required String viewerId, required String photoId}) {
    photoForViewer(viewerId, photoId);
    final byUser = _reactions[photoId];
    if (byUser == null) return;
    byUser.remove(viewerId);
    if (byUser.isEmpty) _reactions.remove(photoId);
  }
}
