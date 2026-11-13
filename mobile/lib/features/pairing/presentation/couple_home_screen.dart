import 'package:flutter/material.dart';

import '../../../album_list_screen.dart';
import '../../../core/config/app_config.dart';
import '../../../core/state/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/album_repository.dart';
import '../../../data/memory_story_repository.dart';
import '../../../data/photo_repository.dart';
import '../../../photo_screen.dart';
import '../../auth/presentation/profile_screen.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/presentation/couple_calendar_screen.dart';
import '../../timeline/data/timeline_repository.dart';
import '../../timeline/presentation/timeline_screen.dart';
import '../data/pairing_models.dart';
import 'pairing_controller.dart';

/// Couple Home: thông tin cặp đôi, lối vào gửi ảnh và luồng Unpair có hộp
/// thoại xác nhận (S1-09).
class CoupleHomeScreen extends StatefulWidget {
  const CoupleHomeScreen({
    super.key,
    required this.auth,
    required this.controller,
    required this.userId,
    required this.photos,
    this.albums,
    this.stories,
    required this.timeline,
    this.calendar,
  });

  final AuthController auth;
  final PairingController controller;
  final String userId;
  final PhotoRepository photos;
  final AlbumRepository? albums;
  final MemoryStoryRepository? stories;
  final TimelineRepository timeline;
  final CalendarRepository? calendar;

  @override
  State<CoupleHomeScreen> createState() => _CoupleHomeScreenState();
}

class _CoupleHomeScreenState extends State<CoupleHomeScreen> {
  bool _busy = false;
  String? _actionError;

  Future<void> _confirmUnpair(Couple couple) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hủy ghép đôi?'),
            content: const Text(
              'Hai bạn sẽ không còn thấy ảnh và kỷ niệm chung nữa. '
              'Hành động này không thể hoàn tác.',
            ),
            actions: [
              TextButton(
                key: const Key('unpairCancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                key: const Key('unpairConfirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Hủy ghép đôi'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await widget.controller.unpair();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError = 'Không thể hủy ghép đôi. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couple = widget.controller.couple;
    final user = widget.auth.user;
    if (couple == null || user == null) return const SizedBox.shrink();
    final partner = couple.partnerOf(widget.userId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Không gian của hai bạn'),
        actions: [
          IconButton(
            key: const Key('openProfile'),
            tooltip: 'Mở hồ sơ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(auth: widget.auth),
              ),
            ),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.softRose,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 36,
                        color: AppColors.rose,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Bạn và ${partner?.displayName ?? 'người ấy'}',
                        key: const Key('coupleTitle'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text('Trạng thái: ${_statusLabel(couple.status)}'),
                      const SizedBox(height: 6),
                      Text(
                        'Ngày kỷ niệm: '
                        '${couple.anniversaryDate == null ? 'chưa đặt' : formatLocalDateTime(couple.anniversaryDate!)}',
                        key: const Key('coupleAnniversary'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Thành viên',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final member in couple.members)
                  ListTile(
                    key: Key('member_${member.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.softRose,
                      child: Text(
                        member.displayName.isEmpty
                            ? '?'
                            : member.displayName.characters.first.toUpperCase(),
                      ),
                    ),
                    title: Text(
                      member.id == widget.userId
                          ? '${member.displayName} (bạn)'
                          : member.displayName,
                    ),
                    subtitle: Text(_roleLabel(member.role)),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('openTimeline'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TimelineScreen(
                        repository: widget.timeline,
                        currentUserId: widget.userId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_mosaic_outlined),
                  label: const Text('Timeline của hai bạn'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('openCalendar'),
                  onPressed: widget.calendar == null
                      ? null
                      : () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => CoupleCalendarScreen(
                                repository: widget.calendar!,
                                token: widget.auth.token ?? '',
                                onBack: () => Navigator.of(context).pop(),
                                onLogout: widget.auth.forceLogout,
                              ),
                            ),
                          );
                          if (mounted && widget.auth.isAuthenticated) {
                            await widget.controller.load();
                          }
                        },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Ngày kỷ niệm & lịch chung'),
                ),
                if (widget.calendar == null)
                  const Text(
                    'Lịch chung chưa khả dụng trong chế độ dữ liệu mẫu.',
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('openAlbums'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: widget.albums == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AlbumListScreen(
                              albumRepository: widget.albums!,
                              photoRepository: widget.photos,
                              storyRepository: widget.stories ??
                                  (AppConfig.useMock
                                      ? MockMemoryStoryRepository()
                                      : HttpMemoryStoryRepository(
                                          baseUrl: AppConfig.baseUrl,
                                          onUnauthenticated:
                                              widget.auth.forceLogout,
                                        )),
                              token: widget.auth.token ?? '',
                              userId: widget.userId,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Album & Kỷ niệm của hai bạn'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('openPhotos'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PhotoScreen(
                        repository: widget.photos,
                        token: widget.auth.token ?? '',
                        userId: widget.userId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Gửi ảnh cho người ấy'),
                ),
                if (_actionError != null) ...[
                  const SizedBox(height: 18),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _actionError!,
                      key: const Key('coupleHomeError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                TextButton(
                  key: const Key('unpairButton'),
                  onPressed: _busy ? null : () => _confirmUnpair(couple),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Hủy ghép đôi'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  static String _statusLabel(String status) =>
      status == 'ACTIVE' ? 'Đang hoạt động' : status;

  static String _roleLabel(String role) =>
      role == 'OWNER' ? 'Người tạo cặp đôi' : 'Thành viên';
}
