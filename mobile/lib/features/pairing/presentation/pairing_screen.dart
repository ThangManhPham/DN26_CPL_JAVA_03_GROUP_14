import 'package:flutter/material.dart';

import '../../../core/state/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../auth/presentation/profile_screen.dart';
import 'invite_create_screen.dart';
import 'invite_join_screen.dart';
import 'pairing_controller.dart';

/// Màn Pairing: điểm vào của hai luồng tạo mã mời và nhập mã mời (S1-08).
class PairingScreen extends StatelessWidget {
  const PairingScreen({
    super.key,
    required this.auth,
    required this.controller,
  });

  final AuthController auth;
  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final displayName = auth.user?.displayName ?? 'bạn';
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
                    const Expanded(child: BrandMark()),
                    IconButton(
                      key: const Key('openProfile'),
                      tooltip: 'Mở hồ sơ',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileScreen(auth: auth),
                        ),
                      ),
                      icon: const Icon(Icons.person_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'Chào $displayName,',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Kết nối với người ấy để mở không gian chỉ hai bạn nhìn thấy.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.softRose,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.favorite_outline,
                        size: 40,
                        color: AppColors.rose,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Hai cách để ghép đôi',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tạo một mã mời rồi gửi cho người ấy, hoặc nhập mã mà '
                        'người ấy gửi cho bạn. Mỗi mã chỉ dùng được một lần.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const Key('createInviteEntry'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => InviteCreateScreen(controller: controller),
                    ),
                  ),
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Tạo mã mời'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('joinInviteEntry'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => InviteJoinScreen(controller: controller),
                    ),
                  ),
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Nhập mã mời'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  key: const Key('pairingLogout'),
                  onPressed: () => auth.logout(),
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
