# M1 Sprint 1 — UI and authentication handoff

This is the implementation handoff for S1-01 to S1-05. The source specification
is [06-sprints-ownership.md](06-sprints-ownership.md); API shapes follow
[05-api-contract.md](05-api-contract.md). The screens and tokens below are
implemented in `mobile/lib`. The [four-screen SVG board](design/m1-sprint1-screens.svg)
can be imported into Figma for further editing. A native Figma file has not
been created.

## Screen flow

```text
Login ⇄ Register
  │       │
  └── auth success ──> Home ──> Profile ──> Home
                         ▲          │
                         └─ save ───┘
                         Profile ──> logout ──> Login
```

The Home screen is an authenticated placeholder. Pairing and Couple Home belong
to M2 (S1-08/S1-09), so that screen must be replaced after the pairing API is
available.

## Design tokens

| Token | Value | Usage |
|---|---|---|
| Background | `#FFFBF8` | Page surface |
| Ink | `#29262B` | Headings and body |
| Rose | `#C74E70` | Primary action and brand |
| Soft rose | `#FCE8EC` | Home panel and avatar |
| Border | `#E8DDD9` | Form fields |
| Content width | 440 px max | Mobile and tablet form layout |
| Page gutter | 24 px | Screen margins |
| Touch target | 48 px minimum | Buttons and icon controls |

The screen copy is Vietnamese. Labels remain visible when fields contain values.
Validation appears next to its field; server errors appear in a live region.
Password visibility has an explicit spoken label. Actions disable while a
request is pending.

## API mapping and integration notes

| UI action | Request | Response used |
|---|---|---|
| Register | `POST /api/v1/auth/register` | User response, followed by login |
| Login | `POST /api/v1/auth/login` | `accessToken`, `user` |
| Open profile | `GET /api/v1/users/me` | Latest user |
| Save profile | `PATCH /api/v1/users/me` | Updated user |

The draft register response contains no token; the client logs in after a
successful registration. The backend must return the fields `id`, `email`,
and `displayName` for a user. The client sends a Bearer token for profile
updates. M2 owns secure token persistence and auth state across restarts; the
current token is kept only in app memory. Profile avatar editing is deferred
because the upload and `avatarKey` contract is not defined.

## Run and verify

```bash
cd mobile
flutter pub get
flutter run --dart-define=OURSPACE_USE_MOCK=true
flutter analyze
flutter test
```

For a real backend on Android emulator, omit `OURSPACE_USE_MOCK` and use the
default `http://10.0.2.2:8080`. For another device or HTTPS environment, set
`--dart-define=OURSPACE_API_BASE_URL=<reachable-origin>`. Local HTTP is allowed
only in the Android debug manifest. Release builds require HTTPS.
