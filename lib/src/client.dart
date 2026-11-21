import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'spec.generated.dart';

class SessionDescriptor {
  final String id;
  final String token;
  final Uri apiBase;
  final DateTime expiresAt;

  SessionDescriptor.fromJson(Map<String, dynamic> json)
    : id = json['session_id'] as String,
      token = json['token'] as String,
      apiBase = Uri.parse(json['api_base_url'] as String),
      expiresAt = DateTime.parse(json['expires_at'] as String) {
    final local = ['localhost', '127.0.0.1', '::1'].contains(apiBase.host);
    if ((apiBase.scheme != 'https' && !(local && apiBase.scheme == 'http')) ||
        apiBase.userInfo.isNotEmpty ||
        apiBase.hasQuery ||
        apiBase.hasFragment ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        token.isEmpty) {
      throw ArgumentError('Invalid session descriptor or API URL.');
    }
  }
}

class CredflareException implements Exception {
  final String message;
  final int status;
  final Object? errors;
  final String? code;
  CredflareException(this.message, this.status, [this.errors, this.code]);
  bool get hasKnownCode => SpecErrorCode.meanings.containsKey(code);
  String get type => status == 0
      ? 'network'
      : status == 401
      ? 'session_unavailable'
      : status == 409
      ? 'verification_closed'
      : status == 422
      ? 'validation'
      : 'api';
  @override
  String toString() => message;
}

String requestKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class CredflareSession {
  SessionDescriptor descriptor;
  final http.Client _http;
  final bool _ownsClient;
  CredflareSession(this.descriptor, {http.Client? client})
    : _http = client ?? http.Client(),
      _ownsClient = client == null;

  void replaceSession(SessionDescriptor next) {
    if (next.apiBase != descriptor.apiBase) {
      throw ArgumentError('A replacement session must use the same API.');
    }
    descriptor = next;
  }

  Future<dynamic> _send(
    http.BaseRequest request, {
    String? key,
    bool keyed = true,
  }) async {
    if (request.method == 'POST' &&
        keyed &&
        !RegExp(
          r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
        ).hasMatch(key ?? '')) {
      throw ArgumentError(
        'A UUID request key is required for uploads and submissions.',
      );
    }
    request.followRedirects = false;
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer ${descriptor.token}',
    });
    if (key != null) request.headers['X-Idempotency-Key'] = key;
    late http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request),
      ).timeout(const Duration(seconds: 60));
    } on http.ClientException {
      throw CredflareException(
        'Could not reach Credflare. Retry with the same request key.',
        0,
      );
    } on TimeoutException {
      throw CredflareException(
        'Credflare timed out. Retry with the same request key.',
        0,
      );
    }
    dynamic envelope;
    try {
      envelope = jsonDecode(response.body);
    } on FormatException {
      throw CredflareException(
        'Credflare returned an invalid response.',
        response.statusCode,
      );
    }
    if (envelope is! Map<String, dynamic> ||
        envelope['success'] != true ||
        response.statusCode >= 300) {
      throw CredflareException(
        envelope is Map
            ? envelope['message'] as String? ?? 'Request failed.'
            : 'Invalid response.',
        response.statusCode,
        envelope is Map ? envelope['errors'] : null,
        envelope is Map && envelope['code'] is String
            ? envelope['code'] as String
            : null,
      );
    }
    return envelope['data'];
  }

  Uri _url([String suffix = '']) => Uri.parse(
    '${descriptor.apiBase.toString().replaceFirst(RegExp(r'/$'), '')}/sdk/sessions/${descriptor.id}$suffix',
  );

  Future<Map<String, dynamic>> get() async => Map<String, dynamic>.from(
    await _send(http.Request('GET', _url())) as Map,
  );

  Future<Map<String, dynamic>> upload({
    required List<int> bytes,
    required String filename,
    required String key,
    int? documentTypeId,
    String type = 'documents',
    String side = 'front',
    String source = 'upload',
  }) async {
    if (!['documents', 'biometrics'].contains(type) ||
        !['front', 'back'].contains(side)) {
      throw ArgumentError('Invalid upload type or side.');
    }
    final request = http.MultipartRequest('POST', _url('/uploads/$type'))
      ..fields.addAll({
        if (documentTypeId != null) 'document_type_id': '$documentTypeId',
      })
      ..fields['side'] = side
      ..fields['capture_source'] = source
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    return Map<String, dynamic>.from(await _send(request, key: key) as Map);
  }

  Future<int> submit(
    Map<String, dynamic> submission, {
    required String key,
  }) async {
    final request = http.Request('POST', _url('/submit'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(submission);
    final result = await _send(request, key: key) as Map;
    return result['id'] as int;
  }

  Future<LivenessChallenge> createLivenessChallenge() async {
    final data = await _send(
      http.Request('POST', _url('/liveness-challenges')),
      keyed: false,
    );
    return LivenessChallenge.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<int> uploadBiometric({
    required List<int> bytes,
    required String filename,
    required String key,
    required BiometricUploadType type,
    required String challengeId,
    String? gesture,
  }) async {
    if ((type == BiometricUploadType.gesture) != (gesture != null)) {
      throw ArgumentError(
        'A gesture name is required for gesture frames only.',
      );
    }
    final request = http.MultipartRequest('POST', _url('/uploads/biometrics'))
      ..fields['type'] = type.value
      ..fields['challenge_id'] = challengeId
      ..fields['capture_source'] = 'camera';
    if (gesture != null) request.fields['gesture'] = gesture;
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final data = await _send(request, key: key) as Map;
    return data['id'] as int;
  }

  Future<int> submitFacial({
    required String challengeId,
    required int imageFileId,
    required List<int> gestureFileIds,
    int? videoFileId,
    required Map<String, dynamic> metadata,
    required String key,
  }) => submit({
    'type': 'facial_verification',
    'challenge_id': challengeId,
    'image_file_id': imageFileId,
    'gesture_file_ids': gestureFileIds,
    'video_file_id': ?videoFileId,
    'metadata': metadata,
  }, key: key);

  Future<int> submitLocation(LocationFix fix, {required String key}) =>
      submit(fix.toSubmission(), key: key);

  Future<void> cancel() async {
    await _send(http.Request('DELETE', _url()));
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}

enum BiometricUploadType {
  gesture('gesture'),
  livenessVideo('liveness_video'),
  selfie('selfie');

  final String value;
  const BiometricUploadType(this.value);
}

class LivenessChallenge {
  final String id;
  final List<String> gestures;
  final DateTime expiresAt;
  final bool recordVideo;
  final int maxVideoSeconds;
  const LivenessChallenge({
    required this.id,
    required this.gestures,
    required this.expiresAt,
    required this.recordVideo,
    required this.maxVideoSeconds,
  });

  factory LivenessChallenge.fromJson(Map<String, dynamic> json) =>
      LivenessChallenge(
        id: json['challenge_id'] as String,
        gestures: (json['gestures'] as List).cast<String>(),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        recordVideo: json['record_video'] as bool? ?? false,
        maxVideoSeconds: (json['max_video_seconds'] as num?)?.toInt() ?? 0,
      );
}

class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final DateTime fixTime;
  final bool? isMock;
  final String provider;
  final DateTime capturedAt;
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.fixTime,
    required this.provider,
    required this.capturedAt,
    this.altitude,
    this.isMock,
  });

  Map<String, dynamic> toSubmission() => {
    'type': 'location_verification',
    'latitude': latitude,
    'longitude': longitude,
    'metadata': {
      'accuracy': accuracy,
      'altitude': altitude,
      'fix_time': fixTime.toUtc().toIso8601String(),
      'is_mock': isMock,
      'provider': provider,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    },
  };
}
