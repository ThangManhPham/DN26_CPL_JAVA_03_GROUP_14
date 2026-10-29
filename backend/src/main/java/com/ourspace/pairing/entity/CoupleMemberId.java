package com.ourspace.pairing.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class CoupleMemberId implements Serializable {

    @Column(name = "couple_id", nullable = false)
    private UUID coupleId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    public CoupleMemberId() {
    }

    public CoupleMemberId(UUID coupleId, UUID userId) {
        this.coupleId = coupleId;
        this.userId = userId;
    }

    public UUID getCoupleId() {
        return coupleId;
    }

    public void setCoupleId(UUID coupleId) {
        this.coupleId = coupleId;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        CoupleMemberId that = (CoupleMemberId) o;
        return Objects.equals(coupleId, that.coupleId) && Objects.equals(userId, that.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(coupleId, userId);
    }
}
