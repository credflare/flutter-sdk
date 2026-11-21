import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'liveness_engine.dart';

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

FaceSample faceSampleFromMlKit(
  List<Face> faces, {
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

class MlKitFaceSignalProvider implements FaceSignalProvider {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  @override
  String get name => 'mlkit';

  @override
  Future<FaceSample> process(CameraFrame frame, {required int t}) async {
    final input = InputImage.fromBytes(
      bytes: frame.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation:
            InputImageRotationValue.fromRawValue(frame.rotation) ??
            InputImageRotation.rotation0deg,
        format: frame.nv21 ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: frame.bytesPerRow,
      ),
    );
    final faces = await _detector.processImage(input);
    return faceSampleFromMlKit(
      faces,
      t: t,
      width: frame.uprightWidth,
      height: frame.uprightHeight,
      mirrored: frame.mirrored,
    );
  }

  @override
  Future<void> close() => _detector.close();
}
