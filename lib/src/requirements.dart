import 'spec.generated.dart';

class FacialSettings {
  final List<String> gestures;
  final int gestureCount;
  final bool recordVideo;
  final int? videoRetentionDays;
  const FacialSettings({
    required this.gestures,
    required this.gestureCount,
    required this.recordVideo,
    this.videoRetentionDays,
  });

  factory FacialSettings.fromJson(Map? json) => FacialSettings(
    gestures:
        (json?['gestures'] as List?)?.cast<String>() ??
        SpecSettings.facialVerificationGesturesDefault,
    gestureCount:
        (json?['gesture_count'] as num?)?.toInt() ??
        SpecSettings.facialVerificationGestureCountDefault,
    recordVideo:
        json?['record_video'] as bool? ??
        SpecSettings.facialVerificationRecordVideoDefault,
    videoRetentionDays: (json?['video_retention_days'] as num?)?.toInt(),
  );
}

class LocationReference {
  final String rule;
  final String match;
  final List<String> labels;
  const LocationReference({
    required this.rule,
    required this.labels,
    this.match = 'any',
  });

  factory LocationReference.fromJson(Map json) => LocationReference(
    rule: json['rule'] as String? ?? 'within',
    match: json['match'] as String? ?? 'any',
    labels: [
      for (final place in json['places'] as List? ?? const [])
        if ((place as Map)['label'] is String) place['label'] as String,
    ],
  );
}

class LocationRequirementSettings {
  final int maxAccuracyM;
  final int maxAgeS;
  final String mockLocation;
  final String ipCountry;
  final LocationReference? reference;
  const LocationRequirementSettings({
    required this.maxAccuracyM,
    required this.maxAgeS,
    required this.mockLocation,
    required this.ipCountry,
    this.reference,
  });

  factory LocationRequirementSettings.fromJson(Map? json) {
    final reference = json?['reference'];
    return LocationRequirementSettings(
      maxAccuracyM:
          (json?['max_accuracy_m'] as num?)?.toInt() ??
          SpecSettings.locationVerificationMaxAccuracyMDefault,
      maxAgeS:
          (json?['max_age_s'] as num?)?.toInt() ??
          SpecSettings.locationVerificationMaxAgeSDefault,
      mockLocation:
          json?['mock_location'] as String? ??
          SpecSettings.locationVerificationMockLocationDefault,
      ipCountry:
          json?['ip_country'] as String? ??
          SpecSettings.locationVerificationIpCountryDefault,
      reference: reference is Map
          ? LocationReference.fromJson(reference)
          : null,
    );
  }
}

class VerificationRequirement {
  final String type;
  final Map<String, dynamic> settings;
  const VerificationRequirement(this.type, this.settings);

  FacialSettings get facial => FacialSettings.fromJson(settings);
  LocationRequirementSettings get location =>
      LocationRequirementSettings.fromJson(settings);
}

List<VerificationRequirement> verificationRequirements(
  Map<String, dynamic> info,
) => [
  for (final item
      in (info['profile'] as Map?)?['verification_requirements'] as List? ??
          const [])
    VerificationRequirement(
      (item as Map)['verification_type'] as String,
      Map<String, dynamic>.from(item['settings'] as Map? ?? const {}),
    ),
];

const sdkVerificationTypes = [
  'facial_verification',
  'location_verification',
  'email_verification',
  'phone_verification',
];

/// The refresh rule: a session still needs the applicant while its status is
/// open and any outstanding list is non empty.
bool sessionOutstanding(Map<String, dynamic> info) {
  if (!SpecRequirements.refreshOpenStatuses.contains(info['status'])) {
    return false;
  }
  return SpecRequirements.refreshOutstanding.any((path) {
    Object? value = info;
    for (final segment in path.split('.')) {
      value = value is Map ? value[segment] : null;
    }
    return value is List && value.isNotEmpty;
  });
}
