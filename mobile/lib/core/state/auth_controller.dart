import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_models.dart';
import '../../features/auth/data/auth_repository.dart';
import '../network/api_exception.dart';
import '../storage/token_storage.dart';

/// Trạng thái xác thực dùng chung cho toàn app: đăng nhập, đăng xuất và
/// khôi phục phiên từ token đã lưu khi mở lại app (S1-07).
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required TokenStorage storage,
    this.onTokenChanged,
  }) : _repository = repository,
       _storage = storage;

  final AuthRepository _repository;
  final TokenStorage _storage;

  /// Đồng bộ token sang `ApiClient` để interceptor gắn Bearer cho mọi request.
  final void Function(String? token)? onTokenChanged;

  AuthSession? _session;
  bool _restoring = true;

  AuthSession? get session => _session;
  UserProfile? get user => _session?.user;
  String? get token => _session?.token;
  bool get isAuthenticated => _session != null;
  bool get isRestoring => _restoring;

  /// Khôi phục phiên khi mở app. Token hết hạn -> xóa token và về Login.
  Future<void> restore() async {
    _restoring = true;
    notifyListeners();
    final stored = await _storage.read();
    if (stored != null && stored.isNotEmpty) {
      _setToken(stored);
      try {
        final user = await _repository.getProfile(stored);
        _session = AuthSession(token: stored, user: user);
      } on ApiException catch (error) {
        if (error.isSessionExpired) {
          await _clearSession();
        } else {
          // Không xác minh được phiên (mạng lỗi): không giữ phiên nửa vời.
          await _clearSession();
        }
      } catch (_) {
        await _clearSession();
      }
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final session = await _repository.login(email, password);
    await _persist(session);
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    final session = await _repository.register(email, password, displayName);
    await _persist(session);
  }

  Future<void> updateDisplayName(String displayName) async {
    final current = _session;
    if (current == null) return;
    final user = await _repository.updateProfile(current.token, displayName);
    _session = current.withUser(user);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final current = _session;
    if (current == null) return;
    final user = await _repository.getProfile(current.token);
    _session = current.withUser(user);
    notifyListeners();
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  /// Gọi từ interceptor khi server trả 401: xóa phiên ngay lập tức.
  void forceLogout() {
    if (_session == null) return;
    _session = null;
    _setToken(null);
    unawaited(_storage.clear());
    notifyListeners();
  }

  Future<void> _persist(AuthSession session) async {
    await _storage.write(session.token);
    _setToken(session.token);
    _session = session;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _session = null;
    _setToken(null);
    await _storage.clear();
  }

  void _setToken(String? token) => onTokenChanged?.call(token);
}
