# Development test coverage

Date: 2026-11-20. Host: macOS 26.3, Apple Silicon. Flutter 3.41.9, Dart 3.11.5, Xcode 26.6, JDK 17.

| Check | Result |
| --- | --- |
| Static analysis | Passed |
| HTTP client and session-controller tests | 5 passed |
| Example initial-screen widget test | Passed |
| Android debug APK build | Passed |
| iOS simulator build | Passed |
| Android launch on Desk_Pixel_9_API_35 | Passed |
| iOS launch on iPhone 17 Pro, iOS 26.5 | Passed |

The HTTP tests use responses from isolated Laravel API requests with synthetic accounts and evidence. The initial native screens launch without client credentials.

Outstanding coverage: native camera and gallery selection, permission denial/restoration, background and process recovery, real-device upload interruptions, full requirement navigation, and end-to-end submission from a device to the API. No physical device is connected. Liveness, trusted-camera and deepfake detection are unavailable and have not been tested.
