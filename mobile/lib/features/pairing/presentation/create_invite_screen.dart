import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/error/app_exception.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../auth/auth_provider.dart';
import '../domain/invite.dart';

class CreateInviteScreen extends ConsumerStatefulWidget {
  const CreateInviteScreen({super.key});

  @override
  ConsumerState<CreateInviteScreen> createState() => _CreateInviteScreenState();
}

class _CreateInviteScreenState extends ConsumerState<CreateInviteScreen> {
  InviteCode? _invite;
  String? _error;
  bool _loading = false;
  Timer? _countdownTimer;
  Duration? _remaining;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _createInvite() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(coupleRepositoryProvider);
      final invite = await repo.createInvite();
      setState(() => _invite = invite);
      _startCountdown(invite.expiresAt);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Không thể tạo mã. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer?.cancel();
    _updateRemaining(expiresAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      _updateRemaining(expiresAt);
    });
  }

  void _updateRemaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _invite = null;
          _error = 'Mã mời đã hết hạn.';
        });
      }
      return;
    }
    if (mounted) setState(() => _remaining = remaining);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _copyCode() async {
    if (_invite == null) return;
    await Clipboard.setData(ClipboardData(text: _invite!.inviteCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã copy mã mời!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Tạo mã mời'),
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
                if (_invite == null && !_loading) ...[
                  _buildCreateSection(context),
                ] else if (_loading) ...[
                  const Center(child: CircularProgressIndicator()),
                ] else if (_invite != null) ...[
                  _buildInviteDisplay(context),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.link, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Ghép đôi với người yêu',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo mã mời và chia sẻ với người ấy để bắt đầu.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createInvite,
              icon: const Icon(Icons.add),
              label: const Text('Tạo mã mời'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteDisplay(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mã mời của bạn',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_remaining != null)
              Text(
                'Hết hạn sau ${_formatDuration(_remaining!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _remaining!.inMinutes < 2
                          ? Theme.of(context).colorScheme.error
                          : Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _invite!.inviteCode,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _createInvite,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tạo mới'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Chia sẻ mã này với người ấy để ghép đôi.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
