import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'data/photo_repository.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({
    super.key,
    required this.repository,
    required this.token,
    required this.userId,
  });
  final PhotoRepository repository;
  final String token;
  final String userId;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  SharedPhoto? _latest;
  Uint8List? _latestBytes;
  Uint8List? _selected;
  String? _mime;
  String? _requestId;
  String? _error;
  bool _busy = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_busy) return;
    final previousId = _latest?.id;
    setState(() {
      if (!silent) {
        _busy = true;
        _error = null;
      }
    });
    try {
      final photo = await widget.repository.latest(widget.token);
      if (silent && photo?.id == previousId) return;
      final bytes = photo == null
          ? null
          : await widget.repository.image(widget.token, photo);
      if (mounted) {
        setState(() {
          _latest = photo;
          _latestBytes = bytes;
        });
        if (silent &&
            previousId != null &&
            photo != null &&
            photo.senderId != widget.userId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Người yêu vừa gửi một ảnh mới 💕')),
          );
        }
      }
    } on PhotoException catch (error) {
      if (mounted && !silent) setState(() => _error = error.message);
    } catch (_) {
      if (mounted && !silent) {
        setState(
          () => _error = 'Không thể tải ảnh. Kiểm tra mạng rồi thử lại.',
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _busy = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        setState(() => _error = 'Ảnh phải nhỏ hơn 10 MB.');
        return;
      }
      final mime = _detectMime(bytes);
      if (mime == null) {
        setState(() => _error = 'Chỉ hỗ trợ ảnh JPEG hoặc PNG.');
        return;
      }
      setState(() {
        _selected = bytes;
        _mime = mime;
        _requestId = newPhotoRequestId();
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Không thể mở camera/thư viện. Kiểm tra quyền truy cập.',
        );
      }
    }
  }

  String? _detectMime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      return 'image/png';
    }
    return null;
  }

  Future<void> _send() async {
    if (_busy || _selected == null || _mime == null || _requestId == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await widget.repository.upload(
        widget.token,
        _selected!,
        _mime!,
        _requestId!,
      );
      final bytes = await widget.repository.image(widget.token, photo);
      if (mounted) {
        setState(() {
          _latest = photo;
          _latestBytes = bytes;
          _selected = null;
          _mime = null;
          _requestId = null;
        });
      }
    } on PhotoException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gửi ảnh thất bại. Bạn có thể thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ảnh của hai bạn')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Khoảnh khắc mới nhất',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (_latestBytes == null)
            const SizedBox(
              height: 220,
              child: Center(
                child: Text('Chưa có ảnh chung. Hãy gửi khoảnh khắc đầu tiên.'),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(
                _latestBytes!,
                height: 300,
                fit: BoxFit.cover,
              ),
            ),
          if (_latest != null) ...[
            const SizedBox(height: 8),
            Text(
              'Gửi lúc ${_latest!.createdAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          if (_selected != null) ...[
            Text(
              'Ảnh chuẩn bị gửi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_selected!, height: 190, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Chụp ảnh'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Thư viện'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('sendPhoto'),
            onPressed: _busy || _selected == null ? null : _send,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Gửi cho người yêu'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _refresh(),
            child: const Text('Tải lại ảnh mới nhất'),
          ),
        ],
      ),
    ),
  );
}
