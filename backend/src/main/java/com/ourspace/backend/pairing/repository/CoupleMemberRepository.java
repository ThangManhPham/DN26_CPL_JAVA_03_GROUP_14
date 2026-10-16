package com.ourspace.backend.pairing.repository;

import com.ourspace.backend.pairing.entity.CoupleMemberEntity;
import com.ourspace.backend.pairing.entity.CoupleMemberId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CoupleMemberRepository extends JpaRepository<CoupleMemberEntity, CoupleMemberId> {

    boolean existsByIdUserIdAndLeftAtIsNull(UUID userId);

    Optional<CoupleMemberEntity> findByIdUserIdAndLeftAtIsNull(UUID userId);

    List<CoupleMemberEntity> findByIdCoupleIdAndLeftAtIsNull(UUID coupleId);
}
