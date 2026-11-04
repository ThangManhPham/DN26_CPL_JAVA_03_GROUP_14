import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_states.dart';
import '../data/timeline_models.dart';
import '../data/timeline_repository.dart';
import 'reaction_bar.dart';
import 'timeline_screen.dart' show PhotoImageView;

/// Chi tiết một ảnh: làm mới bằng `GET /api/v1/photos/{id}`, hiển thị người
/// gửi, thời gian theo giờ local và reaction có optimistic update (S2-C02).
class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({
    super.key,
    required this.repository,
    required this.photo,
    required this.currentUserId,
  });

  final TimelineRepository repository;

  /// Ảnh đã có từ timeline: dùng ngay để tránh màn hình trắng khi chờ API.
  final PhotoItem photo;
  final String currentUserId;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late PhotoItem _photo = widget.photo;
  late Future<Uint8List> _image = widget.repository.fetchImage(
    widget.photo.imagePath,
  );
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fresh = await widget.repository.fetchPhoto(widget.photo.id);
      if (!mounted) return;
      setState(() {
        _photo = fresh;
        _image = widget.repository.fetchImage(fresh.imagePath);
        _loading = false;
      });
    } on ApiException catch (error) {
      // 403/404 được map sẵn thành thông điệp thân thiện trong ApiException.
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.userMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không thể tải ảnh. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _react(PhotoReactionType? type) async {
    if (_busy || _photo.reactionBy(widget.currentUserId) == type) return;
    final previous = _photo;
    setState(() {
      _busy = true;
      _photo = previous.withReaction(userId: widget.currentUserId, type: type);
    });
    try {
      if (type == null) {
        await widget.repository.clearReaction(previous.id);
      } else {
        await widget.repository.setReaction(previous.id, type);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _photo = previous);
      final message = error is ApiException
          ? error.userMessage
          : 'Không lưu được cảm xúc. Vui lòng thử lại.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết ảnh')),
    body: SafeArea(child: _buildBody(context)),
  );

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const LoadingStateView(message: 'Đang tải ảnh…');
    }
    final error = _error;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: _load);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              key: const Key('photoDetailImage'),
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: PhotoImageView(imageFuture: _image),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _photo.senderId == widget.currentUserId
                  ? 'Bạn đã gửi'
                  : '${_photo.senderDisplayName} đã gửi',
              key: const Key('photoDetailSender'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              formatLocalDateTime(_photo.createdAt),
              key: const Key('photoDetailTime'),
            ),
            const SizedBox(height: 20),
            ReactionBar(
              photo: _photo,
              currentUserId: widget.currentUserId,
              onSelect: _react,
              busy: _busy,
            ),
          ],
        ),
      ),
    );
  }
}
