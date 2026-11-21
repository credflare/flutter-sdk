import 'spec.generated.dart';

class FaceBox {
  final double x;
  final double y;
  final double w;
  final double h;
  const FaceBox(this.x, this.y, this.w, this.h);

  factory FaceBox.fromJson(Map json) => FaceBox(
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
    (json['w'] as num).toDouble(),
    (json['h'] as num).toDouble(),
  );

  Map<String, double> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};
}

class FaceSample {
  final int t;
  final int faces;
  final FaceBox? box;
  final double? eyeOpen;
  final double? smile;
  final double? yaw;
  final double? pitch;
  const FaceSample({
    required this.t,
    required this.faces,
    this.box,
    this.eyeOpen,
    this.smile,
    this.yaw,
    this.pitch,
  });

  factory FaceSample.fromJson(Map json) => FaceSample(
    t: (json['t'] as num).toInt(),
    faces: (json['faces'] as num).toInt(),
    box: json['box'] is Map ? FaceBox.fromJson(json['box'] as Map) : null,
    eyeOpen: (json['eye_open'] as num?)?.toDouble(),
    smile: (json['smile'] as num?)?.toDouble(),
    yaw: (json['yaw'] as num?)?.toDouble(),
    pitch: (json['pitch'] as num?)?.toDouble(),
  );

  FaceSample withTime(int value) => FaceSample(
    t: value,
    faces: faces,
    box: box,
    eyeOpen: eyeOpen,
    smile: smile,
    yaw: yaw,
    pitch: pitch,
  );

  double? signal(String name) => switch (name) {
    'eye_open' => eyeOpen,
    'smile' => smile,
    'yaw' => yaw,
    'pitch' => pitch,
    _ => throw ArgumentError('Unknown face signal $name'),
  };
}

Map<String, double> resolveThresholds(String provider) => {
  ...SpecLiveness.thresholds['default']!,
  ...?SpecLiveness.thresholds[provider],
};

double _lookup(Map<String, double> thresholds, String value) =>
    double.tryParse(value) ?? thresholds[value]!;

bool testStep(
  SpecGestureStep step,
  FaceSample sample,
  Map<String, double> thresholds,
) {
  final s = sample.signal(step.signal);
  if (s == null) return false;
  final v = _lookup(thresholds, step.value);
  return switch (step.op) {
    'gt' => s > v,
    'lt' => s < v,
    'lt_neg' => s < -v,
    'abs_lt' => s.abs() < v,
    _ => throw ArgumentError('Unknown op ${step.op}'),
  };
}

enum PositionStatus {
  noFace('no_face', SpecCopyKey.livenessPositionNoFace),
  multipleFaces('multiple_faces', SpecCopyKey.livenessPositionOneFace),
  tooSmall('too_small', SpecCopyKey.livenessPositionMoveCloser),
  tooLarge('too_large', SpecCopyKey.livenessPositionMoveFurther),
  offCenter('off_center', SpecCopyKey.livenessPositionCenter),
  ok('ok', SpecCopyKey.livenessPositionReady);

  final String value;
  final String copyKey;
  const PositionStatus(this.value, this.copyKey);
}

PositionStatus positionStatus(FaceSample sample) {
  if (sample.faces == 0) return PositionStatus.noFace;
  if (sample.faces > SpecLiveness.positionFaces) {
    return PositionStatus.multipleFaces;
  }
  final box = sample.box!;
  final area = box.w * box.h;
  if (area < SpecLiveness.positionFaceAreaMin) return PositionStatus.tooSmall;
  if (area > SpecLiveness.positionFaceAreaMax) return PositionStatus.tooLarge;
  final dx = (box.x + box.w / 2 - 0.5).abs();
  final dy = (box.y + box.h / 2 - 0.5).abs();
  if (dx > SpecLiveness.positionCenterTolerance ||
      dy > SpecLiveness.positionCenterTolerance) {
    return PositionStatus.offCenter;
  }
  return PositionStatus.ok;
}

enum EngineState { running, pass, timeout }

class EngineResult {
  final EngineState state;
  final int? t;
  final PositionStatus? status;
  final int step;
  final bool tracked;
  const EngineResult(
    this.state, {
    this.t,
    this.status,
    this.step = 0,
    this.tracked = true,
  });
}

class PositionGate {
  int? _start;
  bool _done = false;

  EngineResult push(FaceSample sample) {
    if (_done) throw StateError('Position gate already finished');
    final start = _start ??= sample.t;
    final status = positionStatus(sample);
    if (sample.t - start >= SpecLiveness.gestureTimeoutMs) {
      _done = true;
      return EngineResult(EngineState.timeout, status: status);
    }
    if (status == PositionStatus.ok) {
      _done = true;
      return EngineResult(EngineState.pass, status: status, t: sample.t);
    }
    return EngineResult(EngineState.running, status: status);
  }
}

class GestureRun {
  final String gesture;
  final List<SpecGestureStep> _steps;
  final Map<String, double> _thresholds;
  int? _start;
  int? _prevT;
  int? _lostSince;
  int _index = 0;
  int _count = 0;
  bool _done = false;

  GestureRun(this.gesture, {String provider = 'default'})
    : _steps =
          SpecLiveness.gestures[gesture] ??
          (throw ArgumentError('Unknown gesture $gesture')),
      _thresholds = resolveThresholds(provider);

  int get step => _index;

  EngineResult push(FaceSample sample) {
    if (_done) throw StateError('Gesture run already finished');
    final reset = SpecLiveness.faceLostResetMs;
    final start = _start ??= sample.t;
    if (sample.t - start >= SpecLiveness.gestureTimeoutMs) {
      _done = true;
      return EngineResult(EngineState.timeout, step: _index);
    }
    final gap = _prevT != null && sample.t - _prevT! >= reset;
    _prevT = sample.t;
    if (sample.faces != 1) {
      _count = 0;
      final lostSince = _lostSince ??= sample.t;
      if (sample.t - lostSince >= reset) _index = 0;
      return EngineResult(EngineState.running, step: _index, tracked: false);
    }
    if (gap || (_lostSince != null && sample.t - _lostSince! >= reset)) {
      _index = 0;
      _count = 0;
    }
    _lostSince = null;
    final step = _steps[_index];
    if (testStep(step, sample, _thresholds)) {
      _count += 1;
      final hold = step.holdFrames == null
          ? 1.0
          : _lookup(_thresholds, step.holdFrames!);
      if (_count >= hold) {
        _index += 1;
        _count = 0;
        if (_index == _steps.length) {
          _done = true;
          return EngineResult(EngineState.pass, step: _index, t: sample.t);
        }
      }
    } else {
      _count = 0;
    }
    return EngineResult(EngineState.running, step: _index);
  }
}

class TraceOutcome {
  final String outcome;
  final int? t;
  final PositionStatus? status;
  final int? step;
  const TraceOutcome(this.outcome, {this.t, this.status, this.step});
}

TraceOutcome runTrace(Map trace) {
  final gesture = trace['gesture'] as String;
  final provider = trace['provider'] as String? ?? 'default';
  final gate = gesture == 'position' ? PositionGate() : null;
  final run = gate == null ? GestureRun(gesture, provider: provider) : null;
  EngineResult? last;
  for (final raw in trace['samples'] as List) {
    final sample = FaceSample.fromJson(raw as Map);
    last = gate?.push(sample) ?? run!.push(sample);
    if (last.state != EngineState.running) break;
  }
  final outcome = last != null && last.state != EngineState.running
      ? last.state.name
      : 'fail';
  return TraceOutcome(
    outcome,
    t: last?.t,
    status: last?.status,
    step: last?.step,
  );
}
