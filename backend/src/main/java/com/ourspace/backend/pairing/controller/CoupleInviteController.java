package com.ourspace.backend.pairing.controller;

import com.ourspace.backend.common.security.SecurityUtils;
import com.ourspace.backend.pairing.dto.CoupleResponse;
import com.ourspace.backend.pairing.dto.CreateInviteResponse;
import com.ourspace.backend.pairing.dto.JoinCoupleRequest;
import com.ourspace.backend.pairing.service.CoupleInviteService;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class CoupleInviteController {

    private final CoupleInviteService coupleInviteService;

    public CoupleInviteController(CoupleInviteService coupleInviteService) {
        this.coupleInviteService = coupleInviteService;
    }

    @PostMapping("/couple-invites")
    public ResponseEntity<CreateInviteResponse> createInvite() {
        UUID inviterId = SecurityUtils.getCurrentUserId();
        CreateInviteResponse response = coupleInviteService.createInvite(inviterId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/couples/join")
    public ResponseEntity<CoupleResponse> joinCouple(@Valid @RequestBody JoinCoupleRequest request) {
        UUID joinerId = SecurityUtils.getCurrentUserId();
        CoupleResponse response = coupleInviteService.acceptInvite(joinerId, request.getInviteCode());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}
