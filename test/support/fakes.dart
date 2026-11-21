import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';

final pixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Map<String, dynamic> trace(String name) =>
    jsonDecode(
          File('test/fixtures/liveness-traces/$name.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<FaceSample> samplesUntilDone(String name, {int offset = 0}) {
  final data = trace(name);
  final gesture = data['gesture'] as String;
  final gate = gesture == 'position' ? PositionGate() : null;
  final run = gate == null ? GestureRun(gesture) : null;
  final out = <FaceSample>[];
  for (final raw in data['samples'] as List) {
    final sample = FaceSample.fromJson(raw as Map);
    out.add(sample.withTime(sample.t + offset));
    final result = gate?.push(sample) ?? run!.push(sample);
    if (result.state != EngineState.running) break;
  }
  return out;
}

class FakeLivenessSource implements LivenessCaptureSource {
  final _samples = StreamController<FaceSample>.broadcast();
  final events = <String>[];
  bool started = false;
  int _t = 0;

  @override
  String get provider => 'default';

  @override
  Stream<FaceSample> get samples => _samples.stream;

  void play(String traceName) {
    final samples = samplesUntilDone(traceName, offset: _t);
    for (final sample in samples) {
      _samples.add(sample);
    }
    _t = samples.last.t + 66;
  }

  @override
  Future<void> start() async {
    started = true;
    events.add('start');
  }

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF8899AA));

  @override
  Future<Uint8List> captureFrame() async {
    events.add('frame');
    return pixelPng;
  }

  @override
  Future<void> startRecording() async => events.add('record');

  @override
  Future<CapturedMedia> stopRecording() async {
    events.add('stop');
    return CapturedMedia(Uint8List.fromList([0, 0, 0, 24]), 'liveness.mp4');
  }

  @override
  Future<CapturedMedia> takeSelfie() async {
    events.add('selfie');
    return CapturedMedia(pixelPng, 'selfie.jpg');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
    await _samples.close();
  }
}

class FakeLocationSource implements LocationSource {
  final LocationAccess access;
  final List<LocationFix Function()> fixes;
  int requests = 0;
  FakeLocationSource(this.fixes, {this.access = LocationAccess.granted});

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Future<LocationFix> currentFix(Duration timeout) async =>
      fixes[(requests++).clamp(0, fixes.length - 1)]();
}

LocationFix locationFix({
  double accuracy = 12,
  bool? isMock = false,
  Duration age = Duration.zero,
}) {
  final now = DateTime.now();
  return LocationFix(
    latitude: 4.0511,
    longitude: 9.7679,
    accuracy: accuracy,
    fixTime: now.subtract(age),
    isMock: isMock,
    provider: 'fused',
    capturedAt: now,
  );
}

class RecordedRequest {
  final String method;
  final String path;
  final Map<String, String> fields;
  final String? body;
  RecordedRequest(this.method, this.path, this.fields, this.body);
}
