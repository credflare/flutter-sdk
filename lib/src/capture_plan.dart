const _supported = ['upload', 'either', 'snapshot', 'snapshot_and_upload'];

class CaptureStep {
  final String source;
  final String side;
  const CaptureStep(this.source, this.side);
  String get id => '$source:$side';
  String get label => side == 'front' ? 'Front' : 'Back';
  String get sourceLabel => source == 'camera'
      ? 'Camera photo'
      : source == 'upload'
      ? 'Saved file'
      : 'Photo or file';
}

String capturePolicy(Map<String, dynamic> requirement) {
  final document = requirement['document_type'] as Map;
  return requirement['capture_method'] as String? ??
      (document['capture_method'] == 'camera' ? 'either' : 'upload');
}

bool isCaptureSupported(Map<String, dynamic> requirement) =>
    _supported.contains(capturePolicy(requirement));

String methodSummary(Map<String, dynamic> requirement) =>
    switch (capturePolicy(requirement)) {
      'snapshot' => 'Camera photos',
      'upload' => 'Saved files',
      'either' => 'Photo or file',
      'snapshot_and_upload' => 'Photo and saved file',
      _ => 'Not available in this app',
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
              : method == 'either'
              ? 'either'
              : 'upload',
        ];
  return [
    for (final source in sources)
      for (final side in sides) CaptureStep(source, side),
  ];
}
