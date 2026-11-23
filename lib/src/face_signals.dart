import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'liveness_engine.dart';

const _faces = MethodChannel('credflare_sdk/faces');

class CameraFrame {
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool nv21;
  final int rotation;
  final bool mirrored;
  const CameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.nv21,
    required this.rotation,
    required this.mirrored,
  });

  int get uprightWidth => rotation % 180 == 0 ? width : height;
  int get uprightHeight => rotation % 180 == 0 ? height : width;
}

Uint8List encodeFrameJpeg(CameraFrame frame) {
  img.Image image;
  if (frame.nv21) {
    image = img.Image(width: frame.width, height: frame.height);
    final y = frame.bytes;
    final uvStart = frame.width * frame.height;
    for (var row = 0; row < frame.height; row++) {
      for (var col = 0; col < frame.width; col++) {
        final luma = y[row * frame.width + col];
        final uv = uvStart + (row >> 1) * frame.width + (col & ~1);
        final v = y[uv] - 128;
        final u = y[uv + 1] - 128;
        image.setPixelRgb(
          col,
          row,
          (luma + 1.402 * v).round().clamp(0, 255),
          (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
          (luma + 1.772 * u).round().clamp(0, 255),
        );
      }
    }
  } else {
    image = img.Image.fromBytes(
      width: frame.width,
      height: frame.height,
      bytes: frame.bytes.buffer,
      bytesOffset: frame.bytes.offsetInBytes,
      rowStride: frame.bytesPerRow,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );
  }
  if (frame.rotation != 0) {
    image = img.copyRotate(image, angle: frame.rotation);
  }
  if (frame.mirrored) image = img.flipHorizontal(image);
  return img.encodeJpg(image, quality: 85);
}

abstract class FaceSignalProvider {
  String get name;

  Future<FaceSample> process(CameraFrame frame, {required int t});

  Future<void> close();
}

/// A face found by ML Kit, in pixels of the upright frame.
class DetectedFace {
  final Rect boundingBox;
  final double? headEulerAngleX;
  final double? headEulerAngleY;
  final double? smilingProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  const DetectedFace({
    required this.boundingBox,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });
}

FaceSample faceSampleFromDetectedFaces(
  List<DetectedFace> faces, {
  required int t,
  required int width,
  required int height,
  required bool mirrored,
}) {
  if (faces.isEmpty) return FaceSample(t: t, faces: 0);
  final face = faces.reduce(
    (a, b) =>
        a.boundingBox.width * a.boundingBox.height >=
            b.boundingBox.width * b.boundingBox.height
        ? a
        : b,
  );
  final rect = face.boundingBox;
  final w = rect.width / width;
  final x = rect.left / width;
  final eyes = [
    face.leftEyeOpenProbability,
    face.rightEyeOpenProbability,
  ].whereType<double>().toList();
  final yaw = face.headEulerAngleY;
  return FaceSample(
    t: t,
    faces: faces.length,
    box: FaceBox(
      mirrored ? 1 - x - w : x,
      rect.top / height,
      w,
      rect.height / height,
    ),
    eyeOpen: eyes.isEmpty ? null : eyes.reduce((a, b) => a + b) / eyes.length,
    smile: face.smilingProbability,
    yaw: yaw == null ? null : (mirrored ? -yaw : yaw),
    pitch: face.headEulerAngleX,
  );
}

/// Reads faces with the fields of an ML Kit `Face`.
@Deprecated('Use faceSampleFromDetectedFaces with DetectedFace.')
FaceSample faceSampleFromMlKit(
  List<Object> faces, {
  required int t,
  required int width,
  required int height,
  required bool mirrored,
}) => faceSampleFromDetectedFaces(
  [
    for (final dynamic face in faces)
      face is DetectedFace
          ? face
          : DetectedFace(
              boundingBox: face.boundingBox as Rect,
              headEulerAngleX: (face.headEulerAngleX as num?)?.toDouble(),
              headEulerAngleY: (face.headEulerAngleY as num?)?.toDouble(),
              smilingProbability: (face.smilingProbability as num?)?.toDouble(),
              leftEyeOpenProbability: (face.leftEyeOpenProbability as num?)
                  ?.toDouble(),
              rightEyeOpenProbability: (face.rightEyeOpenProbability as num?)
                  ?.toDouble(),
            ),
  ],
  t: t,
  width: width,
  height: height,
  mirrored: mirrored,
);

/// Turns Vision eye and mouth shapes into the contract's 0 to 1 signals,
/// relative to the applicant's own first frames.
class VisionSignalNormalizer {
  static const fallbackEyeRatio = 0.27;
  static const fallbackMouthRatio = 0.95;
  static const baselineFrames = 8;
  static const closedEyeFraction = 0.35;
  static const fullSmileWidening = 0.18;

  final _eyeRatios = <double>[];
  final _mouthRatios = <double>[];

  double get eyeBaseline => _median(_eyeRatios) ?? fallbackEyeRatio;
  double get mouthBaseline => _median(_mouthRatios) ?? fallbackMouthRatio;

  double eyeOpen(double ratio) {
    if (_eyeRatios.length < baselineFrames) _eyeRatios.add(ratio);
    final relative = ratio / eyeBaseline;
    return _clamp((relative - closedEyeFraction) / (1 - closedEyeFraction));
  }

  double smile(double ratio) {
    if (_mouthRatios.length < baselineFrames) _mouthRatios.add(ratio);
    return _clamp((ratio / mouthBaseline - 1) / fullSmileWidening);
  }

  static double contractYaw(double radians) => radians * 180 / math.pi;
  static double contractPitch(double radians) => -radians * 180 / math.pi;

  /// Vision boxes start at the bottom left; the contract's at the top left.
  static FaceBox contractBox(double x, double y, double w, double h) =>
      FaceBox(x, 1 - (y + h), w, h);

  static double _clamp(double value) => math.min(1, math.max(0, value));

  static double? _median(List<double> values) {
    if (values.length < baselineFrames) return null;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }
}

/// Builds a sample from one Vision reading of an upright frame.
FaceSample faceSampleFromVision(
  Map reading,
  VisionSignalNormalizer normalizer, {
  required int t,
  required bool mirrored,
}) {
  final faces = (reading['faces'] as num?)?.toInt() ?? 0;
  if (faces != 1) return FaceSample(t: t, faces: faces);
  double? value(String key) => (reading[key] as num?)?.toDouble();
  final box = VisionSignalNormalizer.contractBox(
    value('x')!,
    value('y')!,
    value('width')!,
    value('height')!,
  );
  final yaw = value('yaw');
  final pitch = value('pitch');
  final eyes = value('eye_ratio');
  final mouth = value('mouth_ratio');
  final contractYaw = yaw == null
      ? null
      : VisionSignalNormalizer.contractYaw(yaw);
  return FaceSample(
    t: t,
    faces: 1,
    box: mirrored ? FaceBox(1 - box.x - box.w, box.y, box.w, box.h) : box,
    yaw: contractYaw == null ? null : (mirrored ? -contractYaw : contractYaw),
    pitch: pitch == null ? null : VisionSignalNormalizer.contractPitch(pitch),
    eyeOpen: eyes == null ? null : normalizer.eyeOpen(eyes),
    smile: mouth == null ? null : normalizer.smile(mouth),
  );
}

const _deviceRotation = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

CameraFrame? cameraFrame(
  CameraImage image,
  CameraDescription camera,
  DeviceOrientation orientation,
) {
  if (image.planes.length != 1) return null;
  final plane = image.planes.first;
  if (Platform.isAndroid) {
    if (image.format.group != ImageFormatGroup.nv21) return null;
    final device = _deviceRotation[orientation] ?? 0;
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + device) % 360
        : (camera.sensorOrientation - device + 360) % 360;
    return CameraFrame(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      nv21: true,
      rotation: rotation,
      mirrored: false,
    );
  }
  if (image.format.group != ImageFormatGroup.bgra8888) return null;
  return CameraFrame(
    bytes: plane.bytes,
    width: image.width,
    height: image.height,
    bytesPerRow: plane.bytesPerRow,
    nv21: false,
    rotation: 0,
    mirrored: camera.lensDirection == CameraLensDirection.front,
  );
}

/// The face reader for this platform: Apple's Vision on iOS, ML Kit
/// elsewhere.
FaceSignalProvider defaultFaceSignalProvider() =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? VisionFaceSignalProvider()
    : MlKitFaceSignalProvider();

/// Reads faces with ML Kit on Android.
class MlKitFaceSignalProvider implements FaceSignalProvider {
  static var _next = 0;
  final String _id = 'faces-${_next++}';

  @override
  String get name => 'mlkit';

  @override
  Future<FaceSample> process(CameraFrame frame, {required int t}) async {
    if (!frame.nv21) {
      throw UnsupportedError('ML Kit here reads NV21 frames only.');
    }
    final faces =
        await _faces.invokeListMethod<Map>('mlkit#process', {
          'id': _id,
          'bytes': frame.bytes,
          'width': frame.width,
          'height': frame.height,
          'rotation': frame.rotation,
        }) ??
        const [];
    return faceSampleFromDetectedFaces(
      [
        for (final face in faces)
          DetectedFace(
            boundingBox: Rect.fromLTRB(
              (face['left'] as num).toDouble(),
              (face['top'] as num).toDouble(),
              (face['right'] as num).toDouble(),
              (face['bottom'] as num).toDouble(),
            ),
            headEulerAngleX: (face['pitch'] as num?)?.toDouble(),
            headEulerAngleY: (face['yaw'] as num?)?.toDouble(),
            smilingProbability: (face['smile'] as num?)?.toDouble(),
            leftEyeOpenProbability: (face['left_eye_open'] as num?)?.toDouble(),
            rightEyeOpenProbability: (face['right_eye_open'] as num?)
                ?.toDouble(),
          ),
      ],
      t: t,
      width: frame.uprightWidth,
      height: frame.uprightHeight,
      mirrored: frame.mirrored,
    );
  }

  @override
  Future<void> close() => _faces.invokeMethod('mlkit#close', {'id': _id});
}

/// Reads faces with Apple's Vision framework on iOS.
class VisionFaceSignalProvider implements FaceSignalProvider {
  var _normalizer = VisionSignalNormalizer();

  @override
  String get name => 'vision';

  /// Starts a new baseline for the eyes and mouth.
  void reset() => _normalizer = VisionSignalNormalizer();

  @override
  Future<FaceSample> process(CameraFrame frame, {required int t}) async {
    if (frame.nv21 || frame.rotation != 0) {
      throw UnsupportedError('Vision here reads upright BGRA frames only.');
    }
    final reading =
        await _faces.invokeMapMethod<String, Object?>('vision#process', {
          'bytes': frame.bytes,
          'width': frame.width,
          'height': frame.height,
          'bytesPerRow': frame.bytesPerRow,
        }) ??
        const {'faces': 0};
    return faceSampleFromVision(
      reading,
      _normalizer,
      t: t,
      mirrored: frame.mirrored,
    );
  }

  @override
  Future<void> close() async {}
}
