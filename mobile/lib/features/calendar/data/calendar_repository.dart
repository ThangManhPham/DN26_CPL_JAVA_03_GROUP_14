import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

export '../../../core/network/api_exception.dart';

/// Offset at the event's date (not today's offset, which can differ over DST).
String calendarTimezone([DateTime? at]) {
  final offset = (at ?? DateTime.now()).timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  return '${offset.isNegative ? '-' : '+'}${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

class CoupleSpace {
  const CoupleSpace({
    required this.coupleId,
    this.anniversary,
    this.daysTogether,
  });
  final String coupleId;
  final DateTime? anniversary;
  final int? daysTogether;

  factory CoupleSpace.fromJson(Map<String, dynamic> data) => CoupleSpace(
    coupleId: data['coupleId'] as String,
    // A civil date must never be converted from UTC to the device's zone.
    anniversary: data['anniversaryDate'] == null
        ? null
        : DateTime.parse(data['anniversaryDate'] as String),
    daysTogether: (data['daysTogether'] as num?)?.toInt(),
  );
}

class CoupleEvent {
  const CoupleEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.version,
  });
  final String id, title, timezone;
  final String? description;
  final DateTime startsAt, endsAt;
  final int version;

  factory CoupleEvent.fromJson(Map<String, dynamic> data) => CoupleEvent(
    id: data['id'] as String,
    title: data['title'] as String,
    description: data['description'] as String?,
    startsAt: DateTime.parse(data['startsAt'] as String).toLocal(),
    endsAt: DateTime.parse(data['endsAt'] as String).toLocal(),
    timezone: data['timezone'] as String,
    version: (data['version'] as num).toInt(),
  );
}

abstract class CalendarRepository {
  Future<CoupleSpace> space(String token);
  Future<CoupleSpace> anniversary(String token, DateTime date);
  Future<List<CoupleEvent>> events(String token, DateTime from, DateTime until);
  Future<CoupleEvent> get(String token, String id);
  Future<CoupleEvent> save(
    String token,
    Map<String, dynamic> data, {
    CoupleEvent? event,
  });
  Future<void> delete(String token, CoupleEvent event);
}

/// Uses the app's shared Dio client, including timeouts and 401 logout.
/// No dart:io dependency, so iOS and Flutter Web use the same implementation.
class ApiCalendarRepository implements CalendarRepository {
  ApiCalendarRepository(this._client);
  final ApiClient _client;

  @override
  Future<CoupleSpace> space(String token) async => CoupleSpace.fromJson(
    await _client.getJson(
      '/api/v1/couple-space',
      query: {'timezone': calendarTimezone()},
      headers: ApiClient.bearer(token),
    ),
  );

  @override
  Future<CoupleSpace> anniversary(
    String token,
    DateTime date,
  ) async => CoupleSpace.fromJson(
    await _client.patchJson(
      '/api/v1/couple-space?${Uri(queryParameters: {'timezone': calendarTimezone()}).query}',
      body: {
        'anniversaryDate':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      },
      headers: ApiClient.bearer(token),
    ),
  );

  @override
  Future<List<CoupleEvent>> events(
    String token,
    DateTime from,
    DateTime until,
  ) async {
    final items = <CoupleEvent>[];
    final seen = <int>{};
    int? page = 0;
    while (page != null) {
      if (page < 0 || page > 10000 || !seen.add(page)) {
        throw const ApiException(
          statusCode: 0,
          code: 'CALENDAR_PAGINATION_ERROR',
          message: 'Không thể tải đầy đủ lịch. Vui lòng thử lại.',
        );
      }
      final result = await _client.getJson(
        '/api/v1/events',
        query: {
          'from': from.toUtc().toIso8601String(),
          'until': until.toUtc().toIso8601String(),
          'page': page,
          'size': 100,
        },
        headers: ApiClient.bearer(token),
      );
      items.addAll(
        (result['items'] as List).map(
          (e) => CoupleEvent.fromJson(e as Map<String, dynamic>),
        ),
      );
      page = (result['nextPage'] as num?)?.toInt();
    }
    return items;
  }

  @override
  Future<CoupleEvent> get(String token, String id) async =>
      CoupleEvent.fromJson(
        await _client.getJson(
          '/api/v1/events/$id',
          headers: ApiClient.bearer(token),
        ),
      );

  @override
  Future<CoupleEvent> save(
    String token,
    Map<String, dynamic> data, {
    CoupleEvent? event,
  }) async {
    final result = event == null
        ? await _client.postJson(
            '/api/v1/events',
            body: data,
            headers: ApiClient.bearer(token),
          )
        : await _client.patchJson(
            '/api/v1/events/${event.id}',
            body: {...data, 'version': event.version},
            headers: ApiClient.bearer(token),
          );
    return CoupleEvent.fromJson(result);
  }

  @override
  Future<void> delete(String token, CoupleEvent event) async {
    await _client.deleteJson(
      '/api/v1/events/${event.id}?version=${event.version}',
      headers: ApiClient.bearer(token),
    );
  }
}
