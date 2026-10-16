import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/router/app_router.dart';
import '../../../core/network/dio_client.dart';
import '../../domain/auth_state.dart';
import '../../domain/user_profile.dart';
import '../../data/auth_repository.dart';
import '../../data/http_auth_repository.dart';
import '../../data/mock_auth_repository.dart';
import '../../pairing/data/couple_repository.dart';
import '../../pairing/data/mock_couple_repository.dart';
import '../../pairing/data/http_couple_repository.dart';

// ---------------------------------------------------------------------------
// Core service providers
// ---------------------------------------------------------------------------

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return DioClient(
    baseUrl: AppConfig.apiBaseUrl,
    storage: storage,
  );
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(dioClientProvider).dio;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useMock) {
    return MockAuthRepository(storage: ref.watch(secureStorageProvider));
  }
  return HttpAuthRepository(
    client: ref.watch(dioClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  if (AppConfig.useMock) {
    return MockCoupleRepository(storage: ref.watch(secureStorageProvider));
  }
  return HttpCoupleRepository(
    client: ref.watch(dioClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

// ---------------------------------------------------------------------------
// Auth state notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required AuthRepository repository,
    required SecureStorageService storage,
    required Ref ref,
  })  : _repository = repository,
        _storage = storage,
        _ref = ref,
        super(const LoadingAuthState()) {
    // Register callback so 401 interceptor triggers state → Unauthenticated.
    _storage.onTokenCleared = () {
      state = const UnauthenticatedAuthState();
    };
    _restoreSession();
  }

  final AuthRepository _repository;
  final SecureStorageService _storage;
  final Ref _ref;

  Future<void> _restoreSession() async {
    final token = await _storage.getToken();
    if (token != null) {
      // TODO(M1): gọi getProfile để xác nhận token còn valid
      // Hiện tại coi như còn valid, M1 sẽ cập nhật
      state = const UnauthenticatedAuthState();
    } else {
      state = const UnauthenticatedAuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = const LoadingAuthState();
    try {
      final result = await _repository.login(email, password);
      state = AuthenticatedAuthState(user: result.user);
    } on AppException catch (e) {
      state = const UnauthenticatedAuthState();
      rethrow;
    } catch (_) {
      state = const UnauthenticatedAuthState();
      rethrow;
    }
  }

  Future<void> register(
      String email, String password, String displayName) async {
    state = const LoadingAuthState();
    try {
      final result = await _repository.register(email, password, displayName);
      state = AuthenticatedAuthState(user: result.user);
    } on AppException catch (e) {
      state = const UnauthenticatedAuthState();
      rethrow;
    } catch (_) {
      state = const UnauthenticatedAuthState();
      rethrow;
    }
  }

  void setCouple(CoupleInfo couple) {
    final current = state;
    if (current is AuthenticatedAuthState) {
      state = current.copyWith(couple: couple);
    }
  }

  void clearCouple() {
    final current = state;
    if (current is AuthenticatedAuthState) {
      state = current.copyWith(clearCouple: true);
    }
  }

  Future<void> logout() async {
    await _storage.deleteToken();
    state = const UnauthenticatedAuthState();
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
    storage: ref.watch(secureStorageProvider),
    ref: ref,
  );
});

// ---------------------------------------------------------------------------
// Auth session helpers — expose UserProfile/CoupleInfo for easy access
// ---------------------------------------------------------------------------

final currentUserProvider = Provider<UserProfile?>((ref) {
  final state = ref.watch(authStateProvider);
  return state is AuthenticatedAuthState ? state.user : null;
});

final currentCoupleProvider = Provider<CoupleInfo?>((ref) {
  final state = ref.watch(authStateProvider);
  return state is AuthenticatedAuthState ? state.couple : null;
});
