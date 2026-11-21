import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../test/support/backend.dart';
import '../test/support/fakes.dart';
import '../test/support/fixtures.dart';

final gestures = (fixture('liveness-challenge')['data']['gestures'] as List)
    .cast<String>();

Future<void> _loadFonts() async {
  final ubuntu = FontLoader('packages/credflare_sdk/Ubuntu');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    ubuntu.addFont(
      rootBundle.load('packages/credflare_sdk/assets/fonts/Ubuntu-$weight.ttf'),
    );
  }
  await ubuntu.load();
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent.parent.parent.path;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}

Map<String, dynamic> _session({required bool received}) {
  final raw = captureSession('snapshot_and_upload');
  final data = raw['data'] as Map<String, dynamic>;
  data['requester'] = {'name': 'Example Lending', 'logo_url': null};
  data['custom_message'] =
      'We need these to open your account. It takes about two minutes.';
  final profile = data['profile'] as Map<String, dynamic>;
  final id = Map<String, dynamic>.from(
    (profile['document_requirements'] as List).first as Map,
  );
  id['document_type'] = {
    ...id['document_type'] as Map,
    'name': 'National ID card',
  };
  id['capture_method'] = 'snapshot';
  final statement = jsonDecode(jsonEncode(id)) as Map<String, dynamic>;
  statement['document_type'] = {
    ...statement['document_type'] as Map,
    'id': 2,
    'name': 'Bank statement',
    'two_sided': false,
  };
  statement['capture_method'] = 'upload';
  statement['requested_sides'] = ['front'];
  profile['document_requirements'] = received ? [] : [id, statement];
  profile['form_schema'] = null;
  profile['verification_requirements'] = received
      ? []
      : fixture(
          'capture-session',
        )['data']['profile']['verification_requirements'];
  return raw;
}

void main() {
  final out = Directory(
    Platform.environment['SCREENS_OUT'] ?? 'build/doc_screens',
  )..createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    bool received = false,
    bool start = true,
    Future<void> Function()? then,
    Brightness brightness = Brightness.light,
    http.Client? backend,
    LivenessSourceFactory? liveness,
    LocationSource? location,
  }) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final client =
        backend ??
        MockClient(
          (request) async =>
              http.Response(jsonEncode(_session(received: received)), 200),
        );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: brightness),
          home: CredflareVerification(
            httpClient: client,
            autoStart: start,
            onClose: () {},
            livenessSource: liveness ?? FakeLivenessSource.new,
            locationSource: location ?? FakeLocationSource([locationFix]),
            sessionProvider: () async => SessionDescriptor.fromJson({
              'session_id': '01a1f911-78ef-70b7-8ebc-4651850380c5',
              'token': 'docs-session-token',
              'api_base_url': 'https://api.example.test/api/v1',
              'expires_at': '2030-01-01T00:00:00Z',
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (then != null) await then();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      File(
        '${out.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('start', (tester) => shoot(tester, 'sdk-start', start: false));
  testWidgets('documents', (tester) => shoot(tester, 'sdk-documents'));
  testWidgets(
    'capture',
    (tester) => shoot(
      tester,
      'sdk-capture',
      then: () async {
        await tester.tap(find.text('National ID card'));
        await tester.pumpAndSettle();
      },
    ),
  );
  testWidgets(
    'received',
    (tester) => shoot(tester, 'sdk-received', received: true),
  );
  testWidgets(
    'documents dark',
    (tester) =>
        shoot(tester, 'sdk-documents-dark', brightness: Brightness.dark),
  );

  for (final dark in [false, true]) {
    final suffix = dark ? '-dark' : '';
    final brightness = dark ? Brightness.dark : Brightness.light;
    testWidgets('liveness intro$suffix', (tester) {
      final backend = Backend()
        ..sessions.add(withRequirements(['facial_verification']));
      return shoot(
        tester,
        'sdk-liveness-intro$suffix',
        backend: backend.client,
        brightness: brightness,
      );
    });
    testWidgets('liveness prompt$suffix', (tester) {
      final backend = Backend()
        ..sessions.add(withRequirements(['facial_verification']));
      final source = FakeLivenessSource();
      return shoot(
        tester,
        'sdk-liveness-prompt$suffix',
        backend: backend.client,
        brightness: brightness,
        liveness: () => source,
        then: () async {
          await tester.ensureVisible(
            find.text(copy(SpecCopyKey.livenessStart)),
          );
          await tester.tap(find.text(copy(SpecCopyKey.livenessStart)));
          await tester.pump();
          await tester.pump();
          source.play('position_ok_pass');
          await tester.pump();
          source.play('${gestures.first}_pass');
          await tester.pump();
        },
      );
    });
    testWidgets('liveness review$suffix', (tester) {
      final backend = Backend()
        ..sessions.add(withRequirements(['facial_verification']));
      final source = FakeLivenessSource();
      return shoot(
        tester,
        'sdk-liveness-review$suffix',
        backend: backend.client,
        brightness: brightness,
        liveness: () => source,
        then: () async {
          await tester.ensureVisible(
            find.text(copy(SpecCopyKey.livenessStart)),
          );
          await tester.tap(find.text(copy(SpecCopyKey.livenessStart)));
          await tester.pump();
          await tester.pump();
          for (final name in [
            'position_ok_pass',
            for (final gesture in gestures) '${gesture}_pass',
          ]) {
            source.play(name);
            await tester.pump();
          }
          await tester.pumpAndSettle();
        },
      );
    });
    testWidgets('location consent$suffix', (tester) {
      final backend = Backend()
        ..sessions.add(withRequirements(['location_verification']));
      return shoot(
        tester,
        'sdk-location$suffix',
        backend: backend.client,
        brightness: brightness,
      );
    });
    testWidgets('location found$suffix', (tester) {
      final backend = Backend()
        ..sessions.add(withRequirements(['location_verification']));
      return shoot(
        tester,
        'sdk-location-found$suffix',
        backend: backend.client,
        brightness: brightness,
        then: () async {
          await tester.ensureVisible(
            find.text(copy(SpecCopyKey.locationShare)),
          );
          await tester.tap(find.text(copy(SpecCopyKey.locationShare)));
          await tester.pumpAndSettle();
        },
      );
    });
    testWidgets('location rejected$suffix', (tester) {
      final backend = Backend()
        ..locationRejection = fixture('reference-rejection')
        ..sessions.add(withRequirements(['location_verification']));
      return shoot(
        tester,
        'sdk-location-rejected$suffix',
        backend: backend.client,
        brightness: brightness,
        then: () async {
          await tester.ensureVisible(
            find.text(copy(SpecCopyKey.locationShare)),
          );
          await tester.tap(find.text(copy(SpecCopyKey.locationShare)));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(copy(SpecCopyKey.locationSend)));
          await tester.tap(find.text(copy(SpecCopyKey.locationSend)));
          await tester.pumpAndSettle();
        },
      );
    });
    testWidgets('receipt$suffix', (tester) {
      final backend = Backend()
        ..sessions.addAll([
          withRequirements(['location_verification']),
          fixture('facial-complete'),
        ]);
      return shoot(
        tester,
        'sdk-receipt$suffix',
        backend: backend.client,
        brightness: brightness,
        then: () async {
          await tester.ensureVisible(
            find.text(copy(SpecCopyKey.locationShare)),
          );
          await tester.tap(find.text(copy(SpecCopyKey.locationShare)));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(copy(SpecCopyKey.locationSend)));
          await tester.tap(find.text(copy(SpecCopyKey.locationSend)));
          await tester.pumpAndSettle();
        },
      );
    });
  }
}
