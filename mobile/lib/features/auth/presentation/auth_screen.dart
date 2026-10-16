// TODO(M1): Thay bằng Login/Register UI thực tế theo Figma.
// Screen này là placeholder tạm thời để routing hoạt động.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/error/app_exception.dart';
import '../auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await ref.read(authStateProvider.notifier).register(
              _email.text.trim(),
              _password.text,
              _name.text.trim(),
            );
      } else {
        await ref.read(authStateProvider.notifier).login(
              _email.text.trim(),
              _password.text,
            );
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể kết nối. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              children: [
                const _BrandMark(),
                const SizedBox(height: 46),
                Text(
                  _register ? 'Tạo không gian\ncho hai người.' : 'Chào mừng\ntrở lại.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  _register
                      ? 'Bắt đầu lưu những khoảnh khắc chỉ hai bạn nhìn thấy.'
                      : 'Những điều thân thuộc đang đợi bạn ở đây.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Đăng nhập')),
                    ButtonSegment(value: true, label: Text('Đăng ký')),
                  ],
                  selected: {_register},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    if (_busy) return;
                    setState(() {
                      _register = value.first;
                      _error = null;
                      _form.currentState?.reset();
                      _password.clear();
                    });
                  },
                ),
                const SizedBox(height: 28),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Tên hiển thị',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Vui lòng nhập tên'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Email không hợp lệ'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Mật khẩu ít nhất 6 ký tự'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _register ? 'Tạo tài khoản' : 'Đăng nhập'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                const Center(
                    child: Text('Một nơi riêng cho những điều chung.')),
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
