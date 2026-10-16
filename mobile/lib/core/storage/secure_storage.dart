import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper an toàn cho flutter_secure_storage, dùng lưu token.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyAccessToken = 'access_token';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyAccessToken);
  }

  Future<bool> hasToken() async {
    return await getToken() != null;
  }
}
