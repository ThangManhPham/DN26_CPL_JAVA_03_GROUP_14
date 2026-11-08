import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'data/album_repository.dart';
import 'data/memory_story_repository.dart';
import 'data/photo_repository.dart';
import 'memory_story_screen.dart';
import 'theme.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    required this.albumRepository,
    required this.photoRepository,
    this.storyRepository,
    required this.token,
    required this.userId,
  });

  final String albumId;
  final AlbumRepository albumRepository;
  final PhotoRepository photoRepository;
  final MemoryStoryRepository? storyRepository;
  final String token;
  final String userId;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  AlbumDetail? _detail;
  bool _loading = true;
  String? _error;

  late final MemoryStoryRepository _storyRepo;
  List<MemoryStoryDetail> _stories = [];
  bool _loadingStories = false;

  @override
  void initState() {
    super.initState();
    _storyRepo = widget.storyRepository ??
        (AppConfig.useMock
            ? MockMemoryStoryRepository()
            : HttpMemoryStoryRepository(baseUrl: AppConfig.baseUrl));
    _loadDetail();
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() => _loadingStories = true);
    try {
      final stories = await _storyRepo.listStoriesInAlbum(widget.token, widget.albumId);
      if (mounted) {
        setState(() {
          _stories = stories;
          _loadingStories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStories = false);
    }
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

  Future<void> _showGenerateStorySheet() async {
    if (_detail == null || _detail!.photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Album cần có ít nhất 1 ảnh để tạo câu chuyện kỷ niệm AI.'),
        ),
      );
      return;
    }

    final notesController = TextEditingController();
    final availablePhotos = _detail!.photos;
    final selectedPhotoIds = availablePhotos.take(10).map((p) => p.id).toSet();
    String selectedTone = 'ROMANTIC';
    bool consent = false;
    bool generating = false;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.rose, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Tạo Câu Chuyện Kỷ Niệm AI',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'AI sẽ dựa trên ảnh và ghi chú của hai bạn để viết nên câu chuyện tình yêu đầy cảm xúc.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  // 1. Chọn ảnh (tối đa 20)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Chọn ảnh đưa vào câu chuyện',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${selectedPhotoIds.length}/20 đã chọn',
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedPhotoIds.isEmpty ? Colors.red : AppColors.rose,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: availablePhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final photo = availablePhotos[index];
                        final isSelected = selectedPhotoIds.contains(photo.id);
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                selectedPhotoIds.remove(photo.id);
                              } else {
                                if (selectedPhotoIds.length < 20) {
                                  selectedPhotoIds.add(photo.id);
                                }
                              }
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppColors.rose : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _ThumbnailWidget(
                                  photo: photo,
                                  photoRepository: widget.photoRepository,
                                  token: widget.token,
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.rose,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Gợi ý / Ghi chú
                  const Text(
                    '2. Lời nhắn / Gợi ý kỷ niệm (tùy chọn)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('storyNotesInput'),
                    controller: notesController,
                    maxLines: 2,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: 'Ví dụ: Buổi chiều ngắm hoàng hôn bên hồ, cốc cà phê đầu tiên...',
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Phong cách (Tone)
                  const Text(
                    '3. Phong cách lời kể',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _toneChip('ROMANTIC', 'Lãng mạn', selectedTone, (t) => setSheetState(() => selectedTone = t)),
                      _toneChip('PLAYFUL', 'Hài hước', selectedTone, (t) => setSheetState(() => selectedTone = t)),
                      _toneChip('SENTIMENTAL', 'Sâu lắng', selectedTone, (t) => setSheetState(() => selectedTone = t)),
                      _toneChip('POETIC', 'Thơ mộng', selectedTone, (t) => setSheetState(() => selectedTone = t)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Đồng thuận người dùng (Mandatory Consent)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.pink.shade100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: CheckboxListTile(
                      key: const Key('storyConsentCheckbox'),
                      contentPadding: EdgeInsets.zero,
                      value: consent,
                      activeColor: AppColors.rose,
                      onChanged: (val) => setSheetState(() => consent = val ?? false),
                      title: const Text(
                        'Tôi đồng ý sử dụng AI để sáng tạo câu chuyện từ ghi chú và album kỷ niệm này.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'OurSpace tuân thủ bảo mật riêng tư: ảnh gốc của bạn không bị chia sẻ ra ngoài.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('submitGenerateStoryButton'),
                      onPressed: (!consent || selectedPhotoIds.isEmpty || generating)
                          ? null
                          : () async {
                              setSheetState(() {
                                generating = true;
                                errorMessage = null;
                              });

                              try {
                                final story = await _storyRepo.generateStory(
                                  widget.token,
                                  albumId: widget.albumId,
                                  photoIds: selectedPhotoIds.toList(),
                                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                  tone: selectedTone,
                                  consent: consent,
                                );

                                if (sheetCtx.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                }

                                if (mounted) {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MemoryStoryScreen(
                                        storyId: story.id,
                                        albumId: widget.albumId,
                                        storyRepository: _storyRepo,
                                        token: widget.token,
                                        userId: widget.userId,
                                        initialStory: story,
                                      ),
                                    ),
                                  );
                                  _loadStories();
                                }
                              } on MemoryStoryException catch (e) {
                                setSheetState(() {
                                  generating = false;
                                  errorMessage = e.message;
                                });
                              } catch (_) {
                                setSheetState(() {
                                  generating = false;
                                  errorMessage = 'Đã xảy ra lỗi khi tạo câu chuyện. Vui lòng thử lại sau.';
                                });
                              }
                            },
                      icon: generating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(generating ? 'AI đang viết câu chuyện...' : 'Bắt đầu tạo câu chuyện AI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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

  Widget _toneChip(String value, String label, String selectedTone, ValueChanged<String> onSelected) {
    final isSelected = selectedTone == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.softRose,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.rose : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(value),
    );
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
          if (_detail != null && _detail!.photos.isNotEmpty)
            IconButton(
              key: const Key('generateStoryAppBarButton'),
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Tạo câu chuyện AI',
              onPressed: _showGenerateStorySheet,
            ),
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
                  if (_stories.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppColors.rose, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Câu chuyện kỷ niệm AI',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          key: const Key('addMoreStoryButton'),
                          onPressed: _showGenerateStorySheet,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tạo thêm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _stories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) => _buildStoryCard(_stories[index]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (detail.photos.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.softRose, Colors.pink.shade50.withOpacity(0.5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.pink.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.rose, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tạo câu chuyện kỷ niệm với AI',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Để AI viết nên câu chuyện ngọt ngào từ những bức ảnh của hai bạn.',
                                  style: TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            key: const Key('createFirstStoryButton'),
                            onPressed: _showGenerateStorySheet,
                            child: const Text('Tạo ngay'),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildStoryCard(MemoryStoryDetail story) {
    return InkWell(
      key: Key('storyCard_${story.id}'),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoryStoryScreen(
              storyId: story.id,
              albumId: widget.albumId,
              storyRepository: _storyRepo,
              token: widget.token,
              userId: widget.userId,
              initialStory: story,
            ),
          ),
        );
        _loadStories();
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: story.isSaved ? Colors.green.shade200 : Colors.amber.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: story.isSaved ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    story.isSaved ? 'Đã lưu' : 'Bản nháp',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: story.isSaved ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
                if (story.tone != null)
                  Text(
                    story.tone!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            Text(
              story.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.rose),
                const SizedBox(width: 4),
                Text(
                  story.isDraft ? 'Xem & Lưu' : 'Đọc câu chuyện',
                  style: const TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
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
