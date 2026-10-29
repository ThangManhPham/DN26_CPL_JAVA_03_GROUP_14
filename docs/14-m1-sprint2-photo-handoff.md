# M1 Sprint 2 — Photo Sharing & Widget handoff

## Implemented

- Private JPEG/PNG upload (up to 10 MB) to an S3-compatible object store; authenticated couple-only image access.
- Idempotent upload key, latest-photo API, migration V4, authorization and invalid-file tests.
- Flutter camera/gallery picker, preview, loading/error/retry, latest photo view.
- Android launcher widget proof: cached latest image refreshes when Photos is open and on send; logout/cold start clears it.
- Basic in-app notification when a partner photo appears while Photos is open (30-second poll).

Run `docker compose up -d --build`, then run Flutter from `mobile/`. Register two accounts and pair them via `/api/v1/couple-invites` and `/api/v1/couples/join` until M2's pairing UI lands. Use `--dart-define=OURSPACE_API_BASE_URL=...` for a physical device. See [Docker runbook](../DOCKER-README.md) and [API contract](05-api-contract.md).

## Remaining integration dependencies

- M2: durable auth session and pairing UI. Without them, the photo screen needs a fresh login after an app restart, and pairing must be done through the API.
- iOS WidgetKit extension is not part of this Android widget proof. It needs an Apple App Group/signing setup and physical-device verification.
- Background push is a Sprint 3 integration task. The in-app notification above is not a push notification.

## Firebase setup for later push integration

1. Create a Firebase project at the [Firebase console](https://console.firebase.google.com/). Keep project ownership under the team's Google account.
2. From `mobile/`, run the [FlutterFire setup](https://firebase.google.com/docs/flutter/setup): install Firebase CLI, log in, activate FlutterFire CLI, then run `flutterfire configure`. Select Android and iOS. The package/bundle ID in this repo is `com.ourspace.mobile` on both platforms.
3. For iOS push, a paid Apple Developer team, APNs authentication key, and a physical iPhone are required. In Xcode, enable Push Notifications and Background Modes (Background fetch and Remote notifications), then upload the APNs `.p8` key in Firebase Cloud Messaging settings. Follow the [FCM Flutter guide](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
4. Send the Firebase project ID and confirm the Android/iOS app registrations. Do **not** send the APNs private key, service-account JSON or other secrets in chat or commit them to Git.

Firebase configuration alone will not turn on push: the backend still needs device-token registration and a private server-side FCM sender. That work should be reviewed with M2's session lifecycle so logout/unpair revokes tokens correctly.
