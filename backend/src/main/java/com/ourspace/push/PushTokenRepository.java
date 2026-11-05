package com.ourspace.push;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface PushTokenRepository extends JpaRepository<PushToken, String> {
    List<PushToken> findByUserId(UUID userId);
    @Transactional
    long deleteByTokenAndUserId(String token, UUID userId);
}
