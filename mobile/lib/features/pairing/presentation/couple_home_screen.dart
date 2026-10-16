import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../auth/auth_provider.dart';
import '../../auth/domain/user_profile.dart';

class CoupleHomeScreen extends ConsumerWidget {
  const CoupleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final couple = authState is AuthenticatedAuthState
        ? authState.couple
        : null;
    final currentUser = authState is AuthenticatedAuthState
        ? authState.user
        : null;

    if (couple == null) {
      // No couple yet — redirect to pairing
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chưa có thông tin cặp đôi.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Ghép đôi ngay'),
              ),
            ],
          ),
        ),
      );
    }

    final partner = couple.members.firstWhere(
      (m) => m.id != currentUser?.id,
      orElse: () => couple.members.first,
    );
    final partnerName = partner.displayName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _showUnpairDialog(context, ref),
          tooltip: 'Hủy ghép đôi',
        ),
        title: const Text('OurSpace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.profile),
            tooltip: 'Hồ sơ',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const BrandMark(),
                const SizedBox(height: 32),
                _CoupleAvatars(couple: couple, currentUser: currentUser),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Bạn & $partnerName',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (couple.anniversaryDate != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: _AnniversaryDisplay(date: couple.anniversaryDate!),
                  ),
                ],
                const SizedBox(height: 32),
                _buildCoupleCard(context, couple),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showUnpairDialog(context, ref),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Hủy ghép đôi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoupleCard(BuildContext context, CoupleInfo couple) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Không gian của hai bạn',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Những kỷ niệm và khoảnh khắc của hai bạn sẽ xuất hiện ở đây.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  void _showUnpairDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy ghép đôi?'),
        content: const Text(
          'Bạn và người ấy sẽ không còn là cặp đôi nữa. Hành động này có thể làm mất một số dữ liệu chung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _unpair(context, ref);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hủy ghép đôi'),
          ),
        ],
      ),
    );
  }

  Future<void> _unpair(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(coupleRepositoryProvider);
      await repo.unpair();
      ref.read(authStateProvider.notifier).clearCouple();
      if (context.mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể hủy ghép đôi: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _CoupleAvatars extends StatelessWidget {
  const _CoupleAvatars({required this.couple, required this.currentUser});

  final CoupleInfo couple;
  final UserProfile? currentUser;

  @override
  Widget build(BuildContext context) {
    final member1 = couple.members[0];
    final member2 = couple.members.length > 1 ? couple.members[1] : null;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(name: member1.displayName, isCurrentUser: member1.id == currentUser?.id),
          if (member2 != null) ...[
            const SizedBox(width: 12),
            Stack(
              children: [
                _Avatar(name: member2.displayName, isCurrentUser: member2.id == currentUser?.id),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.isCurrentUser});

  final String name;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 36,
      backgroundColor: isCurrentUser
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      child: Text(
        name.substring(0, 1).toUpperCase(),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: isCurrentUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
            ),
      ),
    );
  }
}

class _AnniversaryDisplay extends StatelessWidget {
  const _AnniversaryDisplay({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = now.year - date.year;
    final isToday = date.month == now.month && date.day == now.day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isToday
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cake,
            size: 16,
            color: isToday
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isToday
                ? '🎉 Kỷ niệm $years năm hôm nay!'
                : 'Kỷ niệm $years năm (${_formatDate(date)})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  fontWeight: isToday ? FontWeight.bold : null,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}
