import 'package:flutter/material.dart';

import '../../../core/state/auth_controller.dart';
import '../../../core/widgets/async_states.dart';
import '../../../data/photo_repository.dart';
import '../../timeline/data/timeline_repository.dart';
import '../data/pairing_repository.dart';
import 'couple_home_screen.dart';
import 'pairing_controller.dart';
import 'pairing_screen.dart';

/// Cổng vào sau khi đăng nhập: quyết định người dùng thấy màn Pairing hay
/// Couple Home dựa trên `GET /api/v1/couples/me` (S1-06 + S1-09).
class PairingGate extends StatefulWidget {
  const PairingGate({
    super.key,
    required this.userId,
    required this.auth,
    required this.couples,
    required this.photos,
    required this.timeline,
  });

  final String userId;
  final AuthController auth;
  final CoupleRepository couples;
  final PhotoRepository photos;
  final TimelineRepository timeline;

  @override
  State<PairingGate> createState() => _PairingGateState();
}

class _PairingGateState extends State<PairingGate> {
  late final PairingController _controller = PairingController(
    repository: widget.couples,
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final couple = _controller.couple;
      if (couple == null) {
        if (_controller.isLoading) {
          return const Scaffold(
            body: LoadingStateView(message: 'Đang kiểm tra cặp đôi…'),
          );
        }
        final error = _controller.error;
        if (error != null) {
          return Scaffold(
            body: ErrorStateView(message: error, onRetry: _controller.load),
          );
        }
        return PairingScreen(auth: widget.auth, controller: _controller);
      }
      return CoupleHomeScreen(
        auth: widget.auth,
        controller: _controller,
        userId: widget.userId,
        photos: widget.photos,
        timeline: widget.timeline,
      );
    },
  );
}
