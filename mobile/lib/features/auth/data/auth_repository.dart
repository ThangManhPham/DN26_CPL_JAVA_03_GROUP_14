import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'auth_models.dart';

/// Contract auth/profile (docs/05-api-contract.md §5.2).
abstract class AuthRepository {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  );
  Future<UserProfile> getProfile(String token);
  Future<UserProfile> updateProfile(String token, String displayName);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<AuthSession> login(String email, String password) async {
    final data = await _client.postJson(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession(
      token: data['accessToken'] as String,
      user: UserProfile.fromJson(_asMap(data['user'])),
    );
  }

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  ) async {
    await _client.postJson(
      '/api/v1/auth/register',
      body: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
    // Contract đăng ký chưa trả token nên client đăng nhập ngay sau đó.
    return login(email, password);
  }

  @override
  Future<UserProfile> getProfile(String token) async => UserProfile.fromJson(
    await _client.getJson(
      '/api/v1/users/me',
      headers: ApiClient.bearer(token),
    ),
  );

  @override
  Future<UserProfile> updateProfile(String token, String displayName) async =>
      UserProfile.fromJson(
        await _client.patchJson(
          '/api/v1/users/me',
          body: {'displayName': displayName},
          headers: ApiClient.bearer(token),
        ),
      );

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
}

/// Mock theo đúng JSON shape của contract, có độ trễ và case lỗi.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 350)});

  final Duration latency;

  /// Dùng static để chia sẻ tài khoản giữa các instance (logout/login).
  static final Map<String, ({String password, UserProfile user})> _users = {};
  static int _sequence = 0;

  /// Xóa toàn bộ dữ liệu mock (dùng cho test).
  static void clear() {
    _users.clear();
    _sequence = 0;
  }

  /// Nạp sẵn tài khoản demo để test/demo hai tài khoản A/B.
  void seed({required String email, required String password, required String displayName}) {
    final user = UserProfile(
      id: 'mock-${++_sequence}',
      email: email.toLowerCase(),
      displayName: displayName,
    );
    _users[user.email] = (password: password, user: user);
  }

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  ) async {
    await Future<void>.delayed(latency);
    final key = email.toLowerCase();
    if (_users.containsKey(key)) {
      throw const ApiException(
        statusCode: 409,
        code: 'EMAIL_ALREADY_EXISTS',
        message: 'Email is already registered.',
      );
    }
    final user = UserProfile(
      id: 'mock-${++_sequence}',
      email: key,
      displayName: displayName,
    );
    _users[key] = (password: password, user: user);
    return AuthSession(token: _tokenFor(user.id), user: user);
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    await Future<void>.delayed(latency);
    final account = _users[email.toLowerCase()];
    if (account == null || account.password != password) {
      throw const ApiException(
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Email or password is incorrect.',
      );
    }
    return AuthSession(
      token: _tokenFor(account.user.id),
      user: account.user,
    );
  }

  @override
  Future<UserProfile> getProfile(String token) async {
    await Future<void>.delayed(latency);
    for (final entry in _users.values) {
      if (_tokenFor(entry.user.id) == token) return entry.user;
    }
    throw const ApiException(
      statusCode: 401,
      code: 'UNAUTHORIZED',
      message: 'Account is no longer available.',
    );
  }

  @override
  Future<UserProfile> updateProfile(String token, String displayName) async {
    await Future<void>.delayed(latency);
    for (final entry in _users.entries) {
      if (_tokenFor(entry.value.user.id) != token) continue;
      final updated = UserProfile(
        id: entry.value.user.id,
        email: entry.value.user.email,
        displayName: displayName,
      );
      _users[entry.key] = (password: entry.value.password, user: updated);
      return updated;
    }
    throw const ApiException(
      statusCode: 401,
      code: 'UNAUTHORIZED',
      message: 'Account is no longer available.',
    );
  }

  String _tokenFor(String userId) => 'mock-token-$userId';
}
