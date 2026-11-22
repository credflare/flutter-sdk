import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fixtures.dart';

CredflareException rejected(String code) {
  final body = fixture('rejections/$code');
  return CredflareException(
    body['message'] as String,
    422,
    body['errors'],
    body['code'] as String,
  );
}

void main() {
  final info = fixture('help-contact-session')['data'] as Map<String, dynamic>;
  final requester = info['requester'] as Map;
  final verifier = requester['name'] as String;
  final email = requester['help_email'] as String;
  final url = requester['help_url'] as String;

  Map<String, dynamic> withContact({String? helpEmail, String? helpUrl}) => {
    ...info,
    'requester': {...requester, 'help_email': helpEmail, 'help_url': helpUrl},
  };

  test('the help line prefers the email address, then the link', () {
    final error = rejected(SpecErrorCode.phoneCodeInvalid);
    final both = Rejection.from(error, info: info);
    expect(
      both.help,
      copy(SpecRejection.helpEmail, {
        'verifier': verifier,
        'help_email': email,
      }),
    );
    expect(both.helpLink!.$2, Uri(scheme: 'mailto', path: email));

    final link = Rejection.from(error, info: withContact(helpUrl: url));
    expect(link.help, copy(SpecRejection.helpUrl, {'help_url': url}));
    expect(link.helpLink!.$2, Uri.parse(url));

    final none = Rejection.from(error, info: withContact());
    expect(none.help, copy(SpecRejection.help, {'verifier': verifier}));
    expect(none.helpLink, isNull);

    final unknown = Rejection.from(
      CredflareException('Something new', 422, null, 'phone.something_new'),
      info: info,
    );
    expect(unknown.message, 'Something new');
    expect(unknown.action, 'retry');
    expect(unknown.helpLink, isNotNull);
  });

  test('a missing requester uses the verifier fallback', () {
    final none = Rejection.from(
      rejected(SpecErrorCode.emailCodeExpired),
      info: {...info, 'requester': null},
    );
    final fallback = copy(SpecCopyKey.commonVerifierFallback);
    expect(
      none.requestedBy,
      copy(SpecRejection.requestedBy, {'verifier': fallback}),
    );
    expect(none.help, copy(SpecRejection.help, {'verifier': fallback}));
  });

  testWidgets('the help address is shown as a link', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CredflareRejection(
            rejection: Rejection.from(
              rejected(SpecErrorCode.phoneSendLimit),
              info: info,
            ),
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.text(email), findsOneWidget);
    expect(
      find.ancestor(of: find.text(email), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.text(copy(SpecRejection.requestedBy, {'verifier': verifier})),
      findsOneWidget,
    );
  });
}
