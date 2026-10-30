# OurSpace mobile

Flutter client for M1 auth/profile and Sprint 2 photo-sharing UI. See
[the design and integration handoff](../docs/13-m1-sprint1-ui.md).

Use Flutter 3.41.6 / Dart 3.11.4:

```bash
flutter pub get
flutter run --dart-define=OURSPACE_USE_MOCK=true
flutter analyze
flutter test
```

The mock mode stores demo users and the latest photo only in memory. For the real
API, start Docker Compose from the repository root, omit the mock flag and run
on an iOS Simulator (`http://localhost:8080`). Set `--dart-define=OURSPACE_API_BASE_URL=https://...`
for another host or a real device. Local HTTP is for debug only.

The Photos screen lets a paired user choose/capture JPEG or PNG (max 10 MB),
send it with an idempotency key, and retrieve the latest photo through an
authenticated endpoint. The Photos screen polls every 30 seconds while open.
When a new partner photo arrives, it shows an in-app
notification. Firebase Messaging registers a device after login and handles
generic photo alerts when configured server-side; see the Sprint 2 handoff.
Logout unregisters the device. iOS WidgetKit is not yet enabled; iOS push
still requires APNs setup and a physical-device test.

This client does not yet persist tokens across app restarts; that is S1-07
(M2). The authenticated Home is a placeholder for S1-09 (M2).
