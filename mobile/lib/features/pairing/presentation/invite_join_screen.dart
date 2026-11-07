import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/validators.dart';
import 'pairing_controller.dart';

/// Màn nhập mã mời (S1-08). Mọi lỗi nghiệp vụ của backend được hiển thị
/// nguyên văn theo `code`: mã sai, mã hết hạn, mã đã dùng, tự ghép với chính
/// mình, người gửi mã đã có cặp đôi.
class InviteJoinScreen extends StatefulWidget {
  const InviteJoinScreen({super.key, required this.controller});

  final PairingController controller;

  @override
  State<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends State<InviteJoinScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
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
      await widget.controller.join(_code.text.trim().toUpperCase());
      if (!mounted) return;
      // Ghép đôi thành công: router đã chuyển sang Couple Home, chỉ cần đóng
      // các màn Pairing đang mở.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể ghép đôi. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhập mã mời')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Nhập mã người ấy gửi',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Mã gồm 6 ký tự chữ và số, không phân biệt chữ hoa chữ thường.',
              ),
              const SizedBox(height: 28),
              Form(
                key: _form,
                child: TextFormField(
                  key: const Key('inviteCodeField'),
                  controller: _code,
                  enabled: !_busy,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  maxLength: inviteCodeLength,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(inviteCodeLength),
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mã mời',
                    hintText: 'K7P4R8',
                    counterText: '',
                  ),
                  style: const TextStyle(letterSpacing: 4, fontSize: 20),
                  validator: validateInviteCode,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('joinInviteError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('joinInviteSubmit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ghép đôi'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
