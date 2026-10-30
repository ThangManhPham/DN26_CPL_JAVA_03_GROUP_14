package com.ourspace.push;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import java.io.IOException;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class PhotoPushSender {
    private static final Logger log = LoggerFactory.getLogger(PhotoPushSender.class);
    private final CoupleMemberRepository members;
    private final PushTokenRepository tokens;
    private final FirebaseMessaging messaging;

    public PhotoPushSender(CoupleMemberRepository members, PushTokenRepository tokens,
                           @Value("${ourspace.push.enabled:false}") boolean enabled) {
        this.members = members;
        this.tokens = tokens;
        if (enabled) {
            try {
                FirebaseApp app = FirebaseApp.initializeApp(FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.getApplicationDefault()).build(), "ourspace-push");
                this.messaging = FirebaseMessaging.getInstance(app);
            } catch (IOException ex) {
                throw new IllegalStateException("Push is enabled but Firebase server credentials are missing", ex);
            }
        } else {
            this.messaging = null;
        }
    }

    public void photoShared(UUID coupleId, UUID senderId, UUID photoId) {
        if (messaging == null) return;
        for (var member : members.findByIdCoupleIdAndLeftAtIsNull(coupleId)) {
            UUID recipientId = member.getId().getUserId();
            if (recipientId.equals(senderId)) continue;
            for (var device : tokens.findByUserId(recipientId)) {
                try {
                    messaging.send(Message.builder()
                            .setFid(device.getToken())
                            .setNotification(Notification.builder()
                                    .setTitle("OurSpace")
                                    .setBody("Người yêu vừa gửi một ảnh mới 💕")
                                    .build())
                            .putData("type", "photo")
                            .putData("photoId", photoId.toString())
                            .build());
                } catch (FirebaseMessagingException ex) {
                    log.warn("Photo push delivery failed: {}", ex.getMessagingErrorCode());
                }
            }
        }
    }
}
