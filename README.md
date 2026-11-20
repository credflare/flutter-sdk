# CredFlare Flutter SDK

Development package for scoped applicant sessions and native document collection on Android and iOS. Requires the scoped-session backend changes. This package is not published.

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter test
flutter run
```

## Session client

Your authenticated backend creates the verification and returns a temporary session descriptor. It retains all client credentials.

```dart
final session = CredflareSession(SessionDescriptor.fromJson(descriptor));
final info = await session.get();
final uploaded = await session.upload(
  bytes: documentBytes,
  filename: 'front.jpg',
  key: requestKey(),
);
final submissionId = await session.submit({
  'type': 'document_verification',
  'document_type_id': documentTypeId,
  'file_id': uploaded['id'],
}, key: requestKey());
```

Keep each request key with its unchanged payload until the operation succeeds. Use the same key after a network interruption. Use a new key when the applicant replaces evidence. Supply `back_file_id` when the requirement requests both sides.

The client also submits requested form fields, facial images and coordinates. A facial photo is not a liveness result. Submission receipts are not verification decisions. Use the server API or webhook for the final decision.

`CredflareSessionController(provider: ...)` loads a descriptor from your authenticated backend and exposes `session`, `info`, `loading` and `error`. Concurrent `load()` calls share one operation. The provider must keep the same verification case when renewing access. Dispose the controller when leaving the flow.

A 401 means the session is unavailable. Ask the host backend whether it can issue a replacement. `replaceSession` updates the temporary credential while retaining the client object. `cancel()` revokes that session while preserving the verification case. Dispose clients with `close()` when no longer needed.

## Native capture

Use `CredflareDocumentCapture` with a selected session requirement, the session client, `maxFileSizeBytes`, `allowedFileTypes` and `onSubmitted`. It collects the requested sides with preview, replacement and explicit submission. It preserves upload IDs and retry keys after a failed send.

Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to the iOS app's Info.plist and Internet permission to Android. The component uses native image selection and camera capture rather than a WebView. It refuses unsupported trusted-camera policies. Gallery selection currently handles images; use the session client with your own file picker for other permitted document formats.

The example accepts a temporary descriptor produced by the JavaScript repository's local backend and collects one outstanding document at a time. Never paste or embed client credentials in a mobile app. For a local Android emulator API, use `adb reverse` to forward the API port and a loopback API URL.

See [flow requirements](docs/SDK-FLOW.md). Guided forms, full workflow navigation, process recovery and physical-device capture tests remain required before release. Trusted-camera checks, liveness and deepfake detection are unavailable.
