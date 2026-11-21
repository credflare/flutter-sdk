# CredFlare Flutter SDK

Development package for scoped applicant sessions and native collection of documents, a liveness challenge with selfie, and location on Android and iOS. Requires the scoped-session backend changes. This package is not published.

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

Keep each request key with its unchanged payload until the operation succeeds. Use the same key after a network interruption. Use a new key when the applicant replaces evidence. Use `captureSteps(requirement)` to collect every requested side and source.

The client also submits requested form fields, liveness evidence and coordinates. `createLivenessChallenge()` asks the server for the gestures to run, `uploadBiometric` sends gesture frames, the liveness video and the selfie bound to that challenge, and `submitFacial` and `submitLocation` submit them. A completed challenge shows that the camera recorded a server chosen sequence in time. It is not a verification decision and does not detect deepfakes. Submission receipts are not verification decisions. Use the server API or webhook for the final decision.

`CredflareSessionController(provider: ...)` loads a descriptor from your authenticated backend and exposes `session`, `info`, `loading` and `error`. Concurrent `load()` calls share one operation. The provider must keep the same verification case when renewing access. Dispose the controller when leaving the flow.

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

Choose the compliance profile on your server when creating the case. The recipient does not choose a profile or verification mode. After the outstanding documents, the SDK runs the remaining facial and location requirements itself, in profile order, and shows a receipt only when everything required has been received. Form steps still return control to the host app.

The facial step asks the server for a challenge, shows a mirrored front camera preview with positioning hints, runs the server's gestures in order with a timeout for each, keeps a JPEG frame when each gesture completes, records a video without audio over the challenge window when the profile asks for one, then takes the selfie. The applicant reviews the selfie before the frames, video and selfie are uploaded and submitted. A timeout or failure offers a retry that requests a new challenge. Face signals come from ML Kit face detection through a `FaceSignalProvider`, so another provider can be swapped in. Pass `livenessSource` to `CredflareVerification` to replace the camera source.

The location step explains what is shared and, when the profile names reference places, which place by label. It asks for permission, takes a high accuracy fix and retries until the fix meets the profile's accuracy and age limits. It reports whether the platform flagged the fix as mocked and shows the server's reason when a location is rejected. The SDK never calls geocoding or IP lookup services. Pass `locationSource` to replace the location source.

### Permissions

- Android: `CAMERA`, `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`. Video is recorded without audio; the example removes the `RECORD_AUDIO` permission that the camera plugin declares.
- iOS: `NSCameraUsageDescription` and `NSLocationWhenInUseUsageDescription`. No microphone permission is needed. ML Kit needs iOS 15.5 or newer.

The backend reports `"liveness": "challenge"` and `"deepfake_detection": false`. Automated face matching is not part of this SDK.
