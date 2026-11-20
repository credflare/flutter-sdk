import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:credflare_sdk/credflare_sdk.dart';

void main() {
  test(
    'combined capture keeps photos and uploads as separate required steps',
    () async {
      final fixture =
          jsonDecode(
                await File(
                  'test/fixtures/capture-snapshot_and_upload.json',
                ).readAsString(),
              )
              as Map;
      final requirement = Map<String, dynamic>.from(
        fixture['data']['profile']['document_requirements'][0] as Map,
      );
      final steps = captureSteps(requirement);
      expect(steps.map((e) => e.id).toList(), [
        'camera:front',
        'camera:back',
        'upload:front',
        'upload:back',
      ]);
    },
  );
  test('snapshot_or_upload capture asks once for each side', () async {
    final fixture =
        jsonDecode(
              await File(
                'test/fixtures/capture-snapshot-or-upload.json',
              ).readAsString(),
            )
            as Map;
    final requirement = Map<String, dynamic>.from(
      fixture['data']['profile']['document_requirements'][0] as Map,
    );
    expect(captureSteps(requirement).map((e) => e.id).toList(), [
      'camera_or_upload:front',
      'camera_or_upload:back',
    ]);
  });
  Future<Map<String, dynamic>> fixture(String name) async {
    final data = jsonDecode(await File(name).readAsString()) as Map;
    return Map<String, dynamic>.from(
      data['data']['profile']['document_requirements'][0] as Map,
    );
  }

  test('steps carry side and source labels', () async {
    final steps = captureSteps(
      await fixture('test/fixtures/capture-snapshot_and_upload.json'),
    );
    expect(steps.map((e) => '${e.label} ${e.sourceLabel}').toList(), [
      'Front Camera photo',
      'Back Camera photo',
      'Front Saved file',
      'Back Saved file',
    ]);
  });
  test(
    'a requirement without capture_method follows its document type',
    () async {
      final requirement =
          await fixture('test/fixtures/capture-snapshot-or-upload.json')
            ..remove('capture_method');
      expect(capturePolicy(requirement), 'snapshot_or_upload');
      expect(methodSummary(requirement), 'Photo or file');
    },
  );
  test('a stored either method reads as snapshot_or_upload', () async {
    final requirement =
        await fixture('test/fixtures/capture-snapshot-or-upload.json')
          ..['capture_method'] = 'either';
    expect(capturePolicy(requirement), 'snapshot_or_upload');
    expect(captureSteps(requirement).map((e) => e.id).toList(), [
      'camera_or_upload:front',
      'camera_or_upload:back',
    ]);
  });
  test(
    'an unsupported method is reported instead of producing steps',
    () async {
      final requirement =
          await fixture('test/fixtures/capture-snapshot-or-upload.json')
            ..['capture_method'] = 'camera_only';
      expect(isCaptureSupported(requirement), isFalse);
      expect(methodSummary(requirement), 'Not available in this app');
      expect(() => captureSteps(requirement), throwsUnsupportedError);
    },
  );
  test('file size limits read as whole or one-decimal megabytes', () {
    expect(formatSize(10485760), '10 MB');
    expect(formatSize(524288), '0.5 MB');
  });
  test('brand text stays readable in both themes', () {
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + 0.05) / (values.first + 0.05);
    }

    for (final palette in [CredflareTheme.light, CredflareTheme.dark]) {
      for (final name in ['ink', 'muted', 'primary', 'error', 'success']) {
        expect(
          contrast(palette[name]!, palette['surface']!),
          greaterThanOrEqualTo(4.5),
          reason: name,
        );
      }
      expect(
        contrast(palette['onPrimary']!, palette['primary']!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(palette['warningInk']!, palette['warningSoft']!),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
