import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'client.dart';
import 'copy.dart';
import 'liveness_engine.dart';
import 'liveness_source.dart';
import 'requirements.dart';
import 'spec.generated.dart';
import 'spec_icon.dart';
import 'theme.dart';
import 'ui.dart';

enum _Phase { intro, starting, position, gestures, finishing, review, sending }

class CredflareLivenessCapture extends StatefulWidget {
  final CredflareSession session;
  final Map<String, dynamic> info;
  final FacialSettings settings;
  final LivenessSourceFactory sourceFactory;
  final VoidCallback onSubmitted;
  final ValueChanged<bool> onBusyChanged;
  final DateTime Function() now;
  const CredflareLivenessCapture({
    super.key,
    required this.session,
    required this.info,
    required this.settings,
    required this.sourceFactory,
    required this.onSubmitted,
    required this.onBusyChanged,
    this.now = DateTime.now,
  });
  @override
  State<CredflareLivenessCapture> createState() => _LivenessState();
}

class _Upload {
  final String key = requestKey();
  int? id;
}

class _LivenessState extends State<CredflareLivenessCapture> {
  _Phase _phase = _Phase.intro;
  LivenessChallenge? _challenge;
  LivenessCaptureSource? _source;
  StreamSubscription<FaceSample>? _subscription;
  Timer? _watchdog;
  Timer? _videoLimit;
  PositionGate? _gate;
  GestureRun? _run;
  int _index = 0;
  DateTime _stageStart = DateTime.now();
  PositionStatus _status = PositionStatus.noFace;
  bool _faceLost = false;
  bool _recording = false;
  Future<void>? _videoStarted;
  Future<CapturedMedia>? _videoResult;
  String _provider = 'default';
  final _frames = <Future<Uint8List>>[];
  final _results = <Map<String, dynamic>>[];
  Map<String, dynamic>? _faceDetection;
  List<Uint8List> _frameBytes = [];
  CapturedMedia? _videoMedia;
  CapturedMedia? _selfie;
  List<_Upload> _gestureUploads = [];
  _Upload _videoUpload = _Upload(), _selfieUpload = _Upload();
  String _submitKey = requestKey();
  String? _error;
  bool _canRetry = false;

  String get _verifier => verifierName(widget.info);

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _stop() {
    _watchdog?.cancel();
    _videoLimit?.cancel();
    _subscription?.cancel();
    _subscription = null;
    final source = _source;
    _source = null;
    _recording = false;
    if (source != null) unawaited(source.dispose());
  }

  void _fail(String message, {bool retry = true}) {
    _stop();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.intro;
      _error = message;
      _canRetry = retry;
    });
  }

  String _cameraError(Object error) {
    if (error is LivenessCameraException) {
      return copy(switch (error.failure) {
        CameraFailure.denied => SpecCopyKey.errorsCameraDenied,
        CameraFailure.noFrontCamera => SpecCopyKey.errorsFrontCameraRequired,
        CameraFailure.unavailable => SpecCopyKey.errorsCameraUnavailable,
      });
    }
    return copy(SpecCopyKey.errorsCameraUnavailable);
  }

  Future<void> _start() async {
    if (_phase != _Phase.intro) return;
    _stop();
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _index = 0;
      _status = PositionStatus.noFace;
      _faceLost = false;
      _frames.clear();
      _results.clear();
      _faceDetection = null;
      _videoStarted = null;
      _videoResult = null;
      _selfie = null;
      _videoMedia = null;
      _frameBytes = [];
    });
    final LivenessChallenge challenge;
    try {
      challenge = await widget.session.createLivenessChallenge();
    } catch (error) {
      _fail(
        error is CredflareException && error.status == 401
            ? copy(SpecCopyKey.errorsSessionExpired)
            : copy(SpecCopyKey.errorsChallengeFailed),
        retry: !(error is CredflareException && error.status == 401),
      );
      return;
    }
    if (!mounted) return;
    final source = widget.sourceFactory();
    _source = source;
    try {
      await source.start();
    } catch (error) {
      if (identical(_source, source)) _fail(_cameraError(error));
      return;
    }
    if (!mounted || !identical(_source, source)) return;
    _provider = source.provider;
    _gestureUploads = [for (final _ in challenge.gestures) _Upload()];
    _videoUpload = _Upload();
    _selfieUpload = _Upload();
    _submitKey = requestKey();
    setState(() {
      _challenge = challenge;
      _gate = PositionGate();
      _phase = _Phase.position;
      _stageStart = widget.now();
    });
    _subscription = source.samples.listen(_onSample);
    _watchdog = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _checkTime();
    });
  }

  void _checkTime() {
    if (_phase != _Phase.position && _phase != _Phase.gestures) return;
    final now = widget.now();
    if (!now.isBefore(_challenge!.expiresAt)) {
      _fail(copy(SpecCopyKey.livenessExpired));
    } else if (now.difference(_stageStart).inMilliseconds >=
        SpecLiveness.gestureTimeoutMs + 2000) {
      _fail(copy(SpecCopyKey.livenessTimeout));
    }
  }

  void _onSample(FaceSample sample) {
    if (!mounted) return;
    if (_phase == _Phase.position) {
      final result = _gate!.push(sample);
      setState(() => _status = result.status!);
      if (result.state == EngineState.timeout) {
        _fail(copy(SpecCopyKey.livenessTimeout));
      } else if (result.state == EngineState.pass) {
        _faceDetection = {
          'detected': true,
          'face_count': sample.faces,
          'is_centered': true,
          'is_correct_size': true,
        };
        setState(() {
          _phase = _Phase.gestures;
          _index = 0;
          _run = GestureRun(_challenge!.gestures.first, provider: _provider);
          _stageStart = widget.now();
        });
        if (_challenge!.recordVideo) _startVideo();
      }
      return;
    }
    if (_phase != _Phase.gestures) return;
    final result = _run!.push(sample);
    if (result.state == EngineState.timeout) {
      _fail(copy(SpecCopyKey.livenessTimeout));
      return;
    }
    if (result.state == EngineState.running) {
      if (_faceLost == result.tracked) {
        setState(() => _faceLost = !result.tracked);
      }
      return;
    }
    _frames.add(_source!.captureFrame());
    _results.add({
      'challenge': _challenge!.gestures[_index],
      'completed': true,
      'timestamp': widget.now().toUtc().toIso8601String(),
    });
    if (_index + 1 == _challenge!.gestures.length) {
      unawaited(_finish());
      return;
    }
    setState(() {
      _index += 1;
      _faceLost = false;
      _run = GestureRun(_challenge!.gestures[_index], provider: _provider);
      _stageStart = widget.now();
    });
  }

  void _startVideo() {
    final source = _source!;
    _recording = true;
    _videoStarted = source.startRecording();
    _videoLimit = Timer(
      Duration(seconds: _challenge!.maxVideoSeconds),
      _endVideo,
    );
  }

  Future<CapturedMedia>? _endVideo() {
    final started = _videoStarted;
    if (started == null) return null;
    final source = _source!;
    _videoLimit?.cancel();
    if (_recording && mounted) setState(() => _recording = false);
    return _videoResult ??= started.then((_) => source.stopRecording());
  }

  Future<void> _finish() async {
    _watchdog?.cancel();
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      _phase = _Phase.finishing;
      _faceLost = false;
    });
    final source = _source!;
    try {
      final video = _endVideo();
      if (video != null) {
        _videoMedia = await video;
        if (_videoMedia!.bytes.isEmpty) throw StateError('Empty video');
      }
      _frameBytes = await Future.wait(_frames);
      _selfie = await source.takeSelfie();
    } catch (_) {
      _fail(copy(SpecCopyKey.errorsSelfieFailed));
      return;
    }
    _stop();
    if (!mounted) return;
    setState(() => _phase = _Phase.review);
  }

  Future<void> _send() async {
    final challenge = _challenge!;
    if (!widget.now().isBefore(challenge.expiresAt)) {
      _fail(copy(SpecCopyKey.livenessExpired));
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      for (var i = 0; i < challenge.gestures.length; i++) {
        final upload = _gestureUploads[i];
        upload.id ??= await widget.session.uploadBiometric(
          bytes: _frameBytes[i],
          filename: '${challenge.gestures[i]}.jpg',
          key: upload.key,
          type: BiometricUploadType.gesture,
          challengeId: challenge.id,
          gesture: challenge.gestures[i],
        );
      }
      if (_videoMedia != null) {
        _videoUpload.id ??= await widget.session.uploadBiometric(
          bytes: _videoMedia!.bytes,
          filename: _videoMedia!.filename,
          key: _videoUpload.key,
          type: BiometricUploadType.livenessVideo,
          challengeId: challenge.id,
        );
      }
      _selfieUpload.id ??= await widget.session.uploadBiometric(
        bytes: _selfie!.bytes,
        filename: _selfie!.filename,
        key: _selfieUpload.key,
        type: BiometricUploadType.selfie,
        challengeId: challenge.id,
      );
      await widget.session.submitFacial(
        challengeId: challenge.id,
        imageFileId: _selfieUpload.id!,
        gestureFileIds: [for (final upload in _gestureUploads) upload.id!],
        videoFileId: _videoUpload.id,
        metadata: {
          'provider': _provider,
          'liveness_results': _results,
          'face_detection': _faceDetection,
          'captured_at': widget.now().toUtc().toIso8601String(),
        },
        key: _submitKey,
      );
      widget.onBusyChanged(false);
      widget.onSubmitted();
    } catch (error) {
      widget.onBusyChanged(false);
      if (!mounted) return;
      final validation = error is CredflareException && error.status == 422;
      setState(() {
        _phase = validation ? _Phase.intro : _Phase.review;
        _canRetry = true;
        _error = _sendError(error);
      });
    }
  }

  String _sendError(Object error) {
    if (error is! CredflareException || error.status == 0) {
      return copy(SpecCopyKey.errorsSendSelfieFailed);
    }
    return switch (error.code) {
      SpecErrorCode.livenessChallengeExpired ||
      SpecErrorCode.livenessChallengeInvalid ||
      SpecErrorCode.livenessChallengeUsed ||
      SpecErrorCode.livenessFrameOutOfWindow => copy(
        SpecCopyKey.livenessExpired,
      ),
      _ => error.message,
    };
  }

  Widget _preview(BuildContext context) {
    final source = _source;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 240,
        height: 300,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(SpecTokens.radiusSheet * 5.0),
          border: Border.all(
            color:
                _phase == _Phase.position && _status == PositionStatus.ok ||
                    _phase == _Phase.gestures && !_faceLost
                ? CredflareTheme.of(context)['success']!
                : colors.outline,
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: source == null
            ? const Center(child: CircularProgressIndicator())
            : FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 240,
                  height: 320,
                  child: source.buildPreview(context),
                ),
              ),
      ),
    );
  }

  List<Widget> _intro(ThemeData theme) => [
    const CredflareGlyph(SpecIcons.selfie),
    CredflareTitle(copy(SpecCopyKey.livenessTitle)),
    const SizedBox(height: 8),
    CredflareBody(
      copy(SpecCopyKey.livenessBody, {'total': widget.settings.gestureCount}),
    ),
    const SizedBox(height: 12),
    CredflareBody(copy(SpecCopyKey.selfieGuidance), small: true),
    if (widget.settings.recordVideo) ...[
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(CredflareTheme.radius),
        ),
        child: Column(
          children: [
            CredflareIcon(SpecIcons.video, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            CredflareBody(
              copy(SpecCopyKey.videoConsent, {'verifier': _verifier}),
              color: theme.colorScheme.onSurface,
            ),
          ],
        ),
      ),
    ],
    if (_error != null) CredflareNotice(_error!),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: _phase == _Phase.intro && (_error == null || _canRetry)
          ? _start
          : null,
      child: Text(
        copy(
          _error == null
              ? SpecCopyKey.livenessStart
              : SpecCopyKey.livenessRetry,
        ),
      ),
    ),
    const SizedBox(height: 16),
    CredflareBody(
      copy(SpecCopyKey.selfiePrivacy, {'verifier': _verifier}),
      small: true,
    ),
  ];

  List<Widget> _running(ThemeData theme) {
    final challenge = _challenge;
    final total = challenge?.gestures.length ?? widget.settings.gestureCount;
    final gesture = challenge == null || _phase != _Phase.gestures
        ? null
        : challenge.gestures[_index];
    final prompt = switch (_phase) {
      _Phase.starting => copy(SpecCopyKey.selfieStartingCamera),
      _Phase.position => copy(_status.copyKey),
      _Phase.finishing => copy(SpecCopyKey.livenessSuccess),
      _ => copy('liveness.gesture.$gesture'),
    };
    return [
      CredflareTitle(copy(SpecCopyKey.livenessTitle)),
      const SizedBox(height: 4),
      CredflareBody(
        _phase == _Phase.gestures
            ? copy(SpecCopyKey.livenessProgress, {
                'current': _index + 1,
                'total': total,
              })
            : ' ',
        small: true,
      ),
      const SizedBox(height: 16),
      _preview(context),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 6),
      if (_faceLost)
        CredflareBody(
          copy(SpecCopyKey.livenessFaceLost),
          color: theme.colorScheme.error,
        ),
      if (_recording)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              copy(SpecCopyKey.videoRecording),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: _phase == _Phase.finishing
            ? null
            : () => setState(() {
                _stop();
                _phase = _Phase.intro;
              }),
        child: Text(copy(SpecCopyKey.commonCancel)),
      ),
    ];
  }

  List<Widget> _review(ThemeData theme) => [
    CredflareTitle(copy(SpecCopyKey.selfieReviewTitle)),
    const SizedBox(height: 8),
    CredflareBody(copy(SpecCopyKey.selfieReviewBody)),
    const SizedBox(height: 8),
    CredflareBody(
      copy(SpecCopyKey.livenessSuccess),
      small: true,
      color: CredflareTheme.of(context)['success'],
    ),
    const SizedBox(height: 16),
    ClipRRect(
      borderRadius: BorderRadius.circular(CredflareTheme.radius),
      child: Image.memory(
        _selfie!.bytes,
        height: 280,
        cacheWidth: 1200,
        fit: BoxFit.contain,
        semanticLabel: copy(SpecCopyKey.selfiePreviewLabel),
        errorBuilder: (_, _, _) => const SizedBox(height: 280),
      ),
    ),
    if (_error != null) CredflareNotice(_error!),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _phase == _Phase.review ? _send : null,
      child: Text(
        copy(
          _phase == _Phase.sending
              ? SpecCopyKey.livenessSending
              : SpecCopyKey.selfieSend,
        ),
      ),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _phase == _Phase.review
          ? () => setState(() {
              _phase = _Phase.intro;
              _error = null;
              _start();
            })
          : null,
      child: Text(copy(SpecCopyKey.livenessRetry)),
    ),
    const SizedBox(height: 16),
    CredflareBody(
      copy(SpecCopyKey.selfiePrivacy, {'verifier': _verifier}),
      small: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (_phase) {
        _Phase.intro => _intro(theme),
        _Phase.review || _Phase.sending => _review(theme),
        _ => _running(theme),
      },
    );
  }
}
