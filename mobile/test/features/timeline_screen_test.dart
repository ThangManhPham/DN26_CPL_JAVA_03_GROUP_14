import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/timeline/data/timeline_repository.dart';
import 'package:mobile/features/timeline/presentation/timeline_screen.dart';

MockTimelineRepository buildRepository({
  int photoCount = 5,
  Duration latency = Duration.zero,
  MockTimelineScenario scenario = MockTimelineScenario.success,
  bool failReaction = false,
}) => MockTimelineRepository(
  photoCount: photoCount,
  latency: latency,
  scenario: scenario,
  failReaction: failReaction,
  currentUserId: () => 'mock-me',
);

Widget wrap(Widget child) => MaterialApp(theme: ourSpaceTheme, home: child);

Widget timeline(MockTimelineRepository repository) => wrap(
  TimelineScreen(repository: repository, currentUserId: 'mock-me'),
);

void main() {
  testWidgets('hiện skeleton trong lúc tải rồi chuyển sang danh sách ảnh', (
    tester,
  ) async {
    await tester.pumpWidget(
      timeline(
        buildRepository(latency: const Duration(milliseconds: 200)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const Key('timelineSkeleton')), findsOneWidget);

    // Vượt qua độ trễ 200ms của mock rồi mới settle để danh sách kịp hiện.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timelineSkeleton')), findsNothing);
    expect(find.byKey(const Key('timelineList')), findsOneWidget);
    expect(find.byKey(const Key('photo_mock-photo-1')), findsOneWidget);
    expect(find.byKey(const Key('reaction_mock-photo-1_LOVE')), findsOneWidget);
  });

  testWidgets('danh sách rỗng hiển thị trạng thái empty', (tester) async {
    await tester.pumpWidget(timeline(buildRepository(photoCount: 0)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timelineEmptyList')), findsOneWidget);
    expect(find.byKey(const Key('emptyStateMessage')), findsOneWidget);
  });

  testWidgets('lỗi 403 hiển thị trạng thái lỗi kèm nút thử lại', (tester) async {
    await tester.pumpWidget(
      timeline(buildRepository(scenario: MockTimelineScenario.forbidden)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('errorStateMessage')), findsOneWidget);
    expect(find.text('Bạn không có quyền xem nội dung này.'), findsOneWidget);
    expect(find.byKey(const Key('errorStateRetry')), findsOneWidget);
  });

  testWidgets('bấm reaction cập nhật ngay lập tức (optimistic)', (tester) async {
    await tester.pumpWidget(timeline(buildRepository(photoCount: 3)));
    await tester.pumpAndSettle();

    final love = find.byKey(const Key('reaction_mock-photo-1_LOVE'));
    await tester.ensureVisible(love);
    await tester.pumpAndSettle();
    await tester.tap(love);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('reaction_mock-photo-1_LOVE')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reaction lỗi thì rollback và báo SnackBar', (tester) async {
    await tester.pumpWidget(
      timeline(buildRepository(photoCount: 3, failReaction: true)),
    );
    await tester.pumpAndSettle();

    final love = find.byKey(const Key('reaction_mock-photo-1_LOVE'));
    await tester.ensureVisible(love);
    await tester.pumpAndSettle();
    await tester.tap(love);
    await tester.pumpAndSettle();

    expect(find.text('Mock: không lưu được reaction.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('reaction_mock-photo-1_LOVE')),
        matching: find.text('1'),
      ),
      findsNothing,
    );
  });

  testWidgets('mở chi tiết ảnh hiển thị người gửi và thời gian theo giờ local', (
    tester,
  ) async {
    await tester.pumpWidget(timeline(buildRepository(photoCount: 3)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('photoImage_mock-photo-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photoDetailImage')), findsOneWidget);
    expect(find.byKey(const Key('photoDetailSender')), findsOneWidget);
    // Ảnh thứ nhất của mock gửi lúc 2026-10-21T09:00Z.
    expect(
      tester.widget<Text>(find.byKey(const Key('photoDetailTime'))).data,
      formatLocalDateTime(DateTime.utc(2026, 10, 21, 9)),
    );
  });
}
