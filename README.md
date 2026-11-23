# CredFlare Flutter SDK

Development package for scoped applicant sessions and native collection of documents, questionnaires, email and phone confirmation, a liveness challenge with selfie, and location on Android and iOS. Requires the scoped-session backend changes. This package is not published.

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter test
flutter run
```

Constants, copy, tokens and icons come from the shared spec in `lib/src/spec.generated.dart`. Never edit it by hand. With the spec repository checked out next to this one:

```sh
node ../sdk-spec/scripts/generate.mjs --target dart --out lib/src/spec.generated.dart
sh scripts/check-spec.sh
```

The check fails when the generated file or the API fixtures in `test/fixtures` differ from the spec. CI runs it on every push.

## Session client

Your authenticated backend creates the verification and returns a temporary session descriptor. It retains all client credentials.

```dart
final session = CredflareSession(SessionDescriptor.fromJson(descriptor));
final info = await session.get();
final uploaded = await session.upload(
  bytes: documentBytes,
  filename: 'front.jpg',
  key: requestKey(),
  source: 'upload',
  side: 'front',
);
final submissionId = await session.submit({
  'type': 'document_verification',
  'document_type_id': documentTypeId,
  'evidence': [{'file_id': uploaded['id'], 'source': 'upload', 'side': 'front'}],
}, key: requestKey());
```

Every upload and submission requires an `X-Idempotency-Key`, so each call takes a `key`. Keep each request key with its unchanged payload until the operation succeeds. Use the same key after a network interruption. Use a new key when the applicant replaces evidence. Use `captureSteps(requirement)` to collect every requested side and source.

The client also submits requested form fields, liveness evidence and coordinates. `createLivenessChallenge()` asks the server for the gestures to run, `uploadBiometric` sends gesture frames, the liveness video and the selfie bound to that challenge, and `submitFacial` and `submitLocation` submit them. A completed challenge shows that the camera recorded a server chosen sequence in time. It is not a verification decision and does not detect deepfakes. Submission receipts are not verification decisions. Use the server API or webhook for the final decision.

`CredflareSessionController(provider: ...)` loads a descriptor from your authenticated backend and exposes `session`, `info`, `loading` and `error`. Concurrent `load()` calls share one operation. The provider must keep the same verification case when renewing access. Dispose the controller when leaving the flow.

`requestContactCode(channel, destination)` sends a code to an email address or phone number and returns the masked destination, expiry, resend time and sends remaining. `confirmContactCode(channel, code)` confirms it. `submitAnswers(fields, key: ...)` sends questionnaire answers as a `form_submission`. Use `questionVisible(question, answers)` to decide whether a question with `show_if` is shown; send no answer for a hidden question.

A rejected request throws `CredflareException` with status 422 and a stable `code` from `SpecErrorCode` (for example `location.stale`, `liveness.challenge_expired` or `phone.code_invalid`). Match on `code`; `message` is for people and may change. A code the SDK does not know yet is kept as the raw string and `hasKnownCode` is false. `Rejection.from(error, info: info)` reads the title, message and action for a code from the spec rejection map, fills the verifier name from the session, and falls back to the server message with a retry for a missing or unknown code. `CredflareRejection` shows it with who asked for the evidence and where to get help: the requester's help address as a mail link, otherwise its help page as a link, otherwise the requester's name. A `resend_too_soon` rejection carries `resend_available_at`, which `CredflareException.resendAvailableAt` exposes, and the masked `destination`, `expires_at` and `sends_remaining` of the code still waiting, exposed as `destination`, `expiresAt` and `sendsRemaining`.

A 401 means the session is unavailable. Ask the host backend whether it can issue a replacement. `replaceSession` updates the temporary credential while retaining the client object. `cancel()` revokes that session while preserving the verification case. Dispose clients with `close()` when no longer needed.

## Native capture

Use `CredflareDocumentCapture` with a selected session requirement, the session client, `maxFileSizeBytes`, `allowedFileTypes` and `onSubmitted`. It collects the requested sides with preview, replacement and explicit submission. It preserves upload IDs and retry keys after a failed send.

Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to the iOS app's Info.plist and Internet permission to Android. The component uses native image selection and camera capture rather than a WebView. It refuses unsupported trusted-camera policies. The file picker accepts configured images, PDFs and DOCX files. File size and type checks also run on the server.

Use `CredflareVerification(sessionProvider: provider, onClose: close)` for the guided document flow. The provider obtains a fresh session from your authenticated backend. The example calls the JavaScript demo backend on localhost port 3107 when Start is pressed; no session entry or pasting is needed. Never paste or embed client credentials in a mobile app. For a local Android emulator API, use `adb reverse` to forward the API port and a loopback API URL.

See [flow requirements](docs/SDK-FLOW.md). Guided forms, process recovery and physical-device capture tests remain required before release. Trusted-camera checks and deepfake detection are unavailable.

## Capture choices

Each document has its own capture rule. An ID can require `snapshot` while a bank statement requires `upload` in the same profile. `snapshot_or_upload` lets the applicant choose a photo or file for each side. `snapshot_and_upload` separately requires both sources for the same document. These rules are separate from document groups that ask for all documents or a subset of alternatives.

The guided screens show each required side, preview and replacement, a final review, and a collection receipt. Camera source is client-reported. It does not establish liveness or a trusted feed.

Run `sh validate.sh` for the spec drift check, static analysis, unit and widget tests and the example flow test. Native builds require Android SDK and Xcode separately.

## Upload test files

Synthetic front and back PNGs are in the sibling JavaScript SDK at `test/fixtures/documents`. Android demo files are available under Downloads > Credflare-Samples. The iOS example enables local document sharing so files placed in its Documents directory appear in Files under On My iPhone. Use the Upload-Samples folder in either demo app. These are test documents, not real identity records.

## Liveness and location steps

Choose the compliance profile on your server when creating the case. The recipient does not choose a profile or verification mode. After the outstanding documents, the SDK asks the outstanding questions, then runs the remaining facial, location, email and phone requirements itself, in profile order. After every submission or code confirmation it loads the session again: it continues while the session is open and anything is outstanding, including a requirement a workflow added during the case, and shows the receipt otherwise. If that check answers 409, the case is closed (for example a workflow approved it after the last step) and the receipt is shown. Any other failure offers a retry and never shows the receipt in its place. If the answers show a question of a type this SDK version cannot ask, the questionnaire returns control to the host app instead of sending, even when other answers are still blank; on its own, without `onUnsupported`, it says the app will guide the applicant and sends nothing. A submission or code confirmation refused with 409 because the case closed goes straight to the receipt without loading the session again, and the receipt does not list the refused evidence. Whenever the case turns out to be closed, the flow calls `onClosed` and does not call `onSubmitted`, since no current session exists for a closed case.

## Questionnaire

Text, long text, number, date, email, phone, single and multiple choice, country, consent and founders questions are supported. Questions with `show_if` appear and disappear as answers change, judged on the answers exactly as they will be sent and on the earlier answers of the case from `profile.form_answers`; hidden questions are not checked and not sent, and earlier answers are not sent again unless their question is asked again. Clearing an earlier answer that is asked again sends it as `null`; an answered optional date, single choice or country has a Remove button for this. An optional consent the applicant never touched is not sent. The form is locked while answers are being sent, and changed answers get a new request key. A number that a JSON number would change is sent as the text typed. The date picker accepts any date from year 0000 to 9999. Answers are checked against the spec limits before they are sent, and server messages for a question are shown under it. Countries are listed by English name with their flags and can be searched by name or code; the ISO 3166 code is the value sent.

## Email and phone confirmation

The applicant enters an address or an international number, receives a code, and types it in. Sending a new code is enabled at the resend time from the server, and the screen shows how many codes remain. Every `email.*` and `phone.*` rejection shows its spec screen: a wrong code clears the field, an expired or burnt code sends a new one, a resend that is too soon waits for the resend time, and a send limit or missing sender lets the applicant leave. Leaving that screen by its button, the Close button or system Back calls `onHostActionRequired` with the rejection code before `onClose`, never `onCancelled`, so the host app can follow up. A resend that is too soon before any code was requested in this flow, for example after a reload, opens the code entry for the address or number the server names in the rejection, since that code is already on its way; the address typed is never shown as where the code went. A new code for the code on screen goes to the same address or number; when the flow only knows its masked form, the applicant enters it again. If a new address or number is refused because the countdown for the last code is still running, the code entry for that last code stays on screen with a note that a different one can be used when the countdown ends.

The facial step asks the server for a challenge, shows a mirrored front camera preview with positioning hints, runs the server's gestures in order with a timeout for each, keeps a JPEG frame when each gesture completes, records a video without audio over the challenge window when the profile asks for one, then takes the selfie. The applicant reviews the selfie before the frames, video and selfie are uploaded and submitted. A timeout or failure offers a retry that requests a new challenge. Face signals come from Apple's Vision framework on iOS and from ML Kit face detection on Android, each through a `FaceSignalProvider` in the plugin's own platform code, so another provider can be swapped in. The provider name sent with the evidence (`vision` or `mlkit`) picks the spec thresholds. Pass `livenessSource` to `CredflareVerification` to replace the camera source.

The location step explains what is shared and, when the profile names reference places, which place by label. It asks for permission, takes a high accuracy fix and retries until the fix meets the profile's accuracy and age limits. It reports whether the platform flagged the fix as mocked and shows the spec rejection screen when a location is rejected. The SDK never calls geocoding or IP lookup services. Pass `locationSource` to replace the location source.

### Permissions

- Android: `CAMERA`, `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`. Video is recorded without audio; the example removes the `RECORD_AUDIO` permission that the camera plugin declares.
- iOS: `NSCameraUsageDescription` and `NSLocationWhenInUseUsageDescription`. No microphone permission is needed. iOS 15 or newer; the SDK adds no ML Kit pods on iOS, so the app builds and runs on Apple silicon simulators.

The backend reports `"liveness": "challenge"` and `"deepfake_detection": false`. Automated face matching is not part of this SDK.
