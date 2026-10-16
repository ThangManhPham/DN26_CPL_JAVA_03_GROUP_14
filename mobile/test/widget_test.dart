// Widget tests cho auth UI sẽ được M1 viết sau khi thay placeholder bằng UI thực.
// Hiện tại architecture đã thay đổi (go_router + Riverpod).

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/auth_state.dart';
import 'package:mobile/features/auth/domain/user_profile.dart';

void main() {
  group('AuthState sealed class', () {
    test('AuthenticatedAuthState contains user and optional couple', () {
      const user = UserProfile(
        id: 'user-1',
        email: 'alex@example.com',
        displayName: 'Alex',
      );

      final state = AuthenticatedAuthState(user: user);
      expect(state.user, user);
      expect(state.couple, isNull);

      final couple = CoupleInfo(
        id: 'couple-1',
        status: 'ACTIVE',
        members: [
          CoupleMember(id: 'user-1', displayName: 'Alex'),
          CoupleMember(id: 'user-2', displayName: 'Sam'),
        ],
      );
      final stateWithCouple = AuthenticatedAuthState(
        user: user,
        couple: couple,
      );
      expect(stateWithCouple.couple, couple);
    });

    test('copyWith replaces user correctly', () {
      const user = UserProfile(
        id: 'user-1',
        email: 'alex@example.com',
        displayName: 'Alex',
      );
      const updatedUser = UserProfile(
        id: 'user-1',
        email: 'alex@example.com',
        displayName: 'Sam',
      );
      final state = AuthenticatedAuthState(user: user);

      final updated = state.copyWith(user: updatedUser);
      expect(updated.user.displayName, 'Sam');
      expect(updated.user.id, user.id);
    });

    test('UnauthenticatedAuthState equality', () {
      const state1 = UnauthenticatedAuthState();
      const state2 = UnauthenticatedAuthState();
      expect(state1, equals(state2));
    });

    test('LoadingAuthState equality', () {
      const state1 = LoadingAuthState();
      const state2 = LoadingAuthState();
      expect(state1, equals(state2));
    });
  });

  group('UserProfile', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'avatarUrl': 'https://example.com/avatar.png',
      };
      final user = UserProfile.fromJson(json);
      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('toJson roundtrips correctly', () {
      const user = UserProfile(
        id: 'user-1',
        email: 'alex@example.com',
        displayName: 'Alex',
      );
      final roundtrip = UserProfile.fromJson(user.toJson());
      expect(roundtrip.id, user.id);
      expect(roundtrip.email, user.email);
      expect(roundtrip.displayName, user.displayName);
    });
  });
}
