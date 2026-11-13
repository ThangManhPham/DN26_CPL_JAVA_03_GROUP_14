/// Trừu tượng hoá `PushBridge` (M1/M5) để lớp UI dùng chung không phải kéo
/// theo `dart:io`. Nhờ vậy cùng một `main.dart` build được cả iOS và Flutter
/// Web (yêu cầu nền tảng của M2).
abstract class AppPushBridge {
  Future<void> activate(String authToken);
  Future<void> deactivate(String authToken);
  Future<void> dispose();
}
