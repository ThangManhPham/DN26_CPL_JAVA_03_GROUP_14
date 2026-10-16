import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'features/auth/auth_provider.dart';
import 'theme.dart';

void main() => runApp(
  const ProviderScope(
    child: OurSpaceApp(),
  ),
);

class OurSpaceApp extends ConsumerStatefulWidget {
  const OurSpaceApp({super.key});

  @override
  ConsumerState<OurSpaceApp> createState() => _OurSpaceAppState();
}

class _OurSpaceAppState extends ConsumerState<OurSpaceApp> {
  @override
  void initState() {
    super.initState();
    // Listen to auth state changes: on 401 (token expired), go to /login.
    ref.listen<AuthState>(authStateProvider, (_, state) {
      if (state is UnauthenticatedAuthState) {
        // Delay to avoid navigating during router redirect cycle.
        Future.microtask(
          () => ref.read(appRouterProvider).go('/login'),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OurSpace',
      debugShowCheckedModeBanner: false,
      theme: ourSpaceTheme,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
