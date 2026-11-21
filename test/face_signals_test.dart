import 'dart:typed_data';
import 'dart:ui';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

Face face({
  Rect box = const Rect.fromLTWH(100, 120, 200, 260),
  double yaw = 25,
  double pitch = -18,
}) => Face(
  boundingBox: box,
  landmarks: const {},
  contours: const {},
  headEulerAngleX: pitch,
  headEulerAngleY: yaw,
  headEulerAngleZ: 0,
  leftEyeOpenProbability: 0.9,
  rightEyeOpenProbability: 0.7,
  smilingProbability: 0.8,
);

void main() {
  test('unmirrored frames keep the ML Kit signs and box', () {
    final sample = faceSampleFromMlKit(
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
    final sample = faceSampleFromMlKit(
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
      faceSampleFromMlKit([], t: 0, width: 1, height: 1, mirrored: false).faces,
      0,
    );
    final two = faceSampleFromMlKit(
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
