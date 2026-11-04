package com.ourspace.couplespace.repository;

import com.ourspace.couplespace.entity.CoupleEvent;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.domain.*;
import java.time.Instant;
import java.util.*;

public interface EventRepository extends JpaRepository<CoupleEvent,UUID> {
    Optional<CoupleEvent> findByIdAndCoupleId(UUID id, UUID coupleId);
    @Query("select e from CoupleEvent e where e.coupleId=:coupleId and e.startsAt < :until and e.endsAt > :from order by e.startsAt, e.id")
    Slice<CoupleEvent> inRange(UUID coupleId, Instant from, Instant until, Pageable pageable);
}
