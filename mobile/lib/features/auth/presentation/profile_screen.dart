import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import 'validators.dart';

/// Màn hồ sơ cá nhân: xem/sửa tên hiển thị, đăng xuất (S1-07).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final String _originalName;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.auth.user?.displayName ?? '');
    _originalName = _name.text;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await widget.auth.refreshProfile();
      if (!mounted) return;
      final latest = widget.auth.user?.displayName;
      // Chỉ ghi đè khi người dùng chưa sửa ô nhập.
      if (latest != null && _name.text == _originalName) _name.text = latest;
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải hồ sơ mới nhất.');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.updateDisplayName(_name.text.trim());
      if (mounted) Navigator.of(context).maybePop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể lưu hồ sơ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    await widget.auth.logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: user == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: AppColors.softRose,
                        child: Text(
                          user.displayName.isEmpty
                              ? '?'
                              : user.displayName.characters.first
                                    .toUpperCase(),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: AppColors.rose),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Thông tin cá nhân',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tên này sẽ hiển thị trong không gian chung của hai bạn.',
                      ),
                      const SizedBox(height: 28),
                      Form(
                        key: _form,
                        child: TextFormField(
                          key: const Key('profileNameField'),
                          controller: _name,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Tên hiển thị',
                          ),
                          validator: validateDisplayName,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        initialValue: user.email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          helperText: 'Email hiện chưa thể thay đổi',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            key: const Key('profileError'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        key: const Key('saveProfile'),
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Lưu thay đổi'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        key: const Key('logoutButton'),
                        onPressed: _busy ? null : _logout,
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
