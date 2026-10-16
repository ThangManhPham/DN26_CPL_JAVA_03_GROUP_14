// TODO(M1): Thay bằng Home screen thực tế (sau khi ghép đôi sẽ sang CoupleHome).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../auth_provider.dart';
import '../domain/user_profile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Row(
                  children: [
                    const Expanded(child: _BrandMark()),
                    IconButton(
                      tooltip: 'Mở hồ sơ',
                      onPressed: () => context.push(AppRoutes.profile),
                      icon: const Icon(Icons.person_outline),
                    ),
                    IconButton(
                      tooltip: 'Đăng xuất',
                      onPressed: () =>
                          ref.read(authStateProvider.notifier).logout(),
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Chào ${user?.displayName ?? 'bạn'}!',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ghép đôi với người yêu',
                          style:
                              Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tạo mã mời hoặc nhập mã để kết nối.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.createInvite),
                          icon: const Icon(Icons.add_link),
                          label: const Text('Tạo mã mời'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.joinInvite),
                          icon: const Icon(Icons.link),
                          label: const Text('Nhập mã mời'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'OurSpace',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      );
}
