# Firebase push setup — OurSpace

FlutterFire configuration for Firebase project `ourspace-81e96` and app ID `com.ourspace.mobile` is in `mobile/`. These client configuration files identify the Firebase project; they are not server credentials. Push sending is **disabled by default** until the backend gets private credentials.

## 1. Backend service account (required to send)

1. Open [Firebase console](https://console.firebase.google.com/) → `OurSpace` → gear icon → **Project settings** → **Service accounts** → **Generate new private key**. The downloaded JSON is a powerful private credential.
2. Move that JSON to a private folder **outside this Git repository**, for example `/Users/binhtran/.config/ourspace/firebase-service-account.json`; restrict file access to your Mac user. Never paste its contents in chat, commit it, or put it under `mobile/` or `backend/`.
3. In the local, ignored root `.env`, set `FIREBASE_SERVICE_ACCOUNT_FILE=` to the **absolute path** of that JSON and `FIREBASE_HOST_UID=` to the output of `id -u` (on this Mac). Start the push-enabled backend with `docker compose -f compose.yaml -f compose.firebase.yaml up -d --build`. The overlay runs the backend as your non-root host user so it can read a private `0600` key, mounts the key read-only, and sets `OURSPACE_PUSH_ENABLED=true`.
4. Confirm the backend is healthy. Sign in on two devices; the app registers each Firebase installation ID after login. Upload an image from one paired user; only the other user's registered devices receive a generic alert. The push payload contains a photo ID, not an image URL or private photo bytes.

If you are running the backend outside Docker, set `GOOGLE_APPLICATION_CREDENTIALS` to the absolute JSON path and `OURSPACE_PUSH_ENABLED=true` in that shell. Do not put credentials in `application.yml`.

## 2. iOS APNs (required for iPhone push)

1. Ensure you have an Apple Developer team and a **physical iPhone** signed into it. The iOS Simulator can build the app, but it is not the acceptance test for Firebase push.
2. In [Apple Developer Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/), register/configure App ID `com.ourspace.mobile`, enable Push Notifications, then create an **APNs Auth Key**. Download the `.p8` once; note its Key ID and your Team ID. Keep the `.p8` private and outside Git.
3. In Firebase Console → Project settings → **Cloud Messaging** → your iOS app → **APNs authentication key**, upload the `.p8` and enter Key ID and Team ID.
4. Open `mobile/ios/Runner.xcworkspace` in Xcode. Select Runner → **Signing & Capabilities**: choose your Team, add **Push Notifications**, and ensure **Background Modes** has Background fetch and Remote notifications. For WidgetKit, select both Runner and OurSpaceWidget targets and enable the shared App Group `group.com.ourspace.mobile`. Build/run on the physical iPhone, grant notification permission, and test with two paired accounts.

The API/device registration tests can run without Apple or Google private keys; real iPhone delivery cannot.

Official references: [Firebase Admin SDK setup](https://firebase.google.com/docs/admin/setup), [FlutterFire setup](https://firebase.google.com/docs/flutter/setup), [FCM Flutter/iOS setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
