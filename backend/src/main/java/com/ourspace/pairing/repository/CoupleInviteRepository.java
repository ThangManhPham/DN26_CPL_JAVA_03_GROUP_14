package com.ourspace.pairing.repository;

import com.ourspace.pairing.entity.CoupleInviteEntity;
import com.ourspace.pairing.entity.InviteStatus;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface CoupleInviteRepository extends JpaRepository<CoupleInviteEntity, UUID> {

    Optional<CoupleInviteEntity> findFirstByCodeHashAndStatus(String codeHash, InviteStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM CoupleInviteEntity i WHERE i.codeHash = :codeHash AND i.status = :status")
    Optional<CoupleInviteEntity> findFirstByCodeHashAndStatusForUpdate(
            @Param("codeHash") String codeHash,
            @Param("status") InviteStatus status
    );

    List<CoupleInviteEntity> findByInviterIdAndStatus(UUID inviterId, InviteStatus status);
}
