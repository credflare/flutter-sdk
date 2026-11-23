import 'dart:math' as math;
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

DetectedFace face({
  Rect box = const Rect.fromLTWH(100, 120, 200, 260),
  double yaw = 25,
  double pitch = -18,
}) => DetectedFace(
  boundingBox: box,
  headEulerAngleX: pitch,
  headEulerAngleY: yaw,
  leftEyeOpenProbability: 0.9,
  rightEyeOpenProbability: 0.7,
  smilingProbability: 0.8,
);

const channel = MethodChannel('credflare_sdk/faces');

CameraFrame frame({bool nv21 = false, bool mirrored = true}) => CameraFrame(
  bytes: Uint8List(16),
  width: 480,
  height: 640,
  bytesPerRow: nv21 ? 480 : 1920,
  nv21: nv21,
  rotation: nv21 ? 270 : 0,
  mirrored: mirrored,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Object? reply;
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('iOS reads faces with Vision and Android with ML Kit', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(defaultFaceSignalProvider().name, 'vision');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(defaultFaceSignalProvider().name, 'mlkit');
    debugDefaultTargetPlatformOverride = null;
    expect(resolveThresholds('vision'), resolveThresholds('default'));
  });

  test('the Vision normalizer uses the contract conventions', () {
    expect(
      VisionSignalNormalizer.contractYaw(-0.5),
      closeTo(-0.5 * 180 / math.pi, 1e-9),
    );
    expect(
      VisionSignalNormalizer.contractPitch(0.3),
      closeTo(-0.3 * 180 / math.pi, 1e-9),
    );
    final box = VisionSignalNormalizer.contractBox(0.2, 0.1, 0.4, 0.5);
    expect(box.x, closeTo(0.2, 1e-9));
    expect(box.y, closeTo(0.4, 1e-9));
    final normalizer = VisionSignalNormalizer();
    final thresholds = resolveThresholds('vision');
    for (var i = 0; i < VisionSignalNormalizer.baselineFrames; i++) {
      expect(normalizer.eyeOpen(0.3), closeTo(1, 0.2));
    }
    expect(normalizer.eyeBaseline, closeTo(0.3, 1e-9));
    expect(normalizer.eyeOpen(0.12), lessThan(thresholds['eye_closed']!));
    expect(
      normalizer.eyeOpen(0.27),
      greaterThan(thresholds['eye_open_baseline']!),
    );
    for (var i = 0; i < VisionSignalNormalizer.baselineFrames; i++) {
      normalizer.smile(0.9);
    }
    expect(normalizer.smile(0.9), closeTo(0, 1e-9));
    expect(normalizer.smile(1.05), greaterThan(thresholds['smile']!));
  });

  test('a Vision reading of a mirrored frame gives contract signals', () async {
    reply = {
      'faces': 1,
      'x': 0.2,
      'y': 0.1,
      'width': 0.4,
      'height': 0.5,
      'yaw': 0.5,
      'pitch': 0.3,
      'eye_ratio': 0.27,
      'mouth_ratio': 0.95,
    };
    final provider = VisionFaceSignalProvider();
    final sample = await provider.process(frame(), t: 12);
    expect(calls.single.method, 'vision#process');
    expect(calls.single.arguments, {
      'bytes': Uint8List(16),
      'width': 480,
      'height': 640,
      'bytesPerRow': 1920,
    });
    expect(sample.t, 12);
    expect(sample.faces, 1);
    expect(sample.box!.x, closeTo(1 - 0.2 - 0.4, 1e-9));
    expect(sample.box!.y, closeTo(0.4, 1e-9));
    expect(sample.yaw, closeTo(-0.5 * 180 / math.pi, 1e-9));
    expect(sample.pitch, closeTo(-0.3 * 180 / math.pi, 1e-9));
    expect(sample.eyeOpen, closeTo(1, 1e-9));
    expect(sample.smile, closeTo(0, 1e-9));
    reply = {'faces': 2};
    final two = await provider.process(frame(mirrored: false), t: 13);
    expect(two.faces, 2);
    expect(two.box, isNull);
  });

  test('ML Kit faces from the platform become samples', () async {
    reply = [
      {
        'left': 100,
        'top': 120,
        'right': 300,
        'bottom': 380,
        'pitch': -18.0,
        'yaw': 25.0,
        'smile': 0.8,
        'left_eye_open': 0.9,
        'right_eye_open': 0.7,
      },
    ];
    final provider = MlKitFaceSignalProvider();
    final sample = await provider.process(
      frame(nv21: true, mirrored: false),
      t: 5,
    );
    final call = calls.single;
    expect(call.method, 'mlkit#process');
    expect((call.arguments as Map)['rotation'], 270);
    expect(sample.faces, 1);
    expect(sample.yaw, 25);
    expect(sample.pitch, -18);
    expect(sample.eyeOpen, closeTo(0.8, 1e-9));
    expect(sample.smile, 0.8);
    expect(sample.box!.x, closeTo(100 / 640, 1e-9));
    expect(sample.box!.h, closeTo(260 / 480, 1e-9));
    await provider.close();
    expect(calls.last.method, 'mlkit#close');
    expect((calls.last.arguments as Map)['id'], (call.arguments as Map)['id']);
  });

  test('unmirrored frames keep the ML Kit signs and box', () {
    final sample = faceSampleFromDetectedFaces(
      [face()],
      t: 66,
      width: 480,
      height: 640,
      mirrored: false,
    );
    expect(sample.t, 66);
    expect(sample.faces, 1);
    expect(sample.yaw, 25);
    expect(sample.pitch, -18);
    expect(sample.eyeOpen, closeTo(0.8, 1e-9));
    expect(sample.smile, 0.8);
    expect(sample.box!.x, closeTo(100 / 480, 1e-9));
    expect(sample.box!.y, closeTo(120 / 640, 1e-9));
    expect(sample.box!.w, closeTo(200 / 480, 1e-9));
    expect(sample.box!.h, closeTo(260 / 640, 1e-9));
  });

  test('mirrored frames flip yaw and the horizontal box position', () {
    final sample = faceSampleFromDetectedFaces(
      [face()],
      t: 0,
      width: 480,
      height: 640,
      mirrored: true,
    );
    expect(sample.yaw, -25);
    expect(sample.pitch, -18);
    expect(sample.box!.x, closeTo(1 - 300 / 480, 1e-9));
  });

  test('no face and several faces are reported as counts', () {
    expect(
      faceSampleFromDetectedFaces(
        [],
        t: 0,
        width: 1,
        height: 1,
        mirrored: false,
      ).faces,
      0,
    );
    final two = faceSampleFromDetectedFaces(
      [
        face(box: const Rect.fromLTWH(0, 0, 10, 10)),
        face(box: const Rect.fromLTWH(100, 100, 200, 200), yaw: 3),
      ],
      t: 0,
      width: 400,
      height: 400,
      mirrored: false,
    );
    expect(two.faces, 2);
    expect(two.yaw, 3);
  });

  test('NV21 frames encode as upright JPEG images', () {
    const width = 8, height = 4;
    final bytes = Uint8List(width * height * 3 ~/ 2)
      ..fillRange(0, width * height, 200)
      ..fillRange(width * height, width * height * 3 ~/ 2, 128);
    final jpeg = encodeFrameJpeg(
      CameraFrame(
        bytes: bytes,
        width: width,
        height: height,
        bytesPerRow: width,
        nv21: true,
        rotation: 270,
        mirrored: false,
      ),
    );
    final decoded = img.decodeJpg(jpeg)!;
    expect(decoded.width, height);
    expect(decoded.height, width);
  });

  test('every spec icon parses into a drawable path', () {
    for (final entry in SpecIcons.all.entries) {
      for (final path in entry.value.paths) {
        final bounds = parseSpecPath(path.d).getBounds();
        expect(bounds.width + bounds.height, greaterThan(0), reason: entry.key);
      }
    }
  });
}
