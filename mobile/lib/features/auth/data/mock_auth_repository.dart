import '../../../core/storage/secure_storage.dart';
import '../../../core/error/app_exception.dart';
import '../../domain/user_profile.dart';
import 'auth_repository.dart';

/// Mock implementation của AuthRepository — dùng khi OURSPACE_USE_MOCK=true.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;
  final Map<String, ({String password, UserProfile user})> _users = {};
  int _id = 0;

  @override
  Future<({String token, UserProfile user})> login(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final record = _users[email.toLowerCase()];
    if (record == null || record.password != password) {
      throw const AppException(
        message: 'Email hoặc mật khẩu không đúng.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    const token = 'mock-token';
    await _storage.saveToken(token);
    return (token: token, user: record.user);
  }

  @override
  Future<({String token, UserProfile user})> register(
    String email,
    String password,
    String displayName,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final key = email.toLowerCase();
    if (_users.containsKey(key)) {
      throw const AppException(
        message: 'Email này đã được sử dụng.',
        code: 'EMAIL_ALREADY_EXISTS',
      );
    }
    final user = UserProfile(
      id: 'mock-${++_id}',
      email: key,
      displayName: displayName,
    );
    _users[key] = (password: password, user: user);
    const token = 'mock-token';
    await _storage.saveToken(token);
    return (token: token, user: user);
  }

  @override
  Future<UserProfile> getProfile(String token) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // In mock, we don't track token→user mapping, so this is a no-op stub.
    throw const AppException(
      message: 'Mock getProfile not implemented — use stored session.',
    );
  }
}
