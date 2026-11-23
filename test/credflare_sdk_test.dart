import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late HttpServer server;
  late CredflareSession client;
  final calls = <HttpRequest>[];
  final bodies = <String>[];
  var rejectLocation = false;
  setUp(() async {
    rejectLocation = false;
    calls.clear();
    bodies.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      calls.add(request);
      final body = await utf8.decoder.bind(request).join();
      bodies.add(body);
      final path = request.uri.path;
      String field(String name) =>
          RegExp('name="$name"\r\n\r\n([^\r]*)\r\n').firstMatch(body)?[1] ?? '';
      final submitted = path.endsWith('/submit')
          ? (jsonDecode(body) as Map)['type']
          : null;
      final name = request.headers.value('authorization') == 'Bearer wrong'
          ? 'unauthorized'
          : path.endsWith('/liveness-challenges')
          ? 'liveness-challenge'
          : path.endsWith('/uploads/biometrics')
          ? switch (field('type')) {
              'gesture' => 'gesture-upload',
              'liveness_video' => 'video-upload',
              'selfie' => 'selfie-upload',
              _ => 'facial-upload',
            }
          : path.contains('/uploads/')
          ? 'upload'
          : submitted == 'facial_verification'
          ? 'facial-submission'
          : submitted == 'location_verification'
          ? (rejectLocation ? 'location-rejection' : 'location-submission')
          : path.endsWith('/submit')
          ? 'submission'
          : 'session';
      request.response.statusCode = name == 'unauthorized'
          ? 401
          : name == 'location-rejection'
          ? 422
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
    final submitKey = requestKey();
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
    }, key: submitKey);
    expect(id, 1);
    expect(calls.first.headers.value('x-idempotency-key'), key);
    expect(calls.last.headers.value('x-idempotency-key'), submitKey);
    expect(calls.first.headers.contentType!.mimeType, 'multipart/form-data');
    expect(bodies.first, contains('name="document_type_id"\r\n\r\n7\r\n'));
    expect(bodies.first, contains('name="capture_source"\r\n\r\ncamera\r\n'));
  });
  String field(String body, String name) =>
      RegExp('name="$name"\r\n\r\n([^\r]*)\r\n').firstMatch(body)?[1] ??
      '<missing>';

  test('requests a liveness challenge for the session', () async {
    final challenge = await client.createLivenessChallenge();
    final fixture = jsonDecode(
      File('test/fixtures/liveness-challenge.json').readAsStringSync(),
    )['data'];
    expect(calls.single.method, 'POST');
    expect(
      calls.single.uri.path,
      '/api/v1/sdk/sessions/00000000-0000-4000-8000-000000000001/liveness-challenges',
    );
    expect(
      calls.single.headers.value('authorization'),
      'Bearer test-session-token',
    );
    expect(challenge.id, fixture['challenge_id']);
    expect(challenge.gestures, fixture['gestures']);
    expect(challenge.recordVideo, isTrue);
    expect(challenge.maxVideoSeconds, 8);
    expect(challenge.expiresAt, DateTime.parse(fixture['expires_at']));
  });

  test('uploads gesture, video and selfie evidence for a challenge', () async {
    final keys = [requestKey(), requestKey(), requestKey()];
    final gesture = await client.uploadBiometric(
      bytes: [1, 2, 3],
      filename: 'turn_right.jpg',
      key: keys[0],
      type: BiometricUploadType.gesture,
      challengeId: 'challenge-1',
      gesture: 'turn_right',
    );
    final video = await client.uploadBiometric(
      bytes: [4, 5, 6],
      filename: 'clip.mp4',
      key: keys[1],
      type: BiometricUploadType.livenessVideo,
      challengeId: 'challenge-1',
    );
    final selfie = await client.uploadBiometric(
      bytes: [7, 8, 9],
      filename: 'selfie.jpg',
      key: keys[2],
      type: BiometricUploadType.selfie,
      challengeId: 'challenge-1',
    );
    expect([gesture, video, selfie], [3, 5, 4]);
    for (var i = 0; i < 3; i++) {
      expect(calls[i].uri.path, endsWith('/uploads/biometrics'));
      expect(calls[i].headers.contentType!.mimeType, 'multipart/form-data');
      expect(calls[i].headers.value('x-idempotency-key'), keys[i]);
      expect(field(bodies[i], 'challenge_id'), 'challenge-1');
      expect(field(bodies[i], 'capture_source'), 'camera');
      expect(bodies[i], isNot(contains('name="side"')));
      expect(bodies[i], isNot(contains('document_type_id')));
    }
    expect(field(bodies[0], 'type'), 'gesture');
    expect(field(bodies[0], 'gesture'), 'turn_right');
    expect(bodies[0], contains('filename="turn_right.jpg"'));
    expect(field(bodies[1], 'type'), 'liveness_video');
    expect(bodies[1], isNot(contains('name="gesture"')));
    expect(field(bodies[2], 'type'), 'selfie');
    expect(
      () => client.uploadBiometric(
        bytes: [1],
        filename: 'blink.jpg',
        key: requestKey(),
        type: BiometricUploadType.gesture,
        challengeId: 'challenge-1',
      ),
      throwsArgumentError,
    );
  });

  test('submits a facial verification with challenge evidence', () async {
    final key = requestKey();
    final id = await client.submitFacial(
      challengeId: 'challenge-1',
      imageFileId: 4,
      gestureFileIds: [1, 2, 3],
      videoFileId: 5,
      metadata: {
        'provider': 'mlkit',
        'liveness_results': [
          {
            'challenge': 'blink',
            'completed': true,
            'timestamp': '2026-11-20T23:04:00.000Z',
          },
        ],
        'face_detection': {
          'detected': true,
          'face_count': 1,
          'is_centered': true,
          'is_correct_size': true,
        },
        'captured_at': '2026-11-20T23:04:05.000Z',
      },
      key: key,
    );
    expect(id, 1);
    expect(calls.single.uri.path, endsWith('/submit'));
    expect(calls.single.headers.value('x-idempotency-key'), key);
    final body = jsonDecode(bodies.single) as Map;
    expect(body['type'], 'facial_verification');
    expect(body['challenge_id'], 'challenge-1');
    expect(body['image_file_id'], 4);
    expect(body['gesture_file_ids'], [1, 2, 3]);
    expect(body['video_file_id'], 5);
    expect(body['metadata']['provider'], 'mlkit');
    expect(body['metadata']['face_detection']['face_count'], 1);
  });

  LocationFix fix() => LocationFix(
    latitude: 4.0511,
    longitude: 9.7679,
    accuracy: 12.5,
    fixTime: DateTime.utc(2026, 11, 20, 23, 4),
    isMock: false,
    provider: 'fused',
    capturedAt: DateTime.utc(2026, 11, 20, 23, 4, 2),
  );

  test('submits a location fix with its metadata', () async {
    final key = requestKey();
    final id = await client.submitLocation(fix(), key: key);
    expect(id, 2);
    expect(calls.single.headers.value('x-idempotency-key'), key);
    final body = jsonDecode(bodies.single) as Map;
    expect(body, {
      'type': 'location_verification',
      'latitude': 4.0511,
      'longitude': 9.7679,
      'metadata': {
        'accuracy': 12.5,
        'altitude': null,
        'fix_time': '2026-11-20T23:04:00.000Z',
        'is_mock': false,
        'provider': 'fused',
        'captured_at': '2026-11-20T23:04:02.000Z',
      },
    });
  });

  test('surfaces a rejected location with its rejection code', () async {
    rejectLocation = true;
    final fixture = jsonDecode(
      File('test/fixtures/location-rejection.json').readAsStringSync(),
    );
    final key = requestKey();
    await expectLater(
      client.submitLocation(fix(), key: key),
      throwsA(
        isA<CredflareException>()
            .having((e) => e.status, 'status', 422)
            .having((e) => e.type, 'type', 'validation')
            .having((e) => e.message, 'message', fixture['message'])
            .having((e) => e.code, 'code', SpecErrorCode.locationAccuracy)
            .having((e) => e.hasKnownCode, 'hasKnownCode', isTrue),
      ),
    );
    expect(calls.single.headers.value('x-idempotency-key'), key);
  });

  test('reads the code of every backend rejection fixture', () async {
    for (final code in SpecErrorCode.meanings.keys) {
      final envelope = jsonDecode(
        File('test/fixtures/rejections/$code.json').readAsStringSync(),
      );
      final session = CredflareSession(
        client.descriptor,
        client: MockClient(
          (_) async => http.Response(jsonEncode(envelope), 422),
        ),
      );
      await expectLater(
        session.submitLocation(fix(), key: requestKey()),
        throwsA(
          isA<CredflareException>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.hasKnownCode, 'hasKnownCode', isTrue)
              .having((e) => e.message, 'message', envelope['message']),
        ),
      );
    }
  });

  test('keeps unknown rejection codes and tolerates missing ones', () async {
    Future<CredflareException> reject(Map<String, dynamic> envelope) async {
      final session = CredflareSession(
        client.descriptor,
        client: MockClient(
          (_) async => http.Response(jsonEncode(envelope), 422),
        ),
      );
      try {
        await session.submitLocation(fix(), key: requestKey());
      } on CredflareException catch (error) {
        return error;
      }
      throw StateError('Expected a rejection');
    }

    final base =
        jsonDecode(
              File('test/fixtures/reference-rejection.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final unknown = await reject({...base, 'code': 'location.new_rule'});
    expect(unknown.code, 'location.new_rule');
    expect(unknown.hasKnownCode, isFalse);
    final missing = await reject({...base}..remove('code'));
    expect(missing.code, isNull);
    expect(missing.hasKnownCode, isFalse);
  });

  test('requests and confirms contact codes and sends answers', () async {
    final requests = <http.Request>[];
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
            as Map<String, dynamic>;
    final session = CredflareSession(
      client.descriptor,
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        return path.endsWith('/phone-codes')
            ? http.Response(jsonEncode(read('phone-code-request')), 202)
            : path.endsWith('/email-codes')
            ? http.Response(jsonEncode(read('email-code-request')), 202)
            : path.endsWith('/confirm')
            ? http.Response(jsonEncode(read('email-code-confirm')), 201)
            : http.Response(jsonEncode(read('questionnaire-submission')), 201);
      }),
    );
    final phone = await session.requestContactCode(
      ContactChannel.phone,
      '+237650000001',
    );
    final sample = read('phone-code-request')['data'];
    expect(phone.channel, ContactChannel.phone);
    expect(phone.destination, sample['destination']);
    expect(phone.expiresAt, DateTime.parse(sample['expires_at']));
    expect(
      phone.resendAvailableAt,
      DateTime.parse(sample['resend_available_at']),
    );
    expect(phone.sendsRemaining, sample['sends_remaining']);
    final email = await session.requestContactCode(
      ContactChannel.email,
      'Jane.Doe@example.test',
    );
    expect(email.channel, ContactChannel.email);
    final confirmed = await session.confirmContactCode(
      ContactChannel.email,
      '123456',
    );
    expect(confirmed['verified'], isTrue);
    final key = requestKey();
    final id = await session.submitAnswers({'employment': 'Student'}, key: key);
    expect(id, read('questionnaire-submission')['data']['id']);
    final base = '/api/v1/sdk/sessions/${client.descriptor.id}';
    expect(requests.map((r) => r.url.path), [
      '$base/phone-codes',
      '$base/email-codes',
      '$base/email-codes/confirm',
      '$base/submit',
    ]);
    expect(jsonDecode(requests[0].body), {'phone': '+237650000001'});
    expect(jsonDecode(requests[2].body), {'code': '123456'});
    expect(jsonDecode(requests[3].body), {
      'type': 'form_submission',
      'fields': {'employment': 'Student'},
    });
    expect(requests[3].headers['X-Idempotency-Key'], key);
    expect(requests[0].headers['X-Idempotency-Key'], isNull);
    for (final r in requests) {
      expect(r.headers['Authorization'], 'Bearer test-session-token');
    }
  });

  test('reads the session status and outstanding lists', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('test/fixtures/$name.json').readAsStringSync())['data']
            as Map<String, dynamic>;
    expect(sessionOutstanding(read('questionnaire-session')), isTrue);
    expect(sessionOutstanding(read('requirement-added-session')), isTrue);
    final done = read('requirement-added-session');
    done['profile']['verification_requirements'] = [];
    expect(sessionOutstanding(done), isFalse);
    final closed = read('questionnaire-session')..['status'] = 'submitted';
    expect(sessionOutstanding(closed), isFalse);
  });

  test('reads facial and location settings with reference labels', () {
    final info =
        jsonDecode(
              File('test/fixtures/capture-session.json').readAsStringSync(),
            )['data']
            as Map<String, dynamic>;
    final requirements = verificationRequirements(info);
    expect(requirements.map((e) => e.type), [
      'facial_verification',
      'location_verification',
    ]);
    final facial = requirements.first.facial;
    expect(facial.gestureCount, 3);
    expect(facial.recordVideo, isTrue);
    expect(facial.gestures, contains('nod'));
    final location = requirements.last.location;
    expect(location.maxAccuracyM, 50);
    expect(location.maxAgeS, 60);
    expect(location.mockLocation, 'reject');
    expect(location.reference!.rule, 'within');
    expect(location.reference!.labels, ['Head office']);
    expect(location.reference!.match, 'any');
    final all = LocationReference.fromJson({
      'rule': 'outside',
      'match': 'all',
      'places': [
        {'label': 'Depot'},
        {'label': 'Port'},
      ],
    });
    expect(all.match, 'all');
    expect(all.labels, ['Depot', 'Port']);
  });

  test('fills missing requirement settings from the spec defaults', () {
    final info =
        jsonDecode(
              File('test/fixtures/facial-session.json').readAsStringSync(),
            )['data']
            as Map<String, dynamic>;
    final facial = verificationRequirements(info).single.facial;
    expect(
      facial.gestureCount,
      SpecSettings.facialVerificationGestureCountDefault,
    );
    expect(
      facial.recordVideo,
      SpecSettings.facialVerificationRecordVideoDefault,
    );
    final location = LocationRequirementSettings.fromJson(null);
    expect(location.maxAccuracyM, 100);
    expect(location.reference, isNull);
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
