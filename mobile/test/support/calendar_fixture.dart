import 'package:mobile/features/calendar/data/calendar_repository.dart';

/// Test-only in-memory server state, shared by simulated A/B sessions.
class CalendarFixture implements CalendarRepository {
  final items = <String, CoupleEvent>{};
  CoupleSpace currentSpace = const CoupleSpace(
    coupleId: 'ab',
    daysTogether: 100,
    anniversary: null,
  );
  ApiException? failure;
  int writes = 0;

  void check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<CoupleSpace> space(String token) async {
    check();
    return currentSpace;
  }

  @override
  Future<CoupleSpace> anniversary(String token, DateTime date) async {
    check();
    return currentSpace = CoupleSpace(
      coupleId: 'ab',
      anniversary: date,
      daysTogether: 100,
    );
  }

  @override
  Future<List<CoupleEvent>> events(
    String token,
    DateTime from,
    DateTime until,
  ) async {
    check();
    return items.values
        .where((e) => e.startsAt.isBefore(until) && e.endsAt.isAfter(from))
        .toList();
  }

  @override
  Future<CoupleEvent> get(String token, String id) async {
    check();
    return items[id]!;
  }

  @override
  Future<CoupleEvent> save(
    String token,
    Map<String, dynamic> data, {
    CoupleEvent? event,
  }) async {
    check();
    if (event != null && items[event.id]!.version != event.version) {
      throw const ApiException(
        statusCode: 409,
        code: 'EVENT_CONFLICT',
        message: 'Changed',
      );
    }
    writes++;
    final id = event?.id ?? 'event-$writes';
    return items[id] = CoupleEvent(
      id: id,
      title: data['title'] as String,
      description: data['description'] as String?,
      startsAt: DateTime.parse(data['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(data['endsAt'] as String).toLocal(),
      timezone: data['timezone'] as String,
      version: event == null ? 0 : event.version + 1,
    );
  }

  @override
  Future<void> delete(String token, CoupleEvent event) async {
    check();
    items.remove(event.id);
  }

  CoupleEvent seed({String title = 'Ăn tối cùng nhau', int version = 0}) {
    final now = DateTime.now();
    final event = CoupleEvent(
      id: 'shared',
      title: title,
      description: 'Lịch chung của A/B',
      startsAt: DateTime(now.year, now.month, now.day, 19),
      endsAt: DateTime(now.year, now.month, now.day, 20),
      timezone: calendarTimezone(),
      version: version,
    );
    items[event.id] = event;
    return event;
  }
}
