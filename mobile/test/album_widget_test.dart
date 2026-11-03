import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/album_detail_screen.dart';
import 'package:mobile/album_list_screen.dart';
import 'package:mobile/data/album_repository.dart';
import 'package:mobile/data/photo_repository.dart';
import 'package:mobile/theme.dart';

void main() {
  testWidgets('AlbumListScreen displays empty state and creates album', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final albumRepo = MockAlbumRepository();
    final photoRepo = MockPhotoRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: ourSpaceTheme,
        home: AlbumListScreen(
          albumRepository: albumRepo,
          photoRepository: photoRepo,
          token: 'mock-token',
          userId: 'user-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty state is rendered
    expect(find.text('Chưa có album nào'), findsOneWidget);
    expect(find.byKey(const Key('emptyStateCreateAlbumButton')), findsOneWidget);

    // Tap create album
    await tester.tap(find.byKey(const Key('emptyStateCreateAlbumButton')));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Tạo album mới'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('albumTitleInput')), 'Kỷ niệm Đà Lạt');
    await tester.enterText(find.byKey(const Key('albumDescInput')), 'Chuyến đi tháng 10');
    await tester.tap(find.byKey(const Key('submitCreateAlbum')));
    await tester.pumpAndSettle();

    // Verify album card appears in list
    expect(find.text('Kỷ niệm Đà Lạt'), findsOneWidget);
    expect(find.text('Chuyến đi tháng 10'), findsOneWidget);
    expect(find.text('0 ảnh'), findsOneWidget);
  });

  testWidgets('AlbumDetailScreen shows detail and adds/removes photo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final albumRepo = MockAlbumRepository();
    final photoRepo = MockPhotoRepository();

    // Seed a couple photo
    final photo = SharedPhoto(
      id: 'photo-101',
      senderId: 'user-1',
      createdAt: DateTime.now(),
      imagePath: '/api/v1/photos/photo-101/image',
    );
    albumRepo.seedMockPhoto(photo);

    // Create an album
    final album = await albumRepo.createAlbum('mock-token', 'Album Biển Vũng Tàu');

    await tester.pumpWidget(
      MaterialApp(
        theme: ourSpaceTheme,
        home: AlbumDetailScreen(
          albumId: album.id,
          albumRepository: albumRepo,
          photoRepository: photoRepo,
          token: 'mock-token',
          userId: 'user-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Album Biển Vũng Tàu'), findsAtLeast(1));
    expect(find.text('Album chưa có ảnh nào'), findsOneWidget);

    // Tap add photo
    await tester.tap(find.byKey(const Key('emptyDetailAddPhotoButton')));
    await tester.pumpAndSettle();

    // Bottom sheet is displayed
    expect(find.text('Chọn ảnh để thêm vào album'), findsOneWidget);
    expect(find.byKey(const Key('photoPickerItem_photo-101')), findsOneWidget);

    // Tap photo item to add
    await tester.tap(find.byKey(const Key('photoPickerItem_photo-101')));
    await tester.pumpAndSettle();

    // Photo is now in album
    expect(find.text('1 ảnh trong album'), findsOneWidget);
    expect(find.byKey(const Key('removePhotoButton_photo-101')), findsOneWidget);

    // Remove photo
    await tester.tap(find.byKey(const Key('removePhotoButton_photo-101')));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Bỏ ảnh khỏi album?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmRemovePhotoButton')));
    await tester.pumpAndSettle();

    // Photo removed
    expect(find.text('Album chưa có ảnh nào'), findsOneWidget);
  });
}
