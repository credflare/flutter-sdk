import 'dart:convert';
import 'dart:io';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final traces =
      Directory('test/fixtures/liveness-traces')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('every spec trace is present', () {
    expect(traces, hasLength(33));
  });

  for (final file in traces) {
    final trace = jsonDecode(file.readAsStringSync()) as Map;
    test('${file.uri.pathSegments.last}: ${trace['expect']}', () {
      final result = runTrace(trace);
      expect(result.outcome, trace['expect'], reason: trace['description']);
      if (trace['expect_status'] != null) {
        expect(result.status?.value, trace['expect_status']);
      }
    });
  }

  test('provider thresholds overwrite the defaults', () {
    expect(resolveThresholds('mlkit')['smile'], 0.7);
    expect(resolveThresholds('mediapipe')['smile'], 0.4);
    expect(resolveThresholds('unknown')['smile'], 0.6);
    expect(resolveThresholds('mlkit')['turn'], 20);
  });
}
