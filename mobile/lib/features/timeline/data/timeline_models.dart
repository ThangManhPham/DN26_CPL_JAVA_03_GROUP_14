/// Loại reaction cho một ảnh — khớp `photo_reactions.reaction_type`
/// trong `docs/04-database.md`, mỗi người tối đa một reaction trên mỗi ảnh.
enum PhotoReactionType {
  love('LOVE', '❤️', 'Yêu thích'),
  like('LIKE', '👍', 'Thích'),
  laugh('LAUGH', '😂', 'Buồn cười'),
  sad('SAD', '😢', 'Buồn');

  const PhotoReactionType(this.wire, this.emoji, this.label);

  /// Giá trị gửi/nhận qua API.
  final String wire;
  final String emoji;
  final String label;

  static PhotoReactionType? fromWire(String? value) {
    if (value == null) return null;
    final normalized = value.toUpperCase();
    for (final type in values) {
      if (type.wire == normalized) return type;
    }
    return null;
  }
}

class PhotoReaction {
  const PhotoReaction({required this.userId, required this.type});

  final String userId;
  final PhotoReactionType type;

  /// Bỏ qua reaction có `type` lạ để một loại mới của backend không làm hỏng
  /// việc tải timeline.
  static PhotoReaction? tryParse(Map<String, dynamic> json) {
    final userId = json['userId'] as String?;
    final type = PhotoReactionType.fromWire(
      (json['type'] ?? json['reactionType']) as String?,
    );
    if (userId == null || type == null) return null;
    return PhotoReaction(userId: userId, type: type);
  }
}

class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.coupleId,
    required this.senderId,
    required this.senderDisplayName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    required this.imagePath,
    required this.reactions,
  });

  final String id;
  final String coupleId;
  final String senderId;
  final String senderDisplayName;
  final String mimeType;
  final int sizeBytes;

  /// Thời điểm gửi theo UTC (backend trả ISO-8601); UI hiển thị giờ local.
  final DateTime createdAt;

  /// Đường dẫn API có xác thực (không phải URL công khai vĩnh viễn).
  final String imagePath;

  final List<PhotoReaction> reactions;

  PhotoReactionType? reactionBy(String? userId) {
    if (userId == null) return null;
    for (final reaction in reactions) {
      if (reaction.userId == userId) return reaction.type;
    }
    return null;
  }

  int countOf(PhotoReactionType type) =>
      reactions.where((reaction) => reaction.type == type).length;

  /// Áp reaction của [userId] theo kiểu optimistic update: mỗi người chỉ giữ
  /// một reaction trên mỗi ảnh. Truyền `type = null` để bỏ reaction.
  PhotoItem withReaction({required String userId, PhotoReactionType? type}) {
    final next = reactions
        .where((reaction) => reaction.userId != userId)
        .toList(growable: true);
    if (type != null) {
      next.add(PhotoReaction(userId: userId, type: type));
    }
    return copyWith(reactions: next);
  }

  PhotoItem copyWith({
    List<PhotoReaction>? reactions,
    String? senderDisplayName,
  }) => PhotoItem(
    id: id,
    coupleId: coupleId,
    senderId: senderId,
    senderDisplayName: senderDisplayName ?? this.senderDisplayName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    imagePath: imagePath,
    reactions: reactions ?? this.reactions,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'coupleId': coupleId,
    'senderId': senderId,
    'senderDisplayName': senderDisplayName,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'imagePath': imagePath,
    'reactions': reactions.map((r) => {
      'userId': r.userId,
      'type': r.type.wire,
    }).toList(),
  };

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return PhotoItem(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderDisplayName:
          json['senderDisplayName'] as String? ??
          (sender is Map ? sender['displayName'] as String? : null) ??
          '',
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      imagePath:
          json['imagePath'] as String? ?? '/api/v1/photos/${json['id']}/image',
      reactions: (json['reactions'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => PhotoReaction.tryParse(item.cast<String, dynamic>()))
          .whereType<PhotoReaction>()
          .toList(growable: false),
    );
  }
}

/// Một trang timeline: `{ "items": [...], "nextCursor": "..." }`
/// (`docs/05-api-contract.md` §5.1). `nextCursor == null` nghĩa là hết dữ liệu.
class PhotoPage {
  const PhotoPage({required this.items, this.nextCursor});

  final List<PhotoItem> items;
  final String? nextCursor;

  factory PhotoPage.fromJson(Map<String, dynamic> json) => PhotoPage(
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => PhotoItem.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    nextCursor: json['nextCursor'] as String?,
  );
}
