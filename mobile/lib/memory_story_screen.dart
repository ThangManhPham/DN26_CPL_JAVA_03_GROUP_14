import 'package:flutter/material.dart';
import 'data/memory_story_repository.dart';
import 'theme.dart';

class MemoryStoryScreen extends StatefulWidget {
  const MemoryStoryScreen({
    super.key,
    required this.storyId,
    required this.albumId,
    required this.storyRepository,
    required this.token,
    required this.userId,
    this.initialStory,
  });

  final String storyId;
  final String albumId;
  final MemoryStoryRepository storyRepository;
  final String token;
  final String userId;
  final MemoryStoryDetail? initialStory;

  @override
  State<MemoryStoryScreen> createState() => _MemoryStoryScreenState();
}

class _MemoryStoryScreenState extends State<MemoryStoryScreen> {
  MemoryStoryDetail? _story;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialStory != null) {
      _story = widget.initialStory;
      _loading = false;
    } else {
      _loadStory();
    }
  }

  Future<void> _loadStory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final story = await widget.storyRepository.getStory(widget.token, widget.storyId);
      if (mounted) {
        setState(() {
          _story = story;
          _loading = false;
        });
      }
    } on MemoryStoryException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải câu chuyện. Vui lòng thử lại sau.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveStory() async {
    if (_story == null || _saving) return;

    setState(() => _saving = true);
    try {
      final saved = await widget.storyRepository.saveStory(widget.token, _story!.id);
      if (mounted) {
        setState(() {
          _story = saved;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu câu chuyện kỷ niệm vào Album thành công!'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    } on MemoryStoryException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi kết nối khi lưu câu chuyện.')),
        );
      }
    }
  }

  Future<void> _showEditDialog() async {
    if (_story == null) return;

    final titleController = TextEditingController(text: _story!.title);
    final storyController = TextEditingController(text: _story!.storyText);
    final highlightsController = TextEditingController(text: _story!.highlights.join('\n'));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa câu chuyện AI'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề câu chuyện',
                  hintText: 'Nhập tiêu đề...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storyController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Nội dung câu chuyện',
                  hintText: 'Chỉnh sửa lời kể...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: highlightsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Điểm nhấn (mỗi dòng 1 ý)',
                  hintText: 'Điểm nhấn 1\nĐiểm nhấn 2',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final newTitle = titleController.text.trim();
      final newStory = storyController.text.trim();
      final newHighlights = highlightsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (newTitle.isEmpty || newStory.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiêu đề và nội dung không được để trống.')),
        );
        return;
      }

      setState(() => _saving = true);
      try {
        final updated = await widget.storyRepository.updateStory(
          widget.token,
          _story!.id,
          title: newTitle,
          storyText: newStory,
          highlights: newHighlights,
          tone: _story!.tone,
        );
        if (mounted) {
          setState(() {
            _story = updated;
            _saving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật câu chuyện.')),
          );
        }
      } on MemoryStoryException catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Câu Chuyện Kỷ Niệm'),
        actions: [
          if (_story != null && _story!.isDraft)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Chỉnh sửa',
              onPressed: _showEditDialog,
            ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải câu chuyện...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadStory,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_story == null) {
      return const Center(child: Text('Không tìm thấy câu chuyện'));
    }

    final story = _story!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and metadata header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: story.isSaved ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: story.isSaved ? Colors.green.shade300 : Colors.amber.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      story.isSaved ? Icons.check_circle : Icons.edit_note,
                      size: 14,
                      color: story.isSaved ? Colors.green.shade700 : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      story.isSaved ? 'Đã lưu vào Album' : 'Bản nháp riêng tư',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: story.isSaved ? Colors.green.shade700 : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (story.photoIds.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.photo_library, size: 14),
                  label: Text('${story.photoIds.length} ảnh'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            story.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          if (story.isDraft)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bản nháp chỉ hiển thị cho bạn. Sau khi nhấn "Lưu câu chuyện", đối phương mới có thể cùng xem.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),

          // Story Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.rose, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Lời kể AI • Tone: ${story.tone ?? "Lãng mạn"}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    story.storyText,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Highlights Section
          if (story.highlights.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.stars, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text(
                  'Điểm nhấn đáng nhớ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...story.highlights.map(
              (hl) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4, right: 8),
                      child: Icon(Icons.favorite, size: 12, color: AppColors.rose),
                    ),
                    Expanded(
                      child: Text(
                        hl,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_story == null || !_story!.isDraft) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _showEditDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Chỉnh sửa'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveStory,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bookmark_added),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu vào Album'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

