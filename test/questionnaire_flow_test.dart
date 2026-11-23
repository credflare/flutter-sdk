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

String consentLabel() =>
    fixture(
          'questionnaire-session',
        )['data']['profile']['form_schema'].last['label']
        as String;

Future<void> pickToday(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('question-birth_date')));
  await tester.tap(find.byKey(const ValueKey('question-birth_date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> answerRequired(WidgetTester tester) async {
  await choose(tester, 'employment', 'Student');
  await choose(tester, 'country', '${flag('AD')}  AD');
  await pickToday(tester);
  await tapText(tester, consentLabel());
}

Map<String, dynamic> questionnaireWith(
  void Function(List<Map<String, dynamic>> schema) change,
) {
  final raw = fixture('questionnaire-session');
  final schema = [
    for (final q in raw['data']['profile']['form_schema'] as List)
      Map<String, dynamic>.from(q as Map),
  ];
  change(schema);
  raw['data']['profile']['form_schema'] = schema;
  return raw;
}

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

  testWidgets('an empty multiple choice is evaluated as not answered', (
    tester,
  ) async {
    final missing = (fixture('show-if-cases')['conditions'] as List)
        .cast<Map>()
        .firstWhere((c) => c['name'] == 'not_contains missing answer');
    expect(missing['expect'], isFalse);
    final session = questionnaireWith((schema) {
      final other = schema.firstWhere((q) => q['key'] == 'sources_other');
      schema.insert(schema.indexOf(other) + 1, {
        ...other,
        'key': 'sources_note',
        'required': false,
        'show_if': {
          'conditions': [missing['condition']],
        },
      });
    });
    final backend = Backend()
      ..sessions.addAll([session, fixture('requirement-added-session')]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(question('sources_note'), findsNothing);
    await tapText(tester, 'Salary');
    expect(question('sources_note'), findsOneWidget);
    await type(tester, 'sources_note', 'Payslips');
    await tapText(tester, 'Salary');
    expect(question('sources_note'), findsNothing);
    await answerRequired(tester);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    final fields = lastSubmit(backend)['fields'] as Map;
    expect(fields.containsKey('sources'), isFalse);
    expect(fields.containsKey('sources_note'), isFalse);
  });

  testWidgets('numbers that a JSON number would change are sent as text', (
    tester,
  ) async {
    final session = questionnaireWith((schema) {
      schema.firstWhere((q) => q['key'] == 'income')
        ..remove('min')
        ..remove('max');
    });
    for (final (typed, sent) in [
      ('12345678901234567890', '12345678901234567890' as Object),
      ('0.10', '0.10'),
      ('-7', -7),
      ('2.5', 2.5),
    ]) {
      final backend = Backend()
        ..sessions.addAll([session, fixture('requirement-added-session')]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(flow(backend));
      await tester.pumpAndSettle();
      await answerRequired(tester);
      await choose(tester, 'employment', 'Self employed');
      await type(tester, 'income', typed);
      await tapText(tester, copy(SpecCopyKey.questionsSend));
      expect((lastSubmit(backend)['fields'] as Map)['income'], sent);
    }
  });

  testWidgets('founders are asked as names and whether the applicant is one', (
    tester,
  ) async {
    final session = questionnaireWith((schema) {
      schema.insert(schema.length - 1, {
        'key': 'founders',
        'label': 'Founders',
        'type': 'founders',
        'required': true,
      });
    });
    final backend = Backend()
      ..sessions.addAll([session, fixture('requirement-added-session')]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(question('founders'), findsOneWidget);
    await answerRequired(tester);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(
      find.descendant(
        of: question('founders'),
        matching: find.text(copy(SpecCopyKey.questionsRequired)),
      ),
      findsOneWidget,
    );
    await tapText(tester, copy(SpecCopyKey.questionsFoundersIncludesMe));
    await type(tester, 'founders-0', ' Ada Obi ');
    await tapText(tester, copy(SpecCopyKey.questionsFoundersAdd));
    await type(tester, 'founders-1', 'Ben Eto');
    await tapText(tester, copy(SpecCopyKey.questionsFoundersAdd));
    await type(tester, 'founders-2', 'Cy Doe');
    await tester.tap(
      find.text(copy(SpecCopyKey.questionsFoundersRemove)).at(2),
    );
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.questionsFoundersAdd));
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect((lastSubmit(backend)['fields'] as Map)['founders'], {
      'includes_applicant': true,
      'names': ['Ada Obi', 'Ben Eto'],
    });
  });

  test('only a visible question of an unknown type sends the form back', () {
    final schema = [
      for (final q
          in fixture('questionnaire-session')['data']['profile']['form_schema']
              as List)
        Map<String, dynamic>.from(q as Map),
    ];
    final employer = schema.firstWhere((q) => q['key'] == 'employer');
    expect(canAskQuestions(schema), isTrue);
    employer['type'] = 'signature';
    expect(canAskQuestions(schema), isTrue);
    expect(canAskQuestions(schema, {'employment': 'Employed'}), isFalse);
    employer.remove('show_if');
    expect(canAskQuestions(schema), isFalse);
  });

  testWidgets('an unknown question revealed by an answer goes to the host', (
    tester,
  ) async {
    final session = questionnaireWith((schema) {
      schema.firstWhere((q) => q['key'] == 'employer')['type'] = 'signature';
    });
    final backend = Backend()..sessions.add(session);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(find.text(copy(SpecCopyKey.questionsTitle)), findsOneWidget);
    await answerRequired(tester);
    await choose(tester, 'employment', 'Employed');
    expect(question('employer'), findsNothing);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(backend.requests.where((r) => r.path.endsWith('/submit')), isEmpty);
    expect(find.text(copy(SpecCopyKey.questionsTitle)), findsNothing);
    expect(find.text(copy(SpecCopyKey.emailTitle)), findsOneWidget);
  });

  testWidgets('earlier answers of the case decide which questions show', (
    tester,
  ) async {
    final session = fixture('questionnaire-earlier-answers-session');
    final backend = Backend()
      ..sessions.addAll([session, fixture('requirement-added-session')]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(question('employer'), findsOneWidget);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(find.text(copy(SpecCopyKey.questionsRequired)), findsOneWidget);
    await type(tester, 'employer', 'Acme');
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(lastSubmit(backend)['fields'], {'employer': 'Acme'});
  });

  testWidgets('an earlier answer asked again starts with its value', (
    tester,
  ) async {
    final session = fixture('questionnaire-earlier-answers-session');
    final employment =
        (fixture('questionnaire-session')['data']['profile']['form_schema']
                as List)
            .firstWhere((q) => q['key'] == 'employment');
    (session['data']['profile']['form_schema'] as List).insert(0, employment);
    final backend = Backend()
      ..sessions.addAll([session, fixture('requirement-added-session')]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: question('employment'),
        matching: find.text('Employed'),
      ),
      findsOneWidget,
    );
    await type(tester, 'employer', 'Acme');
    await choose(tester, 'employment', 'Student');
    expect(question('employer'), findsNothing);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(lastSubmit(backend)['fields'], {'employment': 'Student'});
  });

  testWidgets('a form of optional questions left empty sends no fields', (
    tester,
  ) async {
    final session = questionnaireWith((schema) {
      schema.retainWhere((q) => q['key'] == 'contact_email');
    });
    final backend = Backend()
      ..sessions.addAll([session, fixture('requirement-added-session')]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(lastSubmit(backend)['fields'], <String, Object?>{});
  });

  testWidgets('clearing an earlier answer asked again sends it as empty', (
    tester,
  ) async {
    final session = fixture('questionnaire-earlier-answers-session');
    final profile = session['data']['profile'] as Map<String, dynamic>;
    final employer = (profile['form_schema'] as List).single as Map;
    employer['required'] = false;
    (profile['form_answers'] as Map)['employer'] = 'Acme';
    (profile['form_schema'] as List).add({
      ...employer,
      'key': 'employer_note',
      'show_if': {
        'conditions': [
          {'path': 'form.employer', 'op': 'equals', 'value': 'Acme'},
        ],
      },
    });
    final backend = Backend()
      ..sessions.addAll([session, fixture('requirement-added-session')]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('question-employer')))
          .controller!
          .text,
      'Acme',
    );
    expect(question('employer_note'), findsOneWidget);
    await type(tester, 'employer', '');
    expect(question('employer_note'), findsNothing);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(lastSubmit(backend)['fields'], {'employer': null});
  });

  testWidgets('changed answers after a lost response get a new request key', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.addAll([
        fixture('questionnaire-session'),
        fixture('requirement-added-session'),
      ])
      ..dropNextSubmit = true;
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await answerRequired(tester);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(
      find.text(copy(SpecCopyKey.errorsSendAnswersFailed)),
      findsOneWidget,
    );
    final first = backend.requests.lastWhere((r) => r.path.endsWith('/submit'));
    backend.dropNextSubmit = true;
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    final same = backend.requests.lastWhere((r) => r.path.endsWith('/submit'));
    expect(same.key, first.key);
    await type(tester, 'contact_email', 'jane@example.test');
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    final changed = backend.requests.lastWhere(
      (r) => r.path.endsWith('/submit'),
    );
    expect(changed.key, isNot(first.key));
    expect(find.text(copy(SpecCopyKey.phoneTitle)), findsOneWidget);
  });

  testWidgets('answers refused because the case closed show the receipt', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(fixture('questionnaire-session'))
      ..closedAfterSubmit = fixture('session-closed')
      ..closeOnPost = true;
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await answerRequired(tester);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(find.text(copy(SpecCopyKey.receiptTitle)), findsOneWidget);
    expect(find.text(copy(SpecCopyKey.receiptAnswers)), findsOneWidget);
  });

  testWidgets('the questionnaire on its own reads earlier answers from info', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.add(fixture('questionnaire-earlier-answers-session'));
    final session = CredflareSession(descriptor(), client: backend.client);
    final info = await session.get();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CredflareQuestionnaire(
              session: session,
              info: info,
              onSubmitted: (_) {},
              onBusyChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(question('employer'), findsOneWidget);
  });

  testWidgets('text length counts characters, not UTF-16 units', (
    tester,
  ) async {
    final backend = Backend()
      ..sessions.addAll([
        fixture('questionnaire-session'),
        fixture('requirement-added-session'),
      ]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await answerRequired(tester);
    await choose(tester, 'employment', 'Employed');
    final long =
        '\u{1F600}' * (SpecRequirements.questionsTextMaxLength ~/ 2 + 1);
    await type(tester, 'employer', long);
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect(find.text(copy(SpecCopyKey.questionsTextTooLong)), findsNothing);
    expect((lastSubmit(backend)['fields'] as Map)['employer'], long);
  });

  testWidgets('the date picker reaches dates before 1900', (tester) async {
    final backend = Backend()
      ..sessions.addAll([
        fixture('questionnaire-session'),
        fixture('requirement-added-session'),
      ]);
    await tester.pumpWidget(flow(backend));
    await tester.pumpAndSettle();
    await choose(tester, 'employment', 'Student');
    await choose(tester, 'country', '${flag('AD')}  AD');
    await tester.ensureVisible(
      find.byKey(const ValueKey('question-birth_date')),
    );
    await tester.tap(find.byKey(const ValueKey('question-birth_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      '12/31/1899',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapText(tester, consentLabel());
    await tapText(tester, copy(SpecCopyKey.questionsSend));
    expect((lastSubmit(backend)['fields'] as Map)['birth_date'], '1899-12-31');
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
