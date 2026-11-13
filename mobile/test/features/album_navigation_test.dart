import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/album_repository.dart';
import 'package:mobile/main.dart';
import '../support/app_harness.dart';

void main() {
  testWidgets(
    'End-to-end album flow via real AppRouter: login, paired CoupleHome -> openAlbums -> create album -> open detail -> navigate back',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = AppHarness();

      // Pair Alex and Sam
      await tester.runAsync(() async {
        await harness.auth.login('alex@ourspace.dev', 'Password123!');
        final invite = await harness.couples.createInvite();
        await harness.auth.logout();
        await harness.auth.login('sam@ourspace.dev', 'Password123!');
        await harness.couples.join(invite.inviteCode);
      });

      // Launch full app
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // 1. Verify we are on CoupleHomeScreen
      expect(find.text('Không gian của hai bạn'), findsOneWidget);
      expect(find.byKey(const Key('openAlbums')), findsOneWidget);

      // 2. Tap openAlbums to navigate to AlbumListScreen
      await tester.ensureVisible(find.byKey(const Key('openAlbums')));
      await tester.tap(find.byKey(const Key('openAlbums')));
      await tester.pumpAndSettle();

      // 3. Verify AlbumListScreen empty state
      expect(find.text('Chưa có album nào'), findsOneWidget);
      expect(find.byKey(const Key('emptyStateCreateAlbumButton')), findsOneWidget);

      // 4. Create new album
      await tester.tap(find.byKey(const Key('emptyStateCreateAlbumButton')));
      await tester.pumpAndSettle();

      expect(find.text('Tạo album mới'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('albumTitleInput')), 'Chuyến đi Phú Quốc');
      await tester.enterText(find.byKey(const Key('albumDescInput')), 'Tháng 11 năm 2026');
      await tester.tap(find.byKey(const Key('submitCreateAlbum')));
      await tester.pumpAndSettle();

      // 5. Verify newly created album appears in list
      expect(find.text('Chuyến đi Phú Quốc'), findsOneWidget);
      expect(find.text('Tháng 11 năm 2026'), findsOneWidget);

      // 6. Tap album card to open AlbumDetailScreen
      final albumCardFinder = find.byWidgetPredicate(
        (widget) => widget is Card && widget.key != null && widget.key.toString().contains('albumCard_'),
      );
      expect(albumCardFinder, findsOneWidget);
      await tester.tap(albumCardFinder);
      await tester.pumpAndSettle();

      // 7. Verify AlbumDetailScreen
      expect(find.text('Chuyến đi Phú Quốc'), findsAtLeast(1));
      expect(find.text('Album chưa có ảnh nào'), findsOneWidget);

      // 8. Navigate back to AlbumListScreen via BackButton
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Chuyến đi Phú Quốc'), findsOneWidget);

      // 9. Navigate back to CoupleHomeScreen via BackButton
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Không gian của hai bạn'), findsOneWidget);
    },
  );

  testWidgets(
    'forceLogout closes open album route and returns to Login screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = AppHarness();

      await tester.runAsync(() async {
        await harness.auth.login('alex@ourspace.dev', 'Password123!');
        final invite = await harness.couples.createInvite();
        await harness.auth.logout();
        await harness.auth.login('sam@ourspace.dev', 'Password123!');
        await harness.couples.join(invite.inviteCode);
      });

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // Navigate to AlbumListScreen
      await tester.ensureVisible(find.byKey(const Key('openAlbums')));
      await tester.tap(find.byKey(const Key('openAlbums')));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có album nào'), findsOneWidget);

      // Trigger session expiry via forceLogout
      harness.auth.forceLogout();
      await tester.pumpAndSettle();

      // Verify album routes popped and Login appears
      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.byKey(const Key('passwordField')), findsOneWidget);
      expect(find.text('Chưa có album nào'), findsNothing);
      expect(find.text('Không gian của hai bạn'), findsNothing);
    },
  );

  testWidgets(
    'album 401 response from HttpAlbumRepository triggers onUnauthenticated, clears session, closes album route and displays Login without direct forceLogout call',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = AppHarness();

      await tester.runAsync(() async {
        await harness.auth.login('alex@ourspace.dev', 'Password123!');
        final invite = await harness.couples.createInvite();
        await harness.auth.logout();
        await harness.auth.login('sam@ourspace.dev', 'Password123!');
        await harness.couples.join(invite.inviteCode);
      });

      // Inject HttpAlbumRepository with MockClient returning 401 on /api/v1/albums
      final mockClient = MockClient((request) async {
        if (request.url.path.startsWith('/api/v1/albums')) {
          return http.Response(
            jsonEncode({'message': 'Phiên đăng nhập đã hết hạn'}),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final httpAlbumRepo = HttpAlbumRepository(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
        onUnauthenticated: harness.auth.forceLogout,
      );

      // Render OurSpaceApp injecting httpAlbumRepo
      await tester.pumpWidget(
        OurSpaceApp(
          auth: harness.auth,
          couples: harness.couples,
          timeline: harness.timeline,
          photos: harness.photos,
          albums: httpAlbumRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không gian của hai bạn'), findsOneWidget);
      expect(harness.auth.isAuthenticated, isTrue);

      // Tap openAlbums: AlbumListScreen.initState() triggers listAlbums() -> returns 401
      await tester.ensureVisible(find.byKey(const Key('openAlbums')));
      await tester.tap(find.byKey(const Key('openAlbums')));
      await tester.pumpAndSettle();

      // Verify that 401 from repository automatically triggered auth.forceLogout:
      // 1. Session is cleared
      expect(harness.auth.isAuthenticated, isFalse);
      expect(harness.auth.token, isNull);

      // 2. Album route is closed and app navigated back to Login screen
      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.byKey(const Key('passwordField')), findsOneWidget);
      expect(find.text('Không gian của hai bạn'), findsNothing);
      expect(find.text('Chưa có album nào'), findsNothing);
    },
  );
}
