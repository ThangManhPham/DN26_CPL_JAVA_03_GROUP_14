import 'package:web/web.dart' as web;

/// Bản thực thi cho Web: dùng window.localStorage.
void saveToLocalStorage(String key, String value) {
  web.window.localStorage.setItem(key, value);
}

String? loadFromLocalStorage(String key) => web.window.localStorage.getItem(key);
