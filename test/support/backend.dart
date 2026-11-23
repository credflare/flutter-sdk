import 'dart:async';
import 'dart:convert';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fakes.dart';
import 'fixtures.dart';

Map<String, String> multipartFields(http.Request request) {
  final body = latin1.decode(request.bodyBytes);
  return {
    for (final match in RegExp(
      'name="([a-z_]+)"\r\n\r\n([^\r]*)\r\n',
    ).allMatches(body))
      match[1]!: match[2]!,
  };
}

class Backend {
  final String root;
  Backend({this.root = 'test/fixtures'});
  final requests = <RecordedRequest>[];
  final sessions = <Map<String, dynamic>>[];
  var challenges = 0;
  var nextFileId = 10;
  Map<String, dynamic>? locationRejection;
  Map<String, dynamic>? facialRejection;
  var dropNextSubmit = false;
  var failNextGet = false;
  Map<String, dynamic>? closedAfterSubmit;
  var _submitted = false;
  final codeRejections = <Map<String, dynamic>>[];
  final confirmRejections = <Map<String, dynamic>>[];
  Map<String, dynamic>? formRejection;
  Completer<void>? holdSubmit;
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    final fields = path.contains('/uploads/')
        ? multipartFields(request)
        : <String, String>{};
    requests.add(
      RecordedRequest(
        request.method,
        path,
        fields,
        path.endsWith('/submit') || path.contains('-codes')
            ? request.body
            : null,
        request.headers['X-Idempotency-Key'],
      ),
    );
    if (request.method == 'GET' && failNextGet) {
      failNextGet = false;
      throw http.ClientException('Connection reset', request.url);
    }
    if (request.method == 'GET' && _submitted && closedAfterSubmit != null) {
      return http.Response(jsonEncode(closedAfterSubmit), 409);
    }
    if (request.method == 'GET') {
      final next = sessions.length > 1 ? sessions.removeAt(0) : sessions.first;
      return http.Response(jsonEncode(next), 200);
    }
    if (path.endsWith('/liveness-challenges')) {
      challenges++;
      final raw = fixture('liveness-challenge', root: root);
      raw['data']['challenge_id'] =
          '01a1fb33-a1ee-71b2-bba9-9f484aa3bb1$challenges';
      raw['data']['expires_at'] = DateTime.now()
          .add(const Duration(minutes: 2))
          .toUtc()
          .toIso8601String();
      return http.Response(jsonEncode(raw), 201);
    }
    if (path.endsWith('/uploads/biometrics')) {
      final raw = fixture(switch (fields['type']) {
        'gesture' => 'gesture-upload',
        'liveness_video' => 'video-upload',
        _ => 'selfie-upload',
      }, root: root);
      raw['data']['id'] = nextFileId++;
      return http.Response(jsonEncode(raw), 201);
    }
    if (request.method == 'POST' &&
        (path.endsWith('/submit') || path.endsWith('-codes/confirm'))) {
      await holdSubmit?.future;
      _submitted = true;
    }
    if (path.endsWith('-codes/confirm')) {
      if (confirmRejections.isNotEmpty) {
        return http.Response(jsonEncode(confirmRejections.removeAt(0)), 422);
      }
      return http.Response(
        jsonEncode(fixture('email-code-confirm', root: root)),
        201,
      );
    }
    if (path.endsWith('-codes')) {
      if (codeRejections.isNotEmpty) {
        return http.Response(jsonEncode(codeRejections.removeAt(0)), 422);
      }
      final channel = path.endsWith('/phone-codes') ? 'phone' : 'email';
      return http.Response(
        jsonEncode(fixture('$channel-code-request', root: root)),
        202,
      );
    }
    if (dropNextSubmit) {
      dropNextSubmit = false;
      throw http.ClientException('Connection reset', request.url);
    }
    final type = jsonDecode(request.body)['type'];
    final rejection = type == 'location_verification'
        ? locationRejection
        : null;
    if (rejection != null) {
      return http.Response(jsonEncode(rejection), 422);
    }
    if (type == 'form_submission') {
      final rejected = formRejection;
      formRejection = null;
      return rejected != null
          ? http.Response(jsonEncode(rejected), 422)
          : http.Response(
              jsonEncode(fixture('questionnaire-submission', root: root)),
              201,
            );
    }
    final facial = type == 'facial_verification' ? facialRejection : null;
    if (facial != null) {
      facialRejection = null;
      return http.Response(jsonEncode(facial), 422);
    }
    return http.Response(
      jsonEncode(
        fixture(
          type == 'location_verification'
              ? 'location-submission'
              : 'facial-submission',
          root: root,
        ),
      ),
      201,
    );
  });
}

Map<String, dynamic> withRequirements(
  List<String> types, {
  String root = 'test/fixtures',
}) {
  final raw = fixture('capture-session', root: root);
  final profile = raw['data']['profile'] as Map<String, dynamic>;
  profile['verification_requirements'] = [
    for (final item in profile['verification_requirements'] as List)
      if (types.contains(item['verification_type'])) item,
  ];
  return raw;
}

SessionDescriptor descriptor() => SessionDescriptor.fromJson({
  'session_id': '01a1fb33-a1d0-7081-aa9e-7ce29c2a41d8',
  'token': 'test-session-token',
  'api_base_url': 'https://api.example.test/api/v1',
  'expires_at': '2030-01-01T00:00:00Z',
});
