import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/push/push_bridge_factory.dart';
import 'core/router/app_router.dart';
import 'core/state/auth_controller.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/album_repository.dart';
import 'data/photo_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/calendar/data/calendar_repository.dart';
import 'features/calendar/data/anniversary_notifications.dart';
import 'features/pairing/data/pairing_repository.dart';
import 'features/timeline/data/timeline_repository.dart';
import 'firebase_options.dart';
import 'ios_widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  // Firebase/APNs chỉ có trên iOS; Flutter Web dùng để test chức năng nên bỏ
  // qua phần push thay vì làm app không khởi động được.
  AppPushBridge? push;
  if (!AppConfig.useMock && !kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_backgroundPushHandler);
    push = createPushBridge(
      baseUrl: AppConfig.baseUrl,
      messengerKey: messengerKey,
    );
  }

  final client = ApiClient(baseUrl: AppConfig.baseUrl);
  final auth = AuthController(
    repository: AppConfig.useMock
        ? _seedMockAuthRepository()
        : ApiAuthRepository(client),
    storage: SecureTokenStorage(),
    onTokenChanged: (token) => client.token = token,
  );
  // Interceptor báo 401 -> xóa phiên và quay về Login (S1-07).
  client.onUnauthenticated = auth.forceLogout;

  runApp(
    OurSpaceApp(
      auth: auth,
      couples: AppConfig.useMock
          ? MockCoupleRepository(currentUser: () => auth.user)
          : ApiCoupleRepository(client),
      timeline: AppConfig.useMock
          ? MockTimelineRepository(
              currentUserId: () => auth.user?.id ?? 'mock-me',
            )
          : ApiTimelineRepository(client),
      photos: AppConfig.useMock
          ? MockPhotoRepository(currentUser: () => auth.user)
          : HttpPhotoRepository(
              baseUrl: AppConfig.baseUrl,
              onUnauthenticated: auth.forceLogout,
            ),
      albums: AppConfig.useMock
          ? MockAlbumRepository()
          : HttpAlbumRepository(
              baseUrl: AppConfig.baseUrl,
              onUnauthenticated: auth.forceLogout,
            ),
      calendar: AppConfig.useMock ? null : ApiCalendarRepository(client),
      push: push,
      messengerKey: messengerKey,
    ),
  );
}

/// Hai tài khoản demo (A/B) để kiểm thử ghép đôi trên 2 thiết bị/2 tab web.
MockAuthRepository _seedMockAuthRepository() {
  final repository = MockAuthRepository();
  repository.seed(
    email: 'alex@ourspace.dev',
    password: 'Password123!',
    displayName: 'Alex',
  );
  repository.seed(
    email: 'sam@ourspace.dev',
    password: 'Password123!',
    displayName: 'Sam',
  );
  return repository;
}

@pragma('vm:entry-point')
Future<void> _backgroundPushHandler(RemoteMessage message) async {
  // Notification payload do OS hiển thị. Không tải ảnh riêng tư ở đây vì
  // người dùng có thể đã đăng xuất khi app bị tắt.
}

class OurSpaceApp extends StatefulWidget {
  const OurSpaceApp({
    super.key,
    required this.auth,
    required this.couples,
    required this.timeline,
    required this.photos,
    this.albums,
    this.calendar,
    this.push,
    this.messengerKey,
  });

  final AuthController auth;
  final CoupleRepository couples;
  final TimelineRepository timeline;
  final PhotoRepository photos;
  final AlbumRepository? albums;
  final CalendarRepository? calendar;
  final AppPushBridge? push;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  @override
  State<OurSpaceApp> createState() => _OurSpaceAppState();
}

class _OurSpaceAppState extends State<OurSpaceApp> {
  String? _registeredPushToken;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_syncPushRegistration);
    widget.auth.restore().whenComplete(() {
      _syncPushRegistration();
      if (!widget.auth.isAuthenticated) {
        const AnniversaryNotifications().clear();
      }
    });
  }

  @override
  void dispose() {
    widget.auth.removeListener(_syncPushRegistration);
    widget.push?.dispose();
    super.dispose();
  }

  /// Đăng ký thiết bị khi có phiên và gỡ khi đăng xuất.
  void _syncPushRegistration() {
    final token = widget.auth.token;
    if (token == _registeredPushToken) return;
    final previous = _registeredPushToken;
    _registeredPushToken = token;
    if (previous != null) {
      const AnniversaryNotifications().clear();
      widget.push?.deactivate(previous);
      IosWidgetBridge.clear();
      if (token == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !widget.auth.isAuthenticated) {
            _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
        });
      }
    }
    if (token != null) widget.push?.activate(token);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    scaffoldMessengerKey: widget.messengerKey,
    title: 'OurSpace',
    debugShowCheckedModeBanner: false,
    theme: ourSpaceTheme,
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: AppRouter(
      auth: widget.auth,
      couples: widget.couples,
      photos: widget.photos,
      albums: widget.albums,
      timeline: widget.timeline,
      calendar: widget.calendar,
    ),
  );
}
