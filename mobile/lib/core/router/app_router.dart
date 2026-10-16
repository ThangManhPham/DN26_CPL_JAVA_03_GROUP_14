import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/home_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/pairing/presentation/create_invite_screen.dart';
import '../../features/pairing/presentation/join_invite_screen.dart';
import '../../features/pairing/presentation/couple_home_screen.dart';
import '../../features/auth/auth_provider.dart';

/// Route paths
abstract final class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String pairing = '/pairing';
  static const String createInvite = '/pairing/create';
  static const String joinInvite = '/pairing/join';
  static const String coupleHome = '/couple-home';
}

/// go_router configuration với route guard.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final hasCouple = (authState.valueOrNull as AuthenticatedAuthState?)
              ?.couple !=
          null;
      final currentPath = state.matchedLocation;

      // Already logged in → redirect based on couple status
      if (isLoggedIn && currentPath == AppRoutes.login) {
        return hasCouple ? AppRoutes.coupleHome : AppRoutes.home;
      }

      // Not logged in → go to login
      if (!isLoggedIn && currentPath != AppRoutes.login) {
        return AppRoutes.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.createInvite,
        builder: (context, state) => const CreateInviteScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinInvite,
        builder: (context, state) => const JoinInviteScreen(),
      ),
      GoRoute(
        path: AppRoutes.coupleHome,
        builder: (context, state) => const CoupleHomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Trang không tìm thấy: ${state.matchedLocation}'),
      ),
    ),
  );
});
