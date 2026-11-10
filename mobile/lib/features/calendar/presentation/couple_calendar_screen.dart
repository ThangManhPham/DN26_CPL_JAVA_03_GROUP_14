import 'package:flutter/material.dart';
import '../data/calendar_repository.dart';
import '../data/anniversary_notifications.dart';

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _time(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class CoupleCalendarScreen extends StatefulWidget {
  const CoupleCalendarScreen({
    super.key,
    required this.repository,
    required this.token,
    required this.onBack,
    required this.onLogout,
    this.notifications = const AnniversaryNotifications(),
  });
  final CalendarRepository repository;
  final String token;
  final VoidCallback onBack, onLogout;
  final AnniversaryNotifications notifications;
  @override
  State<CoupleCalendarScreen> createState() => _CoupleCalendarScreenState();
}

class _CoupleCalendarScreenState extends State<CoupleCalendarScreen>
    with WidgetsBindingObserver {
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  CoupleSpace? _space;
  List<CoupleEvent> _events = [];
  bool _busy = false;
  String? _error, _code;
  int _generation = 0;
  String _notificationStatus = 'disabled';
  DateTime get _month => DateTime(_selected.year, _selected.month);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_busy) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final month = _month;
    setState(() {
      _busy = true;
      _error = null;
      _code = null;
    });
    try {
      final space = await widget.repository.space(widget.token);
      if (!mounted || generation != _generation) return;
      final notificationStatus = await widget.notifications.sync(space);
      final events = await widget.repository.events(
        widget.token,
        month,
        DateTime(month.year, month.month + 1),
      );
      if (mounted && generation == _generation) {
        setState(() {
          _space = space;
          _events = events;
          _notificationStatus = notificationStatus;
        });
      }
    } on ApiException catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.userMessage;
          _code = e.code;
          _space = null;
          _events = [];
        });
        if (e.isSessionExpired || e.code == 'COUPLE_NOT_FOUND') {
          await widget.notifications.clear();
        }
        if (e.isSessionExpired) widget.onLogout();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Không thể tải lịch. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _toggleReminder(bool enabled) async {
    final space = _space;
    if (space == null || _busy) return;
    setState(() => _busy = true);
    final status = await widget.notifications.sync(space, enabled: enabled);
    if (!mounted) return;
    setState(() {
      _notificationStatus = status;
      _busy = false;
    });
  }

  Future<void> _changeAnniversary() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final initial = _space?.anniversary;
    final date = await showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isAfter(now) ? initial : now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Ngày bắt đầu yêu',
    );
    if (date == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.anniversary(widget.token, date);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException
              ? error.userMessage
              : 'Không thể lưu. Vui lòng thử lại.',
        ),
      ),
    );
    if (error is ApiException && error.code == 'UNAUTHORIZED') {
      widget.onLogout();
    }
  }

  Future<void> _edit([CoupleEvent? event]) async {
    if (_busy) return;
    CoupleEvent? fresh;
    if (event != null) {
      setState(() => _busy = true);
      try {
        fresh = await widget.repository.get(widget.token, event.id);
      } catch (e) {
        if (mounted) {
          _showError(e);
          await _load();
        }
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
    }
    final saved = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          repository: widget.repository,
          token: widget.token,
          date: _selected,
          event: fresh,
        ),
      ),
    );
    if (saved != null && mounted) {
      _selected = DateUtils.dateOnly(saved);
      await _load();
    }
  }

  Future<void> _delete(CoupleEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: Text(event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.delete(widget.token, event);
      await _load();
    } catch (e) {
      if (mounted) {
        _showError(e);
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _selected;
    final end = DateTime(start.year, start.month, start.day + 1);
    final selectedEvents = _events
        .where((e) => e.startsAt.isBefore(end) && e.endsAt.isAfter(start))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Không gian đôi'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: _space == null || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm sự kiện'),
                ),
              ),
            ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _code == 'UNAUTHORIZED'
                          ? widget.onLogout
                          : _code == 'COUPLE_NOT_FOUND'
                          ? widget.onBack
                          : _load,
                      child: Text(
                        _code == 'UNAUTHORIZED'
                            ? 'Đăng nhập lại'
                            : _code == 'COUPLE_NOT_FOUND'
                            ? 'Quay về ghép đôi'
                            : 'Thử lại',
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.favorite, color: Colors.pink),
                            Text(
                              _space?.daysTogether == null
                                  ? 'Chọn ngày bắt đầu yêu'
                                  : '${_space!.daysTogether} ngày bên nhau',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (_space?.anniversary != null)
                              Text('Từ ngày ${_date(_space!.anniversary!)}'),
                            TextButton(
                              key: const Key('changeAnniversary'),
                              onPressed: _busy ? null : _changeAnniversary,
                              child: const Text('Đổi ngày kỷ niệm'),
                            ),
                            if (_space?.reminder case final reminder?) ...[
                              const Divider(),
                              Text(
                                reminder.daysUntil == 0
                                    ? 'Hôm nay kỷ niệm ${reminder.yearsTogether} năm bên nhau!'
                                    : 'Còn ${reminder.daysUntil} ngày đến kỷ niệm ${reminder.yearsTogether} năm',
                                key: const Key('anniversaryReminder'),
                                textAlign: TextAlign.center,
                              ),
                              Text('Ngày ${_date(reminder.occursOn)}'),
                              const Text(
                                'Ngày 29/2 được nhắc vào 28/2 nếu năm đó không nhuận.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (widget.notifications.supported &&
                                _space?.anniversary != null)
                              SwitchListTile.adaptive(
                                key: const Key('anniversaryNotificationSwitch'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Nhắc kỷ niệm trên iPhone'),
                                subtitle: Text(
                                  _notificationStatus == 'denied'
                                      ? 'Thông báo bị tắt. Cho phép trong Cài đặt iPhone rồi bật lại.'
                                      : _notificationStatus == 'unavailable'
                                      ? 'Chưa đặt được lịch nhắc. Vui lòng thử lại.'
                                      : 'Lúc 9:00 ngày kỷ niệm, theo giờ thiết bị. Bật riêng trên từng máy.',
                                ),
                                value: _notificationStatus == 'enabled',
                                onChanged: _busy ? null : _toggleReminder,
                              )
                            else if (_space?.reminder != null)
                              const Text(
                                'Nhắc trong ứng dụng. Thông báo khi đóng app cần bản iOS.',
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Text(
                      'Lịch chung',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Tháng trước',
                          onPressed: _month.year <= 1900 && _month.month == 1
                              ? null
                              : () {
                                  _selected = DateTime(
                                    _month.year,
                                    _month.month - 1,
                                  );
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Tháng ${_month.month}/${_month.year}'),
                        IconButton(
                          tooltip: 'Tháng sau',
                          onPressed: _month.year >= 2100 && _month.month == 12
                              ? null
                              : () {
                                  _selected = DateTime(
                                    _month.year,
                                    _month.month + 1,
                                  );
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    _calendar(),
                    const SizedBox(height: 16),
                    Text(
                      'Ngày ${_date(_selected)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Giờ theo thiết bị (UTC${calendarTimezone()}). '
                      'Ngày bắt đầu yêu được tính là ngày 0.',
                    ),
                    if (selectedEvents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Chưa có sự kiện trong ngày này.'),
                      ),
                    ...selectedEvents.map(
                      (event) => Card(
                        child: ListTile(
                          title: Text(
                            event.title,
                            key: Key('calendarEvent_${event.id}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_date(event.startsAt)} ${_time(event.startsAt)} → ${_date(event.endsAt)} ${_time(event.endsAt)}\n${event.description ?? ''}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          onTap: () => _edit(event),
                          trailing: IconButton(
                            tooltip: 'Xóa sự kiện',
                            onPressed: _busy ? null : () => _delete(event),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _calendar() {
    final offset = _month.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return Column(
      children: [
        Row(
          children: [
            'T2',
            'T3',
            'T4',
            'T5',
            'T6',
            'T7',
            'CN',
          ].map((day) => Expanded(child: Center(child: Text(day)))).toList(),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: offset + days,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final date = DateTime(
              _month.year,
              _month.month,
              index - offset + 1,
            );
            final next = DateTime(date.year, date.month, date.day + 1);
            final hasEvents = _events.any(
              (e) => e.startsAt.isBefore(next) && e.endsAt.isAfter(date),
            );
            return Semantics(
              label: '${_date(date)}${hasEvents ? ", có sự kiện" : ""}',
              selected: DateUtils.isSameDay(date, _selected),
              child: InkWell(
                onTap: () => setState(() => _selected = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: DateUtils.isSameDay(date, _selected)
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${date.day}'),
                      if (hasEvents)
                        const Icon(Icons.circle, size: 6, color: Colors.pink),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    required this.repository,
    required this.token,
    required this.date,
    this.event,
  });
  final CalendarRepository repository;
  final String token;
  final DateTime date;
  final CoupleEvent? event;
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description;
  late DateTime _start, _end;
  CoupleEvent? _currentEvent;
  bool _busy = false;
  String? _error;
  bool _conflict = false;
  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _title = TextEditingController(text: widget.event?.title);
    _description = TextEditingController(text: widget.event?.description);
    _start =
        widget.event?.startsAt ??
        DateTime(widget.date.year, widget.date.month, widget.date.day, 19);
    _end = widget.event?.endsAt ?? _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'Giờ kết thúc phải sau giờ bắt đầu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.save(widget.token, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'startsAt': _start.toUtc().toIso8601String(),
        'endsAt': _end.toUtc().toIso8601String(),
        'timezone': calendarTimezone(_start),
      }, event: _currentEvent);
      if (mounted) Navigator.pop(context, saved.startsAt);
    } catch (e) {
      if (mounted) {
        setState(() {
          _conflict = e is ApiException && e.code == 'EVENT_CONFLICT';
          _error = e is ApiException ? e.userMessage : 'Không thể lưu sự kiện.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadEvent() async {
    if (_busy || _currentEvent == null) return;
    setState(() => _busy = true);
    try {
      final latest = await widget.repository.get(
        widget.token,
        _currentEvent!.id,
      );
      if (!mounted) return;
      setState(() {
        _currentEvent = latest;
        _title.text = latest.title;
        _description.text = latest.description ?? '';
        _start = latest.startsAt;
        _end = latest.endsAt;
        _error = null;
        _conflict = false;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.userMessage
              : 'Không thể tải sự kiện.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.event == null ? 'Thêm sự kiện' : 'Sửa sự kiện'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const Key('eventTitle'),
            enabled: !_busy,
            controller: _title,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Tên sự kiện'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên sự kiện.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('eventDescription'),
            enabled: !_busy,
            controller: _description,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          ListTile(
            title: const Text('Bắt đầu'),
            subtitle: Text('${_date(_start)} ${_time(_start)}'),
            onTap: _busy ? null : () => _pick(true),
            trailing: const Icon(Icons.schedule),
          ),
          ListTile(
            title: const Text('Kết thúc'),
            subtitle: Text('${_date(_end)} ${_time(_end)}'),
            onTap: _busy ? null : () => _pick(false),
            trailing: const Icon(Icons.schedule),
          ),
          const Text(
            'Thời gian theo múi giờ thiết bị; hai người nhìn cùng một thời điểm.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_conflict)
            TextButton(
              key: const Key('reloadConflictedEvent'),
              onPressed: _busy ? null : _reloadEvent,
              child: const Text('Tải bản mới (thay nội dung đang nhập)'),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('saveCalendarEvent'),
            onPressed: _busy || _conflict ? null : _save,
            child: Text(_busy ? 'Đang lưu…' : 'Lưu sự kiện'),
          ),
        ],
      ),
    ),
  );
}
