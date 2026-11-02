import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Nhập thông tin đăng nhập ở màn Login (chế độ mặc định).
Future<void> login(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.enterText(find.byKey(const Key('emailField')), email);
  await tester.enterText(find.byKey(const Key('passwordField')), password);
  await tester.ensureVisible(find.byKey(const Key('authSubmit')));
  await tester.tap(find.byKey(const Key('authSubmit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'A tạo mã mời, B nhập mã để ghép đôi, rồi hủy ghép đôi có xác nhận',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(AppHarness().app);
      await tester.pumpAndSettle();

      // Tài khoản A tạo mã mời.
      await login(tester, 'alex@ourspace.dev', 'Password123!');
      expect(find.text('Chào Alex,'), findsOneWidget);

      await tester.tap(find.byKey(const Key('createInviteEntry')));
      await tester.pumpAndSettle();

      final code = tester
          .widget<Text>(find.byKey(const Key('inviteCode')))
          .data!;
      expect(code.length, 6);
      expect(find.byKey(const Key('inviteExpiry')), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Đăng xuất A rồi đăng nhập tài khoản B trên cùng thiết bị.
      await tester.ensureVisible(find.byKey(const Key('pairingLogout')));
      await tester.tap(find.byKey(const Key('pairingLogout')));
      await tester.pumpAndSettle();
      expect(find.text('Chào mừng\ntrở lại.'), findsOneWidget);

      await login(tester, 'sam@ourspace.dev', 'Password123!');
      expect(find.text('Chào Sam,'), findsOneWidget);

      // B nhập mã của A.
      await tester.ensureVisible(find.byKey(const Key('joinInviteEntry')));
      await tester.tap(find.byKey(const Key('joinInviteEntry')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('inviteCodeField')), code);
      await tester.ensureVisible(find.byKey(const Key('joinInviteSubmit')));
      await tester.tap(find.byKey(const Key('joinInviteSubmit')));
      await tester.pumpAndSettle();

      // Couple Home hiển thị thông tin cặp đôi.
      expect(find.byKey(const Key('coupleTitle')), findsOneWidget);
      expect(find.text('Bạn và Alex'), findsOneWidget);
      expect(find.byKey(const Key('member_mock-1')), findsOneWidget);
      expect(find.byKey(const Key('member_mock-2')), findsOneWidget);

      // Hủy ghép đôi: bỏ qua ở hộp thoại thì giữ nguyên.
      await tester.ensureVisible(find.byKey(const Key('unpairButton')));
      await tester.tap(find.byKey(const Key('unpairButton')));
      await tester.pumpAndSettle();
      expect(find.text('Hủy ghép đôi?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unpairCancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coupleTitle')), findsOneWidget);

      // Xác nhận hủy -> quay về màn Pairing.
      await tester.tap(find.byKey(const Key('unpairButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unpairConfirm')));
      await tester.pumpAndSettle();
      expect(find.text('Chào Sam,'), findsOneWidget);
      expect(find.byKey(const Key('joinInviteEntry')), findsOneWidget);
    },
  );

  testWidgets('màn nhập mã hiển thị đúng lỗi cho từng trường hợp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AppHarness().app);
    await tester.pumpAndSettle();
    await login(tester, 'alex@ourspace.dev', 'Password123!');

    await tester.tap(find.byKey(const Key('joinInviteEntry')));
    await tester.pumpAndSettle();

    Future<void> submit(String code) async {
      await tester.enterText(find.byKey(const Key('inviteCodeField')), code);
      await tester.ensureVisible(find.byKey(const Key('joinInviteSubmit')));
      await tester.tap(find.byKey(const Key('joinInviteSubmit')));
      await tester.pumpAndSettle();
    }

    // Sai định dạng (không đủ 6 ký tự) -> validate tại client.
    await submit('AB');
    expect(find.text('Mã mời gồm 6 ký tự.'), findsOneWidget);

    await submit('EXPYR3');
    expect(find.text('Mã ghép đôi đã hết hạn.'), findsOneWidget);

    await submit('US3D22');
    expect(
      find.text('Mã ghép đôi không đúng hoặc đã được sử dụng.'),
      findsOneWidget,
    );

    await submit('S3LF22');
    expect(find.text('Không thể tự ghép đôi với chính mình.'), findsOneWidget);

    await submit('PAYRD2');
    expect(
      find.text('Người gửi mã đã thuộc về một cặp đôi khác.'),
      findsOneWidget,
    );
  });

  testWidgets('từ Couple Home mở được Timeline của hai bạn', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Ghép sẵn A với B ở tầng repository để router vào thẳng Couple Home.
    // Phải chạy trong `runAsync` vì repository mock dùng `Future.delayed`
    // (timer của fake-async chỉ chạy khi pump, nên không thể await trước đó).
    final harness = AppHarness(photoCount: 7);
    await tester.runAsync(() async {
      await harness.auth.login('alex@ourspace.dev', 'Password123!');
      final invite = await harness.couples.createInvite();
      await harness.auth.login('sam@ourspace.dev', 'Password123!');
      await harness.couples.join(invite.inviteCode);
      await harness.auth.logout();
    });

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await login(tester, 'alex@ourspace.dev', 'Password123!');

    expect(find.byKey(const Key('coupleTitle')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('openTimeline')));
    await tester.tap(find.byKey(const Key('openTimeline')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timelineList')), findsOneWidget);
    expect(find.byKey(const Key('photo_mock-photo-1')), findsOneWidget);
  });
}
