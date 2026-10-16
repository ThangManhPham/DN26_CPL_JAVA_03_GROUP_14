// TODO(M1): Thay bằng Profile screen thực tế (edit displayName, avatar, logout).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Hồ sơ'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user?.displayName.substring(0, 1).toUpperCase() ?? '?',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user?.displayName ?? 'Unknown',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),
              const SizedBox(height: 32),
              // Placeholder — M1 will implement edit form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chỉnh sửa hồ sơ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tính năng sửa hồ sơ sẽ được M1 triển khai.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
