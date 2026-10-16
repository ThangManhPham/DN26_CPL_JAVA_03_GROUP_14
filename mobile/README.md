# OurSpace mobile

Flutter client for the M1 Sprint 1 auth and profile UI. See
[the design and integration handoff](../docs/13-m1-sprint1-ui.md).

Use Flutter 3.41.6 / Dart 3.11.4:

```bash
flutter pub get
flutter run --dart-define=OURSPACE_USE_MOCK=true
flutter analyze
flutter test
```

The mock mode stores demo users only in memory. To call the real Spring Boot
API, omit the mock flag and set `OURSPACE_API_BASE_URL` when the backend is
not reachable at the Android emulator default `http://10.0.2.2:8080`.

This client does not yet persist tokens across app restarts; that is S1-07
(M2). The authenticated Home is a placeholder for S1-09 (M2).
