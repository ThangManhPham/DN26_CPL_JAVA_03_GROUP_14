package com.ourspace.backend.pairing.controller;

import com.ourspace.backend.common.security.SecurityUtils;
import com.ourspace.backend.pairing.dto.CoupleResponse;
import com.ourspace.backend.pairing.service.CoupleService;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/couples")
public class CoupleController {

    private final CoupleService coupleService;

    public CoupleController(CoupleService coupleService) {
        this.coupleService = coupleService;
    }

    @GetMapping("/me")
    public ResponseEntity<CoupleResponse> getMyCouple() {
        UUID userId = SecurityUtils.getCurrentUserId();
        CoupleResponse response = coupleService.getCurrentCouple(userId);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/me")
    public ResponseEntity<Void> unpairMyCouple() {
        UUID userId = SecurityUtils.getCurrentUserId();
        coupleService.unpair(userId);
        return ResponseEntity.noContent().build();
    }
}
