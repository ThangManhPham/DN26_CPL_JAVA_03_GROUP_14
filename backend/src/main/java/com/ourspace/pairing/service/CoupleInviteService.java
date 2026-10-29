package com.ourspace.pairing.service;

import com.ourspace.common.exception.ApiException;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.dto.CoupleMemberResponse;
import com.ourspace.pairing.dto.CoupleResponse;
import com.ourspace.pairing.dto.CreateInviteResponse;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleInviteEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.entity.InviteStatus;
import com.ourspace.pairing.exception.AlreadyPairedException;
import com.ourspace.pairing.exception.InvalidInviteCodeException;
import com.ourspace.pairing.exception.InviteExpiredException;
import com.ourspace.pairing.exception.InviterAlreadyPairedException;
import com.ourspace.pairing.exception.SelfPairingException;
import com.ourspace.pairing.repository.CoupleInviteRepository;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CoupleInviteService {

    private static final Logger log = LoggerFactory.getLogger(CoupleInviteService.class);

    private final CoupleInviteRepository inviteRepository;
    private final CoupleRepository coupleRepository;
    private final CoupleMemberRepository coupleMemberRepository;
    private final UserRepository userRepository;
    private final InviteCodeService inviteCodeService;
    private final int inviteTtlHours;

    public CoupleInviteService(
            CoupleInviteRepository inviteRepository,
            CoupleRepository coupleRepository,
            CoupleMemberRepository coupleMemberRepository,
            UserRepository userRepository,
            InviteCodeService inviteCodeService,
            @Value("${ourspace.pairing.invite-ttl-hours:24}") int inviteTtlHours
    ) {
        this.inviteRepository = inviteRepository;
        this.coupleRepository = coupleRepository;
        this.coupleMemberRepository = coupleMemberRepository;
        this.userRepository = userRepository;
        this.inviteCodeService = inviteCodeService;
        this.inviteTtlHours = inviteTtlHours;
    }

    @Transactional
    public CreateInviteResponse createInvite(UUID inviterId) {
        // 1. Check if inviter is already in an active couple
        if (coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(inviterId)) {
            throw new AlreadyPairedException("Bạn đã tham gia một cặp đôi đang hoạt động.");
        }

        User inviter = userRepository.findById(inviterId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Người dùng không tồn tại."));

        // 2. Invalidate / revoke any prior pending invites for this inviter
        List<CoupleInviteEntity> existingPending = inviteRepository.findByInviterIdAndStatus(inviterId, InviteStatus.PENDING);
        for (CoupleInviteEntity pending : existingPending) {
            pending.setStatus(InviteStatus.REVOKED);
            inviteRepository.save(pending);
        }

        // 3. Generate secure code and store only hash
        String rawCode = inviteCodeService.generateCode();
        String codeHash = inviteCodeService.hashCode(rawCode);
        Instant expiresAt = Instant.now().plus(Duration.ofHours(inviteTtlHours));

        CoupleInviteEntity invite = new CoupleInviteEntity(inviter, codeHash, expiresAt);
        inviteRepository.save(invite);

        // Security requirement: Plaintext code must NOT be logged
        log.info("Invite code generated successfully for user: {}, expiresAt: {}", inviterId, expiresAt);

        return new CreateInviteResponse(rawCode, expiresAt);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public CoupleResponse acceptInvite(UUID joinerId, String rawCode) {
        if (rawCode == null || rawCode.isBlank()) {
            throw new InvalidInviteCodeException("Mã ghép đôi không hợp lệ.");
        }

        // 1. Verify joiner does not already belong to an active couple
        if (coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(joinerId)) {
            throw new AlreadyPairedException("Bạn đã tham gia một cặp đôi đang hoạt động.");
        }

        User joiner = userRepository.findById(joinerId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Người dùng không tồn tại."));

        String codeHash = inviteCodeService.hashCode(rawCode);

        // 2. Lock invite row for update
        CoupleInviteEntity invite = inviteRepository.findFirstByCodeHashAndStatusForUpdate(codeHash, InviteStatus.PENDING)
                .orElseThrow(() -> new InvalidInviteCodeException("Mã ghép đôi không tồn tại hoặc đã được sử dụng."));

        // 3. Check expiration
        if (invite.getExpiresAt().isBefore(Instant.now())) {
            invite.setStatus(InviteStatus.EXPIRED);
            inviteRepository.save(invite);
            throw new InviteExpiredException("Mã ghép đôi đã hết hạn.");
        }

        // 4. Prevent self-pairing
        User inviter = invite.getInviter();
        if (inviter.getId().equals(joinerId)) {
            throw new SelfPairingException("Không thể tự ghép đôi với chính mình.");
        }

        // 5. Verify inviter is still free of active couples
        if (coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(inviter.getId())) {
            throw new InviterAlreadyPairedException("Người gửi mã đã thuộc về một cặp đôi khác.");
        }

        // 6. Atomically create Couple and Memberships
        CoupleEntity couple = new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE);
        couple = coupleRepository.save(couple);

        CoupleMemberEntity memberInviter = new CoupleMemberEntity(couple, inviter, "MEMBER");
        CoupleMemberEntity memberJoiner = new CoupleMemberEntity(couple, joiner, "MEMBER");

        coupleMemberRepository.save(memberInviter);
        coupleMemberRepository.save(memberJoiner);

        // 7. Mark invite as ACCEPTED
        invite.setStatus(InviteStatus.ACCEPTED);
        invite.setAcceptedBy(joiner);
        invite.setAcceptedAt(Instant.now());
        inviteRepository.save(invite);

        log.info("Couple paired successfully: coupleId={}, user1={}, user2={}", couple.getId(), inviter.getId(), joiner.getId());

        List<CoupleMemberResponse> memberResponses = List.of(
                new CoupleMemberResponse(inviter.getId(), inviter.getDisplayName(), inviter.getEmail(), memberInviter.getRole(), memberInviter.getJoinedAt()),
                new CoupleMemberResponse(joiner.getId(), joiner.getDisplayName(), joiner.getEmail(), memberJoiner.getRole(), memberJoiner.getJoinedAt())
        );

        return new CoupleResponse(
                couple.getId(),
                couple.getStatus(),
                couple.getAnniversaryDate(),
                memberResponses,
                couple.getCreatedAt()
        );
    }
}
