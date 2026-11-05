package com.ourspace.push;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "push_tokens")
public class PushToken {
    @Id @Column(length = 1024) private String token;
    @Column(name = "user_id", nullable = false) private UUID userId;
    @Column(nullable = false, length = 12) private String platform;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    protected PushToken() {}
    public PushToken(String token, UUID userId, String platform) {
        this.token = token;
        this.userId = userId;
        this.platform = platform;
        this.updatedAt = Instant.now();
    }
    public String getToken() { return token; }
    public UUID getUserId() { return userId; }
    public String getPlatform() { return platform; }
    public Instant getUpdatedAt() { return updatedAt; }
}
