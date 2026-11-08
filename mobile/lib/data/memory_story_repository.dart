import 'dart:convert';
import 'package:http/http.dart' as http;

class MemoryStoryDetail {
  const MemoryStoryDetail({
    required this.id,
    required this.albumId,
    required this.title,
    required this.storyText,
    required this.highlights,
    required this.photoIds,
    required this.status,
    this.promptNotes,
    this.tone,
    required this.createdBy,
    required this.createdAt,
    this.savedAt,
  });

  final String id;
  final String albumId;
  final String title;
  final String storyText;
  final List<String> highlights;
  final List<String> photoIds;
  final String status;
  final String? promptNotes;
  final String? tone;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? savedAt;

  bool get isDraft => status == 'DRAFT';
  bool get isSaved => status == 'SAVED';

  factory MemoryStoryDetail.fromJson(Map<String, dynamic> json) => MemoryStoryDetail(
        id: json['id'] as String,
        albumId: json['albumId'] as String,
        title: json['title'] as String,
        storyText: (json['storyText'] ?? json['story'] ?? '') as String,
        highlights: (json['highlights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        photoIds: ((json['selectedPhotoIds'] ?? json['photoIds']) as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        status: (json['status'] as String?) ?? 'DRAFT',
        promptNotes: json['promptNotes'] as String?,
        tone: json['tone'] as String?,
        createdBy: json['createdBy'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        savedAt: json['savedAt'] != null ? DateTime.parse(json['savedAt'] as String) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'albumId': albumId,
        'title': title,
        'storyText': storyText,
        'highlights': highlights,
        'photoIds': photoIds,
        'status': status,
        if (promptNotes != null) 'promptNotes': promptNotes,
        if (tone != null) 'tone': tone,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
      };
}

class MemoryStoryException implements Exception {
  const MemoryStoryException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

abstract class MemoryStoryRepository {
  Future<MemoryStoryDetail> generateStory(
    String token, {
    required String albumId,
    required List<String> photoIds,
    String? notes,
    String? tone,
    required bool consent,
  });

  Future<MemoryStoryDetail> getStory(String token, String storyId);

  Future<MemoryStoryDetail> updateStory(
    String token,
    String storyId, {
    required String title,
    required String storyText,
    List<String>? highlights,
    String? tone,
  });

  Future<MemoryStoryDetail> saveStory(String token, String storyId);

  Future<List<MemoryStoryDetail>> listStoriesInAlbum(String token, String albumId);
}

class HttpMemoryStoryRepository implements MemoryStoryRepository {
  HttpMemoryStoryRepository({required String baseUrl, http.Client? client})
      : _base = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;

  @override
  Future<MemoryStoryDetail> generateStory(
    String token, {
    required String albumId,
    required List<String> photoIds,
    String? notes,
    String? tone,
    required bool consent,
  }) async {
    final body = jsonEncode({
      'albumId': albumId,
      'selectedPhotoIds': photoIds,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (tone != null && tone.isNotEmpty) 'tone': tone,
      'consent': consent,
    });

    final response = await _client.post(
      _base.resolve('/api/v1/ai/memory-stories'),
      headers: _headers(token)..['Content-Type'] = 'application/json',
      body: body,
    );

    _check(response);
    return MemoryStoryDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<MemoryStoryDetail> getStory(String token, String storyId) async {
    final response = await _client.get(
      _base.resolve('/api/v1/ai/memory-stories/$storyId'),
      headers: _headers(token),
    );

    _check(response);
    return MemoryStoryDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<MemoryStoryDetail> updateStory(
    String token,
    String storyId, {
    required String title,
    required String storyText,
    List<String>? highlights,
    String? tone,
  }) async {
    final body = jsonEncode({
      'title': title,
      'story': storyText,
      if (highlights != null) 'highlights': highlights,
      if (tone != null) 'tone': tone,
    });

    final response = await _client.put(
      _base.resolve('/api/v1/ai/memory-stories/$storyId'),
      headers: _headers(token)..['Content-Type'] = 'application/json',
      body: body,
    );

    _check(response);
    return MemoryStoryDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<MemoryStoryDetail> saveStory(String token, String storyId) async {
    final response = await _client.post(
      _base.resolve('/api/v1/ai/memory-stories/$storyId/save'),
      headers: _headers(token),
    );

    _check(response);
    return MemoryStoryDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<List<MemoryStoryDetail>> listStoriesInAlbum(String token, String albumId) async {
    final response = await _client.get(
      _base.resolve('/api/v1/albums/$albumId/stories'),
      headers: _headers(token),
    );

    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((json) => MemoryStoryDetail.fromJson(json as Map<String, dynamic>)).toList();
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
      };

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String? code;
    String? message;

    try {
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      code = err['code'] as String?;
      message = err['message'] as String?;
    } catch (_) {}

    if (response.statusCode == 401) {
      throw MemoryStoryException('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.', code: code ?? 'UNAUTHORIZED');
    }

    if (response.statusCode == 403) {
      if (code == 'DRAFT_ACCESS_DENIED') {
        throw MemoryStoryException('Bản nháp này chỉ người tạo mới có quyền xem hoặc chỉnh sửa.', code: code);
      }
      throw MemoryStoryException(message ?? 'Bạn không có quyền thực hiện thao tác này.', code: code ?? 'FORBIDDEN');
    }

    if (response.statusCode == 404) {
      throw MemoryStoryException(message ?? 'Câu chuyện hoặc Album không tồn tại.', code: code ?? 'NOT_FOUND');
    }

    if (response.statusCode == 429) {
      throw MemoryStoryException('Bạn đã yêu cầu tạo câu chuyện quá nhanh. Vui lòng chờ 1 phút trước khi thử lại.', code: code ?? 'AI_SUBMIT_LIMIT_EXCEEDED');
    }

    if (response.statusCode == 502 || response.statusCode == 503) {
      throw MemoryStoryException('Dịch vụ AI tạo câu chuyện đang bảo trì hoặc quá tải. Vui lòng thử lại sau.', code: code ?? 'AI_PROVIDER_ERROR');
    }

    if (response.statusCode == 400 || response.statusCode == 422) {
      if (code == 'AI_CONSENT_REQUIRED') {
        throw MemoryStoryException('Bạn cần xác nhận đồng thuận sử dụng AI để tạo câu chuyện kỷ niệm.', code: code);
      }
      if (code == 'CANNOT_EDIT_SAVED_STORY') {
        throw MemoryStoryException('Câu chuyện đã được lưu vào Album và không thể chỉnh sửa.', code: code);
      }
      if (message != null && message.isNotEmpty) {
        throw MemoryStoryException(message, code: code);
      }
      throw MemoryStoryException('Thông tin yêu cầu không hợp lệ.', code: code);
    }

    throw MemoryStoryException('Đã xảy ra lỗi khi kết nối máy chủ. Vui lòng thử lại.', code: code);
  }
}

class MockMemoryStoryRepository implements MemoryStoryRepository {
  final Map<String, List<MemoryStoryDetail>> _albumStories = {};

  @override
  Future<MemoryStoryDetail> generateStory(
    String token, {
    required String albumId,
    required List<String> photoIds,
    String? notes,
    String? tone,
    required bool consent,
  }) async {
    if (!consent) {
      throw const MemoryStoryException('Bạn cần xác nhận đồng thuận sử dụng AI.', code: 'AI_CONSENT_REQUIRED');
    }

    final story = MemoryStoryDetail(
      id: 'mock-story-${DateTime.now().millisecondsSinceEpoch}',
      albumId: albumId,
      title: 'Khoảnh khắc yêu thương tại Đà Lạt',
      storyText: 'Những tia nắng sớm len lỏi qua từng tán thông, mang theo hương vị trong lành và sự ấm áp của hai đứa mình...',
      highlights: const [
        'Cùng nhau ngắm bình minh đồi chè',
        'Cốc sữa đậu nành nóng hổi giữa chợ đêm',
        'Nắm tay nhau dạo bước ven hồ Tuyền Lâm',
      ],
      photoIds: List.from(photoIds),
      status: 'DRAFT',
      promptNotes: notes,
      tone: tone ?? 'ROMANTIC',
      createdBy: 'mock-user-1',
      createdAt: DateTime.now(),
    );

    _albumStories.putIfAbsent(albumId, () => []).add(story);
    return story;
  }

  @override
  Future<MemoryStoryDetail> getStory(String token, String storyId) async {
    for (final stories in _albumStories.values) {
      for (final story in stories) {
        if (story.id == storyId) return story;
      }
    }
    throw const MemoryStoryException('Câu chuyện không tồn tại', code: 'STORY_NOT_FOUND');
  }

  @override
  Future<MemoryStoryDetail> updateStory(
    String token,
    String storyId, {
    required String title,
    required String storyText,
    List<String>? highlights,
    String? tone,
  }) async {
    for (final entry in _albumStories.entries) {
      final list = entry.value;
      for (int i = 0; i < list.length; i++) {
        if (list[i].id == storyId) {
          if (list[i].status == 'SAVED') {
            throw const MemoryStoryException('Không thể sửa câu chuyện đã lưu', code: 'CANNOT_EDIT_SAVED_STORY');
          }
          final updated = MemoryStoryDetail(
            id: list[i].id,
            albumId: list[i].albumId,
            title: title,
            storyText: storyText,
            highlights: highlights ?? list[i].highlights,
            photoIds: list[i].photoIds,
            status: list[i].status,
            promptNotes: list[i].promptNotes,
            tone: tone ?? list[i].tone,
            createdBy: list[i].createdBy,
            createdAt: list[i].createdAt,
            savedAt: list[i].savedAt,
          );
          list[i] = updated;
          return updated;
        }
      }
    }
    throw const MemoryStoryException('Câu chuyện không tồn tại', code: 'STORY_NOT_FOUND');
  }

  @override
  Future<MemoryStoryDetail> saveStory(String token, String storyId) async {
    for (final entry in _albumStories.entries) {
      final list = entry.value;
      for (int i = 0; i < list.length; i++) {
        if (list[i].id == storyId) {
          final saved = MemoryStoryDetail(
            id: list[i].id,
            albumId: list[i].albumId,
            title: list[i].title,
            storyText: list[i].storyText,
            highlights: list[i].highlights,
            photoIds: list[i].photoIds,
            status: 'SAVED',
            promptNotes: list[i].promptNotes,
            tone: list[i].tone,
            createdBy: list[i].createdBy,
            createdAt: list[i].createdAt,
            savedAt: DateTime.now(),
          );
          list[i] = saved;
          return saved;
        }
      }
    }
    throw const MemoryStoryException('Câu chuyện không tồn tại', code: 'STORY_NOT_FOUND');
  }

  @override
  Future<List<MemoryStoryDetail>> listStoriesInAlbum(String token, String albumId) async {
    return List.unmodifiable(_albumStories[albumId] ?? []);
  }
}
