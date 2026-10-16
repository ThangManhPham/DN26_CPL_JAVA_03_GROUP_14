package com.ourspace.backend.pairing.repository;

import com.ourspace.backend.pairing.entity.CoupleEntity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface CoupleRepository extends JpaRepository<CoupleEntity, UUID> {

    @Query("SELECT cm.couple FROM CoupleMemberEntity cm " +
           "WHERE cm.id.userId = :userId AND cm.leftAt IS NULL AND cm.couple.status = 'ACTIVE'")
    Optional<CoupleEntity> findActiveCoupleByUserId(@Param("userId") UUID userId);
}
