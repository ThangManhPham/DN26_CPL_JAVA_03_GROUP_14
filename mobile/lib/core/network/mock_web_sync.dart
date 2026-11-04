import 'dart:convert';
import 'mock_web_sync_stub.dart'
    if (dart.library.js_interop) 'mock_web_sync_web.dart' as platform;

/// Tiện ích đồng bộ dữ liệu mock qua LocalStorage trên Web.
/// Giúp test pairing và timeline giữa 2 tab trình duyệt.
class MockWebSync {
  static void save(String key, dynamic value) {
    platform.saveToLocalStorage(key, jsonEncode(value));
  }

  static dynamic load(String key) {
    final data = platform.loadFromLocalStorage(key);
    if (data == null) return null;
    try {
      return jsonDecode(data);
    } catch (_) {
      return null;
    }
  }
}
