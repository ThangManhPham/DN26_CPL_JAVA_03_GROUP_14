/// Cấu hình runtime của app, lấy từ `--dart-define` để không hardcode
/// secret/URL trong source.
abstract final class AppConfig {
  /// Bật mock: `--dart-define=USE_MOCK=true`.
  /// `OURSPACE_USE_MOCK` vẫn được chấp nhận để tương thích tài liệu của M1/M5.
  static const bool useMock =
      bool.fromEnvironment('USE_MOCK') ||
      bool.fromEnvironment('OURSPACE_USE_MOCK');

  static const String _configuredBaseUrl = String.fromEnvironment(
    'OURSPACE_API_BASE_URL',
  );

  /// Base URL backend. iOS Simulator dùng `http://localhost:8080` mặc định;
  /// máy thật/HTTPS phải truyền `OURSPACE_API_BASE_URL`.
  static String get baseUrl =>
      _configuredBaseUrl.isNotEmpty ? _configuredBaseUrl : 'http://localhost:8080';
}
