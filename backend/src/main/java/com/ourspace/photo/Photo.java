package com.ourspace.photo;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "photos")
public class Photo {
    @Id private UUID id;
    @Column(name = "couple_id", nullable = false) private UUID coupleId;
    @Column(name = "sender_id", nullable = false) private UUID senderId;
    @Column(name = "client_request_id", nullable = false) private UUID clientRequestId;
    @Column(name = "storage_key", nullable = false) private String storageKey;
    @Column(name = "mime_type", nullable = false) private String mimeType;
    @Column(name = "size_bytes", nullable = false) private long sizeBytes;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    protected Photo() {}
    public Photo(UUID id, UUID coupleId, UUID senderId, UUID clientRequestId,
                 String storageKey, String mimeType, long sizeBytes) {
        this.id = id;
        this.coupleId = coupleId;
        this.senderId = senderId;
        this.clientRequestId = clientRequestId;
        this.storageKey = storageKey;
        this.mimeType = mimeType;
        this.sizeBytes = sizeBytes;
        this.createdAt = Instant.now();
    }
    public UUID getId() { return id; }
    public UUID getCoupleId() { return coupleId; }
    public UUID getSenderId() { return senderId; }
    public UUID getClientRequestId() { return clientRequestId; }
    public String getStorageKey() { return storageKey; }
    public String getMimeType() { return mimeType; }
    public long getSizeBytes() { return sizeBytes; }
    public Instant getCreatedAt() { return createdAt; }
}
