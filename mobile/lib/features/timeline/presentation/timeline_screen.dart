import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_states.dart';
import '../data/timeline_models.dart';
import '../data/timeline_repository.dart';
import 'photo_detail_screen.dart';
import 'reaction_bar.dart';
import 'timeline_controller.dart';

/// Timeline feed của couple: cursor pagination (infinite scroll),
/// kéo-để-làm-mới, skeleton và đủ trạng thái loading/empty/error (S2-C01).
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    super.key,
    required this.repository,
    required this.currentUserId,
  });

  final TimelineRepository repository;
  final String currentUserId;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late final TimelineController _controller = TimelineController(
    repository: widget.repository,
    currentUserId: widget.currentUserId,
  );
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _controller.loadMore();
    }
  }

  Future<void> _react(PhotoItem photo, PhotoReactionType? type) async {
    try {
      await _controller.react(photo, type);
    } on ApiException catch (error) {
      _showMessage(error.userMessage);
    } catch (_) {
      _showMessage('Không lưu được cảm xúc. Vui lòng thử lại.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDetail(PhotoItem photo) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PhotoDetailScreen(
        repository: widget.repository,
        photo: photo,
        currentUserId: widget.currentUserId,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Timeline của hai bạn')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.isEmpty) {
            return const _TimelineSkeleton();
          }
          final error = _controller.error;
          if (error != null && _controller.isEmpty) {
            return ErrorStateView(
              message: error,
              onRetry: _controller.loadInitial,
            );
          }
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: _controller.isEmpty
                ? ListView(
                    key: const Key('timelineEmptyList'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 96),
                    children: const [
                      EmptyStateView(
                        message:
                            'Chưa có ảnh nào. Hãy gửi tấm ảnh đầu tiên cho người ấy!',
                      ),
                    ],
                  )
                : ListView.builder(
                    key: const Key('timelineList'),
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: _controller.items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _controller.items.length) {
                        return _TimelineFooter(
                          loading: _controller.isLoadingMore,
                          error: _controller.loadMoreError,
                          hasMore: _controller.hasMore,
                          onRetry: _controller.loadMore,
                        );
                      }
                      final photo = _controller.items[index];
                      return _PhotoCard(
                        key: Key('photo_${photo.id}'),
                        photo: photo,
                        imageFuture: _controller.imageFor(photo),
                        currentUserId: widget.currentUserId,
                        onReact: (type) => _react(photo, type),
                        onOpen: () => _openDetail(photo),
                      );
                    },
                  ),
          );
        },
      ),
    ),
  );
}

/// Skeleton giữ đúng bố cục thẻ ảnh để tránh nhảy giao diện khi dữ liệu về.
class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('timelineSkeleton'),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: const [_SkeletonCard(), _SkeletonCard(), _SkeletonCard()],
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.softRose,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(height: 14, width: 180, color: AppColors.softRose),
        const SizedBox(height: 10),
        Container(height: 14, width: 120, color: AppColors.softRose),
      ],
    ),
  );
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    super.key,
    required this.photo,
    required this.imageFuture,
    required this.currentUserId,
    required this.onReact,
    required this.onOpen,
  });

  final PhotoItem photo;
  final Future<Uint8List> imageFuture;
  final String currentUserId;
  final ValueChanged<PhotoReactionType?> onReact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: Key('photoImage_${photo.id}'),
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: PhotoImageView(imageFuture: imageFuture),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          photo.senderId == currentUserId
              ? 'Bạn đã gửi'
              : '${photo.senderDisplayName} đã gửi',
          key: Key('photoSender_${photo.id}'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          formatLocalDateTime(photo.createdAt),
          key: Key('photoTime_${photo.id}'),
          style: const TextStyle(color: AppColors.ink, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ReactionBar(
          photo: photo,
          currentUserId: currentUserId,
          onSelect: onReact,
        ),
      ],
    ),
  );
}

/// Ảnh tải qua endpoint có xác thực; không dùng URL công khai vĩnh viễn.
class PhotoImageView extends StatelessWidget {
  const PhotoImageView({super.key, required this.imageFuture});

  final Future<Uint8List> imageFuture;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: imageFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const ColoredBox(
          color: AppColors.softRose,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final bytes = snapshot.data;
      if (snapshot.hasError || bytes == null || bytes.isEmpty) {
        return const ColoredBox(
          color: AppColors.softRose,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              key: Key('photoImageError'),
              color: AppColors.rose,
              size: 36,
            ),
          ),
        );
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    },
  );
}

class _TimelineFooter extends StatelessWidget {
  const _TimelineFooter({
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Column(
        children: [
          Text(
            error!,
            key: const Key('timelineLoadMoreError'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('timelineLoadMoreRetry'),
            onPressed: onRetry,
            child: const Text('Tải thêm'),
          ),
        ],
      );
    }
    if (loading) {
      return const Padding(
        key: Key('timelineLoadMore'),
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return const Padding(
        key: Key('timelineEnd'),
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text('Bạn đã xem hết ảnh rồi.')),
      );
    }
    return const SizedBox(height: 32);
  }
}
