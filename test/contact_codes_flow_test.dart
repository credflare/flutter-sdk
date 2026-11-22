import 'dart:convert';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';
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

Widget flow(Backend backend, {VoidCallback? onClose}) => MaterialApp(
  home: CredflareVerification(
    autoStart: true,
    onClose: onClose ?? () {},
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
    expect(
      find.text(
        copy(SpecCopyKey.contactCodeResendIn, {
          'seconds': SpecRequirements.contactCodesResendSeconds,
        }),
      ),
      findsOneWidget,
    );
    final resend = tester.widget<TextButton>(
      find.widgetWithText(TextButton, copy(SpecCopyKey.contactCodeResend)),
    );
    expect(resend.onPressed, isNull);

    await confirmCode(tester, '123456');
    final confirm = posts(backend, '/phone-codes/confirm').single;
    expect(jsonDecode(confirm.body!), {'code': '123456'});
    expect(backend.requests.where((r) => r.method == 'GET'), hasLength(2));
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptPhone)), findsOneWidget);
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
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(flow(backend, onClose: () => closed++));
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

  Future<void> waitScreen(
    WidgetTester tester,
    Map<String, dynamic> rejection,
    DateTime Function() now,
    Backend backend,
  ) async {
    backend
      ..sessions.add(contactSession('phone_verification'))
      ..codeRejections.add(rejection);
    final session = CredflareSession(descriptor(), client: backend.client);
    final info = await session.get();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CredflareContactCodeCapture(
            session: session,
            info: info,
            channel: ContactChannel.phone,
            onSubmitted: () {},
            onLeave: () {},
            onBusyChanged: (_) {},
            now: now,
          ),
        ),
      ),
    );
    await sendDestination(tester, ContactChannel.phone, '+237650000001');
  }

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
}
