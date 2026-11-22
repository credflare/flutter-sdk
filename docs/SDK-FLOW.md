# SDK verification flow

The application backend creates a verification using a compliance profile, then exchanges its request ID for a short-lived applicant session. The app receives only that session. The backend retains its client credentials and the verification request ID.

The SDK loads the outstanding requirements, explains the requested evidence and consent, collects one step at a time, uploads evidence and submits its file IDs. After each submission it reloads the requirements so the backend decides which steps remain. Grouped alternatives must remain choices; the SDK must not ask for every alternative.

Document capture includes the requested sides, preview, retake and explicit confirmation. Gallery uploads appear only when the requirement permits them. A camera photo does not prove a trusted camera feed, liveness or deepfake resistance.

After the documents, the SDK asks the outstanding questions, then runs the facial, location, email and phone requirements in profile order:

1. Facial: request a challenge from the server, pass the position gate, run each server gesture with the shared gesture engine, keep a frame per gesture, record video when the challenge asks for it, take the selfie, let the applicant review it, upload everything bound to the challenge and submit. Any timeout or expiry asks for a new challenge.
2. Location: explain what is shared, request permission, retry fixes until accuracy and age meet the profile settings, refuse a fix the platform flags as mocked when the profile rejects mocks, let the applicant review it and submit. Server rejections are shown with a retry.
3. Email and phone: take the address or international number, request a code, take the six digits and confirm. Sending a new code follows the resend time and sends remaining from the server.

Questions with `show_if` are evaluated against the answers given so far; hidden questions are not shown, not checked and not sent. Every rejection code shows the title, message and action from the spec rejection map, who asked for the evidence and where to get help. A missing or unknown code shows the server message with a retry.

After every submission or code confirmation the SDK loads the session again. It continues while the session is open and anything is outstanding, including a requirement a workflow added during the case. The receipt lists what was received in this visit and appears only when nothing required remains. If the check fails, the SDK offers a retry and never shows the receipt.

A finished collection flow reports `submitted`. The application's backend obtains the verification decision from the API or webhook. Closing the collection UI reports `cancelled`; it must not reject the verification case.

## Lifecycle requirements

- Prevent overlapping camera launches and submissions, including rapid repeated taps.
- Distinguish permission denial, cancellation, an unavailable session, validation failure and network failure.
- Keep retry keys and uploaded file IDs while retrying the same evidence. Replacing an image starts a new operation.
- Let the authenticated host backend renew a session for the same case. The SDK cannot renew its own authority or change workspace/environment.
- Restore the current step after ordinary backgrounding. Process termination needs an explicit recovery policy for temporary images and session renewal.
- Confirm cancellation before discarding selected evidence. Revoking a session preserves the verification case.
- Keep evidence, tokens and personal fields out of diagnostic logs and analytics events.
- Provide accessible labels, clear progress, localized copy and host branding.
- Refuse unsupported capture policies and checks with an actionable explanation.

## Release boundary

The development packages provide a session client and guided document, questionnaire, email, phone, liveness and location collection. Applicants start without entering session credentials, choose a requested document, add each required side and source, review their evidence and receive a collection receipt. The flow refreshes outstanding requirements after each document and selfie. The developer selects the profile on their server; the recipient follows the outstanding requirements without a profile picker.

Before a production release, add typed lifecycle results, guided session-renewal UI, Android process recovery, permission recovery, accessibility and physical-device capture tests. The liveness challenge shows a server chosen sequence was recorded in time; it is not a liveness proof. Trusted-camera and deepfake checks are not available.
