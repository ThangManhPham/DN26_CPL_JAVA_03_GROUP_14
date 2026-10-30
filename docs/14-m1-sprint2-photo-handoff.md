# M1 Sprint 2 — Photo Sharing & iOS handoff

## Implemented

- Private JPEG/PNG upload (up to 10 MB) to an S3-compatible object store; authenticated couple-only image access.
- Idempotent upload key, latest-photo API, migration V4, authorization and invalid-file tests.
- Flutter camera/gallery picker, preview, loading/error/retry, latest photo view.
- Basic in-app notification when a partner photo appears while Photos is open (30-second poll).

Run `docker compose up -d --build`, then run Flutter from `mobile/`. Register two accounts and pair them via `/api/v1/couple-invites` and `/api/v1/couples/join` until M2's pairing UI lands. Use `--dart-define=OURSPACE_API_BASE_URL=...` for a physical device. See [Docker runbook](../DOCKER-README.md) and [API contract](05-api-contract.md).

## Remaining integration dependencies

- M2: durable auth session and pairing UI. Without them, the photo screen needs a fresh login after an app restart, and pairing must be done through the API.
- iOS WidgetKit extension is not implemented yet. It needs an Apple App Group/signing setup and physical-device verification.
- Firebase push registration and server sender are implemented, but off on the server until private credentials are configured. iOS delivery still needs APNs and physical-device testing. The 30-second in-app polling notice remains a fallback, not background push.

## Firebase setup for later push integration

1. Create a Firebase project at the [Firebase console](https://console.firebase.google.com/). Keep project ownership under the team's Google account.
2. From `mobile/`, run the [FlutterFire setup](https://firebase.google.com/docs/flutter/setup): install Firebase CLI, log in, activate FlutterFire CLI, then run `flutterfire configure --platforms=ios`. The iOS bundle ID is `com.ourspace.mobile`.
3. For iOS push, a paid Apple Developer team, APNs authentication key, and a physical iPhone are required. In Xcode, enable Push Notifications and Background Modes (Background fetch and Remote notifications), then upload the APNs `.p8` key in Firebase Cloud Messaging settings. Follow the [FCM Flutter guide](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
4. The configured Firebase project is `ourspace-81e96`, and the iOS bundle ID is `com.ourspace.mobile`. Create a server service-account key only if needed, store it outside Git, and point `FIREBASE_SERVICE_ACCOUNT_FILE` to it for the optional Compose overlay. Do **not** send the APNs private key, service-account JSON or other secrets in chat or commit them to Git.

The backend registers Firebase installation IDs after login and sends a generic alert after a photo is saved. M2's persistent session and logout/unpair lifecycle should be integrated before calling push production-ready.

For the exact backend key and iOS APNs steps, see [Firebase push setup](15-firebase-push-setup.md).
