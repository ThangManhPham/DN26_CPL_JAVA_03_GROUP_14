import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/share_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_states.dart';
import '../data/pairing_models.dart';
import 'pairing_controller.dart';

/// Màn tạo mã mời: sinh mã, hiện thời hạn, cho phép sao chép/chia sẻ (S1-08).
class InviteCreateScreen extends StatefulWidget {
  const InviteCreateScreen({super.key, required this.controller});

  final PairingController controller;

  @override
  State<InviteCreateScreen> createState() => _InviteCreateScreenState();
}

class _InviteCreateScreenState extends State<InviteCreateScreen> {
  CoupleInvite? _invite;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final invite = await widget.controller.createInvite();
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.userMessage;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tạo mã mời. Vui lòng thử lại.';
        _busy = false;
      });
    }
  }

  Future<void> _copy(String code) async {
    await copyText(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép mã mời.')),
    );
  }

  Future<void> _share(String code) async {
    final shared = await shareText(
      'Ghép đôi với mình trên OurSpace bằng mã $code nhé!',
      subject: 'Mã mời OurSpace',
    );
    if (shared || !mounted) return;
    // Nền tảng không hỗ trợ share sheet -> sao chép để người dùng dán tay.
    await copyText(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thiết bị không hỗ trợ chia sẻ. Đã sao chép mã mời.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return Scaffold(
      appBar: AppBar(title: const Text('Mã mời của bạn')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: switch ((invite, _busy)) {
              (null, true) => const LoadingStateView(message: 'Đang tạo mã mời…'),
              (null, false) => ErrorStateView(
                message: _error ?? 'Không thể tạo mã mời. Vui lòng thử lại.',
                onRetry: _generate,
              ),
              _ => _InviteBody(
                invite: invite!,
                busy: _busy,
                error: _error,
                onCopy: () => _copy(invite.inviteCode),
                onShare: () => _share(invite.inviteCode),
                onRegenerate: _generate,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _InviteBody extends StatelessWidget {
  const _InviteBody({
    required this.invite,
    required this.busy,
    required this.error,
    required this.onCopy,
    required this.onShare,
    required this.onRegenerate,
  });

  final CoupleInvite invite;
  final bool busy;
  final String? error;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Gửi mã này cho người ấy',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text('Mã chỉ dùng được một lần và sẽ hết hạn sau 24 giờ.'),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.softRose,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Text(
              invite.inviteCode,
              key: const Key('inviteCode'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                letterSpacing: 8,
                color: AppColors.rose,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hết hạn lúc ${formatLocalDateTime(invite.expiresAt)} (giờ địa phương)',
              key: const Key('inviteExpiry'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            key: const Key('inviteCreateError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
      const SizedBox(height: 28),
      FilledButton.icon(
        key: const Key('copyInviteCode'),
        onPressed: busy ? null : onCopy,
        icon: const Icon(Icons.copy_all_outlined),
        label: const Text('Sao chép mã'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('shareInviteCode'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: busy ? null : onShare,
        icon: const Icon(Icons.ios_share),
        label: const Text('Chia sẻ mã'),
      ),
      const SizedBox(height: 20),
      TextButton(
        key: const Key('regenerateInvite'),
        onPressed: busy ? null : onRegenerate,
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Tạo mã mới'),
      ),
    ],
  );
}
