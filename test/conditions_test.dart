import 'dart:convert';
import 'dart:io';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fixtures.dart';

void main() {
  final cases = fixture('show-if-cases');

  test('the fixture holds every backend case', () {
    expect(
      (cases['conditions'] as List).length + (cases['show_if'] as List).length,
      62,
    );
  });

  for (final item in cases['conditions'] as List) {
    test('condition: ${item['name']}', () {
      expect(
        testCondition(item['condition'] as Map, {'form': item['form']}),
        item['expect'],
      );
    });
  }

  for (final item in cases['show_if'] as List) {
    test('show_if: ${item['name']}', () {
      final form = item['form'];
      expect(
        questionVisible({
          'key': 'q',
          'show_if': item['show_if'],
        }, form is Map ? Map<String, Object?>.from(form) : {}),
        item['expect'],
      );
    });
  }

  final reference =
      jsonDecode(
            File('test/support/reference-conditions.json').readAsStringSync(),
          )
          as List;
  for (final item in reference) {
    test('reference evaluator: ${item['name']}', () {
      expect(
        testCondition(item['condition'] as Map, {'form': item['form']}),
        item['expect'],
      );
    });
  }

  test('every operator in the spec is covered by a backend case', () {
    final ops = {
      for (final item in cases['conditions'] as List) item['condition']['op'],
    };
    expect(ops, containsAll(SpecRequirements.showIfOperators));
  });
}
