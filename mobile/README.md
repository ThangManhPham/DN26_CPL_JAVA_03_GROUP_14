# OurSpace mobile

Flutter client for M1 auth/profile and M2 Sprint 1 & 2 pairing/timeline.

Use Flutter 3.47.9 / Dart 3.13.7:

```bash
flutter pub get
flutter run --dart-define=USE_MOCK=true
flutter analyze
flutter test
```

The mock mode stores demo users, pairing state, and timeline photos only in memory (static). For the real
API, start Docker Compose from the repository root, omit the mock flag and run
on an iOS Simulator (`http://localhost:8080`). Set `--dart-define=OURSPACE_API_BASE_URL=https://...`
for another host or a real device. Local HTTP is for debug only.

### Pairing & Timeline (M2)
- **Pairing**: Create/Join invites with automatic redirect. Supports iOS Share Sheet and Clipboard.
- **Timeline**: Cursor pagination (infinite scroll), pull-to-refresh, skeleton loading.
- **Reactions**: Optimistic updates for LOVE, LIKE, LAUGH, SAD reactions.
- **Security**: Authenticated image endpoints, no public URLs, token persistence via `flutter_secure_storage` (Keychain on iOS, LocalStorage fallback on Web).
- **Mock Mode**: Shared static state for single-session testing. Use special codes `EXPYR3` (expired), `US3D22` (invalid), `S3LF22` (self-pair), `PAYRD2` (partner already paired) for quick testing.

### iOS Configuration
Logout unregisters the device and clears the iOS WidgetKit image. WidgetKit
shows the latest cached photo after it is loaded or sent in-app. The project
uses App Group `group.com.ourspace.mobile`; select the same App Group for both
Runner and OurSpaceWidget in Xcode before signing on an iPhone. iOS push still
requires APNs setup and a physical-device test.

See `docs/M2_REPORT.md` for full implementation details, test results and manual checklist.
