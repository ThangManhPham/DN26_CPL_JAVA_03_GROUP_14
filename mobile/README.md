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
on an iOS Simulator (`http://localhost:8080`) or Android emulator
(`http://10.0.2.2:8080`). Set `--dart-define=OURSPACE_API_BASE_URL=https://...`
for another host or a real device. Local HTTP is for debug only.

The Photos screen lets a paired user choose/capture JPEG or PNG (max 10 MB),
send it with an idempotency key, and retrieve the latest photo through an
authenticated endpoint. An Android home-screen widget displays the last image
cached by the app; add it from Android's widget picker. It refreshes when the
Photos screen loads, is polled every 30 seconds while open, or a photo is sent.
When the screen is open and a new partner photo arrives, it shows an in-app
notification. Logout clears the widget cache. iOS WidgetKit and background
push notification require separate platform setup and are not yet enabled.

This client does not yet persist tokens across app restarts; that is S1-07
(M2). The authenticated Home is a placeholder for S1-09 (M2).
