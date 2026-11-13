import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/memory_story_repository.dart';

void main() {
  const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  group('HttpMemoryStoryRepository', () {
    test('generateStory sends JSON body and parses MemoryStoryDetail draft', () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['Content-Type'], 'application/json');
        expect(request.url.path, '/api/v1/ai/memory-stories');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['albumId'], 'album-1');
        expect(body['selectedPhotoIds'], ['photo-1', 'photo-2']);
        expect(body['notes'], 'Chuyến đi đáng nhớ');
        expect(body['tone'], 'ROMANTIC');
        expect(body['consent'], true);

        return http.Response(
          jsonEncode({
            'id': 'story-1',
            'albumId': 'album-1',
            'coupleId': 'couple-1',
            'title': 'Khoảnh khắc Đà Lạt ngọt ngào',
            'story': 'Những cung đường quanh co trong sương sớm...',
            'highlights': ['Ngắm hoa dã quỳ', 'Cà phê sáng ven hồ'],
            'tone': 'ROMANTIC',
            'status': 'DRAFT',
            'createdBy': 'user-1',
            'selectedPhotoIds': ['photo-1', 'photo-2'],
            'createdAt': '2026-11-08T10:00:00Z',
            'updatedAt': '2026-11-08T10:00:00Z',
          }),
          201,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);
      final story = await repo.generateStory(
        'test-token',
        albumId: 'album-1',
        photoIds: ['photo-1', 'photo-2'],
        notes: 'Chuyến đi đáng nhớ',
        tone: 'ROMANTIC',
        consent: true,
      );

      expect(story.id, 'story-1');
      expect(story.albumId, 'album-1');
      expect(story.title, 'Khoảnh khắc Đà Lạt ngọt ngào');
      expect(story.isDraft, isTrue);
      expect(story.isSaved, isFalse);
      expect(story.highlights.length, 2);
      expect(story.photoIds.length, 2);
    });

    test('getStory fetches story by id', () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.path, '/api/v1/ai/memory-stories/story-1');

        return http.Response(
          jsonEncode({
            'id': 'story-1',
            'albumId': 'album-1',
            'coupleId': 'couple-1',
            'title': 'Câu chuyện đã lưu',
            'story': 'Nội dung câu chuyện...',
            'highlights': ['Điểm 1'],
            'tone': 'ROMANTIC',
            'status': 'SAVED',
            'createdBy': 'user-1',
            'selectedPhotoIds': ['photo-1'],
            'createdAt': '2026-11-08T10:00:00Z',
            'updatedAt': '2026-11-08T10:05:00Z',
            'savedAt': '2026-11-08T10:05:00Z',
          }),
          200,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);
      final story = await repo.getStory('test-token', 'story-1');

      expect(story.id, 'story-1');
      expect(story.isSaved, isTrue);
      expect(story.savedAt, isNotNull);
    });

    test('updateStory sends PUT request and returns updated story', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/ai/memory-stories/story-1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Tiêu đề mới');
        expect(body['story'], 'Nội dung mới');

        return http.Response(
          jsonEncode({
            'id': 'story-1',
            'albumId': 'album-1',
            'coupleId': 'couple-1',
            'title': 'Tiêu đề mới',
            'story': 'Nội dung mới',
            'highlights': ['Ý 1'],
            'tone': 'ROMANTIC',
            'status': 'DRAFT',
            'createdBy': 'user-1',
            'selectedPhotoIds': ['photo-1'],
            'createdAt': '2026-11-08T10:00:00Z',
            'updatedAt': '2026-11-08T10:10:00Z',
          }),
          200,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);
      final updated = await repo.updateStory(
        'test-token',
        'story-1',
        title: 'Tiêu đề mới',
        storyText: 'Nội dung mới',
        highlights: ['Ý 1'],
      );

      expect(updated.title, 'Tiêu đề mới');
      expect(updated.storyText, 'Nội dung mới');
    });

    test('saveStory sends POST /save and marks story as SAVED', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/ai/memory-stories/story-1/save');

        return http.Response(
          jsonEncode({
            'id': 'story-1',
            'albumId': 'album-1',
            'coupleId': 'couple-1',
            'title': 'Tiêu đề',
            'story': 'Nội dung',
            'highlights': [],
            'status': 'SAVED',
            'createdBy': 'user-1',
            'selectedPhotoIds': [],
            'createdAt': '2026-11-08T10:00:00Z',
            'updatedAt': '2026-11-08T10:15:00Z',
          }),
          200,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);
      final saved = await repo.saveStory('test-token', 'story-1');

      expect(saved.isSaved, isTrue);
    });

    test('listStoriesInAlbum fetches stories list for an album', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/albums/album-1/stories');

        return http.Response(
          jsonEncode([
            {
              'id': 'story-1',
              'albumId': 'album-1',
              'coupleId': 'couple-1',
              'title': 'Kỷ niệm 1',
              'story': 'Nội dung 1',
              'highlights': [],
              'status': 'SAVED',
              'createdBy': 'user-1',
              'selectedPhotoIds': [],
              'createdAt': '2026-11-08T10:00:00Z',
              'updatedAt': '2026-11-08T10:00:00Z',
            }
          ]),
          200,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);
      final list = await repo.listStoriesInAlbum('test-token', 'album-1');

      expect(list.length, 1);
      expect(list.first.title, 'Kỷ niệm 1');
    });

    test('400 AI_CONSENT_REQUIRED throws MemoryStoryException with proper code', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'AI_CONSENT_REQUIRED',
            'message': 'Cần sự đồng thuận của người dùng',
          }),
          400,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);

      expect(
        () => repo.generateStory('test-token', albumId: 'a1', photoIds: ['p1'], consent: false),
        throwsA(isA<MemoryStoryException>().having((e) => e.code, 'code', 'AI_CONSENT_REQUIRED')),
      );
    });

    test('403 DRAFT_ACCESS_DENIED throws MemoryStoryException for draft privacy', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'DRAFT_ACCESS_DENIED',
            'message': 'Bản nháp chỉ người tạo mới có quyền truy cập',
          }),
          403,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);

      expect(
        () => repo.getStory('test-token', 'draft-id'),
        throwsA(isA<MemoryStoryException>().having((e) => e.code, 'code', 'DRAFT_ACCESS_DENIED')),
      );
    });

    test('429 AI_SUBMIT_LIMIT_EXCEEDED throws rate limit exception', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'AI_SUBMIT_LIMIT_EXCEEDED',
            'message': 'Quá số lần yêu cầu',
          }),
          429,
          headers: jsonHeaders,
        );
      });

      final repo = HttpMemoryStoryRepository(baseUrl: 'http://localhost:8080', client: client);

      expect(
        () => repo.generateStory('test-token', albumId: 'a1', photoIds: ['p1'], consent: true),
        throwsA(isA<MemoryStoryException>().having((e) => e.code, 'code', 'AI_SUBMIT_LIMIT_EXCEEDED')),
      );
    });
  });

  group('MockMemoryStoryRepository', () {
    test('generateStory, update, and save lifecycle', () async {
      final mock = MockMemoryStoryRepository();

      // Missing consent throws
      expect(
        () => mock.generateStory('token', albumId: 'album-1', photoIds: ['p1'], consent: false),
        throwsA(isA<MemoryStoryException>()),
      );

      // Successful generation
      final draft = await mock.generateStory(
        'token',
        albumId: 'album-1',
        photoIds: ['p1', 'p2'],
        notes: 'Chuyến đi',
        tone: 'ROMANTIC',
        consent: true,
      );
      expect(draft.isDraft, isTrue);
      expect(draft.photoIds.length, 2);

      // Get story
      final fetched = await mock.getStory('token', draft.id);
      expect(fetched.id, draft.id);

      // Update story
      final updated = await mock.updateStory(
        'token',
        draft.id,
        title: 'Chỉnh sửa tiêu đề',
        storyText: 'Chỉnh sửa nội dung',
        highlights: ['Điểm mới'],
      );
      expect(updated.title, 'Chỉnh sửa tiêu đề');
      expect(updated.highlights, ['Điểm mới']);

      // Save story
      final saved = await mock.saveStory('token', draft.id);
      expect(saved.isSaved, isTrue);
      expect(saved.savedAt, isNotNull);

      // Update saved story throws conflict
      expect(
        () => mock.updateStory('token', draft.id, title: 'Thử lại', storyText: 'Không được'),
        throwsA(isA<MemoryStoryException>().having((e) => e.code, 'code', 'STORY_ALREADY_SAVED')),
      );

      // List stories in album
      final list = await mock.listStoriesInAlbum('token', 'album-1');
      expect(list.length, 1);
      expect(list.first.id, draft.id);
    });
  });
}
