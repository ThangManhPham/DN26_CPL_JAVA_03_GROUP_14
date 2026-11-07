package com.ourspace.couplespace.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
import com.ourspace.couplespace.dto.EventRequest;

@Entity
@Table(name="couple_events")
public class CoupleEvent {
    @Id public UUID id;
    @Column(name="couple_id",nullable=false) public UUID coupleId;
    @Column(name="created_by",nullable=false) public UUID createdBy;
    @Column(nullable=false,length=150) public String title;
    @Column(length=2000) public String description;
    @Column(name="starts_at",nullable=false) public Instant startsAt;
    @Column(name="ends_at",nullable=false) public Instant endsAt;
    @Column(nullable=false,length=64) public String timezone;
    @Version public long version;
    @Column(name="created_at",nullable=false) public Instant createdAt;
    @Column(name="updated_at",nullable=false) public Instant updatedAt;

    public CoupleEvent() {}
    public CoupleEvent(UUID coupleId, UUID userId, EventRequest data, Instant now) {
        id=UUID.randomUUID(); this.coupleId=coupleId; createdBy=userId; createdAt=now;
        apply(data, now);
    }
    public void apply(EventRequest data, Instant now) {
        title=data.title().strip(); description=data.description();
        startsAt=data.startsAt(); endsAt=data.endsAt(); timezone=data.timezone(); updatedAt=now;
    }
}
