import 'package:flutter/foundation.dart';

/// Tín hiệu "vừa gửi ảnh mới" giữa màn gửi ảnh và màn timeline.
///
/// `PhotoScreen` phát tín hiệu sau khi upload thành công để `TimelineScreen`
/// làm mới ngay, không phải chờ tới nhịp đồng bộ định kỳ.
abstract final class PhotoFeedBus {
  /// Tăng mỗi lần có ảnh mới; ai quan tâm thì `addListener`.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notifyNewPhoto() => revision.value++;
}
