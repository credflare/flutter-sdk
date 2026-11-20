import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:credflare_sdk/credflare_sdk.dart';

void main() {
  late HttpServer server;
  late CredflareSession client;
  final calls = <HttpRequest>[];
  final bodies = <String>[];
  setUp(() async {
    calls.clear();
    bodies.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      calls.add(request);
      final name = request.uri.path.endsWith('/submit')
          ? 'submission'
          : request.uri.path.contains('/uploads/')
          ? 'upload'
          : request.headers.value('authorization') == 'Bearer wrong'
          ? 'unauthorized'
          : 'session';
      bodies.add(await utf8.decoder.bind(request).join());
      request.response.statusCode = name == 'unauthorized'
          ? 401
          : name == 'session'
          ? 200
          : 201;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        await File('test/fixtures/$name.json').readAsString(),
      );
      await request.response.close();
    });
    client = CredflareSession(
      SessionDescriptor.fromJson({
        'session_id': '00000000-0000-4000-8000-000000000001',
        'token': 'test-session-token',
        'api_base_url': 'http://127.0.0.1:${server.port}/api/v1',
        'expires_at': '2030-01-01T00:00:00Z',
      }),
    );
  });
  tearDown(() async {
    client.close();
    await server.close(force: true);
  });
  test('loads the captured API response over HTTP', () async {
    final info = await client.get();
    expect((info['profile'] as Map)['document_requirements'], hasLength(1));
    expect(
      calls.single.headers.value('authorization'),
      'Bearer test-session-token',
    );
  });
  test('uploads and submits with stable request keys', () async {
    final key = requestKey();
    final file = await client.upload(
      bytes: [1, 2, 3],
      filename: 'front.png',
      key: key,
      documentTypeId: 7,
      source: 'camera',
    );
    final id = await client.submit({
      'type': 'document_verification',
      'document_type_id': 1,
      'file_id': file['id'],
    }, key: requestKey());
    expect(id, 1);
    expect(calls.first.headers.value('x-idempotency-key'), key);
    expect(calls.first.headers.contentType!.mimeType, 'multipart/form-data');
    expect(bodies.first, contains('name="document_type_id"\r\n\r\n7\r\n'));
    expect(bodies.first, contains('name="capture_source"\r\n\r\ncamera\r\n'));
  });
  test('sends selfies through biometric uploads with camera source', () async {
    final uploaded = await client.upload(
      bytes: [1, 2, 3],
      filename: 'selfie.jpg',
      key: requestKey(),
      type: 'biometrics',
      source: 'camera',
    );
    await client.submit({
      'type': 'facial_verification',
      'image_file_id': uploaded['id'],
    }, key: requestKey());
    expect(calls.first.uri.path, endsWith('/uploads/biometrics'));
    expect(bodies.first, contains('name="capture_source"\r\n\r\ncamera\r\n'));
    expect(bodies.first, isNot(contains('document_type_id')));
    expect(jsonDecode(bodies.last)['type'], 'facial_verification');
  });
  test('rejects remote HTTP API destinations', () {
    expect(
      () => SessionDescriptor.fromJson({
        'session_id': '00000000-0000-4000-8000-000000000001',
        'token': 'test-session-token',
        'api_base_url': 'http://example.test/api/v1',
        'expires_at': '2030-01-01T00:00:00Z',
      }),
      throwsArgumentError,
    );
  });
  test('uses UUID request keys', () {
    expect(
      requestKey(),
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
  });
  test(
    'a failed host session provider clears loading and shares concurrent calls',
    () async {
      final pending = Completer<SessionDescriptor>();
      var calls = 0;
      final controller = CredflareSessionController(
        provider: () {
          calls++;
          return pending.future;
        },
      );
      final first = controller.load();
      final second = controller.load();
      expect(identical(first, second), isTrue);
      expect(calls, 1);
      expect(controller.loading, isTrue);
      final check = expectLater(first, throwsStateError);
      pending.completeError(StateError('Host backend refused a new session.'));
      await check;
      expect(controller.loading, isFalse);
      expect(controller.error, isA<StateError>());
      controller.dispose();
    },
  );
}
