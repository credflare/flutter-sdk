import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:credflare_example/main.dart';

void main() {
  testWidgets('asks for scoped session access before showing capture', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Example()));
    expect(find.text('Load session'), findsOneWidget);
    expect(find.text('Session JSON'), findsOneWidget);
    expect(find.text('Submit document'), findsNothing);
  });
}
