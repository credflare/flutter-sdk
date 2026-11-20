import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:credflare_example/main.dart';

void main() {
  testWidgets(
    'starts the selected flow without pasting or keeping a session field',
    (tester) async {
      final raw = File(
        '../test/fixtures/capture-snapshot_and_upload.json',
      ).readAsStringSync();
      final info = jsonDecode(raw) as Map<String, dynamic>;
      String? chosenMode;
      var handoffs = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          handoffs++;
          chosenMode = (jsonDecode(request.body) as Map)['mode'] as String;
          return http.Response(
            jsonEncode({
              'session_id': info['data']['session_id'],
              'token': 'test-session-token',
              'api_base_url': 'https://api.example.test/api/v1',
              'expires_at': info['data']['expires_at'],
            }),
            200,
          );
        }
        return http.Response(raw, 200);
      });
      await tester.pumpWidget(MaterialApp(home: Example(httpClient: client)));
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Photos and files'));
      await tester.ensureVisible(find.text('Start verification'));
      await tester.tap(find.text('Start verification'));
      await tester.pumpAndSettle();
      expect(handoffs, 1);
      expect(chosenMode, 'snapshot_and_upload');
      expect(find.text('Documents requested'), findsOneWidget);
      expect(
        find.text(info['data']['requester']['name'] as String),
        findsOneWidget,
      );
      expect(find.text('Test mode'), findsOneWidget);
      expect(find.text('Secured by Credflare'), findsOneWidget);
      expect(find.text('Photo and saved file'), findsOneWidget);
      expect(find.text('Start verification'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      final name =
          info['data']['profile']['document_requirements'][0]['document_type']['name']
              as String;
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.text('Front'), findsWidgets);
      expect(find.text('Camera photo'), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose a file'), findsNothing);
      client.close();
    },
  );
}
