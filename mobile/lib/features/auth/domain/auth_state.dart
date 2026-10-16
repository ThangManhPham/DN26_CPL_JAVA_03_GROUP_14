import 'user_profile.dart';

/// Auth state dùng cho toàn app (Riverpod).
sealed class AuthState {}

class UnauthenticatedAuthState extends AuthState {
  const UnauthenticatedAuthState();
}

class LoadingAuthState extends AuthState {
  const LoadingAuthState();
}

class AuthenticatedAuthState extends AuthState {
  const AuthenticatedAuthState({
    required this.user,
    this.couple,
  });

  final UserProfile user;
  final CoupleInfo? couple;

  AuthenticatedAuthState copyWith({
    UserProfile? user,
    CoupleInfo? couple,
    bool clearCouple = false,
  }) =>
      AuthenticatedAuthState(
        user: user ?? this.user,
        couple: clearCouple ? null : (couple ?? this.couple),
      );
}
