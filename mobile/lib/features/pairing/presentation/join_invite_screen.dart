import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../auth/auth_provider.dart';
import '../../auth/domain/user_profile.dart';

class JoinInviteScreen extends ConsumerStatefulWidget {
  const JoinInviteScreen({super.key});

  @override
  ConsumerState<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends ConsumerState<JoinInviteScreen> {
  final _form = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(coupleRepositoryProvider);
      final couple = await repo.joinWithCode(_codeController.text.trim());

      // Update AuthNotifier with couple info
      ref.read(authStateProvider.notifier).setCouple(couple);

      if (mounted) {
        context.go('/couple-home');
      }
    } on InviteExpiredException {
      if (mounted) {
        setState(() => _error = 'Mã mời đã hết hạn. Vui lòng yêu cầu mã mới.');
      }
    } on InviteCodeUsedException {
      if (mounted) {
        setState(() => _error = 'Mã mời đã được sử dụng. Vui lòng yêu cầu mã mới.');
      }
    } on InviteCodeInvalidException {
      if (mounted) {
        setState(() => _error = 'Mã mời không hợp lệ. Vui lòng kiểm tra lại.');
      }
    } on SelfPairingException {
      if (mounted) {
        setState(() => _error = 'Bạn không thể ghép đôi với chính mình.');
      }
    } on AlreadyCoupledException {
      if (mounted) {
        setState(() => _error = 'Tài khoản đã thuộc một cặp đôi khác.');
      }
    } on UnauthenticatedException {
      if (mounted) {
        context.go('/login');
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể kết nối. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
        title: const Text('Nhập mã mời'),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.link_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nhập mã mời',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhập mã 6 ký tự mà người ấy đã chia sẻ.',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _codeController,
                            enabled: !_loading,
                            textCapitalization:
                                TextCapitalization.characters,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(letterSpacing: 8),
                            maxLength: 6,
                            decoration: const InputDecoration(
                              hintText: '------',
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập mã mời';
                              }
                              if (value.trim().length < 6) {
                                return 'Mã mời gồm 6 ký tự';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _join(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading ? null : _join,
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Xác nhận ghép đôi'),
                          ),
                        ],
                      ),
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
