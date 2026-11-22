import 'dart:convert';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/backend.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key, String option) async {
  final field = find.byKey(ValueKey('question-$key'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey('question-$key'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

String flag(String code) =>
    String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 0x41));

Widget flow(Backend backend) => MaterialApp(
  home: CredflareVerification(
    autoStart: true,
    onClose: () {},
    httpClient: backend.client,
    sessionProvider: () async => descriptor(),
  ),
);

Map<String, dynamic> lastSubmit(Backend backend) =>
    jsonDecode(
          backend.requests.lastWhere((r) => r.path.endsWith('/submit')).body!,
        )
        as Map<String, dynamic>;

Finder question(String key) => find.byKey(ValueKey('q-$key'));

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  testWidgets(
    'hidden questions are skipped, answers sent, then an added step runs',
    (tester) async {
      final backend = Backend()
        ..sessions.addAll([
          fixture('questionnaire-session'),
          fixture('requirement-added-session'),
        ]);
      await tester.pumpWidget(flow(backend));
      await tester.pumpAndSettle();
      expect(find.text(copy(SpecCopyKey.questionsTitle)), findsOneWidget);
      for (final key in ['employer', 'income', 'sources_other']) {
        expect(question(key), findsNothing, reason: key);
      }
      for (final key in ['country', 'employment', 'birth_date', 'terms']) {
        expect(question(key), findsOneWidget, reason: key);
      }

      await tapText(tester, copy(SpecCopyKey.questionsSend));
      expect(find.text(copy(SpecCopyKey.questionsRequired)), findsNWidgets(3));
      expect(
        find.text(copy(SpecCopyKey.questionsConsentRequired)),
        findsOneWidget,
      );
      expect(
        backend.requests.where((r) => r.path.endsWith('/submit')),
        isEmpty,
      );

      await choose(tester, 'employment', 'Employed');
      expect(question('employer'), findsOneWidget);
      expect(question('income'), findsOneWidget);
      await type(tester, 'employer', 'Acme');
      await choose(tester, 'employment', 'Student');
      expect(question('employer'), findsNothing);
      expect(question('income'), findsNothing);

      await choose(tester, 'country', '${flag('AD')}  AD');
      await tester.ensureVisible(
        find.byKey(const ValueKey('question-birth_date')),
      );
      await tester.tap(find.byKey(const ValueKey('question-birth_date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tapText(tester, 'Other');
      expect(question('sources_other'), findsOneWidget);
      await type(tester, 'sources_other', 'Gift');
      await type(tester, 'contact_phone', 'call me');
      await tapText(
        tester,
        fixture(
              'questionnaire-session',
            )['data']['profile']['form_schema'].last['label']
            as String,
      );
      await tapText(tester, copy(SpecCopyKey.questionsSend));
      expect(
        find.text(copy(SpecCopyKey.questionsInvalidPhone)),
        findsOneWidget,
      );
      await type(tester, 'contact_phone', '+237 650 000 001');
      await tapText(tester, copy(SpecCopyKey.questionsSend));

      final submit = lastSubmit(backend);
      final today = DateTime.now();
      expect(submit, {
        'type': 'form_submission',
        'fields': {
          'country': 'AD',
          'employment': 'Student',
          'birth_date':
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
          'contact_phone': '+237 650 000 001',
          'sources': ['Other'],
          'sources_other': 'Gift',
          'terms': true,
        },
      });
      expect(
        backend.requests.lastWhere((r) => r.path.endsWith('/submit')).key,
        isNotNull,
      );
      expect(backend.requests.where((r) => r.method == 'GET'), hasLength(2));
      expect(find.text(copy(SpecCopyKey.phoneTitle)), findsOneWidget);
      expect(find.text(copy(SpecCopyKey.receiptTitle)), findsNothing);
    },
  );

  testWidgets('numbers are checked against their limits and sent as numbers', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.addAll([
        fixture('questionnaire-session'),
        fixture('requirement-added-session'),
      ]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await choose(tester, 'employment', 'Employed');
    await type(tester, 'income', '-5');
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(
      find.text(copy(SpecCopyKey.questionsNumberMin, {'min': 0})),
      findsOneWidget,
    );
    await type(tester, 'income', '20000000');
    expect(
      find.text(copy(SpecCopyKey.questionsNumberMax, {'max': 10000000})),
      findsOneWidget,
    );
    await type(tester, 'income', 'lots');
    expect(find.text(copy(SpecCopyKey.questionsInvalidNumber)), findsOneWidget);
    await type(tester, 'income', '50000.5');
    expect(find.text(copy(SpecCopyKey.questionsInvalidNumber)), findsNothing);
    await type(tester, 'employer', 'Acme');
    await choose(tester, 'country', '${flag('AD')}  AD');
    await tester.ensureVisible(
      find.byKey(const ValueKey('question-birth_date')),
    );
    await tester.tap(find.byKey(const ValueKey('question-birth_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapText(
      tester,
      fixture(
            'questionnaire-session',
          )['data']['profile']['form_schema'].last['label']
          as String,
    );
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    final fields = lastSubmit(backend)['fields'] as Map;
    expect(fields['income'], 50000.5);
    expect(fields['employer'], 'Acme');
  });

  testWidgets('a server rejection shows its message and marks the question', (
    tester,
  ) async {
    final rejection = fixture('questionnaire-hidden-answer');
    final backend = Backend()
      ..formRejection = rejection
      ..sessions.addAll([
        fixture('questionnaire-session'),
        fixture('requirement-added-session'),
      ]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await choose(tester, 'employment', 'Employed');
    await type(tester, 'employer', 'Acme');
    await choose(tester, 'country', '${flag('AD')}  AD');
    await tester.ensureVisible(
      find.byKey(const ValueKey('question-birth_date')),
    );
    await tester.tap(find.byKey(const ValueKey('question-birth_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapText(
      tester,
      fixture(
            'questionnaire-session',
          )['data']['profile']['form_schema'].last['label']
          as String,
    );
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    final first = backend.requests.lastWhere((r) => r.path.endsWith('/submit'));
    expect(find.text(rejection['message'] as String), findsOneWidget);
    await tapText(tester, copy(SpecRejection.actionLabels['retry']!));
    expect(
      find.descendant(
        of: question('employer'),
        matching: find.text(
          (rejection['errors'] as Map)['fields.employer'].first as String,
        ),
      ),
      findsOneWidget,
    );
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    final second = backend.requests.lastWhere(
      (r) => r.path.endsWith('/submit'),
    );
    expect(second.key, isNot(first.key));
    expect(find.text(copy(SpecCopyKey.phoneTitle)), findsOneWidget);
  });

  testWidgets('a failed check after sending never shows the receipt', (
    tester,
  ) async {
    final done = fixture('requirement-added-session');
    done['data']['profile']['verification_requirements'] = [];
    final backend = Backend()
      ..sessions.addAll([
        withRequirements(['location_verification']),
        done,
      ]);
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
    backend.failNextGet = true;
    await tapText(tester, copy(SpecCopyKey.locationSend));
    expect(find.text(copy(SpecCopyKey.errorsRefreshFailed)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsNothing);
    await tapText(tester, copy(SpecCopyKey.commonTryAgain));
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptLocation)), findsOneWidget);
  });

  testWidgets('a closed session shows the receipt even with steps listed', (
    tester,
  ) async {
    final closed = fixture('requirement-added-session');
    closed['data']['status'] = 'submitted';
    final backend = Backend()..sessions.add(closed);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(SpecRequirements.refreshOpenStatuses, isNot(contains('submitted')));
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.phoneTitle)), findsNothing);
  });
}
