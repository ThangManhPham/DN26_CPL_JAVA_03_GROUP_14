import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/timeline/data/timeline_models.dart';
import 'package:mobile/features/timeline/data/timeline_repository.dart';
import 'package:mobile/features/timeline/presentation/timeline_controller.dart';

MockTimelineRepository buildRepository({
  int photoCount = 23,
  MockTimelineScenario scenario = MockTimelineScenario.success,
  bool failReaction = false,
  int? failOnPageCall,
}) {
  MockTimelineRepository.clear();
  return MockTimelineRepository(
    photoCount: photoCount,
    latency: Duration.zero,
    scenario: scenario,
    failReaction: failReaction,
    failOnPageCall: failOnPageCall,
    currentUserId: () => 'mock-me',
  );
}

void main() {
  test('phân trang theo cursor: nạp trang đầu rồi nạp thêm tới hết dữ liệu', () async {
    final controller = TimelineController(
      repository: buildRepository(photoCount: 23),
      currentUserId: 'mock-me',
      pageSize: 10,
    );

    await controller.loadInitial();
    expect(controller.items.length, 10);
    expect(controller.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.items.length, 20);
    expect(controller.isLoadingMore, isFalse);

    await controller.loadMore();
    expect(controller.items.length, 23);
    expect(controller.hasMore, isFalse);
  });

  test('refresh giữ đúng số trang dữ liệu đầu tiên', () async {
    final controller = TimelineController(
      repository: buildRepository(photoCount: 23),
      currentUserId: 'mock-me',
      pageSize: 10,
    );

    await controller.loadInitial();
    await controller.loadMore();
    expect(controller.items.length, 20);

    await controller.refresh();
    expect(controller.items.length, 10);
    expect(controller.isRefreshing, isFalse);
  });

  test('reaction optimistic update: đặt rồi bỏ ngay trên state', () async {
    final controller = TimelineController(
      repository: buildRepository(photoCount: 3),
      currentUserId: 'mock-me',
    );
    await controller.loadInitial();

    await controller.react(controller.items.first, PhotoReactionType.love);
    expect(controller.items.first.reactionBy('mock-me'), PhotoReactionType.love);

    await controller.react(controller.items.first, null);
    expect(controller.items.first.reactionBy('mock-me'), isNull);
  });

  test('reaction rollback về dữ liệu cũ khi API lỗi', () async {
    final controller = TimelineController(
      repository: buildRepository(photoCount: 3, failReaction: true),
      currentUserId: 'mock-me',
    );
    await controller.loadInitial();
    final photo = controller.items.first;

    await expectLater(
      controller.react(photo, PhotoReactionType.love),
      throwsA(isA<ApiException>()),
    );
    expect(controller.items.first.reactionBy('mock-me'), isNull);
  });

  test('lỗi tải trang đầu trả thông điệp đã bản địa hóa của contract', () async {
    final controller = TimelineController(
      repository: buildRepository(scenario: MockTimelineScenario.forbidden),
      currentUserId: 'mock-me',
    );

    await controller.loadInitial();

    expect(controller.error, 'Bạn không có quyền xem nội dung này.');
    expect(controller.isEmpty, isTrue);
  });

  test('lỗi tải thêm giữ nguyên dữ liệu cũ và chỉ báo ở chân danh sách', () async {
    final controller = TimelineController(
      repository: buildRepository(photoCount: 40, failOnPageCall: 2),
      currentUserId: 'mock-me',
      pageSize: 10,
    );

    await controller.loadInitial();
    await controller.loadMore();

    expect(controller.items.length, 10);
    expect(controller.loadMoreError, isNotNull);
    expect(controller.error, isNull);
  });
}
