# M1 Sprint 3 — photo flow verification

## Implemented

- Photo HTTP 401 now invalidates the shared auth session, as other API requests do.
- After the server accepts an upload, the send form is cleared and timeline refresh is signalled before image/widget refresh. A failed follow-up refresh displays an accurate message and cannot cause an accidental resend. Network failure during upload still retains the same request ID for an idempotent retry.
- App Group widget data is cleared on logout/401 through the existing auth listener. Widget refresh remains best effort while the app is open.

## Acceptance run on an iPhone

1. Enable `group.com.ourspace.mobile` on Runner and OurSpaceWidget in the same signing team. Use a reachable backend URL with `--dart-define=OURSPACE_API_BASE_URL=http://<LAN-IP>:8080`.
2. Sign in as A and B on separate sessions. Pair them. A uploads a test JPEG/PNG. B opens Photos and sees the image; leave Photos open to check the 30-second in-app notice for a second upload.
3. Add the widget, load Photos, and confirm the latest image. If WidgetKit shows an old snapshot, remove and re-add the widget and recheck. Log out or trigger an expired-token 401; confirm the widget shows the empty state.
4. Interrupt an upload and retry the same selection. Confirm one stored photo. As user C outside the couple, request the photo image endpoint and confirm 403/404. Inspect logs for tokens and public long-lived URLs.

Record device model, iOS version, screenshot with test data, backend result and expected/actual for TC-13–16, TC-20 and TC-25. Simulator and automated tests do not replace physical-device WidgetKit verification. APNs background push is outside the coursework scope.
