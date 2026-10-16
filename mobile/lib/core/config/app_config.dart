/// Cấu hình ứng dụng được inject qua dart-define.
/// Ví dụ: flutter run --dart-define=OURSPACE_USE_MOCK=true
class AppConfig {
  const AppConfig._();

  /// true: dùng mock repository thay vì gọi API thật.
  static const bool useMock =
      bool.fromEnvironment('OURSPACE_USE_MOCK', defaultValue: true);

  /// Base URL của backend API.
  /// Mặc định Android emulator: 10.0.2.2:8080, iOS simulator: localhost:8080.
  static const String apiBaseUrl = String.fromEnvironment(
    'OURSPACE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Thời gian chờ request mặc định (giây).
  static const int connectTimeout = 10;
  static const int receiveTimeout = 10;
}
