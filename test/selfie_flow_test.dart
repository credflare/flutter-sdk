import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:credflare_sdk/credflare_sdk.dart';

void main() {
  testWidgets('server-required selfie has no profile or file selection', (
    tester,
  ) async {
    final raw = File('test/fixtures/facial-session.json').readAsStringSync();
    final data = jsonDecode(raw)['data'] as Map<String, dynamic>;
    final client = MockClient((request) async => http.Response(raw, 200));
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          httpClient: client,
          sessionProvider: () async => SessionDescriptor.fromJson({
            'session_id': data['session_id'],
            'token': 'test-session-token',
            'api_base_url': 'https://api.example.test/api/v1',
            'expires_at': data['expires_at'],
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Take a selfie'), findsOneWidget);
    expect(find.text('Open front camera'), findsOneWidget);
    expect(find.text('Choose a file'), findsNothing);
    expect(find.text('Evidence received'), findsNothing);
    expect(find.byType(DropdownButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
}
