import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import '../support/app_harness.dart';
import '../support/calendar_fixture.dart';

void main() {
  testWidgets(
    'paired Home opens calendar; session expiry closes editor and returns to Login',
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
      await tester.pumpWidget(
        OurSpaceApp(
          auth: harness.auth,
          couples: harness.couples,
          timeline: harness.timeline,
          photos: harness.photos,
          calendar: CalendarFixture(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('openCalendar')));
      await tester.tap(find.byKey(const Key('openCalendar')));
      await tester.pumpAndSettle();
      expect(find.text('100 ngày bên nhau'), findsOneWidget);
      await tester.tap(find.text('Thêm sự kiện'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eventTitle')), findsOneWidget);
      harness.auth.forceLogout();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.byKey(const Key('eventTitle')), findsNothing);
      expect(find.text('100 ngày bên nhau'), findsNothing);
    },
  );
}
