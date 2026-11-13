import 'package:flutter/material.dart';

import '../../data/album_repository.dart';
import '../../data/memory_story_repository.dart';
import '../../data/photo_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/pairing/data/pairing_repository.dart';
import '../../features/pairing/presentation/pairing_gate.dart';
import '../../features/timeline/data/timeline_repository.dart';
import '../state/auth_controller.dart';
import '../widgets/async_states.dart';

/// Điều hướng khai báo theo trạng thái phiên (S1-06):
///
/// | Trạng thái                       | Màn hình     |
/// |----------------------------------|--------------|
/// | đang khôi phục phiên             | Splash       |
/// | chưa đăng nhập                   | Login        |
/// | đã đăng nhập, chưa ghép đôi      | Pairing      |
/// | đã ghép đôi                      | Couple Home  |
///
/// Router không dùng `Navigator` cho luồng chính: mỗi khi `AuthController`
/// đổi trạng thái, cây widget được dựng lại và màn hình đúng xuất hiện.
class AppRouter extends StatelessWidget {
  const AppRouter({
    super.key,
    required this.auth,
    required this.couples,
    required this.photos,
    this.albums,
    this.stories,
    required this.timeline,
    this.calendar,
  });

  final AuthController auth;
  final CoupleRepository couples;
  final PhotoRepository photos;
  final AlbumRepository? albums;
  final MemoryStoryRepository? stories;
  final TimelineRepository timeline;
  final CalendarRepository? calendar;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth,
    builder: (context, _) {
      final session = auth.session;
      if (session == null) {
        if (auth.isRestoring) {
          return const Scaffold(
            body: LoadingStateView(message: 'Đang khôi phục phiên đăng nhập…'),
          );
        }
        return AuthScreen(auth: auth);
      }
      // Key theo user để trạng thái ghép đôi không rò rỉ sang tài khoản khác.
      return PairingGate(
        key: ValueKey<String>('pairing-${session.user.id}'),
        userId: session.user.id,
        auth: auth,
        couples: couples,
        photos: photos,
        albums: albums,
        stories: stories,
        timeline: timeline,
        calendar: calendar,
      );
    },
  );
}
