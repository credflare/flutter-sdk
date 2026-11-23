// GENERATED FILE, DO NOT EDIT.
// Source: credflare sdk-spec 1.1.0 (f30a34ca3aac). Regenerate with scripts/generate.mjs.
// ignore_for_file: type=lint

const String credflareSpecVersion = '1.1.0';
const String credflareSpecHash = 'f30a34ca3aac';

/// One step of a gesture. value and holdFrames name a threshold key.
final class SpecGestureStep {
  final String signal;
  final String op;
  final String value;
  final String? holdFrames;
  const SpecGestureStep({required this.signal, required this.op, required this.value, this.holdFrames});
}

/// One setting in the requirement settings schema. path uses dots, with [] for list items. defaultJson is the JSON encoded default.
final class SpecSetting {
  final String path;
  final String type;
  final bool optional;
  final double? min;
  final double? max;
  final List<String> options;
  final String? defaultJson;
  const SpecSetting({required this.path, required this.type, required this.optional, this.min, this.max, required this.options, this.defaultJson});
}

/// Applicant copy for a rejection code. Every text field is a copy key. The place messages replace message when the location requirement has reference places.
final class SpecRejectionCopy {
  final String title;
  final String message;
  final String action;
  final String? placeMessageWithin;
  final String? placeMessageOutside;
  const SpecRejectionCopy({required this.title, required this.message, required this.action, this.placeMessageWithin, this.placeMessageOutside});
}

final class SpecPalette {
  final int primary;
  final int onPrimary;
  final int surface;
  final int ink;
  final int muted;
  final int soft;
  final int border;
  final int accent;
  final int success;
  final int error;
  final int warningSoft;
  final int warningInk;
  const SpecPalette({required this.primary, required this.onPrimary, required this.surface, required this.ink, required this.muted, required this.soft, required this.border, required this.accent, required this.success, required this.error, required this.warningSoft, required this.warningInk});
}

final class SpecTextStyle {
  final double size;
  final double lineHeight;
  final int weight;
  const SpecTextStyle({required this.size, required this.lineHeight, required this.weight});
}

/// Absolute path data using only M, L, C and Z, with values in viewBox units.
final class SpecIconPath {
  final String d;
  final bool stroke;
  final bool fill;
  final double strokeWidth;
  final double strokeOpacity;
  final double fillOpacity;
  const SpecIconPath({required this.d, required this.stroke, required this.fill, required this.strokeWidth, required this.strokeOpacity, required this.fillOpacity});
}

final class SpecIcon {
  final double viewBox;
  final double strokeWidth;
  final List<SpecIconPath> paths;
  const SpecIcon({required this.viewBox, required this.strokeWidth, required this.paths});
}

abstract final class SpecLiveness {
  static const int version = 1;
  static const int challengeTtlS = 120;
  static const int gestureTimeoutMs = 10000;
  static const int sampleIntervalMs = 66;
  static const int videoMaxSeconds = 8;
  static const int videoMaxHeight = 480;
  static const double positionFaceAreaMin = 0.15;
  static const double positionFaceAreaMax = 0.65;
  static const double positionCenterTolerance = 0.2;
  static const int positionFaces = 1;
  static const int faceLostResetMs = 1000;
  static const List<String> gestureNames = [
    'blink',
    'smile',
    'turn_left',
    'turn_right',
    'nod',
  ];
  static const Map<String, Map<String, double>> thresholds = {
    'default': {
      'eye_open_baseline': 0.6,
      'eye_closed': 0.3,
      'eye_reopened': 0.5,
      'smile': 0.6,
      'smile_hold_frames': 5.0,
      'turn': 20.0,
      'nod': 15.0,
      'return': 10.0,
    },
    'mediapipe': {
      'smile': 0.4,
    },
    'mlkit': {
      'smile': 0.7,
    },
    'vision': {},
  };
  static const Map<String, List<SpecGestureStep>> gestures = {
    'blink': [
      SpecGestureStep(
        signal: 'eye_open',
        op: 'gt',
        value: 'eye_open_baseline',
        holdFrames: null,
      ),
      SpecGestureStep(
        signal: 'eye_open',
        op: 'lt',
        value: 'eye_closed',
        holdFrames: null,
      ),
      SpecGestureStep(
        signal: 'eye_open',
        op: 'gt',
        value: 'eye_reopened',
        holdFrames: null,
      ),
    ],
    'smile': [
      SpecGestureStep(
        signal: 'smile',
        op: 'gt',
        value: 'smile',
        holdFrames: 'smile_hold_frames',
      ),
    ],
    'turn_left': [
      SpecGestureStep(
        signal: 'yaw',
        op: 'gt',
        value: 'turn',
        holdFrames: null,
      ),
      SpecGestureStep(
        signal: 'yaw',
        op: 'abs_lt',
        value: 'return',
        holdFrames: null,
      ),
    ],
    'turn_right': [
      SpecGestureStep(
        signal: 'yaw',
        op: 'lt_neg',
        value: 'turn',
        holdFrames: null,
      ),
      SpecGestureStep(
        signal: 'yaw',
        op: 'abs_lt',
        value: 'return',
        holdFrames: null,
      ),
    ],
    'nod': [
      SpecGestureStep(
        signal: 'pitch',
        op: 'lt_neg',
        value: 'nod',
        holdFrames: null,
      ),
      SpecGestureStep(
        signal: 'pitch',
        op: 'abs_lt',
        value: 'return',
        holdFrames: null,
      ),
    ],
  };
}

abstract final class SpecLocation {
  static const int version = 1;
  static const int clockSkewS = 30;
  static const int fixTimeoutS = 30;
  static const int retryAttempts = 3;
}

abstract final class SpecSettings {
  static const int version = 1;
  static const List<String> facialVerificationGesturesDefault = [
    'blink',
    'smile',
    'turn_left',
    'turn_right',
    'nod',
  ];
  static const int facialVerificationGestureCountDefault = 3;
  static const bool facialVerificationRecordVideoDefault = true;
  static const int locationVerificationMaxAccuracyMDefault = 100;
  static const int locationVerificationMaxAgeSDefault = 60;
  static const String locationVerificationMockLocationDefault = 'reject';
  static const String locationVerificationIpCountryDefault = 'flag';
  static const List<SpecSetting> schema = [
    SpecSetting(
      path: 'facial_verification.gestures',
      type: 'set',
      optional: false,
      min: 1.0,
      max: null,
      options: [
        'blink',
        'smile',
        'turn_left',
        'turn_right',
        'nod',
      ],
      defaultJson: '["blink","smile","turn_left","turn_right","nod"]',
    ),
    SpecSetting(
      path: 'facial_verification.gesture_count',
      type: 'int',
      optional: false,
      min: 1.0,
      max: 5.0,
      options: [],
      defaultJson: '3',
    ),
    SpecSetting(
      path: 'facial_verification.record_video',
      type: 'bool',
      optional: false,
      min: null,
      max: null,
      options: [],
      defaultJson: 'true',
    ),
    SpecSetting(
      path: 'facial_verification.video_retention_days',
      type: 'int',
      optional: true,
      min: 1.0,
      max: 3650.0,
      options: [],
      defaultJson: 'null',
    ),
    SpecSetting(
      path: 'location_verification.max_accuracy_m',
      type: 'int',
      optional: false,
      min: 5.0,
      max: 5000.0,
      options: [],
      defaultJson: '100',
    ),
    SpecSetting(
      path: 'location_verification.max_age_s',
      type: 'int',
      optional: false,
      min: 5.0,
      max: 3600.0,
      options: [],
      defaultJson: '60',
    ),
    SpecSetting(
      path: 'location_verification.mock_location',
      type: 'enum',
      optional: false,
      min: null,
      max: null,
      options: [
        'reject',
        'flag',
        'allow',
      ],
      defaultJson: '"reject"',
    ),
    SpecSetting(
      path: 'location_verification.ip_country',
      type: 'enum',
      optional: false,
      min: null,
      max: null,
      options: [
        'reject',
        'flag',
        'off',
      ],
      defaultJson: '"flag"',
    ),
    SpecSetting(
      path: 'location_verification.reference',
      type: 'object',
      optional: true,
      min: null,
      max: null,
      options: [],
      defaultJson: 'null',
    ),
    SpecSetting(
      path: 'location_verification.reference.places',
      type: 'list',
      optional: false,
      min: 1.0,
      max: 50.0,
      options: [],
      defaultJson: null,
    ),
    SpecSetting(
      path: 'location_verification.reference.places[].id',
      type: 'string',
      optional: false,
      min: null,
      max: 64.0,
      options: [],
      defaultJson: null,
    ),
    SpecSetting(
      path: 'location_verification.reference.places[].label',
      type: 'string',
      optional: false,
      min: null,
      max: 120.0,
      options: [],
      defaultJson: null,
    ),
    SpecSetting(
      path: 'location_verification.reference.places[].latitude',
      type: 'number',
      optional: false,
      min: -90.0,
      max: 90.0,
      options: [],
      defaultJson: null,
    ),
    SpecSetting(
      path: 'location_verification.reference.places[].longitude',
      type: 'number',
      optional: false,
      min: -180.0,
      max: 180.0,
      options: [],
      defaultJson: null,
    ),
    SpecSetting(
      path: 'location_verification.reference.places[].radius_m',
      type: 'int',
      optional: false,
      min: 0.0,
      max: 100000.0,
      options: [],
      defaultJson: null,
    ),
    SpecSetting(
      path: 'location_verification.reference.rule',
      type: 'enum',
      optional: false,
      min: null,
      max: null,
      options: [
        'within',
        'outside',
      ],
      defaultJson: '"within"',
    ),
    SpecSetting(
      path: 'location_verification.reference.match',
      type: 'enum',
      optional: false,
      min: null,
      max: null,
      options: [
        'any',
        'all',
      ],
      defaultJson: '"any"',
    ),
    SpecSetting(
      path: 'location_verification.reference.confidence',
      type: 'enum',
      optional: false,
      min: null,
      max: null,
      options: [
        'strict',
        'lenient',
      ],
      defaultJson: '"strict"',
    ),
    SpecSetting(
      path: 'location_verification.reference.on_mismatch',
      type: 'enum',
      optional: false,
      min: null,
      max: null,
      options: [
        'reject',
        'flag',
      ],
      defaultJson: '"reject"',
    ),
  ];
}

abstract final class SpecCopy {
  static const List<String> locales = [
    'en',
  ];
  static const Map<String, String> en = {
    'common.back': 'Back',
    'common.cancel': 'Cancel',
    'common.change': 'Change',
    'common.close': 'Close',
    'common.continue': 'Continue',
    'common.done': 'Done',
    'common.loading': 'Getting ready…',
    'common.return_to_app': 'Return to app',
    'common.secured_by': 'Secured by Credflare',
    'common.start': 'Start',
    'common.step_progress': 'Step {current} of {total}',
    'common.test_mode': 'Test mode',
    'common.try_again': 'Try again',
    'common.verifier_fallback': 'your verifier',
    'intro.title': 'Verify your identity',
    'intro.body': 'Follow the steps requested by {verifier}. Review each item before you send it.',
    'intro.start': 'Start',
    'intro.checking': 'Checking what is still needed…',
    'exit.title': 'Leave for now?',
    'exit.body': 'Evidence you already sent is kept. Unsent photos and files will be discarded. You can come back through the app that sent you here.',
    'exit.stay': 'Keep going',
    'exit.leave': 'Leave for now',
    'exit.discard_title': 'Discard these photos and files?',
    'exit.discard_body': 'You have not sent this document yet.',
    'exit.discard_stay': 'Keep editing',
    'exit.discard_leave': 'Discard',
    'documents.title': 'Documents requested',
    'documents.requested_by': 'Requested by {verifier}.',
    'documents.back': 'Documents',
    'documents.section_required': 'Required',
    'documents.section_one_of': 'Provide one of these',
    'documents.section_count_of': 'Provide {count} of these',
    'documents.method_camera': 'Camera photos',
    'documents.method_upload': 'Saved files',
    'documents.method_either': 'Photo or file',
    'documents.method_both': 'Photo and saved file',
    'documents.unavailable': 'Not available in this app. Contact {verifier}.',
    'documents.selfie_next': 'After your documents, you will take a selfie.',
    'documents.location_next': 'After your documents, you will share your location.',
    'documents.selfie_location_next': 'After your documents, you will take a selfie and share your location.',
    'documents.location_selfie_next': 'After your documents, you will share your location and take a selfie.',
    'documents.host_steps_next': 'After your documents, the app will guide you through the remaining steps.',
    'capture.side_front': 'Front',
    'capture.side_back': 'Back',
    'capture.source_camera': 'Camera photo',
    'capture.source_upload': 'Saved file',
    'capture.instruction_camera': 'Place the {document} on a flat surface. Keep all four corners visible and avoid glare.',
    'capture.instruction_either': 'Take a photo or choose a saved file of the {side}.',
    'capture.instruction_upload': 'Choose a clear photo or scan of the {side}.',
    'capture.instruction_upload_pdf': 'Choose a clear photo, scan or PDF of the {side}.',
    'capture.also_saved_file': 'You also need to add a saved file of each side.',
    'capture.check_photo': 'Check that all four corners are visible, the text is sharp and there is no glare.',
    'capture.take_photo': 'Take photo',
    'capture.choose_file': 'Choose a file',
    'capture.retake_photo': 'Retake photo',
    'capture.change_file': 'Change file',
    'capture.use_file_instead': 'Use a file instead',
    'capture.use_photo_instead': 'Take a photo instead',
    'capture.file_limits': '{types}, up to {size}',
    'capture.preview_pdf': 'PDF',
    'capture.preview_document': 'Document',
    'capture.preview_label': 'Preview of the {side}',
    'review.title': 'Review before sending',
    'review.body': 'Check each photo and file before you send them.',
    'review.item': '{side} · {source}',
    'review.change': 'Change',
    'review.send': 'Send document',
    'sending.uploading': 'Uploading…',
    'sending.uploading_progress': 'Uploading {current} of {total}…',
    'sending.sending': 'Sending…',
    'sending.sent_title': 'Your evidence was sent',
    'sending.sent_body': 'We are checking that everything arrived.',
    'sending.check_again': 'Check again',
    'receipt.title': 'Evidence received',
    'receipt.body': 'Your evidence will be reviewed by {verifier}. You can close this screen.',
    'receipt.document': '{document} received',
    'receipt.selfie': 'Selfie received',
    'receipt.location': 'Location received',
    'receipt.email': 'Email address received',
    'receipt.phone': 'Phone number received',
    'receipt.answers': 'Answers received',
    'receipt.host_steps': 'The app will guide you through the remaining steps.',
    'receipt.done': 'Done',
    'selfie.title': 'Take a selfie',
    'selfie.guidance': 'Face the camera in even light. Keep your whole face visible and remove anything covering it.',
    'selfie.tip_face_camera': 'Face the camera directly.',
    'selfie.tip_light': 'Find even light on your face.',
    'selfie.tip_neutral': 'Keep a neutral expression.',
    'selfie.tip_glasses': 'Take off glasses if you can.',
    'selfie.open_camera': 'Open front camera',
    'selfie.starting_camera': 'Starting the camera…',
    'selfie.take': 'Take selfie',
    'selfie.review_title': 'Review your selfie',
    'selfie.review_body': 'Make sure your face is clear and fully visible before you send it.',
    'selfie.retake': 'Retake selfie',
    'selfie.send': 'Send selfie',
    'selfie.sending': 'Sending your selfie…',
    'selfie.preview_label': 'Your selfie preview',
    'selfie.privacy': 'Your selfie will be sent to {verifier} for review.',
    'liveness.title': 'Follow the prompts',
    'liveness.body': 'You will be asked to make {total} simple movements. Keep your face inside the frame.',
    'liveness.start': 'Start',
    'liveness.progress': 'Movement {current} of {total}',
    'liveness.position.no_face': 'Look at the camera',
    'liveness.position.move_closer': 'Move closer',
    'liveness.position.move_further': 'Move back a little',
    'liveness.position.center': 'Center your face in the frame',
    'liveness.position.one_face': 'Make sure only your face is in the frame',
    'liveness.position.hold_still': 'Hold still',
    'liveness.position.more_light': 'Move to a brighter place',
    'liveness.position.ready': 'Good. Hold still',
    'liveness.gesture.blink': 'Blink',
    'liveness.gesture.smile': 'Smile',
    'liveness.gesture.turn_left': 'Slowly turn your head to your left, then back',
    'liveness.gesture.turn_right': 'Slowly turn your head to your right, then back',
    'liveness.gesture.nod': 'Nod: look down, then back up',
    'liveness.gesture_done': 'Done',
    'liveness.face_lost': 'We lost sight of your face. Look at the camera.',
    'liveness.success': 'All movements recorded',
    'liveness.timeout': 'Time ran out for this movement.',
    'liveness.expired': 'This step timed out. Start it again.',
    'liveness.retry': 'Try again',
    'liveness.sending': 'Sending your recording…',
    'video.consent': 'This step records a short video of your face. It is sent to {verifier} for review.',
    'video.recording': 'Recording',
    'location.title': 'Share your location',
    'location.why': '{verifier} asks where you are right now. Your location is used only for this request.',
    'location.what_shared': 'We send your coordinates, how accurate they are and when they were taken.',
    'location.permission_prompt': 'Your device will ask for permission. Choose Allow.',
    'location.share': 'Share location',
    'location.waiting': 'Finding your location…',
    'location.waiting_accuracy': 'Getting a more accurate reading. Stay where you are, near a window or outside if you can.',
    'location.found_title': 'Location found',
    'location.found_body': 'Check it looks right, then send it.',
    'location.accuracy_label': 'Accuracy',
    'location.accuracy_value': 'Within {meters} m',
    'location.coordinates_label': 'Coordinates',
    'location.time_label': 'Taken at',
    'location.send': 'Send location',
    'location.permission_denied': 'Location access is off. Turn it on in Settings, then try again.',
    'location.permission_denied_browser': 'Location access is blocked. Allow it for this site in your browser settings, then reload the page.',
    'location.unavailable': 'Location is not available on this device.',
    'location.timeout': 'We could not find your location in time. Try again.',
    'location.low_accuracy': 'Your location is not accurate enough yet. Move near a window or outside, then try again.',
    'location.mock_detected': 'An app or setting is changing your device location. Turn it off, then try again.',
    'location.stale': 'Your location reading is out of date. Try again to take a new one.',
    'location.ip_country_mismatch': 'Your internet connection seems to be in a different country from your location. Turn off any VPN or proxy, then try again.',
    'location.retry': 'Try again',
    'location.retries_exhausted': 'We could not get your location. Contact {verifier}.',
    'location.place.title_within': 'Share your location at {place}',
    'location.place.title_outside': 'Share your location away from {place}',
    'location.place.need_within': 'You need to be at {place}.',
    'location.place.need_within_any': 'You need to be at one of these places: {places}.',
    'location.place.need_within_all': 'You need to be at each of these places: {places}.',
    'location.place.need_outside': 'You need to be away from {place}.',
    'location.place.need_outside_all': 'You need to be away from these places: {places}.',
    'location.place.need_outside_any': 'You need to be away from at least one of these places: {places}.',
    'location.place.not_matched_within': 'You do not seem to be at {place} yet. Move closer, then try again.',
    'location.place.not_matched_outside': 'You seem to be too close to {place}. Move away, then try again.',
    'location.place.not_precise': 'Your location is not precise enough to check this place. Move near a window or outside, then try again.',
    'location.place.rejected': 'Your location does not match the place requested by {verifier}. Try again from the right place.',
    'location.place.retry': 'Try again',
    'email.title': 'Confirm your email address',
    'email.body': '{verifier} asks you to confirm an email address. We will send a short code to it.',
    'email.label': 'Email address',
    'email.placeholder': 'name@example.com',
    'email.send': 'Send code',
    'email.invalid': 'Enter a valid email address.',
    'email.change': 'Use a different email address',
    'email.change_after': 'You can use a different email address when the countdown ends.',
    'phone.title': 'Confirm your phone number',
    'phone.body': '{verifier} asks you to confirm a phone number. We will send a short code to it by text message.',
    'phone.label': 'Phone number',
    'phone.hint': 'Start with + and your country code, for example +44 7700 900123.',
    'phone.send': 'Send code',
    'phone.invalid': 'Enter the number in international format, starting with + and the country code.',
    'phone.change': 'Use a different phone number',
    'phone.change_after': 'You can use a different phone number when the countdown ends.',
    'contact_code.sending': 'Sending a code…',
    'contact_code.title': 'Enter the code',
    'contact_code.body': 'We sent a code to {destination}. It expires in {minutes} minutes.',
    'contact_code.label': 'Code',
    'contact_code.confirm': 'Confirm',
    'contact_code.confirming': 'Checking the code…',
    'contact_code.resend': 'Send a new code',
    'contact_code.resend_in': 'You can ask for a new code in {seconds} seconds.',
    'contact_code.sends_remaining': 'You can ask for {count} more codes.',
    'questions.title': 'Answer a few questions',
    'questions.body': '{verifier} asks for these details.',
    'questions.optional': 'Optional',
    'questions.choose_one': 'Choose an option',
    'questions.choose_many': 'Choose all that apply.',
    'questions.choose_country': 'Choose a country',
    'questions.send': 'Send answers',
    'questions.sending': 'Sending your answers…',
    'questions.required': 'Answer this question to continue.',
    'questions.consent_required': 'Give your consent to continue.',
    'questions.invalid_number': 'Enter a number.',
    'questions.number_min': 'Enter at least {min}.',
    'questions.number_max': 'Enter at most {max}.',
    'questions.invalid_date': 'Enter a real date.',
    'questions.invalid_email': 'Enter a valid email address.',
    'questions.invalid_phone': 'Enter a valid phone number.',
    'questions.text_too_long': 'Use at most 5000 characters.',
    'questions.founders_name': 'Founder name',
    'questions.founders_add': 'Add a founder',
    'questions.founders_remove': 'Remove',
    'questions.founders_includes_me': 'I am one of the founders',
    'handoff.action': 'Continue on your phone',
    'handoff.title': 'Continue on your phone',
    'handoff.body': 'Scan this code with your phone camera to carry on there. The code works once and expires in {minutes} minutes.',
    'handoff.expired': 'This code has expired.',
    'handoff.new_code': 'Show a new code',
    'handoff.link_invalid': 'This link has expired or was already used. Open a new one on the device where you started.',
    'rejection.requested_by': 'Requested by {verifier}.',
    'rejection.help': 'If you need help, contact {verifier}.',
    'rejection.help_email': 'If you need help, contact {verifier} at {help_email}.',
    'rejection.help_url': 'If you need help, visit {help_url}.',
    'rejection.action.retry': 'Try again',
    'rejection.action.restart': 'Start again',
    'rejection.action.reenter_code': 'Enter the code again',
    'rejection.action.new_code': 'Send a new code',
    'rejection.action.wait': 'Send a new code',
    'rejection.action.leave': 'Close',
    'rejection.location_accuracy.title': 'Location not precise enough',
    'rejection.location_stale.title': 'Location out of date',
    'rejection.location_mock.title': 'Location is being changed',
    'rejection.location_ip_country.title': 'Connection in another country',
    'rejection.location_reference.title': 'Location does not match',
    'rejection.liveness_expired.title': 'Time ran out',
    'rejection.liveness_restart.title': 'Start this step again',
    'rejection.liveness_restart.message': 'This attempt can no longer be used. Start this step again.',
    'rejection.gesture_mismatch.title': 'Movements did not match',
    'rejection.gesture_mismatch.message': 'Some movements were missing or out of order. Start this step again and follow each prompt.',
    'rejection.not_camera.title': 'Camera needed',
    'rejection.not_camera.message': 'This step needs photos taken with the camera during the step. Start it again and use the camera.',
    'rejection.video_missing.title': 'Recording missing',
    'rejection.video_missing.message': 'The recording of this step did not arrive. Start the step again.',
    'rejection.video_too_long.title': 'Recording too long',
    'rejection.video_too_long.message': 'The recording was longer than allowed. Start the step again and follow the prompts without pausing.',
    'rejection.video_unreadable.title': 'Recording could not be read',
    'rejection.video_unreadable.message': 'We could not read the recording. Start the step again.',
    'rejection.email_not_configured.title': 'Email confirmation unavailable',
    'rejection.email_not_configured.message': 'Confirming an email address is not available for this request yet. Contact {verifier}.',
    'rejection.phone_not_configured.title': 'Phone confirmation unavailable',
    'rejection.phone_not_configured.message': 'Confirming a phone number is not available for this request yet. Contact {verifier}.',
    'rejection.code_resend_too_soon.title': 'Wait before asking again',
    'rejection.code_resend_too_soon.message': 'A code was sent less than a minute ago. Wait a moment, then ask for a new code.',
    'rejection.code_send_limit.title': 'Too many codes sent',
    'rejection.code_send_limit.message': 'Too many codes were sent for this request. Try again in 24 hours.',
    'rejection.code_missing.title': 'No code to check',
    'rejection.code_missing.message': 'Ask for a code first, then enter it here.',
    'rejection.code_expired.title': 'Code expired',
    'rejection.code_expired.message': 'This code has expired. Ask for a new one.',
    'rejection.code_invalid.title': 'Code not correct',
    'rejection.code_invalid.message': 'This code is not correct. Check it and enter it again.',
    'rejection.code_too_many_attempts.title': 'Too many wrong codes',
    'rejection.code_too_many_attempts.message': 'Too many wrong codes were entered. Ask for a new code.',
    'errors.generic': 'Something went wrong. Try again.',
    'errors.network': 'Could not connect. Check your connection and try again.',
    'errors.session_expired': 'Your session has expired. Close this screen and start again.',
    'errors.start_failed': 'We could not start. Check your connection and try again.',
    'errors.refresh_failed': 'We could not check what is still needed. Try again.',
    'errors.camera_denied': 'Camera access is off. Turn it on in Settings, then try again.',
    'errors.camera_denied_browser': 'Camera access is blocked. Allow it in your browser settings, then try again.',
    'errors.camera_unavailable': 'The camera is unavailable. Try again on a device with a camera.',
    'errors.front_camera_required': 'This step needs a front camera. Try another device.',
    'errors.camera_no_photo': 'The camera did not return a readable photo. Try again.',
    'errors.file_unreadable': 'This file could not be read. Choose another file.',
    'errors.file_type': 'Choose a {types} file.',
    'errors.file_too_large': 'This file is larger than {size}. Choose a smaller file.',
    'errors.file_empty': 'This file is empty. Choose another file.',
    'errors.photo_format': 'This photo format is not accepted by {verifier}.',
    'errors.photo_invalid': 'This photo is empty or too large. Retake it.',
    'errors.document_unsupported': 'This document cannot be collected in this app. Contact {verifier}.',
    'errors.add_file_failed': 'Could not add this file. Try again.',
    'errors.send_document_failed': 'Could not send this document. Check your connection and try again.',
    'errors.selfie_failed': 'Could not take your selfie. Try again.',
    'errors.send_selfie_failed': 'Could not send your selfie. Check your connection and try again.',
    'errors.challenge_failed': 'We could not start this step. Check your connection and try again.',
    'errors.send_location_failed': 'Could not send your location. Check your connection and try again.',
    'errors.send_code_failed': 'Could not send the code. Check your connection and try again.',
    'errors.confirm_code_failed': 'Could not check the code. Check your connection and try again.',
    'errors.send_answers_failed': 'Could not send your answers. Check your connection and try again.',
  };
}

abstract final class SpecCopyKey {
  static const String commonBack = 'common.back';
  static const String commonCancel = 'common.cancel';
  static const String commonChange = 'common.change';
  static const String commonClose = 'common.close';
  static const String commonContinue = 'common.continue';
  static const String commonDone = 'common.done';
  static const String commonLoading = 'common.loading';
  static const String commonReturnToApp = 'common.return_to_app';
  static const String commonSecuredBy = 'common.secured_by';
  static const String commonStart = 'common.start';
  static const String commonStepProgress = 'common.step_progress';
  static const String commonTestMode = 'common.test_mode';
  static const String commonTryAgain = 'common.try_again';
  static const String commonVerifierFallback = 'common.verifier_fallback';
  static const String introTitle = 'intro.title';
  static const String introBody = 'intro.body';
  static const String introStart = 'intro.start';
  static const String introChecking = 'intro.checking';
  static const String exitTitle = 'exit.title';
  static const String exitBody = 'exit.body';
  static const String exitStay = 'exit.stay';
  static const String exitLeave = 'exit.leave';
  static const String exitDiscardTitle = 'exit.discard_title';
  static const String exitDiscardBody = 'exit.discard_body';
  static const String exitDiscardStay = 'exit.discard_stay';
  static const String exitDiscardLeave = 'exit.discard_leave';
  static const String documentsTitle = 'documents.title';
  static const String documentsRequestedBy = 'documents.requested_by';
  static const String documentsBack = 'documents.back';
  static const String documentsSectionRequired = 'documents.section_required';
  static const String documentsSectionOneOf = 'documents.section_one_of';
  static const String documentsSectionCountOf = 'documents.section_count_of';
  static const String documentsMethodCamera = 'documents.method_camera';
  static const String documentsMethodUpload = 'documents.method_upload';
  static const String documentsMethodEither = 'documents.method_either';
  static const String documentsMethodBoth = 'documents.method_both';
  static const String documentsUnavailable = 'documents.unavailable';
  static const String documentsSelfieNext = 'documents.selfie_next';
  static const String documentsLocationNext = 'documents.location_next';
  static const String documentsSelfieLocationNext = 'documents.selfie_location_next';
  static const String documentsLocationSelfieNext = 'documents.location_selfie_next';
  static const String documentsHostStepsNext = 'documents.host_steps_next';
  static const String captureSideFront = 'capture.side_front';
  static const String captureSideBack = 'capture.side_back';
  static const String captureSourceCamera = 'capture.source_camera';
  static const String captureSourceUpload = 'capture.source_upload';
  static const String captureInstructionCamera = 'capture.instruction_camera';
  static const String captureInstructionEither = 'capture.instruction_either';
  static const String captureInstructionUpload = 'capture.instruction_upload';
  static const String captureInstructionUploadPdf = 'capture.instruction_upload_pdf';
  static const String captureAlsoSavedFile = 'capture.also_saved_file';
  static const String captureCheckPhoto = 'capture.check_photo';
  static const String captureTakePhoto = 'capture.take_photo';
  static const String captureChooseFile = 'capture.choose_file';
  static const String captureRetakePhoto = 'capture.retake_photo';
  static const String captureChangeFile = 'capture.change_file';
  static const String captureUseFileInstead = 'capture.use_file_instead';
  static const String captureUsePhotoInstead = 'capture.use_photo_instead';
  static const String captureFileLimits = 'capture.file_limits';
  static const String capturePreviewPdf = 'capture.preview_pdf';
  static const String capturePreviewDocument = 'capture.preview_document';
  static const String capturePreviewLabel = 'capture.preview_label';
  static const String reviewTitle = 'review.title';
  static const String reviewBody = 'review.body';
  static const String reviewItem = 'review.item';
  static const String reviewChange = 'review.change';
  static const String reviewSend = 'review.send';
  static const String sendingUploading = 'sending.uploading';
  static const String sendingUploadingProgress = 'sending.uploading_progress';
  static const String sendingSending = 'sending.sending';
  static const String sendingSentTitle = 'sending.sent_title';
  static const String sendingSentBody = 'sending.sent_body';
  static const String sendingCheckAgain = 'sending.check_again';
  static const String receiptTitle = 'receipt.title';
  static const String receiptBody = 'receipt.body';
  static const String receiptDocument = 'receipt.document';
  static const String receiptSelfie = 'receipt.selfie';
  static const String receiptLocation = 'receipt.location';
  static const String receiptEmail = 'receipt.email';
  static const String receiptPhone = 'receipt.phone';
  static const String receiptAnswers = 'receipt.answers';
  static const String receiptHostSteps = 'receipt.host_steps';
  static const String receiptDone = 'receipt.done';
  static const String selfieTitle = 'selfie.title';
  static const String selfieGuidance = 'selfie.guidance';
  static const String selfieTipFaceCamera = 'selfie.tip_face_camera';
  static const String selfieTipLight = 'selfie.tip_light';
  static const String selfieTipNeutral = 'selfie.tip_neutral';
  static const String selfieTipGlasses = 'selfie.tip_glasses';
  static const String selfieOpenCamera = 'selfie.open_camera';
  static const String selfieStartingCamera = 'selfie.starting_camera';
  static const String selfieTake = 'selfie.take';
  static const String selfieReviewTitle = 'selfie.review_title';
  static const String selfieReviewBody = 'selfie.review_body';
  static const String selfieRetake = 'selfie.retake';
  static const String selfieSend = 'selfie.send';
  static const String selfieSending = 'selfie.sending';
  static const String selfiePreviewLabel = 'selfie.preview_label';
  static const String selfiePrivacy = 'selfie.privacy';
  static const String livenessTitle = 'liveness.title';
  static const String livenessBody = 'liveness.body';
  static const String livenessStart = 'liveness.start';
  static const String livenessProgress = 'liveness.progress';
  static const String livenessPositionNoFace = 'liveness.position.no_face';
  static const String livenessPositionMoveCloser = 'liveness.position.move_closer';
  static const String livenessPositionMoveFurther = 'liveness.position.move_further';
  static const String livenessPositionCenter = 'liveness.position.center';
  static const String livenessPositionOneFace = 'liveness.position.one_face';
  static const String livenessPositionHoldStill = 'liveness.position.hold_still';
  static const String livenessPositionMoreLight = 'liveness.position.more_light';
  static const String livenessPositionReady = 'liveness.position.ready';
  static const String livenessGestureBlink = 'liveness.gesture.blink';
  static const String livenessGestureSmile = 'liveness.gesture.smile';
  static const String livenessGestureTurnLeft = 'liveness.gesture.turn_left';
  static const String livenessGestureTurnRight = 'liveness.gesture.turn_right';
  static const String livenessGestureNod = 'liveness.gesture.nod';
  static const String livenessGestureDone = 'liveness.gesture_done';
  static const String livenessFaceLost = 'liveness.face_lost';
  static const String livenessSuccess = 'liveness.success';
  static const String livenessTimeout = 'liveness.timeout';
  static const String livenessExpired = 'liveness.expired';
  static const String livenessRetry = 'liveness.retry';
  static const String livenessSending = 'liveness.sending';
  static const String videoConsent = 'video.consent';
  static const String videoRecording = 'video.recording';
  static const String locationTitle = 'location.title';
  static const String locationWhy = 'location.why';
  static const String locationWhatShared = 'location.what_shared';
  static const String locationPermissionPrompt = 'location.permission_prompt';
  static const String locationShare = 'location.share';
  static const String locationWaiting = 'location.waiting';
  static const String locationWaitingAccuracy = 'location.waiting_accuracy';
  static const String locationFoundTitle = 'location.found_title';
  static const String locationFoundBody = 'location.found_body';
  static const String locationAccuracyLabel = 'location.accuracy_label';
  static const String locationAccuracyValue = 'location.accuracy_value';
  static const String locationCoordinatesLabel = 'location.coordinates_label';
  static const String locationTimeLabel = 'location.time_label';
  static const String locationSend = 'location.send';
  static const String locationPermissionDenied = 'location.permission_denied';
  static const String locationPermissionDeniedBrowser = 'location.permission_denied_browser';
  static const String locationUnavailable = 'location.unavailable';
  static const String locationTimeout = 'location.timeout';
  static const String locationLowAccuracy = 'location.low_accuracy';
  static const String locationMockDetected = 'location.mock_detected';
  static const String locationStale = 'location.stale';
  static const String locationIpCountryMismatch = 'location.ip_country_mismatch';
  static const String locationRetry = 'location.retry';
  static const String locationRetriesExhausted = 'location.retries_exhausted';
  static const String locationPlaceTitleWithin = 'location.place.title_within';
  static const String locationPlaceTitleOutside = 'location.place.title_outside';
  static const String locationPlaceNeedWithin = 'location.place.need_within';
  static const String locationPlaceNeedWithinAny = 'location.place.need_within_any';
  static const String locationPlaceNeedWithinAll = 'location.place.need_within_all';
  static const String locationPlaceNeedOutside = 'location.place.need_outside';
  static const String locationPlaceNeedOutsideAll = 'location.place.need_outside_all';
  static const String locationPlaceNeedOutsideAny = 'location.place.need_outside_any';
  static const String locationPlaceNotMatchedWithin = 'location.place.not_matched_within';
  static const String locationPlaceNotMatchedOutside = 'location.place.not_matched_outside';
  static const String locationPlaceNotPrecise = 'location.place.not_precise';
  static const String locationPlaceRejected = 'location.place.rejected';
  static const String locationPlaceRetry = 'location.place.retry';
  static const String emailTitle = 'email.title';
  static const String emailBody = 'email.body';
  static const String emailLabel = 'email.label';
  static const String emailPlaceholder = 'email.placeholder';
  static const String emailSend = 'email.send';
  static const String emailInvalid = 'email.invalid';
  static const String emailChange = 'email.change';
  static const String emailChangeAfter = 'email.change_after';
  static const String phoneTitle = 'phone.title';
  static const String phoneBody = 'phone.body';
  static const String phoneLabel = 'phone.label';
  static const String phoneHint = 'phone.hint';
  static const String phoneSend = 'phone.send';
  static const String phoneInvalid = 'phone.invalid';
  static const String phoneChange = 'phone.change';
  static const String phoneChangeAfter = 'phone.change_after';
  static const String contactCodeSending = 'contact_code.sending';
  static const String contactCodeTitle = 'contact_code.title';
  static const String contactCodeBody = 'contact_code.body';
  static const String contactCodeLabel = 'contact_code.label';
  static const String contactCodeConfirm = 'contact_code.confirm';
  static const String contactCodeConfirming = 'contact_code.confirming';
  static const String contactCodeResend = 'contact_code.resend';
  static const String contactCodeResendIn = 'contact_code.resend_in';
  static const String contactCodeSendsRemaining = 'contact_code.sends_remaining';
  static const String questionsTitle = 'questions.title';
  static const String questionsBody = 'questions.body';
  static const String questionsOptional = 'questions.optional';
  static const String questionsChooseOne = 'questions.choose_one';
  static const String questionsChooseMany = 'questions.choose_many';
  static const String questionsChooseCountry = 'questions.choose_country';
  static const String questionsSend = 'questions.send';
  static const String questionsSending = 'questions.sending';
  static const String questionsRequired = 'questions.required';
  static const String questionsConsentRequired = 'questions.consent_required';
  static const String questionsInvalidNumber = 'questions.invalid_number';
  static const String questionsNumberMin = 'questions.number_min';
  static const String questionsNumberMax = 'questions.number_max';
  static const String questionsInvalidDate = 'questions.invalid_date';
  static const String questionsInvalidEmail = 'questions.invalid_email';
  static const String questionsInvalidPhone = 'questions.invalid_phone';
  static const String questionsTextTooLong = 'questions.text_too_long';
  static const String questionsFoundersName = 'questions.founders_name';
  static const String questionsFoundersAdd = 'questions.founders_add';
  static const String questionsFoundersRemove = 'questions.founders_remove';
  static const String questionsFoundersIncludesMe = 'questions.founders_includes_me';
  static const String handoffAction = 'handoff.action';
  static const String handoffTitle = 'handoff.title';
  static const String handoffBody = 'handoff.body';
  static const String handoffExpired = 'handoff.expired';
  static const String handoffNewCode = 'handoff.new_code';
  static const String handoffLinkInvalid = 'handoff.link_invalid';
  static const String rejectionRequestedBy = 'rejection.requested_by';
  static const String rejectionHelp = 'rejection.help';
  static const String rejectionHelpEmail = 'rejection.help_email';
  static const String rejectionHelpUrl = 'rejection.help_url';
  static const String rejectionActionRetry = 'rejection.action.retry';
  static const String rejectionActionRestart = 'rejection.action.restart';
  static const String rejectionActionReenterCode = 'rejection.action.reenter_code';
  static const String rejectionActionNewCode = 'rejection.action.new_code';
  static const String rejectionActionWait = 'rejection.action.wait';
  static const String rejectionActionLeave = 'rejection.action.leave';
  static const String rejectionLocationAccuracyTitle = 'rejection.location_accuracy.title';
  static const String rejectionLocationStaleTitle = 'rejection.location_stale.title';
  static const String rejectionLocationMockTitle = 'rejection.location_mock.title';
  static const String rejectionLocationIpCountryTitle = 'rejection.location_ip_country.title';
  static const String rejectionLocationReferenceTitle = 'rejection.location_reference.title';
  static const String rejectionLivenessExpiredTitle = 'rejection.liveness_expired.title';
  static const String rejectionLivenessRestartTitle = 'rejection.liveness_restart.title';
  static const String rejectionLivenessRestartMessage = 'rejection.liveness_restart.message';
  static const String rejectionGestureMismatchTitle = 'rejection.gesture_mismatch.title';
  static const String rejectionGestureMismatchMessage = 'rejection.gesture_mismatch.message';
  static const String rejectionNotCameraTitle = 'rejection.not_camera.title';
  static const String rejectionNotCameraMessage = 'rejection.not_camera.message';
  static const String rejectionVideoMissingTitle = 'rejection.video_missing.title';
  static const String rejectionVideoMissingMessage = 'rejection.video_missing.message';
  static const String rejectionVideoTooLongTitle = 'rejection.video_too_long.title';
  static const String rejectionVideoTooLongMessage = 'rejection.video_too_long.message';
  static const String rejectionVideoUnreadableTitle = 'rejection.video_unreadable.title';
  static const String rejectionVideoUnreadableMessage = 'rejection.video_unreadable.message';
  static const String rejectionEmailNotConfiguredTitle = 'rejection.email_not_configured.title';
  static const String rejectionEmailNotConfiguredMessage = 'rejection.email_not_configured.message';
  static const String rejectionPhoneNotConfiguredTitle = 'rejection.phone_not_configured.title';
  static const String rejectionPhoneNotConfiguredMessage = 'rejection.phone_not_configured.message';
  static const String rejectionCodeResendTooSoonTitle = 'rejection.code_resend_too_soon.title';
  static const String rejectionCodeResendTooSoonMessage = 'rejection.code_resend_too_soon.message';
  static const String rejectionCodeSendLimitTitle = 'rejection.code_send_limit.title';
  static const String rejectionCodeSendLimitMessage = 'rejection.code_send_limit.message';
  static const String rejectionCodeMissingTitle = 'rejection.code_missing.title';
  static const String rejectionCodeMissingMessage = 'rejection.code_missing.message';
  static const String rejectionCodeExpiredTitle = 'rejection.code_expired.title';
  static const String rejectionCodeExpiredMessage = 'rejection.code_expired.message';
  static const String rejectionCodeInvalidTitle = 'rejection.code_invalid.title';
  static const String rejectionCodeInvalidMessage = 'rejection.code_invalid.message';
  static const String rejectionCodeTooManyAttemptsTitle = 'rejection.code_too_many_attempts.title';
  static const String rejectionCodeTooManyAttemptsMessage = 'rejection.code_too_many_attempts.message';
  static const String errorsGeneric = 'errors.generic';
  static const String errorsNetwork = 'errors.network';
  static const String errorsSessionExpired = 'errors.session_expired';
  static const String errorsStartFailed = 'errors.start_failed';
  static const String errorsRefreshFailed = 'errors.refresh_failed';
  static const String errorsCameraDenied = 'errors.camera_denied';
  static const String errorsCameraDeniedBrowser = 'errors.camera_denied_browser';
  static const String errorsCameraUnavailable = 'errors.camera_unavailable';
  static const String errorsFrontCameraRequired = 'errors.front_camera_required';
  static const String errorsCameraNoPhoto = 'errors.camera_no_photo';
  static const String errorsFileUnreadable = 'errors.file_unreadable';
  static const String errorsFileType = 'errors.file_type';
  static const String errorsFileTooLarge = 'errors.file_too_large';
  static const String errorsFileEmpty = 'errors.file_empty';
  static const String errorsPhotoFormat = 'errors.photo_format';
  static const String errorsPhotoInvalid = 'errors.photo_invalid';
  static const String errorsDocumentUnsupported = 'errors.document_unsupported';
  static const String errorsAddFileFailed = 'errors.add_file_failed';
  static const String errorsSendDocumentFailed = 'errors.send_document_failed';
  static const String errorsSelfieFailed = 'errors.selfie_failed';
  static const String errorsSendSelfieFailed = 'errors.send_selfie_failed';
  static const String errorsChallengeFailed = 'errors.challenge_failed';
  static const String errorsSendLocationFailed = 'errors.send_location_failed';
  static const String errorsSendCodeFailed = 'errors.send_code_failed';
  static const String errorsConfirmCodeFailed = 'errors.confirm_code_failed';
  static const String errorsSendAnswersFailed = 'errors.send_answers_failed';
}

abstract final class SpecErrorCode {
  static const String locationAccuracy = 'location.accuracy';
  static const String locationStale = 'location.stale';
  static const String locationMock = 'location.mock';
  static const String locationIpCountry = 'location.ip_country';
  static const String locationReferenceNotMatched = 'location.reference_not_matched';
  static const String livenessChallengeInvalid = 'liveness.challenge_invalid';
  static const String livenessChallengeExpired = 'liveness.challenge_expired';
  static const String livenessChallengeUsed = 'liveness.challenge_used';
  static const String livenessGestureMismatch = 'liveness.gesture_mismatch';
  static const String livenessFrameOutOfWindow = 'liveness.frame_out_of_window';
  static const String livenessNotCamera = 'liveness.not_camera';
  static const String livenessVideoMissing = 'liveness.video_missing';
  static const String livenessVideoTooLong = 'liveness.video_too_long';
  static const String livenessVideoUnreadable = 'liveness.video_unreadable';
  static const String emailNotConfigured = 'email.not_configured';
  static const String emailResendTooSoon = 'email.resend_too_soon';
  static const String emailSendLimit = 'email.send_limit';
  static const String emailCodeMissing = 'email.code_missing';
  static const String emailCodeExpired = 'email.code_expired';
  static const String emailCodeInvalid = 'email.code_invalid';
  static const String emailTooManyAttempts = 'email.too_many_attempts';
  static const String phoneNotConfigured = 'phone.not_configured';
  static const String phoneResendTooSoon = 'phone.resend_too_soon';
  static const String phoneSendLimit = 'phone.send_limit';
  static const String phoneCodeMissing = 'phone.code_missing';
  static const String phoneCodeExpired = 'phone.code_expired';
  static const String phoneCodeInvalid = 'phone.code_invalid';
  static const String phoneTooManyAttempts = 'phone.too_many_attempts';
  static const Map<String, String> meanings = {
    'location.accuracy': 'Accuracy is missing or larger than max_accuracy_m',
    'location.stale': 'fix_time is missing, older than max_age_s plus clock_skew_s, or in the future',
    'location.mock': 'is_mock is true and mock_location is reject',
    'location.ip_country': 'The IP country does not match and ip_country is reject',
    'location.reference_not_matched': 'The place rule failed and on_mismatch is reject',
    'liveness.challenge_invalid': 'The challenge is unknown, belongs to another case or was replaced',
    'liveness.challenge_expired': 'The challenge expired',
    'liveness.challenge_used': 'The challenge was already used',
    'liveness.gesture_mismatch': 'A gesture frame is missing, extra, out of order or for a gesture the challenge does not include',
    'liveness.frame_out_of_window': 'A file was uploaded before the challenge was issued or after it expired',
    'liveness.not_camera': 'Evidence was not uploaded with capture_source=camera for this challenge',
    'liveness.video_missing': 'record_video is on and no video for this challenge was sent',
    'liveness.video_too_long': 'The video is longer than max_video_seconds plus one second',
    'liveness.video_unreadable': 'The server cannot read the video duration',
    'email.not_configured': 'No email sender serves this environment, for example the log driver on a live case',
    'email.resend_too_soon': 'A code was sent to this email address less than 60 seconds ago',
    'email.send_limit': 'Five codes were sent for this case within 24 hours',
    'email.code_missing': 'No unused code was requested for this case',
    'email.code_expired': 'The code is older than 10 minutes',
    'email.code_invalid': 'The code does not match',
    'email.too_many_attempts': 'Five wrong codes were entered; a new code is needed',
    'phone.not_configured': 'No SMS sender serves this environment, for example the log driver on a live case',
    'phone.resend_too_soon': 'A code was sent to this phone number less than 60 seconds ago',
    'phone.send_limit': 'Five codes were sent for this case within 24 hours',
    'phone.code_missing': 'No unused code was requested for this case',
    'phone.code_expired': 'The code is older than 10 minutes',
    'phone.code_invalid': 'The code does not match',
    'phone.too_many_attempts': 'Five wrong codes were entered; a new code is needed',
  };
}

abstract final class SpecRejection {
  static const String requestedBy = 'rejection.requested_by';
  static const String help = 'rejection.help';
  static const String helpEmail = 'rejection.help_email';
  static const String helpUrl = 'rejection.help_url';
  static const List<String> actions = [
    'retry',
    'restart',
    'reenter_code',
    'new_code',
    'wait',
    'leave',
  ];
  static const Map<String, String> actionLabels = {
    'retry': 'rejection.action.retry',
    'restart': 'rejection.action.restart',
    'reenter_code': 'rejection.action.reenter_code',
    'new_code': 'rejection.action.new_code',
    'wait': 'rejection.action.wait',
    'leave': 'rejection.action.leave',
  };
  static const Map<String, SpecRejectionCopy> codes = {
    'location.accuracy': SpecRejectionCopy(
      title: 'rejection.location_accuracy.title',
      message: 'location.low_accuracy',
      action: 'retry',
      placeMessageWithin: 'location.place.not_precise',
      placeMessageOutside: 'location.place.not_precise',
    ),
    'location.stale': SpecRejectionCopy(
      title: 'rejection.location_stale.title',
      message: 'location.stale',
      action: 'retry',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'location.mock': SpecRejectionCopy(
      title: 'rejection.location_mock.title',
      message: 'location.mock_detected',
      action: 'retry',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'location.ip_country': SpecRejectionCopy(
      title: 'rejection.location_ip_country.title',
      message: 'location.ip_country_mismatch',
      action: 'retry',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'location.reference_not_matched': SpecRejectionCopy(
      title: 'rejection.location_reference.title',
      message: 'location.place.rejected',
      action: 'retry',
      placeMessageWithin: 'location.place.not_matched_within',
      placeMessageOutside: 'location.place.not_matched_outside',
    ),
    'liveness.challenge_invalid': SpecRejectionCopy(
      title: 'rejection.liveness_restart.title',
      message: 'rejection.liveness_restart.message',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.challenge_expired': SpecRejectionCopy(
      title: 'rejection.liveness_expired.title',
      message: 'liveness.expired',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.challenge_used': SpecRejectionCopy(
      title: 'rejection.liveness_restart.title',
      message: 'rejection.liveness_restart.message',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.gesture_mismatch': SpecRejectionCopy(
      title: 'rejection.gesture_mismatch.title',
      message: 'rejection.gesture_mismatch.message',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.frame_out_of_window': SpecRejectionCopy(
      title: 'rejection.liveness_expired.title',
      message: 'liveness.expired',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.not_camera': SpecRejectionCopy(
      title: 'rejection.not_camera.title',
      message: 'rejection.not_camera.message',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.video_missing': SpecRejectionCopy(
      title: 'rejection.video_missing.title',
      message: 'rejection.video_missing.message',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.video_too_long': SpecRejectionCopy(
      title: 'rejection.video_too_long.title',
      message: 'rejection.video_too_long.message',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'liveness.video_unreadable': SpecRejectionCopy(
      title: 'rejection.video_unreadable.title',
      message: 'rejection.video_unreadable.message',
      action: 'restart',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'email.not_configured': SpecRejectionCopy(
      title: 'rejection.email_not_configured.title',
      message: 'rejection.email_not_configured.message',
      action: 'leave',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'email.resend_too_soon': SpecRejectionCopy(
      title: 'rejection.code_resend_too_soon.title',
      message: 'rejection.code_resend_too_soon.message',
      action: 'wait',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'email.send_limit': SpecRejectionCopy(
      title: 'rejection.code_send_limit.title',
      message: 'rejection.code_send_limit.message',
      action: 'leave',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'email.code_missing': SpecRejectionCopy(
      title: 'rejection.code_missing.title',
      message: 'rejection.code_missing.message',
      action: 'new_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'email.code_expired': SpecRejectionCopy(
      title: 'rejection.code_expired.title',
      message: 'rejection.code_expired.message',
      action: 'new_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'email.code_invalid': SpecRejectionCopy(
      title: 'rejection.code_invalid.title',
      message: 'rejection.code_invalid.message',
      action: 'reenter_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'email.too_many_attempts': SpecRejectionCopy(
      title: 'rejection.code_too_many_attempts.title',
      message: 'rejection.code_too_many_attempts.message',
      action: 'new_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'phone.not_configured': SpecRejectionCopy(
      title: 'rejection.phone_not_configured.title',
      message: 'rejection.phone_not_configured.message',
      action: 'leave',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'phone.resend_too_soon': SpecRejectionCopy(
      title: 'rejection.code_resend_too_soon.title',
      message: 'rejection.code_resend_too_soon.message',
      action: 'wait',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'phone.send_limit': SpecRejectionCopy(
      title: 'rejection.code_send_limit.title',
      message: 'rejection.code_send_limit.message',
      action: 'leave',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'phone.code_missing': SpecRejectionCopy(
      title: 'rejection.code_missing.title',
      message: 'rejection.code_missing.message',
      action: 'new_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'phone.code_expired': SpecRejectionCopy(
      title: 'rejection.code_expired.title',
      message: 'rejection.code_expired.message',
      action: 'new_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'phone.code_invalid': SpecRejectionCopy(
      title: 'rejection.code_invalid.title',
      message: 'rejection.code_invalid.message',
      action: 'reenter_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
    'phone.too_many_attempts': SpecRejectionCopy(
      title: 'rejection.code_too_many_attempts.title',
      message: 'rejection.code_too_many_attempts.message',
      action: 'new_code',
      placeMessageWithin: null,
      placeMessageOutside: null,
    ),
  };
}

abstract final class SpecRequirements {
  static const int version = 1;
  static const List<String> verificationTypes = [
    'facial_verification',
    'location_verification',
    'email_verification',
    'phone_verification',
  ];
  static const String contactCodesChannelsEmail = 'email_verification';
  static const String contactCodesChannelsPhone = 'phone_verification';
  static const int contactCodesCodeLength = 6;
  static const int contactCodesTtlMinutes = 10;
  static const int contactCodesMaxAttempts = 5;
  static const int contactCodesResendSeconds = 60;
  static const int contactCodesMaxSends = 5;
  static const int contactCodesSendWindowHours = 24;
  static const int contactCodesEmailMaxLength = 254;
  static const int contactCodesPhoneMaxLength = 32;
  static const String contactCodesPhoneStrip = '[\\s().-]';
  static const String contactCodesPhonePattern = '^\\+[1-9][0-9]{6,14}\$';
  static const List<String> questionsTypes = [
    'text',
    'textarea',
    'email',
    'number',
    'date',
    'select',
    'tel',
    'founders',
    'phone',
    'single_select',
    'multi_select',
    'country',
    'consent',
  ];
  static const List<String> questionsChoiceTypes = [
    'select',
    'single_select',
    'multi_select',
  ];
  static const String questionsKeyPattern = '^[A-Za-z][A-Za-z0-9_-]{0,99}\$';
  static const int questionsMaxOptions = 100;
  static const int questionsMaxOptionLength = 200;
  static const int questionsTextMaxLength = 5000;
  static const String questionsNumberPattern = '^-?[0-9]+(\\.[0-9]+)?\$';
  static const String questionsDatePattern = '^\\d{4}-\\d{2}-\\d{2}\$';
  static const String questionsPhonePattern = '^\\+?[0-9][0-9 ().-]{4,30}\$';
  static const String questionsCountryPattern = '^[A-Z]{2}\$';
  static const int questionsEmailMaxLength = 254;
  static const List<String> showIfMatch = [
    'all',
    'any',
  ];
  static const String showIfDefaultMatch = 'all';
  static const int showIfMaxConditions = 10;
  static const String showIfPathPrefix = 'form.';
  static const String showIfEarlierAnswers = 'profile.form_answers';
  static const List<String> showIfOperators = [
    'equals',
    'not_equals',
    'gt',
    'gte',
    'lt',
    'lte',
    'contains',
    'not_contains',
    'in',
    'not_in',
    'is_empty',
    'is_not_empty',
    'regex',
    'fuzzy_match',
  ];
  static const int showIfMaxListValues = 100;
  static const int showIfMaxPatternLength = 200;
  static const int showIfFuzzyDefaultMinScore = 80;
  static const List<String> refreshAfter = [
    'submit',
    'email_code_confirm',
    'phone_code_confirm',
  ];
  static const List<String> refreshOpenStatuses = [
    'pending',
    'in_progress',
  ];
  static const List<String> refreshOutstanding = [
    'profile.document_requirements',
    'profile.verification_requirements',
    'profile.form_schema',
  ];
}

abstract final class SpecTokens {
  static const SpecPalette light = SpecPalette(
    primary: 0xFF20315F,
    onPrimary: 0xFFFFFFFF,
    surface: 0xFFFFFFFF,
    ink: 0xFF18233C,
    muted: 0xFF52617A,
    soft: 0xFFF0F3FA,
    border: 0xFFCAD4E5,
    accent: 0xFFDC6E11,
    success: 0xFF126749,
    error: 0xFFAA2525,
    warningSoft: 0xFFFDF1E6,
    warningInk: 0xFF7A3B06,
  );
  static const SpecPalette dark = SpecPalette(
    primary: 0xFFB9CDFF,
    onPrimary: 0xFF16294E,
    surface: 0xFF111C31,
    ink: 0xFFF4F7FE,
    muted: 0xFFB7C4DA,
    soft: 0xFF1A2942,
    border: 0xFF566983,
    accent: 0xFFFFB579,
    success: 0xFF8FE0B8,
    error: 0xFFFFB4AB,
    warningSoft: 0xFF3A2A1A,
    warningInk: 0xFFFFD3AE,
  );
  static const String fontFamily = 'Ubuntu';
  static const int fontWeightsRegular = 400;
  static const int fontWeightsMedium = 500;
  static const int fontWeightsBold = 700;
  static const String textAlign = 'center';
  static const SpecTextStyle typeTitle = SpecTextStyle(
    size: 24.0,
    lineHeight: 30.0,
    weight: 700,
  );
  static const SpecTextStyle typeSubtitle = SpecTextStyle(
    size: 17.0,
    lineHeight: 24.0,
    weight: 500,
  );
  static const SpecTextStyle typeBody = SpecTextStyle(
    size: 16.0,
    lineHeight: 24.0,
    weight: 400,
  );
  static const SpecTextStyle typeButton = SpecTextStyle(
    size: 16.0,
    lineHeight: 22.0,
    weight: 500,
  );
  static const SpecTextStyle typeLabel = SpecTextStyle(
    size: 14.0,
    lineHeight: 20.0,
    weight: 500,
  );
  static const SpecTextStyle typeSmall = SpecTextStyle(
    size: 13.0,
    lineHeight: 19.0,
    weight: 400,
  );
  static const SpecTextStyle typeEyebrow = SpecTextStyle(
    size: 13.0,
    lineHeight: 18.0,
    weight: 500,
  );
  static const SpecTextStyle typeChip = SpecTextStyle(
    size: 12.0,
    lineHeight: 16.0,
    weight: 500,
  );
  static const int spacingXxs = 2;
  static const int spacingXs = 4;
  static const int spacingSm = 8;
  static const int spacingMd = 12;
  static const int spacingLg = 16;
  static const int spacingXl = 24;
  static const int spacingXxl = 32;
  static const int spacingGutter = 24;
  static const int spacingGap = 16;
  static const int spacingSection = 10;
  static const int radiusXs = 3;
  static const int radiusSm = 6;
  static const int radiusMd = 10;
  static const int radiusLg = 14;
  static const int radiusXl = 16;
  static const int radiusSheet = 24;
  static const int radiusPill = 999;
  static const int sizeButtonHeight = 56;
  static const int sizeLinkHeight = 48;
  static const int sizeOptionHeight = 72;
  static const int sizeHeaderHeight = 56;
  static const int sizeMaxContentWidth = 600;
  static const int sizeMark = 30;
  static const int sizeIcon = 24;
  static const int sizeIllustration = 64;
  static const double sizeIconStroke = 1.75;
}

abstract final class SpecIcons {
  static const SpecIcon camera = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 4 8.5 C 4 7.395 4.895 6.5 6 6.5 L 7.6 6.5 C 7.915 6.5 8.211 6.352 8.4 6.1 L 9.6 4.4 C 9.789 4.148 10.085 4 10.4 4 L 13.6 4 C 13.915 4 14.211 4.148 14.4 4.4 L 15.6 6.1 C 15.789 6.352 16.085 6.5 16.4 6.5 L 18 6.5 C 19.105 6.5 20 7.395 20 8.5 L 20 17.5 C 20 18.605 19.105 19.5 18 19.5 L 6 19.5 C 4.895 19.5 4 18.605 4 17.5 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 15.25 12.75 C 15.25 14.545 13.795 16 12 16 C 10.205 16 8.75 14.545 8.75 12.75 C 8.75 10.955 10.205 9.5 12 9.5 C 13.795 9.5 15.25 10.955 15.25 12.75 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon chevronLeft = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 14.5 6 L 8.5 12 L 14.5 18',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon chevronRight = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 9.5 6 L 15.5 12 L 9.5 18',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon document = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 14 3 L 7 3 C 5.895 3 5 3.895 5 5 L 5 19 C 5 20.105 5.895 21 7 21 L 17 21 C 18.105 21 19 20.105 19 19 L 19 8 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 14 3 L 14 7 C 14 7.552 14.448 8 15 8 L 19 8',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 9 13 L 15 13',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 9 17 L 13 17',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon error = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 21 12 C 21 16.971 16.971 21 12 21 C 7.029 21 3 16.971 3 12 C 3 7.029 7.029 3 12 3 C 16.971 3 21 7.029 21 12 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 12 7.75 L 12 12.75',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 12 16.25 L 12 16.26',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon idCard = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 5 5 L 19 5 C 20.105 5 21 5.895 21 7 L 21 17 C 21 18.105 20.105 19 19 19 L 5 19 C 3.895 19 3 18.105 3 17 L 3 7 C 3 5.895 3.895 5 5 5 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 10.25 10 C 10.25 10.966 9.466 11.75 8.5 11.75 C 7.534 11.75 6.75 10.966 6.75 10 C 6.75 9.034 7.534 8.25 8.5 8.25 C 9.466 8.25 10.25 9.034 10.25 10 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 5.75 15.5 C 6.25 14.1 7.25 13.25 8.5 13.25 C 9.75 13.25 10.75 14.1 11.25 15.5',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 14 10 L 18 10',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 14 14 L 16.5 14',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon location = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 12 21.25 C 12 21.25 5.5 15.6 5.5 10 C 5.5 6.41 8.41 3.5 12 3.5 C 15.59 3.5 18.5 6.41 18.5 10 C 18.5 15.6 12 21.25 12 21.25 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 14.25 10 C 14.25 11.243 13.243 12.25 12 12.25 C 10.757 12.25 9.75 11.243 9.75 10 C 9.75 8.757 10.757 7.75 12 7.75 C 13.243 7.75 14.25 8.757 14.25 10 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon received = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 14 3 L 7 3 C 5.895 3 5 3.895 5 5 L 5 19 C 5 20.105 5.895 21 7 21 L 17 21 C 18.105 21 19 20.105 19 19 L 19 8 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 14 3 L 14 7 C 14 7.552 14.448 8 15 8 L 19 8',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 9 14.75 L 11.25 17 L 15.25 12.5',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon receivedIllustration = SpecIcon(
    viewBox: 64.0,
    strokeWidth: 2.5,
    paths: [
      SpecIconPath(
        d: 'M 62 32 C 62 48.569 48.569 62 32 62 C 15.431 62 2 48.569 2 32 C 2 15.431 15.431 2 32 2 C 48.569 2 62 15.431 62 32 Z',
        stroke: false,
        fill: true,
        strokeWidth: 2.5,
        strokeOpacity: 1.0,
        fillOpacity: 0.08,
      ),
      SpecIconPath(
        d: 'M 36 12 L 23 12 C 20.791 12 19 13.791 19 16 L 19 48 C 19 50.209 20.791 52 23 52 L 41 52 C 43.209 52 45 50.209 45 48 L 45 21 Z',
        stroke: true,
        fill: true,
        strokeWidth: 2.5,
        strokeOpacity: 1.0,
        fillOpacity: 0.16,
      ),
      SpecIconPath(
        d: 'M 36 12 L 36 18 C 36 19.657 37.343 21 39 21 L 45 21',
        stroke: true,
        fill: false,
        strokeWidth: 2.5,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 25 24 L 31 24',
        stroke: true,
        fill: false,
        strokeWidth: 2.5,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 25 30 L 39 30',
        stroke: true,
        fill: false,
        strokeWidth: 2.5,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 25.5 39.5 L 30 44 L 38.5 34.5',
        stroke: true,
        fill: false,
        strokeWidth: 3.0,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon selfie = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 4 8 L 4 6 C 4 4.895 4.895 4 6 4 L 8 4',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 16 4 L 18 4 C 19.105 4 20 4.895 20 6 L 20 8',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 20 16 L 20 18 C 20 19.105 19.105 20 18 20 L 16 20',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 8 20 L 6 20 C 4.895 20 4 19.105 4 18 L 4 16',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 15 10 C 15 11.657 13.657 13 12 13 C 10.343 13 9 11.657 9 10 C 9 8.343 10.343 7 12 7 C 13.657 7 15 8.343 15 10 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 7.5 17.5 C 8.4 15.6 10.1 14.5 12 14.5 C 13.9 14.5 15.6 15.6 16.5 17.5',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon upload = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 12 15 L 12 4',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 7.5 8.5 L 12 4 L 16.5 8.5',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 4 15 L 4 18 C 4 19.105 4.895 20 6 20 L 18 20 C 19.105 20 20 19.105 20 18 L 20 15',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const SpecIcon video = SpecIcon(
    viewBox: 24.0,
    strokeWidth: 1.75,
    paths: [
      SpecIconPath(
        d: 'M 3 7.5 C 3 6.395 3.895 5.5 5 5.5 L 13 5.5 C 14.105 5.5 15 6.395 15 7.5 L 15 16.5 C 15 17.605 14.105 18.5 13 18.5 L 5 18.5 C 3.895 18.5 3 17.605 3 16.5 Z',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
      SpecIconPath(
        d: 'M 15 10.5 L 20.2 7.6 C 20.352 7.486 20.554 7.468 20.724 7.553 C 20.893 7.637 21 7.811 21 8 L 21 16 C 21 16.189 20.893 16.363 20.724 16.447 C 20.554 16.532 20.352 16.514 20.2 16.4 L 15 13.5',
        stroke: true,
        fill: false,
        strokeWidth: 1.75,
        strokeOpacity: 1.0,
        fillOpacity: 1.0,
      ),
    ],
  );
  static const Map<String, SpecIcon> all = {
    'camera': camera,
    'chevron_left': chevronLeft,
    'chevron_right': chevronRight,
    'document': document,
    'error': error,
    'id_card': idCard,
    'location': location,
    'received': received,
    'received_illustration': receivedIllustration,
    'selfie': selfie,
    'upload': upload,
    'video': video,
  };
}
