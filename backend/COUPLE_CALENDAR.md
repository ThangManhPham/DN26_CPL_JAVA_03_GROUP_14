# M3 Sprint 2 — Couple Space and Calendar backend

Backend-only delivery based on the latest `main`. Provides shared anniversary,
elapsed calendar days, and event CRUD for the authenticated user's active couple.
The personal local web demo and mobile changes are outside this delivery.

## API contract

All endpoints require a Bearer JWT. Couple membership and event creator are
resolved on the server; clients cannot select another couple or creator.

| Method | Path | Input | Result |
|---|---|---|---|
| GET | `/api/v1/couple-space` | Optional `timezone`, default `Asia/Ho_Chi_Minh` | Couple ID, anniversary, days together, timezone |
| PATCH | `/api/v1/couple-space` | `anniversaryDate` (`YYYY-MM-DD`), optional timezone query | Updated shared anniversary/counter |
| POST | `/api/v1/events` | Title, optional description, UTC `startsAt`/`endsAt`, timezone | 201 event |
| GET | `/api/v1/events` | UTC `from`/`until`, `page=0`, `size=50` | `items`, `nextPage` |
| GET | `/api/v1/events/{id}` | Event UUID | 200 event |
| PATCH | `/api/v1/events/{id}` | Changed fields and required current `version` | 200 updated event/version |
| DELETE | `/api/v1/events/{id}` | Required current `version` query | 204 |

- Anniversary accepts dates from 1900-01-01 through today in the requested zone.
  Start date is day zero; unset anniversary and counter are null.
- Event title must be nonblank and at most 150 characters; description at most
  2000. A valid timezone and end after start are required, within 1900–2100.
- Listing returns overlapping events in the half-open range `[from, until)`,
  at most 366 days, sorted by start and ID. Size is 1–100; follow `nextPage`
  until null. Offset pagination can shift during concurrent inserts/deletes.
- PATCH preserves omitted fields; `description: null` clears notes. Unknown
  fields or invalid input return 422; stale versions return 409 `EVENT_CONFLICT`.
  JPA optimistic locking also guards concurrent writes.
- Both active members may read/update/delete. Unpaired users and ended/former
  memberships are denied. Cross-couple events return 404 without metadata.
  Missing/invalid token returns 401; malformed/missing query parameters return 400.
- Sprint 3 adds a read-only `reminder` object to GET/PATCH couple-space:
  `{occursOn: YYYY-MM-DD, daysUntil: number, yearsTogether: number}`, or null
  when the anniversary is unset. It is calculated using the requested timezone.
  The first anniversary is after one year; February 29 is observed on February 28
  in non-leap years. Existing fields and API paths remain compatible.
- The Flutter calendar shows the reminder, with opt-in local notifications on iOS.
  Remote event push and recurring events remain outside this delivery.

## Migration coordination

`V6__create_couple_events.sql` is provided for PostgreSQL and H2. The calendar
migration has not been deployed to a shared database by this delivery.

V5 is reserved for the album migration in PR #8:
https://github.com/ThangManhPham/DN26_CPL_JAVA_03_GROUP_14/pull/8

**Before deployment, coordinate with M4/M5 and include/apply album V5 before
calendar V6 if both features are being delivered.** Current main has V1–V4;
Flyway can migrate a clean database directly to V6. However, applying calendar
V6 first and introducing album V5 later requires a migration-order decision;
do not silently enable out-of-order execution or edit already-applied migrations.

H2 migrations (including the existing repeatable push-token migration) move
unchanged from test resources to main resources so packaged dev JARs and tests
use the same schema. PostgreSQL V1–V4 and the push migration remain unchanged.

## Verification

From the backend directory, using the project's JDK 21:

```powershell
mvn clean package
./scripts/smoke-auth.ps1 -Calendar
```

On this workstation's JDK 25, the existing Byte Buddy version needs this local
compatibility flag; it does not change the project JDK/dependencies:

```powershell
mvn clean package '-Dnet.bytebuddy.experimental=true'
./scripts/smoke-auth.ps1 -Calendar
```

The HTTP smoke test starts and stops an isolated loopback server with its own
in-memory H2 database. It exercises real registration/login, pairing, anniversary,
calendar CRUD, access restrictions and stale versions. It does not use the
personal demo accounts or the running demo database.

Calendar integration tests cover shared CRUD, unauthorized/unpaired/outsider
access, input/range/zone validation, partial updates, stale versions, pagination,
leap-date anniversary and ended/former membership. Existing photo/auth/pairing
and push tests must continue to pass. PostgreSQL runtime and staging/CI require
separate verification; local H2 success does not prove those environments.
