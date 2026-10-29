package com.ourspace.pairing.service;

import com.ourspace.pairing.dto.CoupleMemberResponse;
import com.ourspace.pairing.dto.CoupleResponse;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.exception.CoupleNotFoundException;
import com.ourspace.pairing.exception.UnpairingPolicyPendingException;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CoupleService {

    private static final Logger log = LoggerFactory.getLogger(CoupleService.class);

    private final CoupleRepository coupleRepository;
    private final CoupleMemberRepository coupleMemberRepository;

    public CoupleService(CoupleRepository coupleRepository, CoupleMemberRepository coupleMemberRepository) {
        this.coupleRepository = coupleRepository;
        this.coupleMemberRepository = coupleMemberRepository;
    }

    @Transactional(readOnly = true)
    public CoupleResponse getCurrentCouple(UUID userId) {
        CoupleEntity couple = coupleRepository.findActiveCoupleByUserId(userId)
                .orElseThrow(() -> new CoupleNotFoundException("Người dùng hiện không thuộc cặp đôi nào đang hoạt động."));

        List<CoupleMemberEntity> activeMembers = coupleMemberRepository.findByIdCoupleIdAndLeftAtIsNull(couple.getId());

        List<CoupleMemberResponse> memberResponses = activeMembers.stream()
                .map(m -> new CoupleMemberResponse(
                        m.getUser().getId(),
                        m.getUser().getDisplayName(),
                        m.getUser().getEmail(),
                        m.getRole(),
                        m.getJoinedAt()
                ))
                .toList();

        return new CoupleResponse(
                couple.getId(),
                couple.getStatus(),
                couple.getAnniversaryDate(),
                memberResponses,
                couple.getCreatedAt()
        );
    }

    /**
     * Unpair request handler.
     * Blocked pending approval of Unpairing Policy OD-03 (docs/12-open-decisions.md).
     */
    @Transactional
    public void unpair(UUID userId) {
        // Verify current active couple exists for security check
        coupleRepository.findActiveCoupleByUserId(userId)
                .orElseThrow(() -> new CoupleNotFoundException("Người dùng hiện không thuộc cặp đôi nào đang hoạt động."));

        log.warn("Unpair endpoint accessed by user {}. Operation blocked pending OD-03 policy.", userId);
        throw new UnpairingPolicyPendingException(
                "Chức năng hủy ghép đôi đang tạm dừng chờ phê duyệt chính sách lưu trữ và xử lý dữ liệu (OD-03)."
        );
    }
}
