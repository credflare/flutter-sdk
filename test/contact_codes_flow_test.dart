import 'dart:async';
import 'dart:convert';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/backend.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pump();
  await tester.tap(find.text(text).last);
}

Map<String, dynamic> contactSession(String type) {
  final raw = fixture('requirement-added-session');
  raw['data']['profile']['verification_requirements'] = [
    {'verification_type': type, 'settings': null},
  ];
  return raw;
}

Map<String, dynamic> doneSession() {
  final raw = fixture('requirement-added-session');
  raw['data']['profile']['verification_requirements'] = [];
  return raw;
}

String verifier() =>
    fixture('requirement-added-session')['data']['requester']['name'] as String;

Widget flow(
  Backend backend, {
  VoidCallback? onClose,
  ValueChanged<String?>? onHostActionRequired,
}) => MaterialApp(
  home: CredflareVerification(
    autoStart: true,
    onClose: onClose ?? () {},
    onHostActionRequired: onHostActionRequired,
    httpClient: backend.client,
    sessionProvider: () async => descriptor(),
  ),
);

Future<void> sendDestination(
  WidgetTester tester,
  ContactChannel channel,
  String value,
) async {
  await tester.enterText(find.byType(TextField), value);
  await tapText(
    tester,
    copy(
      channel == ContactChannel.email
          ? SpecCopyKey.emailSend
          : SpecCopyKey.phoneSend,
    ),
  );
  await settle(tester);
}

Future<void> confirmCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
  await tapText(tester, copy(SpecCopyKey.contactCodeConfirm));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String resendPrefix() =>
    copy(SpecCopyKey.contactCodeResendIn).split('{seconds}').first;

List<RecordedRequest> posts(Backend backend, String suffix) => backend.requests
    .where((r) => r.method == 'POST' && r.path.endsWith(suffix))
    .toList();

void main() {
  testWidgets('a phone code is requested, confirmed and the session checked', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.addAll([contactSession('phone_verification'), doneSession()]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.phoneTitle)), findsOneWidget);
    expect(
      find.text(copy(SpecCopyKey.phoneBody, {'verifier': verifier()})),
      findsOneWidget,
    );
    await sendDestination(tester, ContactChannel.phone, '650 000 001');
    expect(find.text(copy(SpecCopyKey.phoneInvalid)), findsOneWidget);
    expect(posts(backend, '/phone-codes'), isEmpty);

    await sendDestination(tester, ContactChannel.phone, '+237 (650) 000-001');
    final request = posts(backend, '/phone-codes').single;
    expect(jsonDecode(request.body!), {'phone': '+237650000001'});
    final sent = fixture('phone-code-request')['data'];
    expect(
      find.text(
        copy(SpecCopyKey.contactCodeBody, {
          'destination': sent['destination'],
          'minutes': SpecRequirements.contactCodesTtlMinutes,
        }),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        copy(SpecCopyKey.contactCodeSendsRemaining, {
          'count': sent['sends_remaining'],
        }),
      ),
      findsOneWidget,
    );
    await confirmCode(tester, '123456');
    final confirm = posts(backend, '/phone-codes/confirm').single;
    expect(jsonDecode(confirm.body!), {'code': '123456'});
    expect(backend.requests.where((r) => r.method == 'GET'), hasLength(2));
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptPhone)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a case closed by the last confirmation shows the receipt', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(contactSession('phone_verification'))
      ..closedAfterSubmit = fixture('session-closed');
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          onSubmitted: (info) => submitted = info,
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
    await confirmCode(tester, '123456');
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptPhone)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.errorsRefreshFailed)), findsNothing);
    final before = contactSession('phone_verification')['data'];
    expect(submitted, before);
    expect(
      (submitted!['profile']['verification_requirements'] as List).single,
      {'verification_type': 'phone_verification', 'settings': null},
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a closed case reports onClosed instead of a stale session', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(contactSession('phone_verification'))
      ..closedAfterSubmit = fixture('session-closed');
    var submitted = 0;
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          onSubmitted: (_) => submitted++,
          onClosed: () => closed++,
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
    await confirmCode(tester, '123456');
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(closed, 1);
    expect(submitted, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a confirmation refused because the case closed shows the receipt',
    (tester) async {
      final backend = Backend()
        ..sessions.add(contactSession('phone_verification'))
        ..closedAfterSubmit = fixture('session-closed')
        ..closeOnPost = true;
      await tester.pumpWidget(flow(backend));
      await tester.pumpAndSettle();
      await sendDestination(tester, ContactChannel.phone, '+237650000001');
      await confirmCode(tester, '123456');
      expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
      expect(
        find.text(fixture('session-closed')['message'] as String),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('removing the flow while a code is confirmed is safe', (
    tester,
  ) async {
    final hold = Completer<void>();
    final backend = Backend()
      ..sessions.addAll([contactSession('phone_verification'), doneSession()])
      ..holdSubmit = hold;
    var submitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          onSubmitted: (_) => submitted++,
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
    await confirmCode(tester, '123456');
    await tester.pumpWidget(const SizedBox());
    hold.complete();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(backend.requests.where((r) => r.method == 'GET'), hasLength(1));
    expect(submitted, 0);
  });

  for (final route in ['close', 'back']) {
    testWidgets('leaving a leave rejection by $route reports its code', (
      tester,
    ) async {
      final rejection = fixture('rejections/phone.not_configured');
      final backend = Backend()
        ..sessions.add(contactSession('phone_verification'))
        ..codeRejections.add(rejection);
      final hostActions = <String?>[];
      var cancelled = 0;
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CredflareVerification(
            autoStart: true,
            onClose: () => closed++,
            onCancelled: () => cancelled++,
            onHostActionRequired: hostActions.add,
            httpClient: backend.client,
            sessionProvider: () async => descriptor(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await sendDestination(tester, ContactChannel.phone, '+237650000001');
      expect(
        find.text(copy(SpecRejection.codes[rejection['code']]!.title)),
        findsOneWidget,
      );
      if (route == 'close') {
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(copy(SpecCopyKey.commonClose)),
          ),
        );
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text(copy(SpecCopyKey.exitLeave)));
      await tester.pumpAndSettle();
      expect(hostActions, [rejection['code']]);
      expect(cancelled, 0);
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('leaving after the code screen returns is a cancel', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(contactSession('phone_verification'))
      ..confirmRejections.add(fixture('rejections/phone.code_invalid'));
    final hostActions = <String?>[];
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          onCancelled: () => cancelled++,
          onHostActionRequired: hostActions.add,
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
    await confirmCode(tester, '000000');
    await tester.tap(find.text(copy(SpecCopyKey.commonClose)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy(SpecCopyKey.exitLeave)));
    await tester.pumpAndSettle();
    expect(hostActions, isEmpty);
    expect(cancelled, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an email address is checked before a code is sent', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.addAll([contactSession('email_verification'), doneSession()]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.emailTitle)), findsOneWidget);
    await sendDestination(tester, ContactChannel.email, 'jane.doe');
    expect(find.text(copy(SpecCopyKey.emailInvalid)), findsOneWidget);
    await sendDestination(
      tester,
      ContactChannel.email,
      ' Jane.Doe@example.test ',
    );
    expect(jsonDecode(posts(backend, '/email-codes').single.body!), {
      'email': 'Jane.Doe@example.test',
    });
    await confirmCode(tester, '654321');
    expect(find.text(copy(SpecCopyKey.receiptEmail)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final channel in ContactChannel.values) {
    final name = channel.name;
    testWidgets('every $name rejection shows its spec screen and action', (
      tester,
    ) async {
      final codes = SpecErrorCode.meanings.keys
          .where((c) => c.startsWith('$name.'))
          .toList();
      expect(codes, hasLength(7));
      for (final code in codes) {
        final rejection = fixture('rejections/$code');
        expect(rejection['code'], code);
        final entry = SpecRejection.codes[code]!;
        final onSend = const [
          'not_configured',
          'resend_too_soon',
          'send_limit',
        ].contains(code.split('.').last);
        final backend = Backend()
          ..sessions.addAll([
            contactSession(channel.verificationType),
            doneSession(),
          ]);
        if (onSend) {
          backend.codeRejections.add(rejection);
        } else {
          backend.confirmRejections.add(rejection);
        }
        var closed = 0;
        final hostActions = <String?>[];
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          flow(
            backend,
            onClose: () => closed++,
            onHostActionRequired: hostActions.add,
          ),
        );
        await tester.pumpAndSettle();
        await sendDestination(
          tester,
          channel,
          channel == ContactChannel.email
              ? 'jane.doe@example.test'
              : '+237650000001',
        );
        if (!onSend) await confirmCode(tester, '000000');
        expect(find.text(copy(entry.title)), findsOneWidget, reason: code);
        expect(
          find.text(copy(entry.message, {'verifier': verifier()})),
          findsOneWidget,
          reason: code,
        );
        if (rejection['message'] != copy(entry.message)) {
          expect(find.text(rejection['message'] as String), findsNothing);
        }
        expect(
          find.text(copy(SpecRejection.requestedBy, {'verifier': verifier()})),
          findsOneWidget,
        );
        expect(
          find.text(copy(SpecRejection.help, {'verifier': verifier()})),
          findsOneWidget,
        );
        final label = copy(SpecRejection.actionLabels[entry.action]!);
        final button = find.widgetWithText(FilledButton, label);
        expect(button, findsOneWidget, reason: code);
        final sends = posts(backend, '-codes').length;
        switch (entry.action) {
          case 'wait':
            final at = DateTime.parse(rejection['resend_available_at']);
            expect(DateTime.now().isAfter(at), isTrue);
            expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
            expect(find.textContaining(resendPrefix()), findsNothing);
            await tester.tap(button);
            await settle(tester);
            expect(posts(backend, '-codes').length, sends + 1, reason: code);
          case 'leave':
            await tester.ensureVisible(button);
            await tester.tap(button);
            await settle(tester);
            expect(closed, 1, reason: code);
            expect(hostActions, [code]);
          case 'new_code':
            await tapText(tester, label);
            await settle(tester);
            expect(posts(backend, '-codes').length, sends + 1, reason: code);
            expect(
              find.text(copy(SpecCopyKey.contactCodeTitle)),
              findsOneWidget,
            );
          case 'reenter_code':
            await tapText(tester, label);
            await settle(tester);
            expect(
              find.text(copy(SpecCopyKey.contactCodeTitle)),
              findsOneWidget,
            );
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              isEmpty,
            );
            expect(posts(backend, '-codes').length, sends);
            await confirmCode(tester, '123456');
            expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
          default:
            fail('Unexpected action ${entry.action} for $code');
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  Future<void> capture(
    WidgetTester tester,
    DateTime Function() now,
    Backend backend,
  ) async {
    backend.sessions.add(contactSession('phone_verification'));
    final session = CredflareSession(descriptor(), client: backend.client);
    final info = await session.get();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CredflareContactCodeCapture(
              session: session,
              info: info,
              channel: ContactChannel.phone,
              onSubmitted: () {},
              onLeave: (_) {},
              onBusyChanged: (_) {},
              now: now,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> waitScreen(
    WidgetTester tester,
    Map<String, dynamic> rejection,
    DateTime Function() now,
    Backend backend,
  ) async {
    backend.codeRejections.add(rejection);
    await capture(tester, now, backend);
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
  }

  testWidgets('resend counts down to the server time of the code', (
    tester,
  ) async {
    final sent = fixture('phone-code-request')['data'];
    final at = DateTime.parse(sent['resend_available_at'] as String);
    var now = at.subtract(const Duration(seconds: 40));
    final backend = Backend();
    await capture(tester, () => now, backend);
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
    expect(
      find.text(copy(SpecCopyKey.contactCodeResendIn, {'seconds': 40})),
      findsOneWidget,
    );
    final resend = find.widgetWithText(
      TextButton,
      copy(SpecCopyKey.contactCodeResend),
    );
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    now = at;
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a retry after changing the number uses the new number', (
    tester,
  ) async {
    final rejection = fixture('rejections/phone.resend_too_soon');
    final at = DateTime.parse(rejection['resend_available_at'] as String);
    var now = at.subtract(const Duration(seconds: 30));
    final backend = Backend();
    await capture(tester, () => now, backend);
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
    expect(find.text(copy(SpecCopyKey.contactCodeTitle)), findsOneWidget);
    await tapText(tester, copy(SpecCopyKey.phoneChange));
    await tester.pump();
    backend.codeRejections.add(rejection);
    await sendDestination(tester, ContactChannel.phone, '+237650000002');
    final label = copy(SpecRejection.actionLabels['wait']!);
    expect(find.text(copy(SpecCopyKey.contactCodeTitle)), findsOneWidget);
    final sent = fixture('phone-code-request')['data'];
    expect(
      find.text(
        copy(SpecCopyKey.contactCodeBody, {
          'destination': sent['destination'],
          'minutes': SpecRequirements.contactCodesTtlMinutes,
        }),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('+237650000002'), findsNothing);
    expect(find.text(copy(SpecCopyKey.phoneChangeAfter)), findsOneWidget);
    now = at;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(copy(SpecCopyKey.phoneChangeAfter)), findsNothing);
    await tapText(tester, label);
    await settle(tester);
    final sends = posts(backend, '/phone-codes');
    expect(sends, hasLength(3));
    expect(jsonDecode(sends.last.body!), {'phone': '+237650000002'});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a wait rejection enables a new code at its resend time', (
    tester,
  ) async {
    final rejection = fixture('rejections/phone.resend_too_soon');
    final at = DateTime.parse(rejection['resend_available_at'] as String);
    var now = at.subtract(const Duration(seconds: 45));
    final backend = Backend();
    await waitScreen(tester, rejection, () => now, backend);
    final label = copy(SpecRejection.actionLabels['wait']!);
    final button = find.widgetWithText(FilledButton, label);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      find.text(copy(SpecCopyKey.contactCodeResendIn, {'seconds': 45})),
      findsOneWidget,
    );
    expect(
      find.text(
        copy(SpecCopyKey.contactCodeBody, {
          'destination': '+237650000001',
          'minutes': SpecRequirements.contactCodesTtlMinutes,
        }),
      ),
      findsOneWidget,
    );
    expect(find.text(copy(SpecCopyKey.contactCodeLabel)), findsOneWidget);
    now = at;
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tapText(tester, label);
    await settle(tester);
    expect(posts(backend, '/phone-codes'), hasLength(2));
    expect(find.text(copy(SpecCopyKey.contactCodeTitle)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a wait rejection without a resend time waits the full delay', (
    tester,
  ) async {
    final rejection = fixture('rejections/phone.resend_too_soon')
      ..remove('resend_available_at');
    final now = DateTime.utc(2026, 11, 22, 12);
    await waitScreen(tester, rejection, () => now, Backend());
    expect(
      find.text(
        copy(SpecCopyKey.contactCodeResendIn, {
          'seconds': SpecRequirements.contactCodesResendSeconds,
        }),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a rejection without a code shows the server message', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(contactSession('phone_verification'))
      ..codeRejections.add(fixture('questionnaire-hidden-answer'));
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
    expect(
      find.text(fixture('questionnaire-hidden-answer')['message'] as String),
      findsOneWidget,
    );
    await tapText(tester, copy(SpecRejection.actionLabels['retry']!));
    await settle(tester);
    expect(find.text(copy(SpecCopyKey.phoneTitle)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the header centres the requester and wraps a long name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const long = 'Harbour Credit Union';
    final raw = contactSession('phone_verification');
    raw['data']['requester']['name'] = long;
    final backend = Backend()..sessions.add(raw);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    final name = find.text(long);
    final badge = find.text(copy(SpecCopyKey.commonTestMode));
    expect(tester.getCenter(name).dx, closeTo(195, 1));
    expect(tester.getCenter(badge).dx, closeTo(195, 1));
    expect(
      tester.getTopLeft(badge).dy,
      greaterThan(tester.getBottomLeft(name).dy),
    );
    final paragraph = tester.renderObject<RenderParagraph>(name);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.getSize(name).height, greaterThan(30));
    expect(paragraph.textAlign, TextAlign.center);
    final close = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(copy(SpecCopyKey.commonClose)),
    );
    expect(tester.getCenter(close).dx, greaterThan(300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
