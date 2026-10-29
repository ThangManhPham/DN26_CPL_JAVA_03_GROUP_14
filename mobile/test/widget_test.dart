import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/auth_repository.dart';
import 'package:mobile/data/photo_repository.dart';
import 'package:mobile/main.dart';

void main() {
  test('auth field validation', () {
    expect(validateEmail('bad'), isNotNull);
    expect(validateEmail('alex@example.com'), isNull);
    expect(validateDisplayName(' '), isNotNull);
    expect(validateDisplayName('Alex'), isNull);
    expect(validatePassword('short', registering: true), isNotNull);
    expect(validatePassword('long-enough', registering: true), isNull);
  });

  testWidgets('register, edit profile, logout and login', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(OurSpaceApp(repository: MockAuthRepository()));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('authSubmit')));
    await tester.tap(find.byKey(const Key('authSubmit')));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên hiển thị.'), findsOneWidget);
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('displayNameField')), 'Alex');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'alex@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'Password123!',
    );
    await tester.ensureVisible(find.byKey(const Key('authSubmit')));
    await tester.tap(find.byKey(const Key('authSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Chào Alex,'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profileNameField')), 'Sam');
    await tester.ensureVisible(find.byKey(const Key('saveProfile')));
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Chào Sam,'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openProfile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng\ntrở lại.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'alex@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'Password123!',
    );
    await tester.tap(find.byKey(const Key('authSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Chào Sam,'), findsOneWidget);
  });

  testWidgets('invalid login shows safe error without exposing account state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(OurSpaceApp(repository: MockAuthRepository()));
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'unknown@example.com',
    );
    await tester.enterText(find.byKey(const Key('passwordField')), 'wrongpass');
    await tester.tap(find.byKey(const Key('authSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
  });

  testWidgets('photo screen shows empty state and requires a selected image', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(OurSpaceApp(
      repository: MockAuthRepository(),
      photoRepository: MockPhotoRepository(),
    ));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('displayNameField')), 'Alex');
    await tester.enterText(find.byKey(const Key('emailField')), 'alex@example.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'Password123!');
    await tester.ensureVisible(find.byKey(const Key('authSubmit')));
    await tester.tap(find.byKey(const Key('authSubmit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('openPhotos')));
    await tester.tap(find.byKey(const Key('openPhotos')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ảnh chung. Hãy gửi khoảnh khắc đầu tiên.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('sendPhoto')));
    expect(button.onPressed, isNull);
  });
}
