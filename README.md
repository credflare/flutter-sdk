# CredFlare Flutter SDK

Development package for scoped applicant sessions and native document and selfie collection on Android and iOS. Requires the scoped-session backend changes. This package is not published.

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

The client also submits requested form fields, facial images and coordinates. A facial photo is not a liveness result. Submission receipts are not verification decisions. Use the server API or webhook for the final decision.

`CredflareSessionController(provider: ...)` loads a descriptor from your authenticated backend and exposes `session`, `info`, `loading` and `error`. Concurrent `load()` calls share one operation. The provider must keep the same verification case when renewing access. Dispose the controller when leaving the flow.

A 401 means the session is unavailable. Ask the host backend whether it can issue a replacement. `replaceSession` updates the temporary credential while retaining the client object. `cancel()` revokes that session while preserving the verification case. Dispose clients with `close()` when no longer needed.

## Native capture

Use `CredflareDocumentCapture` with a selected session requirement, the session client, `maxFileSizeBytes`, `allowedFileTypes` and `onSubmitted`. It collects the requested sides with preview, replacement and explicit submission. It preserves upload IDs and retry keys after a failed send.

Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to the iOS app's Info.plist and Internet permission to Android. The component uses native image selection and camera capture rather than a WebView. It refuses unsupported trusted-camera policies. The file picker accepts configured images, PDFs and DOCX files. File size and type checks also run on the server.

Use `CredflareVerification(sessionProvider: provider, onClose: close)` for the guided document flow. The provider obtains a fresh session from your authenticated backend. The example calls the JavaScript demo backend on localhost port 3107 when Start is pressed; no session entry or pasting is needed. Never paste or embed client credentials in a mobile app. For a local Android emulator API, use `adb reverse` to forward the API port and a loopback API URL.

See [flow requirements](docs/SDK-FLOW.md). Guided forms, process recovery and physical-device capture tests remain required before release. Trusted-camera checks, liveness and deepfake detection are unavailable.

## Capture choices

Each document has its own capture rule. An ID can require `snapshot` while a bank statement requires `upload` in the same profile. `either` lets the applicant choose a photo or file for each side. `snapshot_and_upload` separately requires both sources for the same document. These rules are separate from document groups that ask for all documents or a subset of alternatives.

The guided screens show each required side, preview and replacement, a final review, and a collection receipt. Camera source is client-reported. It does not establish liveness or a trusted feed.

Run `sh validate.sh` for static analysis, client tests and the example flow test. Native builds require Android SDK and Xcode separately.

## Upload test files

Synthetic front and back PNGs are in the sibling JavaScript SDK at `test/fixtures/documents`. Android demo files are available under Downloads > Credflare-Samples. The iOS example enables local document sharing so files placed in its Documents directory appear in Files under On My iPhone. Use the Upload-Samples folder in either demo app. These are test documents, not real identity records.

## Developer-configured facial collection

Choose the compliance profile on your server when creating the case. The recipient does not choose a profile or verification mode. The SDK collects outstanding documents first, then opens the selfie step only when the case requests `facial_verification`. Selfie-only cases go directly to that step. Document alternatives and capture-source choices follow the server's requirement rules.

The selfie step uses the front camera, provides a preview and retake action, and sends only after confirmation. Uploads use the scoped biometric endpoint; facial submissions reference the uploaded file ID. Retrying a send reuses its upload and submission keys. A receipt confirms collection for review, not a face match or liveness result.

The backend currently reports liveness, trusted camera and deepfake detection as unavailable. Automated face matching and validated liveness processing are not implemented by this capture interface. Forms and location checks return control to the host app. Example apps obtain their requirements from the demo server without a recipient-facing profile selector.
