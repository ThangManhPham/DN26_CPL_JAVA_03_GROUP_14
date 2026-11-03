import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/photo_repository.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/timeline/data/timeline_repository.dart';

/// PNG 1x1 hợp lệ (chữ ký đúng) — mock chỉ cần đủ để phân biệt nội dung ảnh.
Uint8List png([int marker = 1]) => Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, marker,
]);

void main() {
  const me = UserProfile(
    id: 'user-me',
    email: 'me@ourspace.dev',
    displayName: 'Bạn',
  );

  setUp(MockTimelineRepository.clear);

  test('ảnh gửi qua MockPhotoRepository lên đầu timeline kèm đúng bytes', () async {
    final photos = MockPhotoRepository(currentUser: () => me);
    final bytes = png(7);

    final uploaded = await photos.upload('token', bytes, 'image/png', 'req-1');

    final timeline = MockTimelineRepository(
      photoCount: 0,
      latency: Duration.zero,
      currentUserId: () => me.id,
    );
    final page = await timeline.fetchPage();

    expect(page.items.first.id, uploaded.id);
    expect(page.items.first.senderId, me.id);
    // Ảnh phải hiển thị đúng nội dung vừa gửi, không phải ảnh placeholder.
    expect(await timeline.fetchImage(uploaded.imagePath), bytes);
  });

  test('mỗi ảnh giữ bytes riêng thay vì dùng chung một biến', () async {
    final photos = MockPhotoRepository(currentUser: () => me);
    final first = png(1);
    final second = png(2);

    final photoOne = await photos.upload('token', first, 'image/png', 'req-1');
    final photoTwo = await photos.upload('token', second, 'image/png', 'req-2');

    expect(await photos.image('token', photoOne), first);
    expect(await photos.image('token', photoTwo), second);

    final timeline = MockTimelineRepository(
      photoCount: 0,
      latency: Duration.zero,
      currentUserId: () => me.id,
    );
    expect(await timeline.fetchImage(photoOne.imagePath), first);
    expect(await timeline.fetchImage(photoTwo.imagePath), second);
  });
}
