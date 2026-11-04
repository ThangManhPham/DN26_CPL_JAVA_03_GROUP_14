import 'dart:convert';
import 'dart:typed_data';

/// Một phần (part) của body `multipart/form-data`.
class MultipartPart {
  MultipartPart(this.headers, this.body);

  /// Tên header đã hạ chữ thường.
  final Map<String, String> headers;
  final Uint8List body;

  /// `name` trong `Content-Disposition`.
  String? get name => _parameter('name');

  /// `filename` trong `Content-Disposition` (null khi part không phải file).
  String? get filename => _parameter('filename');

  /// `Content-Type` của part (null khi client không gửi).
  String? get contentType => headers['content-type'];

  String? _parameter(String key) {
    final disposition = headers['content-disposition'];
    if (disposition == null) return null;
    final match = RegExp(
      '$key="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(disposition);
    return match?.group(1);
  }
}

/// Đọc `boundary` từ header `Content-Type: multipart/form-data; boundary=...`.
String? boundaryOf(String? contentType) {
  if (contentType == null) return null;
  final match = RegExp(
    'boundary="?([^";]+)"?',
    caseSensitive: false,
  ).firstMatch(contentType);
  return match?.group(1);
}

/// Parser multipart tối giản, chỉ dùng cho dev server (không cần thư viện ngoài).
///
/// Trả `null` khi body không đúng định dạng multipart.
List<MultipartPart>? parseMultipartBody(Uint8List body, String boundary) {
  // latin1 giữ nguyên 1 byte = 1 ký tự nên tìm delimiter bằng indexOf là chính xác.
  final text = latin1.decode(body);
  final delimiter = '--$boundary';
  final parts = <MultipartPart>[];

  var cursor = text.indexOf(delimiter);
  if (cursor < 0) return null;
  cursor += delimiter.length;

  while (true) {
    if (text.startsWith('--', cursor)) return parts; // delimiter kết thúc
    if (text.startsWith('\r\n', cursor)) {
      cursor += 2;
    } else {
      return parts;
    }

    final headerEnd = text.indexOf('\r\n\r\n', cursor);
    if (headerEnd < 0) return null;
    final headers = _parseHeaders(text.substring(cursor, headerEnd));
    final bodyStart = headerEnd + 4;
    final next = text.indexOf(delimiter, bodyStart);
    if (next < 0) return null;

    var bodyEnd = next;
    if (bodyEnd >= 2 &&
        text.codeUnitAt(bodyEnd - 2) == 13 &&
        text.codeUnitAt(bodyEnd - 1) == 10) {
      bodyEnd -= 2; // bỏ CRLF ngăn cách trước delimiter
    }
    parts.add(MultipartPart(headers, Uint8List.fromList(body.sublist(bodyStart, bodyEnd))));
    cursor = next + delimiter.length;
  }
}

Map<String, String> _parseHeaders(String block) {
  final headers = <String, String>{};
  for (final line in block.split('\r\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    headers[line.substring(0, separator).trim().toLowerCase()] = line
        .substring(separator + 1)
        .trim();
  }
  return headers;
}
