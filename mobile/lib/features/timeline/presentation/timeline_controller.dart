import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/timeline_models.dart';
import '../data/timeline_repository.dart';

/// Trạng thái timeline: phân trang theo cursor, kéo-để-làm-mới và reaction
/// optimistic update có rollback (S2-C01, S2-C05).
class TimelineController extends ChangeNotifier {
  TimelineController({
    required TimelineRepository repository,
    required String currentUserId,
    this.pageSize = 20,
  }) : _repository = repository,
       _currentUserId = currentUserId;

  final TimelineRepository _repository;
  final String _currentUserId;
  final int pageSize;

  final List<PhotoItem> _items = <PhotoItem>[];
  final Map<String, Future<Uint8List>> _images = <String, Future<Uint8List>>{};

  String? _nextCursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _refreshing = false;
  String? _error;
  String? _loadMoreError;

  String get currentUserId => _currentUserId;
  List<PhotoItem> get items => List<PhotoItem>.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get isRefreshing => _refreshing;

  /// Lỗi của lần tải đầu tiên (màn hình hiển thị ErrorStateView).
  String? get error => _error;

  /// Lỗi khi tải thêm trang (chỉ hiện ở chân danh sách, không xóa dữ liệu cũ).
  String? get loadMoreError => _loadMoreError;
  bool get hasMore => _nextCursor != null;
  bool get isEmpty => _items.isEmpty;

  /// Tải trang đầu tiên và hiển thị skeleton.
  Future<void> loadInitial() => _load(reset: true);

  /// Kéo-để-làm-mới: giữ nội dung cũ trên màn hình cho tới khi có kết quả.
  Future<void> refresh() => _load(reset: true, pullToRefresh: true);

  /// Infinite scroll: nạp trang kế tiếp theo `nextCursor`.
  Future<void> loadMore() => _load(reset: false);

  /// Ảnh tải qua endpoint có xác thực; cache theo `imagePath` để việc dựng
  /// lại widget không gọi lại mạng.
  Future<Uint8List> imageFor(PhotoItem photo) => _images.putIfAbsent(
    photo.imagePath,
    () => _repository.fetchImage(photo.imagePath),
  );

  /// Đặt/bỏ reaction của mình với optimistic update + rollback khi lỗi.
  ///
  /// Ném lại lỗi để màn hình hiển thị SnackBar sau khi đã khôi phục dữ liệu.
  Future<void> react(PhotoItem photo, PhotoReactionType? type) async {
    final index = _items.indexWhere((item) => item.id == photo.id);
    if (index < 0) return;
    final previous = _items[index];
    if (previous.reactionBy(_currentUserId) == type) return;

    _items[index] = previous.withReaction(userId: _currentUserId, type: type);
    notifyListeners();

    try {
      if (type == null) {
        await _repository.clearReaction(photo.id);
      } else {
        await _repository.setReaction(photo.id, type);
      }
    } catch (_) {
      final currentIndex = _items.indexWhere((item) => item.id == photo.id);
      if (currentIndex >= 0) {
        _items[currentIndex] = previous;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _load({required bool reset, bool pullToRefresh = false}) async {
    if (reset) {
      if (pullToRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
      _loadMoreError = null;
      notifyListeners();
    } else {
      if (_loadingMore || !hasMore) return;
      _loadingMore = true;
      _loadMoreError = null;
      notifyListeners();
    }

    try {
      final page = await _repository.fetchPage(
        cursor: reset ? null : _nextCursor,
        limit: pageSize,
      );
      if (reset) {
        _items
          ..clear()
          ..addAll(page.items);
      } else {
        final known = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => !known.contains(item.id)));
      }
      _nextCursor = page.nextCursor;
    } on ApiException catch (error) {
      _setError(error.userMessage, reset: reset);
    } catch (_) {
      _setError('Không thể tải timeline. Vui lòng thử lại.', reset: reset);
    } finally {
      _loading = false;
      _loadingMore = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  void _setError(String message, {required bool reset}) {
    if (reset) {
      _error = message;
    } else {
      _loadMoreError = message;
    }
  }
}
