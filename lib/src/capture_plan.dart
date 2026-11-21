import 'copy.dart';
import 'spec.generated.dart';

const _supported = [
  'upload',
  'snapshot_or_upload',
  'snapshot',
  'snapshot_and_upload',
];

class CaptureStep {
  final String source;
  final String side;
  const CaptureStep(this.source, this.side);
  String get id => '$source:$side';
  String get label => copy(
    side == 'front'
        ? SpecCopyKey.captureSideFront
        : SpecCopyKey.captureSideBack,
  );
  String get sourceLabel => copy(
    source == 'camera'
        ? SpecCopyKey.captureSourceCamera
        : source == 'upload'
        ? SpecCopyKey.captureSourceUpload
        : SpecCopyKey.documentsMethodEither,
  );
}

String capturePolicy(Map<String, dynamic> requirement) {
  final document = requirement['document_type'] as Map;
  final method =
      requirement['capture_method'] as String? ??
      (document['capture_method'] == 'camera'
          ? 'snapshot_or_upload'
          : 'upload');
  return method == 'either' ? 'snapshot_or_upload' : method;
}

bool isCaptureSupported(Map<String, dynamic> requirement) =>
    _supported.contains(capturePolicy(requirement));

String methodSummary(Map<String, dynamic> requirement, [String? verifier]) =>
    switch (capturePolicy(requirement)) {
      'snapshot' => copy(SpecCopyKey.documentsMethodCamera),
      'upload' => copy(SpecCopyKey.documentsMethodUpload),
      'snapshot_or_upload' => copy(SpecCopyKey.documentsMethodEither),
      'snapshot_and_upload' => copy(SpecCopyKey.documentsMethodBoth),
      _ => copy(SpecCopyKey.documentsUnavailable, {
        'verifier': verifier ?? copy(SpecCopyKey.commonVerifierFallback),
      }),
    };

List<CaptureStep> captureSteps(Map<String, dynamic> requirement) {
  final document = requirement['document_type'] as Map;
  final method = capturePolicy(requirement);
  if (!_supported.contains(method)) {
    throw UnsupportedError('This document cannot be collected in this app.');
  }
  final sides =
      (requirement['requested_sides'] as List?)?.cast<String>() ??
      (document['two_sided'] == true ? ['front', 'back'] : ['front']);
  final sources = method == 'snapshot_and_upload'
      ? ['camera', 'upload']
      : [
          method == 'snapshot'
              ? 'camera'
              : method == 'snapshot_or_upload'
              ? 'camera_or_upload'
              : 'upload',
        ];
  return [
    for (final source in sources)
      for (final side in sides) CaptureStep(source, side),
  ];
}
