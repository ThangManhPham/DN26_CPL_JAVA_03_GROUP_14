import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../tool/mock_server/server.dart';
import '../../tool/mock_server/store.dart';

/// PNG 1x1 hợp lệ để server nhận diện đúng chữ ký ảnh.
final Uint8List kPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
]);

/// Kịch bản end-to-end trên dev mock server: hai "thiết bị" (A/B) cùng truy cập
/// một nguồn dữ liệu nên mã mời và ảnh chia sẻ được cho nhau (BƯỚC 4).
void main() {
  late HttpServer server;
  late MockStore store;
  late Uri base;
  final http.Client client = http.Client();

  setUp(() async {
    store = MockStore();
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
    server = await startMockServer(port: 0, verbose: false, store: store);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
  });

  Map<String, String> headers(String? token) => {
    'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  };

  Future<http.Response> post(String path, {Object? body, String? token}) =>
      client.post(
        base.resolve(path),
        headers: headers(token),
        body: body == null ? null : jsonEncode(body),
      );

  Future<http.Response> put(String path, {Object? body, String? token}) =>
      client.put(
        base.resolve(path),
        headers: headers(token),
        body: body == null ? null : jsonEncode(body),
      );

  Future<http.Response> get(String path, {String? token}) => client.get(
    base.resolve(path),
    headers: headers(token),
  );

  Future<http.Response> delete(String path, {String? token}) => client.delete(
    base.resolve(path),
    headers: headers(token),
  );

  Future<String> login(String email) async {
    final response = await post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': 'Password123!'},
    );
    expect(response.statusCode, 200, reason: response.body);
    return (jsonDecode(response.body) as Map<String, dynamic>)['accessToken']
        as String;
  }

  Future<String> registerAndLogin(String email, String displayName) async {
    final register = await post(
      '/api/v1/auth/register',
      body: {
        'email': email,
        'password': 'Password123!',
        'displayName': displayName,
      },
    );
    expect(register.statusCode, 201, reason: register.body);
    return login(email);
  }

  Future<http.Response> upload(
    String token,
    String requestId, [
    List<int> bytes = const <int>[],
  ]) async {
    final request =
        http.MultipartRequest('POST', base.resolve('/api/v1/photos'))
          ..headers['authorization'] = 'Bearer $token'
          ..headers['idempotency-key'] = requestId
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes.isEmpty ? kPng : bytes,
              filename: 'photo.png',
              contentType: MediaType('image', 'png'),
            ),
          );
    return http.Response.fromStream(await request.send());
  }

  Map<String, dynamic> json(http.Response response) =>
      jsonDecode(response.body) as Map<String, dynamic>;

  String codeOf(http.Response response) => json(response)['code'] as String;

  /// Ghép đôi A và B qua mã mời; trả về token của cả hai.
  Future<({String a, String b})> pair() async {
    final tokenA = await login('alex@ourspace.dev');
    final tokenB = await login('sam@ourspace.dev');
    final invite = await post('/api/v1/couple-invites', token: tokenA);
    expect(invite.statusCode, 201, reason: invite.body);
    final join = await post(
      '/api/v1/couples/join',
      body: {'inviteCode': json(invite)['inviteCode']},
      token: tokenB,
    );
    expect(join.statusCode, 201, reason: join.body);
    return (a: tokenA, b: tokenB);
  }

  test('A tạo mã mời, B nhập mã ghép đôi thành công trên cùng nguồn dữ liệu', () async {
    final tokenA = await login('alex@ourspace.dev');
    final tokenB = await login('sam@ourspace.dev');

    final invite = await post('/api/v1/couple-invites', token: tokenA);
    expect(invite.statusCode, 201);
    final inviteCode = json(invite)['inviteCode'] as String;
    expect(inviteCode.length, 6);

    final join = await post(
      '/api/v1/couples/join',
      body: {'inviteCode': inviteCode},
      token: tokenB,
    );
    expect(join.statusCode, 201, reason: join.body);
    expect((json(join)['members'] as List).length, 2);

    final coupleOfA = await get('/api/v1/couples/me', token: tokenA);
    final coupleOfB = await get('/api/v1/couples/me', token: tokenB);
    expect(coupleOfA.statusCode, 200);
    expect(json(coupleOfA)['id'], json(join)['id']);
    expect(json(coupleOfB)['id'], json(join)['id']);
  });

  test('mã mời đã dùng lại bị từ chối với INVALID_INVITE_CODE', () async {
    final tokenA = await login('alex@ourspace.dev');
    final tokenB = await login('sam@ourspace.dev');
    final invite = await post('/api/v1/couple-invites', token: tokenA);
    final inviteCode = json(invite)['inviteCode'] as String;

    final first = await post(
      '/api/v1/couples/join',
      body: {'inviteCode': inviteCode},
      token: tokenB,
    );
    expect(first.statusCode, 201, reason: first.body);

    final tokenC = await registerAndLogin('carol@ourspace.dev', 'Carol');
    final reused = await post(
      '/api/v1/couples/join',
      body: {'inviteCode': inviteCode},
      token: tokenC,
    );
    expect(reused.statusCode, 400);
    expect(codeOf(reused), 'INVALID_INVITE_CODE');
  });

  test('người đã có couple không tạo được mã mới (ALREADY_PAIRED)', () async {
    final paired = await pair();
    final invite = await post('/api/v1/couple-invites', token: paired.a);
    expect(invite.statusCode, 409);
    expect(codeOf(invite), 'ALREADY_PAIRED');
  });

  test('không thể tự ghép đôi với chính mình (CANNOT_PAIR_SELF)', () async {
    final tokenA = await login('alex@ourspace.dev');
    final invite = await post('/api/v1/couple-invites', token: tokenA);
    final inviteCode = json(invite)['inviteCode'] as String;

    final join = await post(
      '/api/v1/couples/join',
      body: {'inviteCode': inviteCode},
      token: tokenA,
    );
    expect(join.statusCode, 400);
    expect(codeOf(join), 'CANNOT_PAIR_SELF');
  });

  test('mã mời hết hạn bị từ chối với INVITE_EXPIRED', () async {
    final alex = store.userByEmail('alex@ourspace.dev')!;
    final expired = store.createInvite(alex.id, ttl: const Duration(seconds: -5));
    final tokenB = await login('sam@ourspace.dev');

    final join = await post(
      '/api/v1/couples/join',
      body: {'inviteCode': expired.code},
      token: tokenB,
    );
    expect(join.statusCode, 400);
    expect(codeOf(join), 'INVITE_EXPIRED');
  });

  test('A gửi ảnh: cả A và B đều thấy ảnh, mới nhất đứng đầu', () async {
    final paired = await pair();

    final firstUpload = await upload(paired.a, 'req-a1');
    expect(firstUpload.statusCode, 201, reason: firstUpload.body);
    final photoA = json(firstUpload);
    expect(photoA['senderDisplayName'], 'Alex');

    final secondUpload = await upload(paired.b, 'req-b1');
    expect(secondUpload.statusCode, 201, reason: secondUpload.body);
    final photoB = json(secondUpload);

    final listA = json(await get('/api/v1/photos', token: paired.a));
    final listB = json(await get('/api/v1/photos', token: paired.b));
    final idsOfA = (listA['items'] as List)
        .map((item) => (item as Map)['id'])
        .toList();
    final idsOfB = (listB['items'] as List)
        .map((item) => (item as Map)['id'])
        .toList();

    expect(idsOfA, contains(photoA['id']));
    expect(idsOfA, contains(photoB['id']));
    expect(idsOfB, contains(photoA['id']));
    expect(idsOfB, contains(photoB['id']));
    // Ảnh mới nhất lên đầu feed.
    expect(idsOfA.first, photoB['id']);
    expect(listA['nextCursor'], isNull);

    // Người được ghép tải được đúng bytes ảnh của người kia qua endpoint có xác thực.
    final image = await get(
      '/api/v1/photos/${photoA['id']}/image',
      token: paired.b,
    );
    expect(image.statusCode, 200);
    expect(image.bodyBytes, kPng);
  });

  test('phân trang cursor trả đúng items và nextCursor', () async {
    final paired = await pair();
    for (final requestId in ['req-1', 'req-2', 'req-3']) {
      final response = await upload(paired.a, requestId);
      expect(response.statusCode, 201, reason: response.body);
    }

    final pageOne = json(
      await get('/api/v1/photos?limit=2', token: paired.a),
    );
    expect((pageOne['items'] as List).length, 2);
    expect(pageOne['nextCursor'], '2');

    final pageTwo = json(
      await get('/api/v1/photos?limit=2&cursor=2', token: paired.a),
    );
    expect((pageTwo['items'] as List).length, 1);
    expect(pageTwo['nextCursor'], isNull);
  });

  test('người ngoài couple không xem được ảnh (403/404)', () async {
    final paired = await pair();
    final photo = json(await upload(paired.a, 'req-private'));
    final tokenC = await registerAndLogin('outsider@ourspace.dev', 'Outsider');

    expect((await get('/api/v1/photos', token: tokenC)).statusCode, 404);
    expect(
      (await get('/api/v1/photos/${photo['id']}', token: tokenC)).statusCode,
      404,
    );
    expect(
      (await get('/api/v1/photos/${photo['id']}/image', token: tokenC))
          .statusCode,
      404,
    );
    expect((await get('/api/v1/photos')).statusCode, 401);
  });

  test('reaction của B được A nhìn thấy và bỏ được', () async {
    final paired = await pair();
    final photo = json(await upload(paired.a, 'req-react'));

    final set = await put(
      '/api/v1/photos/${photo['id']}/reaction',
      body: {'type': 'LOVE'},
      token: paired.b,
    );
    expect(set.statusCode, 200, reason: set.body);

    final detail = json(
      await get('/api/v1/photos/${photo['id']}', token: paired.a),
    );
    expect(
      (detail['reactions'] as List).any((item) => item['type'] == 'LOVE'),
      isTrue,
    );

    final clear = await delete(
      '/api/v1/photos/${photo['id']}/reaction',
      token: paired.b,
    );
    expect(clear.statusCode, 200);
    final after = json(
      await get('/api/v1/photos/${photo['id']}', token: paired.a),
    );
    expect(after['reactions'] as List, isEmpty);
  });
}
