import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/memory_story_repository.dart';
import 'package:mobile/memory_story_screen.dart';

void main() {
  testWidgets('MemoryStoryScreen displays draft story, edits and saves to album', (tester) async {
    final storyRepo = MockMemoryStoryRepository();

    // Generate initial draft story
    final draft = await storyRepo.generateStory(
      'mock-token',
      albumId: 'album-1',
      photoIds: ['photo-1', 'photo-2'],
      notes: 'Chuyến đi Phú Quốc',
      tone: 'ROMANTIC',
      consent: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ourSpaceTheme,
        home: MemoryStoryScreen(
          storyId: draft.id,
          albumId: 'album-1',
          storyRepository: storyRepo,
          token: 'mock-token',
          userId: 'user-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify story content rendered
    expect(find.text('Câu Chuyện Kỷ Niệm'), findsOneWidget);
    expect(find.text(draft.title), findsOneWidget);
    expect(find.text(draft.storyText), findsOneWidget);
    expect(find.text('Bản nháp riêng tư'), findsOneWidget);
    expect(find.text('Lưu vào Album'), findsOneWidget);

    // 2. Open edit dialog
    await tester.tap(find.widgetWithText(OutlinedButton, 'Chỉnh sửa'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa câu chuyện AI'), findsOneWidget);

    // Enter new title and story
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Tiêu đề đã sửa');
    await tester.enterText(textFields.at(1), 'Nội dung câu chuyện kỷ niệm ngọt ngào đã được sửa.');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cập nhật'));
    await tester.pumpAndSettle();

    // Verify updated title and story
    expect(find.text('Tiêu đề đã sửa'), findsOneWidget);
    expect(find.text('Nội dung câu chuyện kỷ niệm ngọt ngào đã được sửa.'), findsOneWidget);

    // 3. Save to album
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu vào Album'));
    await tester.pumpAndSettle();

    // Verify saved status: badge says Đã lưu vào Album, save button in bottom bar is gone
    expect(find.text('Đã lưu vào Album'), findsOneWidget);
    expect(find.text('Lưu vào Album'), findsNothing);
  });
}
