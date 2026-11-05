import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';

/// Opt-in: point at a disposable real backend, never the personal demo DB.
/// flutter test test/features/calendar_backend_acceptance_test.dart
///   --dart-define=CALENDAR_API_BASE_URL=http://127.0.0.1:PORT
void main() {
  const baseUrl = String.fromEnvironment('CALENDAR_API_BASE_URL');
  test(
    'real backend: A/B sharing, TC-21 UTC round-trip, version conflict, outsider and delete',
    () async {
      final client = ApiClient(baseUrl: baseUrl);
      final calendar = ApiCalendarRepository(client);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final tokens = <String>[];
      for (final name in ['a', 'b', 'c', 'd']) {
        final credentials = {
          'email': 'calendar-$name-$suffix@example.com',
          'password': 'CalendarTest123!',
        };
        await client.postJson(
          '/api/v1/auth/register',
          body: {...credentials, 'displayName': 'Calendar $name'},
        );
        final login = await client.postJson(
          '/api/v1/auth/login',
          body: credentials,
        );
        tokens.add(login['accessToken'] as String);
      }
      for (final pair in [
        [0, 1],
        [2, 3],
      ]) {
        final invite = await client.postJson(
          '/api/v1/couple-invites',
          headers: ApiClient.bearer(tokens[pair[0]]),
        );
        await client.postJson(
          '/api/v1/couples/join',
          body: {'inviteCode': invite['inviteCode']},
          headers: ApiClient.bearer(tokens[pair[1]]),
        );
      }
      final a = tokens[0], b = tokens[1], outsider = tokens[2];
      await calendar.anniversary(a, DateTime(2020, 2, 29));
      final space = await calendar.space(b);
      expect(space.anniversary, DateTime(2020, 2, 29));
      expect(space.daysTogether, greaterThan(0));
      final start = DateTime.parse('2026-11-02T00:30:00+07:00');
      final data = <String, dynamic>{
        'title': 'Created by A',
        'description': 'TC-21 midnight boundary',
        'startsAt': start.toUtc().toIso8601String(),
        'endsAt': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'timezone': 'Asia/Ho_Chi_Minh',
      };
      final initial = await calendar.save(a, data);
      final fromB = await calendar.get(b, initial.id);
      expect(fromB.startsAt.toUtc(), DateTime.utc(2026, 11, 1, 17, 30));
      expect(fromB.startsAt, start.toLocal());
      final listed = await calendar.events(
        b,
        DateTime.utc(2026, 11),
        DateTime.utc(2026, 12),
      );
      expect(listed.map((e) => e.id), contains(initial.id));
      final updated = await calendar.save(a, {
        'title': 'Updated by A',
      }, event: initial);
      await expectLater(
        calendar.save(b, {'title': 'Stale B'}, event: fromB),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'EVENT_CONFLICT'),
        ),
      );
      final latest = await calendar.get(b, initial.id);
      final changedByB = await calendar.save(b, {
        'title': 'Updated by B',
      }, event: latest);
      expect((await calendar.get(a, initial.id)).title, 'Updated by B');
      expect(changedByB.version, greaterThan(updated.version));
      await expectLater(
        calendar.save(a, {
          'endsAt': start.subtract(const Duration(hours: 1)).toIso8601String(),
        }, event: changedByB),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
      expect((await calendar.get(a, initial.id)).title, 'Updated by B');
      await expectLater(
        calendar.get(outsider, initial.id),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      expect(
        await calendar.events(
          outsider,
          DateTime.utc(2026, 11),
          DateTime.utc(2026, 12),
        ),
        isEmpty,
      );
      await calendar.delete(a, changedByB);
      await expectLater(
        calendar.get(b, initial.id),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      await expectLater(
        calendar.space('invalid-token'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    },
    skip: baseUrl.isEmpty
        ? 'Set CALENDAR_API_BASE_URL to an isolated real backend.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
