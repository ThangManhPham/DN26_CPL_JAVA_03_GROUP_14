import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'data/album_repository.dart';
import 'data/photo_repository.dart';
import 'theme.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    required this.albumRepository,
    required this.photoRepository,
    required this.token,
    required this.userId,
  });

  final String albumId;
  final AlbumRepository albumRepository;
  final PhotoRepository photoRepository;
  final String token;
  final String userId;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  AlbumDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.albumRepository.getAlbumDetail(widget.token, widget.albumId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } on AlbumException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải chi tiết album. Vui lòng thử lại sau.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAddPhotoSheet() async {
    try {
      final available = await widget.albumRepository.getAvailablePhotos(widget.token);
      if (!mounted) return;

      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hai bạn chưa có ảnh nào trong thư viện chung để thêm.')),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn ảnh để thêm vào album',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chạm vào ảnh để thêm vào album kỷ niệm',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final photo = available[index];
                      final isAlreadyAdded = _detail?.photos.any((p) => p.id == photo.id) ?? false;
                      return InkWell(
                        key: Key('photoPickerItem_${photo.id}'),
                        onTap: isAlreadyAdded
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                await _addPhoto(photo.id);
                              },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _ThumbnailWidget(
                              photo: photo,
                              photoRepository: widget.photoRepository,
                              token: widget.token,
                            ),
                            if (isAlreadyAdded)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: Icon(Icons.check_circle, color: Colors.white, size: 28),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải ảnh: $e')),
        );
      }
    }
  }

  Future<void> _addPhoto(String photoId) async {
    try {
      await widget.albumRepository.addPhotoToAlbum(widget.token, widget.albumId, photoId);
      _loadDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm ảnh vào album')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thêm ảnh: $e')),
        );
      }
    }
  }

  Future<void> _confirmRemovePhoto(SharedPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ ảnh khỏi album?'),
        content: const Text('Ảnh sẽ chỉ bị xóa khỏi album này và vẫn được giữ trong thư viện ảnh chung.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
          FilledButton(
            key: const Key('confirmRemovePhotoButton'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá khỏi album'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.albumRepository.removePhotoFromAlbum(widget.token, widget.albumId, photo.id);
        _loadDetail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa ảnh khỏi album')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xóa ảnh: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteAlbum() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá album?'),
        content: const Text('Bạn có chắc chắn muốn xoá album này? Các bức ảnh trong album sẽ không bị xoá khỏi thư viện ảnh chung.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
          FilledButton(
            key: const Key('confirmDeleteAlbumButton'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá album'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.albumRepository.deleteAlbum(widget.token, widget.albumId);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xoá album: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.title ?? 'Chi tiết album'),
        actions: [
          if (_detail != null)
            IconButton(
              key: const Key('deleteAlbumButton'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xoá album',
              onPressed: _confirmDeleteAlbum,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addPhotoToAlbumFab'),
        onPressed: _showAddPhotoSheet,
        backgroundColor: AppColors.rose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Thêm ảnh'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
              const SizedBox(height: 16),
              Text(_error ?? 'Lỗi tải album', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadDetail, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (detail.description != null && detail.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      detail.description!,
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.rose),
                      const SizedBox(width: 6),
                      Text(
                        '${detail.photos.length} ảnh trong album',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.rose),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                ],
              ),
            ),
          ),
          if (detail.photos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_a_photo_outlined, size: 56, color: Colors.black26),
                      const SizedBox(height: 16),
                      const Text(
                        'Album chưa có ảnh nào',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Hãy bấm nút "Thêm ảnh" bên dưới để chọn ảnh đưa vào album.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('emptyDetailAddPhotoButton'),
                        onPressed: _showAddPhotoSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm ảnh ngay'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = detail.photos[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _ThumbnailWidget(
                            photo: photo,
                            photoRepository: widget.photoRepository,
                            token: widget.token,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              key: Key('removePhotoButton_${photo.id}'),
                              iconSize: 18,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.close, color: Colors.white),
                              tooltip: 'Bỏ ảnh khỏi album',
                              onPressed: () => _confirmRemovePhoto(photo),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: detail.photos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbnailWidget extends StatefulWidget {
  const _ThumbnailWidget({
    required this.photo,
    required this.photoRepository,
    required this.token,
  });

  final SharedPhoto photo;
  final PhotoRepository photoRepository;
  final String token;

  @override
  State<_ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<_ThumbnailWidget> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.photoRepository.image(widget.token, widget.photo);
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(_bytes!, fit: BoxFit.cover);
    }
    return Container(
      color: AppColors.softRose,
      child: const Center(
        child: Icon(Icons.image, color: AppColors.rose),
      ),
    );
  }
}
