import 'dart:convert';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/backend.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
}

void main() {
  testWidgets(
    'runs the server challenge, uploads its evidence, then collects location',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final backend = Backend()
        ..sessions.addAll([
          withRequirements(['facial_verification', 'location_verification']),
          withRequirements(['location_verification']),
          fixture('facial-complete'),
        ]);
      final sources = <FakeLivenessSource>[];
      final location = FakeLocationSource([
        () => locationFix(accuracy: 400),
        () => locationFix(accuracy: 20),
      ]);
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: CredflareVerification(
            autoStart: true,
            onClose: () {},
            onSubmitted: (info) => submitted = info,
            httpClient: backend.client,
            sessionProvider: () async => descriptor(),
            livenessSource: () {
              final source = FakeLivenessSource();
              sources.add(source);
              return source;
            },
            locationSource: location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(copy(SpecCopyKey.livenessTitle)), findsOneWidget);
      expect(
        find.text(
          copy(SpecCopyKey.videoConsent, {
            'verifier': "Meghan Stiedemann MD's Workspace",
          }),
        ),
        findsOneWidget,
      );
      await tapText(tester, copy(SpecCopyKey.livenessStart));
      await tester.pump();
      await tester.pump();
      expect(backend.challenges, 1);
      final source = sources.single;
      expect(source.started, isTrue);

      source.play('position_ok_pass');
      await tester.pump();
      expect(find.text(copy(SpecCopyKey.livenessGestureBlink)), findsOneWidget);
      expect(
        find.text(
          copy(SpecCopyKey.livenessProgress, {'current': 1, 'total': 3}),
        ),
        findsOneWidget,
      );
      expect(source.events, contains('record'));
      source.play('blink_pass');
      await tester.pump();
      expect(find.text(copy(SpecCopyKey.livenessGestureSmile)), findsOneWidget);
      source.play('smile_pass');
      await tester.pump();
      expect(
        find.text(copy(SpecCopyKey.livenessGestureTurnRight)),
        findsOneWidget,
      );
      source.play('turn_right_pass');
      await tester.pumpAndSettle();
      expect(find.text(copy(SpecCopyKey.selfieReviewTitle)), findsOneWidget);
      expect(source.events.where((event) => event == 'frame'), hasLength(3));
      expect(source.events, containsAllInOrder(['stop', 'selfie', 'dispose']));

      await tapText(tester, copy(SpecCopyKey.selfieSend));
      await tester.pumpAndSettle();
      final uploads = backend.requests
          .where((r) => r.path.endsWith('/uploads/biometrics'))
          .toList();
      expect(uploads.map((r) => r.fields['type']), [
        'gesture',
        'gesture',
        'gesture',
        'liveness_video',
        'selfie',
      ]);
      expect(uploads.take(3).map((r) => r.fields['gesture']), [
        'blink',
        'smile',
        'turn_right',
      ]);
      for (final upload in uploads) {
        expect(upload.fields['capture_source'], 'camera');
        expect(
          upload.fields['challenge_id'],
          '01a1fb33-a1ee-71b2-bba9-9f484aa3bb11',
        );
      }
      final facial =
          jsonDecode(
                backend.requests
                    .lastWhere((r) => r.path.endsWith('/submit'))
                    .body!,
              )
              as Map;
      expect(facial['type'], 'facial_verification');
      expect(facial['challenge_id'], '01a1fb33-a1ee-71b2-bba9-9f484aa3bb11');
      expect(facial['gesture_file_ids'], [10, 11, 12]);
      expect(facial['video_file_id'], 13);
      expect(facial['image_file_id'], 14);
      expect(facial['metadata']['provider'], 'default');
      expect(
        (facial['metadata']['liveness_results'] as List).map(
          (e) => e['challenge'],
        ),
        ['blink', 'smile', 'turn_right'],
      );
      expect(facial['metadata']['face_detection']['face_count'], 1);

      expect(
        find.text(
          copy(SpecCopyKey.locationPlaceTitleWithin, {'place': 'Head office'}),
        ),
        findsOneWidget,
      );
      await tapText(tester, copy(SpecCopyKey.locationShare));
      await tester.pumpAndSettle();
      expect(location.requests, 2);
      expect(find.text(copy(SpecCopyKey.locationFoundTitle)), findsOneWidget);
      expect(
        find.text(copy(SpecCopyKey.locationAccuracyValue, {'meters': 20})),
        findsOneWidget,
      );
      await tapText(tester, copy(SpecCopyKey.locationSend));
      await tester.pumpAndSettle();
      final sent =
          jsonDecode(
                backend.requests
                    .lastWhere((r) => r.path.endsWith('/submit'))
                    .body!,
              )
              as Map;
      expect(sent['type'], 'location_verification');
      expect(sent['metadata']['accuracy'], 20);
      expect(sent['metadata']['is_mock'], false);
      expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
      expect(find.text(copy(SpecCopyKey.receiptSelfie)), findsOneWidget);
      expect(find.text(copy(SpecCopyKey.receiptLocation)), findsOneWidget);
      expect(submitted, isNotNull);
    },
  );

  testWidgets('a timed out movement asks the server for a new challenge', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(withRequirements(['facial_verification']));
    final sources = <FakeLivenessSource>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
          livenessSource: () {
            final source = FakeLivenessSource();
            sources.add(source);
            return source;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.livenessStart));
    await tester.pump();
    await tester.pump();
    sources.last.play('position_ok_pass');
    await tester.pump();
    sources.last.play('blink_timeout');
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.livenessTimeout)), findsOneWidget);
    expect(sources.last.events, contains('dispose'));
    await tapText(tester, copy(SpecCopyKey.livenessRetry));
    await tester.pump();
    await tester.pump();
    expect(backend.challenges, 2);
    expect(sources, hasLength(2));
    expect(
      backend.requests.where((r) => r.path.contains('/uploads/')),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a place mismatch names the place and offers a retry', (
    tester,
  ) async {
    final backend = Backend()
      ..rejectLocation = true
      ..sessions.add(withRequirements(['location_verification']));
    final location = FakeLocationSource([() => locationFix()]);
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
          locationSource: location,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        copy(SpecCopyKey.locationPlaceTitleWithin, {'place': 'Head office'}),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        copy(SpecCopyKey.locationPlaceNeedWithin, {'place': 'Head office'}),
      ),
      findsNothing,
    );
    await tapText(tester, copy(SpecCopyKey.locationShare));
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationSend));
    await tester.pumpAndSettle();
    expect(
      find.text(
        copy(SpecCopyKey.locationPlaceNotMatchedWithin, {
          'place': 'Head office',
        }),
      ),
      findsOneWidget,
    );
    expect(
      fixture('reference-rejection')['message'],
      referenceRejectionMessage,
    );
    expect(find.text(copy(SpecCopyKey.locationRetry)), findsOneWidget);
  });

  testWidgets('a mocked location is refused before it is sent', (tester) async {
    final backend = Backend()
      ..sessions.add(withRequirements(['location_verification']));
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
          locationSource: FakeLocationSource([() => locationFix(isMock: true)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationShare));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.locationMockDetected)), findsOneWidget);
    expect(backend.requests.where((r) => r.path.endsWith('/submit')), isEmpty);
  });

  testWidgets('denied location access explains how to turn it on', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(withRequirements(['location_verification']));
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
          locationSource: FakeLocationSource([
            () => locationFix(),
          ], access: LocationAccess.denied),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationShare));
    await tester.pumpAndSettle();
    expect(
      find.text(copy(SpecCopyKey.locationPermissionDenied)),
      findsOneWidget,
    );
  });

  testWidgets('the documents list names the steps the SDK runs next', (
    tester,
  ) async {
    Future<void> show(List<String> types, {bool form = false}) async {
      final raw = withRequirements(types);
      final profile = raw['data']['profile'] as Map<String, dynamic>;
      profile['document_requirements'] = fixture(
        'session',
      )['data']['profile']['document_requirements'];
      profile['form_schema'] = form
          ? fixture('session')['data']['profile']['form_schema']
          : null;
      final backend = Backend()..sessions.add(raw);
      await tester.pumpWidget(
        MaterialApp(
          home: CredflareVerification(
            key: UniqueKey(),
            autoStart: true,
            onClose: () {},
            httpClient: backend.client,
            sessionProvider: () async => descriptor(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final lines = [
      SpecCopyKey.documentsSelfieNext,
      SpecCopyKey.documentsLocationNext,
      SpecCopyKey.documentsSelfieLocationNext,
      SpecCopyKey.documentsLocationSelfieNext,
      SpecCopyKey.documentsHostStepsNext,
    ].map(copy).toList();
    void only(String? expected) {
      for (final line in lines) {
        expect(
          find.text(line),
          line == expected ? findsOneWidget : findsNothing,
          reason: line,
        );
      }
    }

    await show(['facial_verification', 'location_verification'], form: true);
    only(copy(SpecCopyKey.documentsSelfieLocationNext));
    await show(['location_verification']);
    only(copy(SpecCopyKey.documentsLocationNext));
    await show(['facial_verification']);
    only(copy(SpecCopyKey.documentsSelfieNext));
    await show([], form: true);
    only(copy(SpecCopyKey.documentsHostStepsNext));
    await show([]);
    only(null);
  });
}
