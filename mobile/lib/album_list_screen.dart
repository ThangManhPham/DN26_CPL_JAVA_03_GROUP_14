import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'album_detail_screen.dart';
import 'data/album_repository.dart';
import 'data/photo_repository.dart';
import 'theme.dart';

class AlbumListScreen extends StatefulWidget {
  const AlbumListScreen({
    super.key,
    required this.albumRepository,
    required this.photoRepository,
    required this.token,
    required this.userId,
  });

  final AlbumRepository albumRepository;
  final PhotoRepository photoRepository;
  final String token;
  final String userId;

  @override
  State<AlbumListScreen> createState() => _AlbumListScreenState();
}

class _AlbumListScreenState extends State<AlbumListScreen> {
  List<AlbumSummary> _albums = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final albums = await widget.albumRepository.listAlbums(widget.token);
      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
      }
    } on AlbumException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách album. Vui lòng thử lại sau.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCreateAlbumDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tạo album mới'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('albumTitleInput'),
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tên album *',
                      hintText: 'Ví dụ: Kỷ niệm 1 năm, Đà Lạt 2026...',
                    ),
                    maxLength: 100,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập tên album';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('albumDescInput'),
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả (tuỳ chọn)',
                      hintText: 'Một vài dòng về khoảnh khắc này...',
                    ),
                    maxLength: 500,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              key: const Key('submitCreateAlbum'),
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => submitting = true);
                      try {
                        await widget.albumRepository.createAlbum(
                          widget.token,
                          titleController.text.trim(),
                          description: descController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadAlbums();
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Album kỷ niệm'),
        actions: [
          IconButton(
            key: const Key('refreshAlbumsButton'),
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlbums,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('createAlbumFab'),
        onPressed: _showCreateAlbumDialog,
        backgroundColor: AppColors.rose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Tạo album'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadAlbums,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_albums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.softRose,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined, size: 64, color: AppColors.rose),
              ),
              const SizedBox(height: 24),
              const Text(
                'Chưa có album nào',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tạo album để gom những bức ảnh kỷ niệm ý nghĩa nhất của hai bạn lại với nhau.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('emptyStateCreateAlbumButton'),
                onPressed: _showCreateAlbumDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tạo album đầu tiên'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlbums,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final album = _albums[index];
          return Card(
            key: Key('albumCard_${album.id}'),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlbumDetailScreen(
                      albumId: album.id,
                      albumRepository: widget.albumRepository,
                      photoRepository: widget.photoRepository,
                      token: widget.token,
                      userId: widget.userId,
                    ),
                  ),
                );
                _loadAlbums();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AlbumCoverWidget(
                    album: album,
                    photoRepository: widget.photoRepository,
                    token: widget.token,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (album.description != null && album.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            album.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.image_outlined, size: 16, color: AppColors.rose),
                            const SizedBox(width: 4),
                            Text(
                              '${album.photoCount} ảnh',
                              style: const TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumCoverWidget extends StatefulWidget {
  const _AlbumCoverWidget({
    required this.album,
    required this.photoRepository,
    required this.token,
  });

  final AlbumSummary album;
  final PhotoRepository photoRepository;
  final String token;

  @override
  State<_AlbumCoverWidget> createState() => _AlbumCoverWidgetState();
}

class _AlbumCoverWidgetState extends State<_AlbumCoverWidget> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  Future<void> _loadCover() async {
    if (widget.album.coverPhotoPath == null) return;
    try {
      final photo = SharedPhoto(
        id: widget.album.coverPhotoId ?? '',
        senderId: '',
        createdAt: DateTime.now(),
        imagePath: widget.album.coverPhotoPath!,
      );
      final bytes = await widget.photoRepository.image(widget.token, photo);
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.memory(_bytes!, fit: BoxFit.cover),
      );
    }
    return Container(
      height: 140,
      color: AppColors.softRose,
      child: const Center(
        child: Icon(Icons.photo_album_outlined, size: 48, color: AppColors.rose),
      ),
    );
  }
}
