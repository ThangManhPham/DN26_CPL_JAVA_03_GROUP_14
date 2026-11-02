import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu token phiên đăng nhập.
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// iOS: Keychain. Web: `flutter_secure_storage` không phải lúc nào cũng sẵn
/// sàng, nên mọi lỗi nền tảng được fallback sang bộ nhớ trong phiên thay vì
/// làm hỏng luồng đăng nhập.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _key = 'ourspace.accessToken';

  final FlutterSecureStorage _storage;
  final InMemoryTokenStorage _fallback = InMemoryTokenStorage();
  bool _storageUnavailable = false;

  @override
  Future<String?> read() async {
    if (_storageUnavailable) return _fallback.read();
    try {
      return await _storage.read(key: _key) ?? await _fallback.read();
    } catch (_) {
      _storageUnavailable = true;
      return _fallback.read();
    }
  }

  @override
  Future<void> write(String token) async {
    await _fallback.write(token);
    if (_storageUnavailable) return;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      _storageUnavailable = true;
    }
  }

  @override
  Future<void> clear() async {
    await _fallback.clear();
    if (_storageUnavailable) return;
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      _storageUnavailable = true;
    }
  }
}

/// Dùng cho test và làm fallback cho web.
class InMemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
