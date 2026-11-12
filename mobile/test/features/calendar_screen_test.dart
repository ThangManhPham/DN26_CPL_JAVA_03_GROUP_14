import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';
import 'package:mobile/features/calendar/data/anniversary_notifications.dart';
import 'package:mobile/features/calendar/presentation/couple_calendar_screen.dart';
import '../support/calendar_fixture.dart';

Widget app(
  CalendarRepository repository, {
  VoidCallback? onLogout,
  AnniversaryNotifications notifications = const AnniversaryNotifications(),
}) => MaterialApp(
  theme: ourSpaceTheme.copyWith(platform: TargetPlatform.iOS),
  locale: const Locale('vi', 'VN'),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('vi', 'VN')],
  home: CoupleCalendarScreen(
    repository: repository,
    token: 'a',
    onBack: () {},
    onLogout: onLogout ?? () {},
    notifications: notifications,
  ),
);

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  Future<void> open(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'anniversary today is announced and denied permission remains off',
    (tester) async {
      final repository = CalendarFixture();
      repository.currentSpace = CoupleSpace(
        coupleId: 'ab',
        anniversary: DateTime(2020, 2, 29),
        daysTogether: 2000,
        reminder: AnniversaryReminder(
          occursOn: DateTime(2027, 2, 28),
          daysUntil: 0,
          yearsTogether: 7,
        ),
      );
      final notifications = ReminderFixture();
      await open(tester, app(repository, notifications: notifications));
      expect(find.text('Hôm nay kỷ niệm 7 năm bên nhau!'), findsOneWidget);
      final toggle = find.byKey(const Key('anniversaryNotificationSwitch'));
      await reveal(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(notifications.requested, true);
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      expect(find.textContaining('Thông báo bị tắt.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unpaired response cancels device reminder and does not show stale anniversary',
    (tester) async {
      final repository = CalendarFixture()
        ..failure = const ApiException(
          statusCode: 404,
          code: 'COUPLE_NOT_FOUND',
          message: 'No couple',
        );
      final notifications = ReminderFixture();
      await open(tester, app(repository, notifications: notifications));
      expect(notifications.cleared, true);
      expect(find.byKey(const Key('anniversaryReminder')), findsNothing);
    },
  );

  testWidgets(
    'anniversary picker saves the selected civil day and refreshes counter',
    (tester) async {
      final repository = CalendarFixture();
      await open(tester, app(repository));
      await tester.tap(find.byKey(const Key('changeAnniversary')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        repository.currentSpace.anniversary,
        DateUtils.dateOnly(DateTime.now()),
      );
      expect(find.text('100 ngày bên nhau'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'end time before start is rejected in editor without sending a save request',
    (tester) async {
      final repository = CalendarFixture();
      await open(tester, app(repository));
      await tester.tap(find.text('Thêm sự kiện'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('eventTitle')), 'Cuộc hẹn');
      await reveal(tester, find.text('Kết thúc'));
      await tester.tap(find.text('Kết thúc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      // Six is valid in both 12-hour and 24-hour device formats; either is before 19:00.
      await tester.enterText(fields.at(0), '6');
      await tester.enterText(fields.at(1), '00');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      await reveal(tester, find.byKey(const Key('saveCalendarEvent')));
      await tester.tap(find.byKey(const Key('saveCalendarEvent')));
      await tester.pumpAndSettle();
      expect(find.text('Giờ kết thúc phải sau giờ bắt đầu.'), findsOneWidget);
      expect(repository.writes, 0);
    },
  );

  testWidgets(
    'iPhone layout: counter, empty state, create/edit/delete with confirmation',
    (tester) async {
      final repository = CalendarFixture();
      await open(tester, app(repository));
      expect(find.text('100 ngày bên nhau'), findsOneWidget);
      await tester.tap(find.text('Thêm sự kiện'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveCalendarEvent')));
      await tester.pumpAndSettle();
      expect(find.text('Nhập tên sự kiện.'), findsOneWidget);
      expect(repository.writes, 0);
      await tester.enterText(find.byKey(const Key('eventTitle')), 'Ăn tối');
      await reveal(tester, find.byKey(const Key('saveCalendarEvent')));
      await tester.tap(find.byKey(const Key('saveCalendarEvent')));
      await tester.pumpAndSettle();
      expect(repository.items.values.single.title, 'Ăn tối');
      await reveal(tester, find.text('Ăn tối'));
      await tester.tap(find.text('Ăn tối'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('eventTitle')),
        'Ăn tối và xem phim',
      );
      await reveal(tester, find.byKey(const Key('saveCalendarEvent')));
      await tester.tap(find.byKey(const Key('saveCalendarEvent')));
      await tester.pumpAndSettle();
      expect(repository.items.values.single.version, 1);
      await reveal(tester, find.byTooltip('Xóa sự kiện'));
      await tester.tap(find.byTooltip('Xóa sự kiện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repository.items, hasLength(1));
      await tester.tap(find.byTooltip('Xóa sự kiện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(repository.items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'conflict preserves draft until explicit reload; retry uses refreshed version',
    (tester) async {
      final repository = CalendarFixture()..seed();
      await open(tester, app(repository));
      await reveal(tester, find.text('Ăn tối cùng nhau'));
      await tester.tap(find.text('Ăn tối cùng nhau'));
      await tester.pumpAndSettle();
      repository.seed(title: 'B đã đổi lịch', version: 1);
      await tester.enterText(find.byKey(const Key('eventTitle')), 'Bản nháp A');
      await reveal(tester, find.byKey(const Key('saveCalendarEvent')));
      await tester.tap(find.byKey(const Key('saveCalendarEvent')));
      await tester.pumpAndSettle();
      expect(find.text('Bản nháp A'), findsOneWidget);
      expect(repository.writes, 0);
      await reveal(tester, find.byKey(const Key('reloadConflictedEvent')));
      await tester.tap(find.byKey(const Key('reloadConflictedEvent')));
      await tester.pumpAndSettle();
      expect(find.text('B đã đổi lịch'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('eventTitle')),
        'A cập nhật sau khi tải lại',
      );
      await reveal(tester, find.byKey(const Key('saveCalendarEvent')));
      await tester.tap(find.byKey(const Key('saveCalendarEvent')));
      await tester.pumpAndSettle();
      expect(repository.items['shared']!.version, 2);
    },
  );

  testWidgets(
    'retry clears network error and unpaired state offers pairing navigation',
    (tester) async {
      final repository = CalendarFixture()
        ..failure = const ApiException(
          statusCode: 0,
          code: 'NETWORK_ERROR',
          message: 'Offline',
        );
      await open(tester, app(repository));
      expect(find.text('Thử lại'), findsOneWidget);
      repository.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('100 ngày bên nhau'), findsOneWidget);
      repository.failure = const ApiException(
        statusCode: 404,
        code: 'COUPLE_NOT_FOUND',
        message: 'Unpaired',
      );
      await tester.tap(find.byTooltip('Tải lại'));
      await tester.pumpAndSettle();
      expect(find.text('Quay về ghép đôi'), findsOneWidget);
      expect(find.text('100 ngày bên nhau'), findsNothing);
    },
  );

  testWidgets(
    'expired session clears calendar instead of showing cached private data',
    (tester) async {
      final repository = CalendarFixture()..seed();
      var loggedOut = false;
      await open(tester, app(repository, onLogout: () => loggedOut = true));
      repository.failure = const ApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Expired',
      );
      await tester.tap(find.byTooltip('Tải lại'));
      await tester.pumpAndSettle();
      expect(loggedOut, isTrue);
      expect(find.text('100 ngày bên nhau'), findsNothing);
      expect(find.text('Đăng nhập lại'), findsOneWidget);
    },
  );
}

class ReminderFixture extends AnniversaryNotifications {
  bool? requested;
  bool cleared = false;
  @override
  bool get supported => true;
  @override
  Future<String> sync(CoupleSpace space, {bool? enabled}) async {
    requested = enabled;
    return enabled == true ? 'denied' : 'disabled';
  }

  @override
  Future<void> clear() async {
    cleared = true;
  }
}
