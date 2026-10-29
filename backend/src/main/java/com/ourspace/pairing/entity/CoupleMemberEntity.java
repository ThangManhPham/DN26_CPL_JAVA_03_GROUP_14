package com.ourspace.pairing.entity;

import com.ourspace.identity.entity.User;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "couple_members")
public class CoupleMemberEntity {

    @EmbeddedId
    private CoupleMemberId id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @MapsId("coupleId")
    @JoinColumn(name = "couple_id", nullable = false)
    private CoupleEntity couple;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @MapsId("userId")
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "role", nullable = false, length = 20)
    private String role = "MEMBER";

    @Column(name = "joined_at", nullable = false, updatable = false)
    private Instant joinedAt;

    @Column(name = "left_at")
    private Instant leftAt;

    public CoupleMemberEntity() {
    }

    public CoupleMemberEntity(CoupleEntity couple, User user, String role) {
        this.couple = couple;
        this.user = user;
        this.role = role != null ? role : "MEMBER";
        this.id = new CoupleMemberId(couple.getId(), user.getId());
    }

    @PrePersist
    protected void onCreate() {
        if (id == null && couple != null && user != null) {
            id = new CoupleMemberId(couple.getId(), user.getId());
        }
        if (joinedAt == null) {
            joinedAt = Instant.now();
        }
    }

    public CoupleMemberId getId() {
        return id;
    }

    public void setId(CoupleMemberId id) {
        this.id = id;
    }

    public CoupleEntity getCouple() {
        return couple;
    }

    public void setCouple(CoupleEntity couple) {
        this.couple = couple;
        if (couple != null && this.id != null) {
            this.id.setCoupleId(couple.getId());
        }
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
        if (user != null && this.id != null) {
            this.id.setUserId(user.getId());
        }
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public Instant getJoinedAt() {
        return joinedAt;
    }

    public void setJoinedAt(Instant joinedAt) {
        this.joinedAt = joinedAt;
    }

    public Instant getLeftAt() {
        return leftAt;
    }

    public void setLeftAt(Instant leftAt) {
        this.leftAt = leftAt;
    }
}
