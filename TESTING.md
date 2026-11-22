# Development test coverage

Date: 2026-11-22. Host: macOS 26.3, Apple Silicon. Flutter 3.41.9, Dart 3.11.5, JDK 17.

| Check | Result |
| --- | --- |
| Spec drift check (`sh scripts/check-spec.sh`) | Generated file and fixtures match the spec |
| Static analysis | Passed |
| Unit and widget tests (`flutter test`) | 158 passed |
| Example flow test | Passed |
| Screenshot tool (`flutter test tool/doc_screens_test.dart`) | 19 screens rendered, light and dark |
| Android debug APK build | Passed |

## What the tests cover

- Every liveness trace in the spec is replayed through the gesture engine and must give its expected outcome.
- Contract tests send real HTTP requests to a local server that answers with the API fixtures: session load, liveness challenge, gesture, video and selfie uploads with their multipart fields and request keys, facial and location submissions, and rejections whose `code` is parsed from the fixtures. Widget tests check that every upload and submission carries a request key, that a dropped submission reuses its key, and that each rejection code shows its own copy.
- ML Kit results are converted to the shared face signals with and without mirroring, using the plugin's own `Face` type.
- Widget tests drive the full flow with a fake camera source that replays spec traces and a fake location source: position gate, three gestures with frames and video, selfie review, uploads bound to the challenge, facial submission, location retries until accurate, location submission and the receipt. Further tests cover a timed out gesture asking for a new challenge, a rejected location showing its rejection screen, a mocked location refused before sending and denied location access.

- All 62 backend `show_if` cases in the spec are replayed through the condition evaluator and must give the server's result.
- Widget tests drive the questionnaire through the guided flow: hidden questions are not shown, not checked and not sent, answers are checked against their limits, and a server rejection marks the question. After the answers are sent, the session is loaded again and a phone step that a workflow added is shown.
- Every `email.*` and `phone.*` rejection fixture shows its spec title, message, requester and help line, and its action: entering the code again, sending a new code, waiting for the resend time, or leaving. Every `liveness.*` and `location.*` rejection shows its spec screen. An unknown or missing code shows the server message with a retry. The help line uses the requester's help address, then its help page, then its name, from the captured help contact session. A failed session check after sending never shows the receipt.

## Android emulator

Against the local backend on an Android 15 emulator, in a sandbox case:

- Phone code: a number without a country code was refused before sending, a code was sent through the log SMS driver, a wrong code showed the code not correct screen, and entering the code from the backend log confirmed the number and showed the receipt.
- Questionnaire: the employer and income questions appeared for Employed and disappeared for Student, Other under sources of funds showed its follow up question, required questions and consent were enforced, and the stored submission held only the shown answers.
- Added requirement: answering Germany as the country made the workflow add a phone confirmation, which the app showed next instead of the receipt.

## Not yet covered

- The camera and ML Kit path has not run end to end on a device. The shared Android emulator was in use by other runs, and iOS simulators have no camera. Yaw and pitch signs follow the ML Kit documentation and must be confirmed on a physical device.
- Live location fixes from geolocator, permission denial and restoration on a device.
- Background and process recovery, real-device upload interruptions.

Trusted-camera and deepfake detection are unavailable and have not been tested.
