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

final uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

List<String> challengeGestures() =>
    (fixture('liveness-challenge')['data']['gestures'] as List).cast<String>();

Future<void> recordChallenge(
  WidgetTester tester,
  FakeLivenessSource Function() last, {
  String button = SpecCopyKey.livenessStart,
}) async {
  await tapText(tester, copy(button));
  await tester.pump();
  await tester.pump();
  for (final trace in [
    'position_ok_pass',
    for (final gesture in challengeGestures()) '${gesture}_pass',
  ]) {
    last().play(trace);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Widget facialApp(Backend backend, List<FakeLivenessSource> sources) =>
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
    );

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
            'verifier': verifierName(fixture('capture-session')['data']),
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
      final gestures = challengeGestures();
      for (var i = 0; i < gestures.length; i++) {
        expect(
          find.text(copy('liveness.gesture.${gestures[i]}')),
          findsOneWidget,
        );
        expect(
          find.text(
            copy(SpecCopyKey.livenessProgress, {
              'current': i + 1,
              'total': gestures.length,
            }),
          ),
          findsOneWidget,
        );
        if (i == 0) expect(source.events, contains('record'));
        source.play('${gestures[i]}_pass');
        await tester.pump();
      }
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
      expect(uploads.take(3).map((r) => r.fields['gesture']), gestures);
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
        gestures,
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
      final keyed = backend.requests
          .where(
            (r) => r.path.contains('/uploads/') || r.path.endsWith('/submit'),
          )
          .toList();
      expect(keyed, hasLength(7));
      for (final request in keyed) {
        expect(request.key, matches(uuid));
      }
      expect(keyed.map((r) => r.key).toSet(), hasLength(7));
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
    sources.last.play('${challengeGestures().first}_timeout');
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
      ..locationRejection = fixture('reference-rejection')
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
    expect(find.text(copy(SpecCopyKey.locationRetry)), findsOneWidget);
    await tapText(tester, copy(SpecCopyKey.locationRetry));
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationSend));
    await tester.pumpAndSettle();
    final keys = backend.requests
        .where((r) => r.path.endsWith('/submit'))
        .map((r) => r.key)
        .toList();
    expect(keys, hasLength(2));
    expect(keys, everyElement(matches(uuid)));
    expect(keys.first, isNot(keys.last));
  });

  testWidgets('a server accuracy rejection asks for a more precise fix', (
    tester,
  ) async {
    final backend = Backend()
      ..locationRejection = fixture('location-rejection')
      ..sessions.add(withRequirements(['location_verification']));
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
          locationSource: FakeLocationSource([() => locationFix()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationShare));
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationSend));
    await tester.pumpAndSettle();
    expect(
      fixture('location-rejection')['code'],
      SpecErrorCode.locationAccuracy,
    );
    expect(
      find.text(copy(SpecCopyKey.locationPlaceNotPrecise)),
      findsOneWidget,
    );
    expect(
      find.text(fixture('location-rejection')['message'] as String),
      findsNothing,
    );
    expect(find.text(copy(SpecCopyKey.locationRetry)), findsOneWidget);
  });

  testWidgets('an expired challenge on submit starts over with a new one', (
    tester,
  ) async {
    final rejection = fixture(
      'rejections/${SpecErrorCode.livenessChallengeExpired}',
    );
    final backend = Backend()
      ..facialRejection = rejection
      ..sessions.add(withRequirements(['facial_verification']));
    final sources = <FakeLivenessSource>[];
    await tester.pumpWidget(facialApp(backend, sources));
    await tester.pumpAndSettle();
    await recordChallenge(tester, () => sources.last);
    await tapText(tester, copy(SpecCopyKey.selfieSend));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.livenessExpired)), findsOneWidget);
    expect(find.text(rejection['message'] as String), findsNothing);
    final first = backend.requests.map((r) => r.key).whereType<String>();
    final firstKeys = first.toSet();
    await recordChallenge(
      tester,
      () => sources.last,
      button: SpecRejection.actionLabels['restart']!,
    );
    expect(backend.challenges, 2);
    await tapText(tester, copy(SpecCopyKey.selfieSend));
    await tester.pumpAndSettle();
    final secondUploads = backend.requests
        .where((r) => r.path.endsWith('/uploads/biometrics'))
        .skip(5)
        .toList();
    expect(secondUploads, hasLength(5));
    for (final upload in secondUploads) {
      expect(
        upload.fields['challenge_id'],
        '01a1fb33-a1ee-71b2-bba9-9f484aa3bb12',
      );
      expect(firstKeys, isNot(contains(upload.key)));
    }
    final submits = backend.requests
        .where((r) => r.path.endsWith('/submit'))
        .toList();
    expect(submits, hasLength(2));
    expect(submits.first.key, isNot(submits.last.key));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each location rejection code shows its own copy', (
    tester,
  ) async {
    final cases = {
      SpecErrorCode.locationAccuracy: copy(SpecCopyKey.locationPlaceNotPrecise),
      SpecErrorCode.locationStale: copy(SpecCopyKey.locationStale),
      SpecErrorCode.locationMock: copy(SpecCopyKey.locationMockDetected),
      SpecErrorCode.locationIpCountry: copy(
        SpecCopyKey.locationIpCountryMismatch,
      ),
      SpecErrorCode.locationReferenceNotMatched: copy(
        SpecCopyKey.locationPlaceNotMatchedWithin,
        {'place': 'Head office'},
      ),
    };
    expect(
      cases.keys.toSet(),
      SpecErrorCode.meanings.keys
          .where((c) => c.startsWith('location.'))
          .toSet(),
    );
    for (final entry in cases.entries) {
      final rejection = fixture('rejections/${entry.key}');
      expect(rejection['code'], entry.key);
      final backend = Backend()
        ..locationRejection = rejection
        ..sessions.add(withRequirements(['location_verification']));
      await tester.pumpWidget(
        MaterialApp(
          home: CredflareVerification(
            key: ValueKey(entry.key),
            autoStart: true,
            onClose: () {},
            httpClient: backend.client,
            sessionProvider: () async => descriptor(),
            locationSource: FakeLocationSource([() => locationFix()]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, copy(SpecCopyKey.locationShare));
      await tester.pumpAndSettle();
      await tapText(tester, copy(SpecCopyKey.locationSend));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      expect(
        find.text(copy(SpecRejection.codes[entry.key]!.title)),
        findsOneWidget,
        reason: entry.key,
      );
      expect(find.text(rejection['message'] as String), findsNothing);
      expect(
        find.text(copy(SpecRejection.actionLabels['retry']!)),
        findsOneWidget,
      );
    }
  });

  testWidgets('every liveness rejection shows its spec screen and restarts', (
    tester,
  ) async {
    final codes = SpecErrorCode.meanings.keys
        .where((c) => c.startsWith('liveness.'))
        .toList();
    final verifier =
        withRequirements(['facial_verification'])['data']['requester']['name']
            as String;
    for (final code in codes) {
      final rejection = fixture('rejections/$code');
      expect(rejection['code'], code);
      final entry = SpecRejection.codes[code]!;
      expect(entry.action, 'restart', reason: code);
      final backend = Backend()
        ..facialRejection = rejection
        ..sessions.add(withRequirements(['facial_verification']));
      final sources = <FakeLivenessSource>[];
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(facialApp(backend, sources));
      await tester.pumpAndSettle();
      await recordChallenge(tester, () => sources.last);
      await tapText(tester, copy(SpecCopyKey.selfieSend));
      await tester.pumpAndSettle();
      expect(find.text(copy(entry.title)), findsOneWidget, reason: code);
      expect(find.text(copy(entry.message)), findsOneWidget, reason: code);
      expect(find.text(rejection['message'] as String), findsNothing);
      expect(
        find.text(copy(SpecRejection.requestedBy, {'verifier': verifier})),
        findsOneWidget,
      );
      expect(
        find.text(copy(SpecRejection.help, {'verifier': verifier})),
        findsOneWidget,
      );
      expect(backend.challenges, 1, reason: code);
      await tapText(tester, copy(SpecRejection.actionLabels['restart']!));
      await tester.pump();
      await tester.pump();
      expect(backend.challenges, 2, reason: code);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unknown or missing code shows the server message', (
    tester,
  ) async {
    for (final code in ['liveness.something_new', null]) {
      final rejection = {
        ...fixture('rejections/${SpecErrorCode.livenessNotCamera}'),
        'code': code,
      };
      final backend = Backend()
        ..facialRejection = rejection
        ..sessions.add(withRequirements(['facial_verification']));
      final sources = <FakeLivenessSource>[];
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(facialApp(backend, sources));
      await tester.pumpAndSettle();
      await recordChallenge(tester, () => sources.last);
      await tapText(tester, copy(SpecCopyKey.selfieSend));
      await tester.pumpAndSettle();
      expect(find.text(rejection['message'] as String), findsOneWidget);
      expect(
        find.text(copy(SpecRejection.actionLabels['retry']!)),
        findsOneWidget,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a dropped submit is retried with the same request key', (
    tester,
  ) async {
    final backend = Backend()
      ..dropNextSubmit = true
      ..sessions.add(withRequirements(['facial_verification']));
    final sources = <FakeLivenessSource>[];
    await tester.pumpWidget(facialApp(backend, sources));
    await tester.pumpAndSettle();
    await recordChallenge(tester, () => sources.last);
    await tapText(tester, copy(SpecCopyKey.selfieSend));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.errorsSendSelfieFailed)), findsOneWidget);
    await tapText(tester, copy(SpecCopyKey.selfieSend));
    await tester.pumpAndSettle();
    final submits = backend.requests
        .where((r) => r.path.endsWith('/submit'))
        .toList();
    expect(submits, hasLength(2));
    expect(submits.first.key, matches(uuid));
    expect(submits.last.key, submits.first.key);
    expect(
      backend.requests.where((r) => r.path.contains('/uploads/')),
      hasLength(5),
    );
    expect(backend.challenges, 1);
    await tester.pumpWidget(const SizedBox());
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

  Future<FakeLocationSource> shareLocation(
    WidgetTester tester,
    Backend backend,
    List<LocationFix Function()> fixes,
  ) async {
    final location = FakeLocationSource(fixes);
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
    await tapText(tester, copy(SpecCopyKey.locationShare));
    await tester.pumpAndSettle();
    return location;
  }

  int maxAge(Map<String, dynamic> session) =>
      (session['data']['profile']['verification_requirements'] as List)
              .single['settings']['max_age_s']
          as int;

  testWidgets('a stale fix is not sent and a fresh one replaces it', (
    tester,
  ) async {
    final session = withRequirements(['location_verification']);
    final stale = Duration(seconds: maxAge(session) + 5);
    final backend = Backend()..sessions.add(session);
    final location = await shareLocation(tester, backend, [
      () => locationFix(age: stale),
      () => locationFix(),
    ]);
    expect(location.requests, 2);
    await tapText(tester, copy(SpecCopyKey.locationSend));
    await tester.pumpAndSettle();
    final sent =
        jsonDecode(
              backend.requests
                  .singleWhere((r) => r.path.endsWith('/submit'))
                  .body!,
            )
            as Map;
    final age = DateTime.now().difference(
      DateTime.parse(sent['metadata']['fix_time'] as String),
    );
    expect(age.inSeconds, lessThanOrEqualTo(maxAge(session)));
  });

  testWidgets('only stale fixes are never sent', (tester) async {
    final session = withRequirements(['location_verification']);
    final stale = Duration(seconds: maxAge(session) + 5);
    final backend = Backend()..sessions.add(session);
    final location = await shareLocation(tester, backend, [
      () => locationFix(age: stale),
    ]);
    expect(location.requests, SpecLocation.retryAttempts);
    expect(find.text(copy(SpecCopyKey.locationSend)), findsNothing);
    expect(find.text(copy(SpecCopyKey.locationRetry)), findsOneWidget);
    expect(backend.requests.where((r) => r.path.endsWith('/submit')), isEmpty);
  });

  testWidgets(
    'a mocked location is sent with its flag when the profile allows',
    (tester) async {
      final session = withRequirements(['location_verification']);
      (session['data']['profile']['verification_requirements'] as List)
              .single['settings']['mock_location'] =
          'flag';
      final backend = Backend()..sessions.add(session);
      await shareLocation(tester, backend, [() => locationFix(isMock: true)]);
      expect(find.text(copy(SpecCopyKey.locationMockDetected)), findsNothing);
      await tapText(tester, copy(SpecCopyKey.locationSend));
      await tester.pumpAndSettle();
      final sent =
          jsonDecode(
                backend.requests
                    .singleWhere((r) => r.path.endsWith('/submit'))
                    .body!,
              )
              as Map;
      expect(sent['metadata']['is_mock'], true);
    },
  );

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
      if (types.contains('phone_verification')) {
        profile['verification_requirements'] = fixture(
          'requirement-added-session',
        )['data']['profile']['verification_requirements'];
      }
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

    await show(['facial_verification', 'location_verification']);
    only(copy(SpecCopyKey.documentsSelfieLocationNext));
    await show(['facial_verification', 'location_verification'], form: true);
    only(copy(SpecCopyKey.documentsHostStepsNext));
    await show(['phone_verification']);
    only(copy(SpecCopyKey.documentsHostStepsNext));
    await show(['location_verification']);
    only(copy(SpecCopyKey.documentsLocationNext));
    await show(['facial_verification']);
    only(copy(SpecCopyKey.documentsSelfieNext));
    await show([], form: true);
    only(copy(SpecCopyKey.documentsHostStepsNext));
    await show([]);
    only(null);
  });

  testWidgets('a location refused because the case closed shows the receipt', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(withRequirements(['location_verification']))
      ..closedAfterSubmit = fixture('session-closed')
      ..closeOnPost = true;
    var closed = 0;
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          onClosed: () => closed++,
          onSubmitted: (info) => submitted = info,
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
          locationSource: FakeLocationSource([() => locationFix()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationShare));
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.locationSend));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptLocation)), findsNothing);
    expect(
      find.text(fixture('session-closed')['message'] as String),
      findsNothing,
    );
    expect(backend.requests.where((r) => r.method == 'GET'), hasLength(1));
    expect(closed, 1);
    expect(submitted, isNull);
  });

  testWidgets('a selfie refused because the case closed shows the receipt', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(withRequirements(['facial_verification']))
      ..closedAfterSubmit = fixture('session-closed')
      ..closeOnPost = true;
    final sources = <FakeLivenessSource>[];
    await tester.pumpWidget(facialApp(backend, sources));
    await tester.pumpAndSettle();
    await recordChallenge(tester, () => sources.last);
    await tapText(tester, copy(SpecCopyKey.selfieSend));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptSelfie)), findsNothing);
    expect(
      find.text(fixture('session-closed')['message'] as String),
      findsNothing,
    );
    expect(backend.requests.where((r) => r.method == 'GET'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}
