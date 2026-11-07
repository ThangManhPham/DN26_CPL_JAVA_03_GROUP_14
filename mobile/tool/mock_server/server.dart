// Dev mock server dùng chung cho nhiều thiết bị/cửa sổ trình duyệt.
//
// Chạy: `dart run tool/mock_server/server.dart` (từ thư mục `mobile/`).
// Mặc định lắng nghe 0.0.0.0:8080 để thiết bị khác trong cùng mạng LAN truy cập
// qua `http://<IP-LAN>:8080`.
//
// Server chỉ giữ dữ liệu trong bộ nhớ (restart là mất), dùng cho dev/demo.
// Endpoint bám theo `docs/05-api-contract.md`; KHÔNG thay thế backend thật.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import 'multipart.dart';
import 'store.dart';

const Set<String> _reactionTypes = {'LOVE', 'LIKE', 'LAUGH', 'SAD'};

/// Khởi động server và trả về [HttpServer] đang chạy.
///
/// `port = 0` để hệ điều hành chọn cổng ngẫu nhiên (dùng cho test).
Future<HttpServer> startMockServer({
  int port = 8080,
  bool verbose = true,
  MockStore? store,
}) async {
  final engine = _MockServerApi(store ?? MockStore());
  final cors = corsHeaders(
    headers: {
      ACCESS_CONTROL_ALLOW_ORIGIN: '*',
      ACCESS_CONTROL_ALLOW_HEADERS:
          'authorization, content-type, idempotency-key',
      ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      ACCESS_CONTROL_ALLOW_CREDENTIALS: 'false',
      ACCESS_CONTROL_EXPOSE_HEADERS: 'Content-Type',
    },
  );
  var pipeline = const Pipeline().addMiddleware(cors);
  if (verbose) pipeline = pipeline.addMiddleware(logRequests());
  final handler = pipeline.addHandler(engine.router.call);
  return shelf_io.serve(handler, InternetAddress.anyIPv4, port);
}

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final store = MockStore();
  store.seedUser(
    email: 'alex@ourspace.dev',
    password: 'Password123!',
    displayName: 'Alex',
  );
  store.seedUser(
    email: 'sam@ourspace.dev',
    password: 'Password123!',
    displayName: 'Sam',
  );
  final server = await startMockServer(port: port, store: store);
  stdout.writeln('OurSpace dev mock server: http://localhost:${server.port}');
  stdout.writeln('LAN (thiết bị thứ hai): http://<IP-máy-tính>:${server.port}');
  stdout.writeln(
    'Tài khoản demo: alex@ourspace.dev | sam@ourspace.dev — mật khẩu Password123!',
  );
}

class _MockServerApi {
  _MockServerApi(this.store);

  final MockStore store;
  int _requestSeed = 0;

  Router get router {
    final router = Router();

    router.post('/api/v1/auth/register', _guard(_register));
    router.post('/api/v1/auth/login', _guard(_login));
    router.get('/api/v1/users/me', _guard(_getProfile));
    router.patch('/api/v1/users/me', _guard(_updateProfile));

    router.post('/api/v1/couple-invites', _guard(_createInvite));
    router.post('/api/v1/couples/join', _guard(_joinCouple));
    router.get('/api/v1/couples/me', _guard(_getMyCouple));
    router.delete('/api/v1/couples/me', _guard(_unpair));

    router.post('/api/v1/photos', _guard(_uploadPhoto));
    // `/latest` phải đăng ký trước `/<id>` để không bị nuốt bởi route động.
    router.get('/api/v1/photos/latest', _guard(_latestPhoto));
    router.get('/api/v1/photos', _guard(_listPhotos));
    router.get('/api/v1/photos/<id>/image', _guardWithId(_photoImage));
    router.get('/api/v1/photos/<id>', _guardWithId(_photoDetail));
    router.put('/api/v1/photos/<id>/reaction', _guardWithId(_setReaction));
    router.delete('/api/v1/photos/<id>/reaction', _guardWithId(_clearReaction));

    router.all('/<ignored|.*>', _notFound);
    return router;
  }

  // ---------------------------------------------------------------- handlers

  Future<Response> _register(Request request) async {
    final body = await _readJson(request);
    final email = _string(body['email']);
    final password = _string(body['password']);
    final displayName = _string(body['displayName']);
    if (email == null || !email.contains('@') || email.trim().length < 3) {
      throw ApiFailure(422, 'VALIDATION_ERROR', 'Email is not valid.');
    }
    if (password == null || password.length < 8) {
      throw ApiFailure(
        422,
        'VALIDATION_ERROR',
        'Password must be at least 8 characters.',
      );
    }
    if (displayName == null || displayName.trim().isEmpty) {
      throw ApiFailure(422, 'VALIDATION_ERROR', 'Display name is required.');
    }
    final user = store.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    return _json(store.userJson(user), status: 201);
  }

  Future<Response> _login(Request request) async {
    final body = await _readJson(request);
    final email = _string(body['email']);
    final password = _string(body['password']);
    final user = email == null ? null : store.userByEmail(email);
    if (user == null || user.password != password) {
      throw ApiFailure(
        401,
        'INVALID_CREDENTIALS',
        'Email or password is incorrect.',
      );
    }
    return _json({
      'accessToken': store.issueToken(user),
      'tokenType': 'Bearer',
      'user': store.userJson(user),
    });
  }

  Future<Response> _getProfile(Request request) async =>
      _json(store.userJson(_requireUser(request)));

  Future<Response> _updateProfile(Request request) async {
    final user = _requireUser(request);
    final body = await _readJson(request);
    final displayName = _string(body['displayName']);
    if (displayName == null || displayName.trim().isEmpty) {
      throw ApiFailure(422, 'VALIDATION_ERROR', 'Display name is required.');
    }
    user.displayName = displayName.trim();
    return _json(store.userJson(user));
  }

  Future<Response> _createInvite(Request request) async {
    final user = _requireUser(request);
    final body = await _readJson(request);
    // Contract cho phép client gợi ý ttl; server tự quyết định (mặc định 24h).
    final ttlSeconds = (body['ttlSeconds'] as num?)?.toInt();
    final invite = store.createInvite(
      user.id,
      ttl: ttlSeconds == null
          ? null
          : Duration(seconds: ttlSeconds.clamp(1, 86400)),
    );
    return _json({
      'inviteCode': invite.code,
      'expiresAt': invite.expiresAt.toUtc().toIso8601String(),
    }, status: 201);
  }

  Future<Response> _joinCouple(Request request) async {
    final user = _requireUser(request);
    final body = await _readJson(request);
    final code = _string(body['inviteCode']);
    if (code == null || code.trim().isEmpty) {
      throw ApiFailure(422, 'VALIDATION_ERROR', 'Invite code is required.');
    }
    return _json(store.coupleJson(store.join(user.id, code)), status: 201);
  }

  Future<Response> _getMyCouple(Request request) async {
    final user = _requireUser(request);
    return _json(store.coupleJson(store.coupleOf(user.id)));
  }

  Future<Response> _unpair(Request request) async {
    final user = _requireUser(request);
    store.unpair(user.id);
    return Response(204);
  }

  Future<Response> _uploadPhoto(Request request) async {
    final user = _requireUser(request);
    final couple = store.activeCoupleOrNull(user.id);
    if (couple == null) {
      throw ApiFailure(
        409,
        'COUPLE_REQUIRED',
        'Pair with your partner before sharing photos.',
      );
    }
    final requestId = request.headers['idempotency-key'];
    if (requestId == null || requestId.trim().isEmpty) {
      throw ApiFailure(
        422,
        'VALIDATION_ERROR',
        'Idempotency-Key header is required.',
      );
    }
    final boundary = boundaryOf(request.headers['content-type']);
    if (boundary == null) {
      throw ApiFailure(
        400,
        'INVALID_PHOTO_TYPE',
        'Request must be multipart/form-data.',
      );
    }
    final raw = await _readBytes(request);
    final parts = parseMultipartBody(raw, boundary) ?? const <MultipartPart>[];
    MultipartPart? file;
    for (final part in parts) {
      if (part.name == 'file' || part.filename != null) {
        file = part;
        break;
      }
    }
    if (file == null || file.body.isEmpty) {
      throw ApiFailure(400, 'INVALID_PHOTO_SIZE', 'Photo file is required.');
    }
    if (file.body.length > MockStore.maxPhotoBytes) {
      throw ApiFailure(
        400,
        'INVALID_PHOTO_SIZE',
        'Photo must be between 1 byte and 10 MB.',
      );
    }
    final mime = _resolveMime(file.contentType, file.body);
    if (mime == null) {
      throw ApiFailure(
        400,
        'INVALID_PHOTO_TYPE',
        'Only JPEG and PNG photos are supported.',
      );
    }
    final photo = store.addPhoto(
      coupleId: couple.id,
      senderId: user.id,
      requestId: requestId.trim(),
      mimeType: mime,
      bytes: file.body,
    );
    return _json(store.photoJson(photo), status: 201);
  }

  Future<Response> _listPhotos(Request request) async {
    final user = _requireUser(request);
    final couple = store.coupleOf(user.id);
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '')?.clamp(1, 100) ??
        20;
    final cursor =
        int.tryParse(request.url.queryParameters['cursor'] ?? '') ?? 0;
    final photos = store.photosOf(couple.id);
    final start = cursor.clamp(0, photos.length);
    final end = (start + limit).clamp(start, photos.length);
    return _json({
      'items': [for (final photo in photos.sublist(start, end)) store.photoJson(photo)],
      'nextCursor': end < photos.length ? '$end' : null,
    });
  }

  Future<Response> _latestPhoto(Request request) async {
    final user = _requireUser(request);
    final couple = store.coupleOf(user.id);
    final photos = store.photosOf(couple.id);
    if (photos.isEmpty) {
      throw ApiFailure(404, 'PHOTO_NOT_FOUND', 'No photo found.');
    }
    return _json(store.photoJson(photos.first));
  }

  Future<Response> _photoDetail(Request request, String id) async {
    final user = _requireUser(request);
    return _json(store.photoJson(store.photoForViewer(user.id, id)));
  }

  Future<Response> _photoImage(Request request, String id) async {
    final user = _requireUser(request);
    final photo = store.photoForViewer(user.id, id);
    return Response.ok(
      photo.bytes,
      headers: {
        'content-type': photo.mimeType,
        'cache-control': 'private, no-store',
      },
    );
  }

  Future<Response> _setReaction(Request request, String id) async {
    final user = _requireUser(request);
    final body = await _readJson(request);
    final type = _string(body['type'])?.toUpperCase();
    if (type == null || !_reactionTypes.contains(type)) {
      throw ApiFailure(
        422,
        'VALIDATION_ERROR',
        'Reaction type must be one of LOVE, LIKE, LAUGH, SAD.',
      );
    }
    store.setReaction(viewerId: user.id, photoId: id, type: type);
    return _json(store.reactionsJson(id));
  }

  Future<Response> _clearReaction(Request request, String id) async {
    final user = _requireUser(request);
    store.clearReaction(viewerId: user.id, photoId: id);
    return _json(store.reactionsJson(id));
  }

  Response _notFound(Request request) =>
      _error(404, 'NOT_FOUND', 'No route matched ${request.url.path}.');

  // ----------------------------------------------------------------- helpers

  Handler _guard(FutureOr<Response> Function(Request request) handler) =>
      (Request request) => _run(() => handler(request));

  Function _guardWithId(
    FutureOr<Response> Function(Request request, String id) handler,
  ) =>
      (Request request, String id) => _run(() => handler(request, id));

  Future<Response> _run(FutureOr<Response> Function() action) async {
    try {
      return await action();
    } on ApiFailure catch (failure) {
      return _error(failure.status, failure.code, failure.message);
    } on FormatException {
      return _error(400, 'VALIDATION_ERROR', 'Malformed request body.');
    } catch (_) {
      return _error(500, 'INTERNAL_ERROR', 'Unexpected server error.');
    }
  }

  MockUser _requireUser(Request request) {
    final header = request.headers['authorization'];
    final token = header != null && header.toLowerCase().startsWith('bearer ')
        ? header.substring(7).trim()
        : null;
    final user = store.userById(store.userIdFromToken(token));
    if (user == null) {
      throw ApiFailure(
        401,
        'UNAUTHORIZED',
        'A valid Bearer token is required.',
      );
    }
    return user;
  }

  Future<Map<String, dynamic>> _readJson(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Body must be a JSON object.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Uint8List> _readBytes(Request request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static String? _string(Object? value) => value is String ? value : null;

  /// Ưu tiên `Content-Type` của part nhưng phải khớp chữ ký bytes.
  static String? _resolveMime(String? declared, Uint8List bytes) {
    final detected = _detectMime(bytes);
    if (detected == null) return null;
    if (declared == null || declared.isEmpty) return detected;
    return declared.contains(detected) ? detected : null;
  }

  static String? _detectMime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    return null;
  }

  Response _json(Object? data, {int status = 200}) => Response(
    status,
    body: jsonEncode(data),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  Response _error(int status, String code, String message) => _json({
    'code': code,
    'message': message,
    'details': const <String, dynamic>{},
    'requestId': 'req_${++_requestSeed}',
  }, status: status);
}
