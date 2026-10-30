# 05. REST API Contract — Draft v1

> **Auth/Profile đã triển khai; các module còn lại là contract đề xuất.** Chuẩn cơ bản: JSON, UTF-8, HTTPS tại staging/prod, JWT Bearer cho các endpoint private, UUID dưới dạng string, thời gian UTC ISO-8601. Chi tiết bàn giao M3: [M3 Sprint 1](13-m3-sprint1-delivery.md).

## 5.1 Response & error convention

Response thành công thường trả resource trực tiếp; collections có `items` và `nextCursor`. Validation/error thống nhất:

```json
{
  "code": "INVITE_EXPIRED",
  "message": "Mã ghép đôi đã hết hạn.",
  "details": {},
  "requestId": "req_123"
}
```

**HTTP:** 200 OK, 201 Created, 204 No Content, 400 Bad Request, 401 Unauthenticated, 403 Forbidden, 404 Not Found, 409 Conflict, 413 Payload Too Large, 422 Validation Error, 429 Rate Limit, 500 Server Error. Chọn chính xác 400/422 cho validation rồi giữ nhất quán.

## 5.2 Sprint 1 — Auth, Profile, Pairing

| Method | Path | Body / Query | Response |
|---|---|---|---|
| POST | `/api/v1/auth/register` | email, password, displayName | 201 + user |
| POST | `/api/v1/auth/login` | email, password | 200 + accessToken, tokenType, user |
| GET | `/api/v1/users/me` | Bearer | 200 + profile |
| PATCH | `/api/v1/users/me` | displayName, avatarKey? | 200 + profile |
| POST | `/api/v1/couple-invites` | optional ttl? (server decides) | 201 + inviteCode, expiresAt |
| POST | `/api/v1/couples/join` | inviteCode | 201 + couple |
| GET | `/api/v1/couples/me` | Bearer | 200 + couple or 404 |
| DELETE | `/api/v1/couples/me` | Bearer, confirmation required by UI | 204 |

**POST /api/v1/auth/register**

```json
{
  "email": "alex@example.com",
  "password": "ExamplePassword123!",
  "displayName": "Alex"
}
```

**POST /api/v1/auth/login — example response**

```json
{
  "accessToken": "example-jwt-do-not-use",
  "tokenType": "Bearer",
  "user": {
    "id": "5fe12b68-7b14-4c15-9dfd-389f7d917c0f",
    "email": "alex@example.com",
    "displayName": "Alex"
  }
}
```

**POST /api/v1/couple-invites — response**

```json
{
  "inviteCode": "K7P4R8",
  "expiresAt": "2026-10-16T12:00:00Z"
}
```

**POST /api/v1/couples/join — request**

```json
{ "inviteCode": "K7P4R8" }
```

**Couple response** (ví dụ rút gọn):

```json
{
  "id": "ae28fc2b-64fa-4a0f-90bc-bfead48e7b70",
  "status": "ACTIVE",
  "anniversaryDate": null,
  "members": [
    {"id":"5fe12b68-7b14-4c15-9dfd-389f7d917c0f","displayName":"Alex"},
    {"id":"28394653-4d2a-45c1-a2d5-a93b452f95e8","displayName":"Sam"}
  ]
}
```

## 5.3 Sprint 2 — Photo & Timeline

**M1 photo-sharing implementation (multipart fallback):** The current backend uses one authenticated multipart upload instead of the two-step upload-intent/finalize draft below. This avoids exposing object-store credentials or direct bucket URLs to mobile clients. M2/M4 should use the response's photo `id`, not a storage key.

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/api/v1/photos` | `multipart/form-data`, field `file` (JPEG/PNG, 1 byte–10 MB), `Idempotency-Key: <UUID>` header, Bearer token | 201 `PhotoResponse`; same key by same sender returns same photo |
| GET | `/api/v1/photos/latest` | Bearer token | 200 `PhotoResponse` for authenticated user's active couple, or 404 `PHOTO_NOT_FOUND` |
| GET | `/api/v1/photos/{id}/image` | Bearer token | Image bytes with private/no-store cache header, or 404 for outsiders |
| PUT | `/api/v1/devices/push-token` | Bearer token, JSON `{ "token": "<Firebase installation ID>", "platform": "android"\|"ios" }` | 204; register current device for generic photo alerts |
| DELETE | `/api/v1/devices/push-token` | Same authenticated JSON body | 204; remove only current user's device |

`PhotoResponse` contains `id`, `coupleId`, `senderId`, `mimeType`, `sizeBytes`, `createdAt`, `imagePath`. `imagePath` is an **authenticated API path**, not a public object URL. Upload without an active couple returns 409 `COUPLE_REQUIRED`; unsupported or forged image format returns 400. Never send `storageKey` to clients. Photo content is stored in a private S3-compatible bucket (SeaweedFS in local Compose).


| Method | Path | Mục đích | Owner |
|---|---|---|---|
| POST | `/api/v1/photos` | Multipart upload + couple-ownership check (implemented) | M1 |
| GET | `/api/v1/photos/latest` | Ảnh mới nhất để đồng bộ app/widget (implemented) | M1 |
| GET | `/api/v1/photos` | Timeline, `cursor`, `limit` | M2 |
| GET | `/api/v1/photos/{id}` | Chi tiết ảnh | M2 |
| PUT | `/api/v1/photos/{id}/reaction` | Tạo/thay reaction hiện hành | M2 |
| DELETE | `/api/v1/photos/{id}/reaction` | Xóa reaction | M2 |
| GET | `/api/v1/events` | Sự kiện couple | M3 |
| POST | `/api/v1/events` | Tạo event | M3 |
| PATCH | `/api/v1/events/{id}` | Sửa event | M3 |
| GET | `/api/v1/albums` | Danh sách album | M4 |
| POST | `/api/v1/albums` | Tạo album | M4 |
| PUT | `/api/v1/albums/{id}/photos/{photoId}` | Thêm ảnh vào album | M4 |
| POST | `/api/v1/date-plans` | Tạo kế hoạch thủ công | M5 |
| GET | `/api/v1/date-plans` | Danh sách kế hoạch | M5 |

Photo URLs nên là **short-lived signed URLs** hoặc endpoint có auth; không trả permanent public link.

## 5.4 Sprint 3 — AI

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/api/v1/ai/memory-stories` | albumId, selectedPhotoIds, notes, consent=true | draft story; M4 |
| GET | `/api/v1/ai/memory-stories/{id}` | Bearer | auth couple; M4 |
| POST | `/api/v1/ai/date-plans` | city, budget, durationMinutes, interests, consent=true | draft suggested plan; M5 |
| PATCH | `/api/v1/date-plans/{id}` | user-edited plan fields | user retains control; M5 |

## 5.5 Contract governance

- Tuần 1: chốt naming (`camelCase`), UUID, timestamp, error codes, version path; mock response theo contract.
- Thay đổi breaking contract phải cập nhật API docs và báo owner liên quan trước merge.
- OpenAPI là nguồn kiểm chứng thực tế; docs Markdown là bản mô tả/định hướng.
- Thao tác ghi nên có idempotency key hoặc chiến lược dedup đối với upload/accept invite khi retry.
- Không tin bất kỳ `coupleId` nào client gửi nếu chưa xác nhận membership; dùng server-side ownership.
