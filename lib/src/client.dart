import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

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
  CredflareException(this.message, this.status, [this.errors]);
  String get kind => status == 0
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

  Future<dynamic> _send(http.BaseRequest request, {String? key}) async {
    if (request.method == 'POST' &&
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
        'Could not reach CredFlare. Retry with the same request key.',
        0,
      );
    } on TimeoutException {
      throw CredflareException(
        'CredFlare timed out. Retry with the same request key.',
        0,
      );
    }
    dynamic envelope;
    try {
      envelope = jsonDecode(response.body);
    } on FormatException {
      throw CredflareException(
        'CredFlare returned an invalid response.',
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
    String type = 'documents',
    String side = 'front',
  }) async {
    if (!['documents', 'biometrics'].contains(type) ||
        !['front', 'back'].contains(side)) {
      throw ArgumentError('Invalid upload type or side.');
    }
    final request = http.MultipartRequest('POST', _url('/uploads/$type'))
      ..fields['side'] = side
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

  Future<void> cancel() async {
    await _send(http.Request('DELETE', _url()));
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}
