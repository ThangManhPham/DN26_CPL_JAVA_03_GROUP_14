import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adapter Dio giả để test interceptor/repository mà không cần HTTP server.
class FakeDioAdapter implements HttpClientAdapter {
  FakeDioAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  /// Mọi request đã đi qua, dùng để kiểm tra header/query/body.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody bytesBody(List<int> bytes, int statusCode) => ResponseBody.fromBytes(
  bytes,
  statusCode,
  headers: {
    Headers.contentTypeHeader: ['image/png'],
  },
);
