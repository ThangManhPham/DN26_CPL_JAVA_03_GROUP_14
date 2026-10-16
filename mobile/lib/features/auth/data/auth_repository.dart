import '../domain/user_profile.dart';

/// Abstract repository cho auth — M1 sẽ gọi các method này cho Login/Register.
abstract class AuthRepository {
  Future<({String token, UserProfile user})> login(
    String email,
    String password,
  );

  Future<({String token, UserProfile user})> register(
    String email,
    String password,
    String displayName,
  );

  Future<UserProfile> getProfile(String token);
}
