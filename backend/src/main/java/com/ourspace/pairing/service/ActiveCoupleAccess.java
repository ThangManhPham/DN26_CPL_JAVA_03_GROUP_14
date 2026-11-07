package com.ourspace.pairing.service;

import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.common.exception.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;

/** Public module boundary for features needing current active membership. */
@Service
public class ActiveCoupleAccess {
    private final CoupleRepository couples;
    public ActiveCoupleAccess(CoupleRepository couples) { this.couples=couples; }
    @Transactional(readOnly=true)
    public CoupleEntity require(UUID userId) {
        return couples.findActiveCoupleByUserId(userId).orElseThrow(() ->
            new ApiException(HttpStatus.NOT_FOUND,"COUPLE_NOT_FOUND","You do not belong to an active couple."));
    }
}
