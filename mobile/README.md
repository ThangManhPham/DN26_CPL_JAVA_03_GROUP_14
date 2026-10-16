# OurSpace mobile

Flutter client cho ứng dụng OurSpace. Xem [API contract](../docs/05-api-contract.md) và [sprint ownership](../docs/06-sprints-ownership.md).

## Flutter / Dart

- **Flutter**: 3.41.6 (khuyến nghị) / tương thích với 3.11.4+
- **Dart**: 3.11.4+

## Cấu trúc thư mục

```
lib/
  core/               # Cấu hình dùng chung, network, routing, error
    config/           # AppConfig (base URL, mock flag)
    error/            # AppException + subclasses
    network/          # DioClient + interceptor
    router/           # go_router + route guard
    storage/          # SecureStorageService (token)
  features/
    auth/             # Auth state (Riverpod), repository, screens
      data/           # AuthRepository interface + HTTP + Mock impl
      domain/         # UserProfile, AuthState, CoupleInfo
      presentation/   # AuthScreen, HomeScreen, ProfileScreen (placeholders)
    pairing/          # Couple pairing: screens + repository
      data/           # CoupleRepository interface
      domain/         # InviteCode DTO
      presentation/   # CreateInvite, JoinInvite, CoupleHome screens
  shared/
    widgets/          # BrandMark, LoadingWidget, ErrorWidget
  main.dart           # App entry point với go_router + Riverpod
```

## Chạy ứng dụng

```bash
flutter pub get
# Mock mode (không cần backend):
flutter run --dart-define=OURSPACE_USE_MOCK=true
# Kết nối backend thật:
flutter run --dart-define=OURSPACE_USE_MOCK=false --dart-define=OURSPACE_API_BASE_URL=http://localhost:8080
```

## Lệnh kiểm tra

```bash
flutter analyze
flutter test
```
