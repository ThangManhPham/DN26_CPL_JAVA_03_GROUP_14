/// Kiểm tra dữ liệu nhập dùng chung cho các form của M2.
library;

/// Tên hiển thị: 2–40 ký tự sau khi cắt khoảng trắng (khớp backend).
String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Vui lòng nhập tên hiển thị.';
  if (name.length < 2 || name.length > 40) return 'Tên cần từ 2 đến 40 ký tự.';
  return null;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Vui lòng nhập email.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Email chưa đúng định dạng.';
  }
  return null;
}

String? validatePassword(String? value, {required bool registering}) {
  if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
  if (registering && value.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự.';
  return null;
}

/// Mã mời: 6 ký tự thuộc bảng chữ backend dùng (bỏ các ký tự dễ nhầm).
const String inviteCodeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const int inviteCodeLength = 6;

String? validateInviteCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  if (code.isEmpty) return 'Vui lòng nhập mã mời.';
  if (code.length != inviteCodeLength) {
    return 'Mã mời gồm $inviteCodeLength ký tự.';
  }
  if (!RegExp('^[$inviteCodeAlphabet]+\$').hasMatch(code)) {
    return 'Mã mời chỉ gồm chữ và số, không có ký tự đặc biệt.';
  }
  return null;
}
