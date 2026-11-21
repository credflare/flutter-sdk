import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'face_signals.dart';
import 'liveness_engine.dart';

enum CameraFailure { denied, unavailable, noFrontCamera }

class LivenessCameraException implements Exception {
  final CameraFailure failure;
  const LivenessCameraException(this.failure);
}

class CapturedMedia {
  final Uint8List bytes;
  final String filename;
  const CapturedMedia(this.bytes, this.filename);
}

abstract class LivenessCaptureSource {
  String get provider;

  Stream<FaceSample> get samples;

  Future<void> start();

  Widget buildPreview(BuildContext context);

  Future<Uint8List> captureFrame();

  Future<void> startRecording();

  Future<CapturedMedia> stopRecording();

  Future<CapturedMedia> takeSelfie();

  Future<void> dispose();
}

typedef LivenessSourceFactory = LivenessCaptureSource Function();

class CameraLivenessSource implements LivenessCaptureSource {
  final FaceSignalProvider faceProvider;
  final _samples = StreamController<FaceSample>.broadcast();
  final _clock = Stopwatch();
  CameraController? _controller;
  CameraFrame? _lastFrame;
  bool _processing = false;
  bool _disposed = false;

  CameraLivenessSource({FaceSignalProvider? faceProvider})
    : faceProvider = faceProvider ?? MlKitFaceSignalProvider();

  @override
  String get provider => faceProvider.name;

  @override
  Stream<FaceSample> get samples => _samples.stream;

  @override
  Future<void> start() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      throw const LivenessCameraException(CameraFailure.unavailable);
    }
    if (cameras.isEmpty) {
      throw const LivenessCameraException(CameraFailure.unavailable);
    }
    final front = cameras
        .where((camera) => camera.lensDirection == CameraLensDirection.front)
        .firstOrNull;
    if (front == null) {
      throw const LivenessCameraException(CameraFailure.noFrontCamera);
    }
    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _clock.start();
      await controller.startImageStream(_onImage);
    } on CameraException catch (error) {
      throw LivenessCameraException(
        error.code.contains('Access') || error.code.contains('ermission')
            ? CameraFailure.denied
            : CameraFailure.unavailable,
      );
    }
  }

  Future<void> _onImage(CameraImage image) async {
    final controller = _controller;
    if (_processing || _disposed || controller == null) return;
    final frame = cameraFrame(
      image,
      controller.description,
      controller.value.lockedCaptureOrientation ??
          controller.value.deviceOrientation,
    );
    if (frame == null) return;
    _processing = true;
    final t = _clock.elapsedMilliseconds;
    try {
      final sample = await faceProvider.process(frame, t: t);
      if (_disposed) return;
      _lastFrame = frame;
      _samples.add(sample);
    } catch (_) {
      if (!_disposed) _samples.add(FaceSample(t: t, faces: 0));
    } finally {
      _processing = false;
    }
  }

  @override
  Widget buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  Future<Uint8List> captureFrame() {
    final frame = _lastFrame;
    if (frame == null) {
      return Future.error(
        const LivenessCameraException(CameraFailure.unavailable),
      );
    }
    return Isolate.run(() => encodeFrameJpeg(frame));
  }

  @override
  Future<void> startRecording() async {
    final controller = _controller!;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.startVideoRecording(onAvailable: _onImage);
  }

  @override
  Future<CapturedMedia> stopRecording() async {
    final controller = _controller!;
    final file = await controller.stopVideoRecording();
    if (!_disposed && !controller.value.isStreamingImages) {
      await controller.startImageStream(_onImage);
    }
    final name = file.name.toLowerCase();
    return CapturedMedia(
      await file.readAsBytes(),
      name.endsWith('.mov') ? 'liveness.mov' : 'liveness.mp4',
    );
  }

  @override
  Future<CapturedMedia> takeSelfie() async {
    final controller = _controller!;
    try {
      final file = await controller.takePicture();
      return CapturedMedia(await file.readAsBytes(), 'selfie.jpg');
    } on CameraException {
      return CapturedMedia(await captureFrame(), 'selfie.jpg');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final controller = _controller;
    _controller = null;
    await _samples.close();
    try {
      if (controller?.value.isRecordingVideo == true) {
        await controller!.stopVideoRecording();
      }
      if (controller?.value.isStreamingImages == true) {
        await controller!.stopImageStream();
      }
    } on CameraException {
      // The camera may already be closed by the platform.
    }
    await controller?.dispose();
    await faceProvider.close();
  }
}
