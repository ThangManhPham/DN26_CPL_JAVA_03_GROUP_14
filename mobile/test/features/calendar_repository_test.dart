import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';
import '../support/fake_dio_adapter.dart';

Map<String, dynamic> eventJson({int version = 0}) => {
  'id': 'event-1',
  'title': 'Dinner',
  'description': null,
  'startsAt': '2026-11-01T17:30:00Z',
  'endsAt': '2026-11-01T18:30:00Z',
  'timezone': 'Asia/Ho_Chi_Minh',
  'version': version,
};

void main() {
  late FakeDioAdapter adapter;
  late ApiCalendarRepository repository;
  void prepare(
    Future<ResponseBody> Function(RequestOptions) handler, {
    void Function()? on401,
  }) {
    adapter = FakeDioAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..httpClientAdapter = adapter;
    repository = ApiCalendarRepository(
      ApiClient(
        baseUrl: 'http://localhost:8080',
        dio: dio,
        onUnauthenticated: on401,
      ),
    );
  }

  test(
    'anniversary stays a civil date, counter comes from server, JWT and zone are sent',
    () async {
      prepare(
        (_) async => jsonBody({
          'coupleId': 'ab',
          'anniversaryDate': '2020-02-29',
          'daysTogether': 2441,
        }, 200),
      );
      final space = await repository.anniversary(
        'token-a',
        DateTime(2020, 2, 29),
      );
      expect(space.anniversary, DateTime(2020, 2, 29));
      expect(space.daysTogether, 2441);
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.data, {'anniversaryDate': '2020-02-29'});
      expect(request.headers['Authorization'], 'Bearer token-a');
      expect(request.uri.queryParameters['timezone'], calendarTimezone());
    },
  );

  test(
    'unset anniversary remains null rather than falling back to pairing date',
    () async {
      prepare(
        (_) async => jsonBody({
          'coupleId': 'ab',
          'anniversaryDate': null,
          'daysTogether': null,
        }, 200),
      );
      final space = await repository.space('token-a');
      expect(space.anniversary, isNull);
      expect(space.daysTogether, isNull);
    },
  );

  test(
    'month range uses UTC instants and follows pagination through the last page',
    () async {
      prepare(
        (request) async => jsonBody({
          'items': [eventJson()],
          'nextPage': request.queryParameters['page'] == 0 ? 1 : null,
        }, 200),
      );
      final from = DateTime(2026, 11), until = DateTime(2026, 12);
      final events = await repository.events('token-a', from, until);
      expect(events, hasLength(2));
      expect(adapter.requests.map((r) => r.queryParameters['page']), [0, 1]);
      expect(
        adapter.requests.first.queryParameters['from'],
        from.toUtc().toIso8601String(),
      );
      expect(
        adapter.requests.first.queryParameters['until'],
        until.toUtc().toIso8601String(),
      );
    },
  );

  test(
    'invalid pagination cannot loop forever or silently return partial results',
    () async {
      prepare(
        (_) async => jsonBody({
          'items': [eventJson()],
          'nextPage': 0,
        }, 200),
      );
      await expectLater(
        repository.events('a', DateTime(2026, 11), DateTime(2026, 12)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'CALENDAR_PAGINATION_ERROR',
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'TC-21: UTC event round-trip preserves instant across positive and negative zones',
    () async {
      for (final input in [
        '2026-11-02T00:30:00+07:00',
        '2026-11-01T23:30:00-08:00',
      ]) {
        final instant = DateTime.parse(input);
        prepare(
          (_) async => jsonBody({
            ...eventJson(),
            'startsAt': instant.toUtc().toIso8601String(),
          }, 200),
        );
        final event = await repository.get('a', 'event-1');
        expect(event.startsAt.toUtc(), instant.toUtc());
        expect(event.startsAt, instant.toLocal());
        expect(event.timezone, 'Asia/Ho_Chi_Minh');
      }
    },
  );

  test(
    'save and delete carry latest server version; clearing description is explicit',
    () async {
      prepare(
        (r) async => r.method == 'DELETE'
            ? ResponseBody.fromString('', 204)
            : jsonBody(eventJson(version: 4), 200),
      );
      final current = CoupleEvent.fromJson(eventJson(version: 3));
      final updated = await repository.save('b', {
        'title': 'Updated',
        'description': null,
      }, event: current);
      await repository.delete('a', updated);
      expect(adapter.requests.first.data, {
        'title': 'Updated',
        'description': null,
        'version': 3,
      });
      expect(adapter.requests.last.uri.queryParameters['version'], '4');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer a');
    },
  );

  test(
    '401 uses shared session callback, 409 keeps actionable error code',
    () async {
      var expired = 0;
      prepare(
        (_) async =>
            jsonBody({'code': 'UNAUTHORIZED', 'message': 'Expired'}, 401),
        on401: () => expired++,
      );
      await expectLater(
        repository.space('expired'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isSessionExpired,
            'expired',
            true,
          ),
        ),
      );
      expect(expired, 1);
      prepare(
        (_) async =>
            jsonBody({'code': 'EVENT_CONFLICT', 'message': 'Changed'}, 409),
      );
      await expectLater(
        repository.delete('b', CoupleEvent.fromJson(eventJson())),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'EVENT_CONFLICT'),
        ),
      );
    },
  );
}
