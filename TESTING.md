# Development test coverage

Date: 2026-11-21. Host: macOS 26.3, Apple Silicon. Flutter 3.41.9, Dart 3.11.5, JDK 17.

| Check | Result |
| --- | --- |
| Spec drift check (`sh scripts/check-spec.sh`) | Generated file and fixtures match the spec |
| Static analysis | Passed |
| Unit and widget tests (`flutter test`) | 65 passed |
| Example flow test | Passed |
| Screenshot tool (`flutter test tool/doc_screens_test.dart`) | 19 screens rendered, light and dark |
| Android debug APK build | Passed |

## What the tests cover

- Every liveness trace in the spec is replayed through the gesture engine and must give its expected outcome.
- Contract tests send real HTTP requests to a local server that answers with the API fixtures: session load, liveness challenge, gesture, video and selfie uploads with their multipart fields and request keys, facial and location submissions, and a rejected location surfaced as a validation error.
- ML Kit results are converted to the shared face signals with and without mirroring, using the plugin's own `Face` type.
- Widget tests drive the full flow with a fake camera source that replays spec traces and a fake location source: position gate, three gestures with frames and video, selfie review, uploads bound to the challenge, facial submission, location retries until accurate, location submission and the receipt. Further tests cover a timed out gesture asking for a new challenge, a rejected location showing the server reason, a mocked location refused before sending and denied location access.

## Not yet covered

- The camera and ML Kit path has not run end to end on a device. The shared Android emulator was in use by other runs, and iOS simulators have no camera. Yaw and pitch signs follow the ML Kit documentation and must be confirmed on a physical device.
- Live location fixes from geolocator, permission denial and restoration on a device.
- Background and process recovery, real-device upload interruptions.

Trusted-camera and deepfake detection are unavailable and have not been tested.
