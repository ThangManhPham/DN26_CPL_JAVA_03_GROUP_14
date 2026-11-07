import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Chia sẻ nội dung qua share sheet của hệ điều hành (iOS) / Web Share API.
///
/// Trả về `false` khi nền tảng không hỗ trợ để UI có thể fallback sang sao
/// chép mã, thay vì làm hỏng luồng chính.
Future<bool> shareText(String text, {String? subject}) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (_) {
    return false;
  }
}

/// Sao chép văn bản vào clipboard.
Future<void> copyText(String text) =>
    Clipboard.setData(ClipboardData(text: text));
