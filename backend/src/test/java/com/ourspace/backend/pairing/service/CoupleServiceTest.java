package com.ourspace.backend.pairing.service;

import com.ourspace.backend.common.exception.CoupleNotFoundException;
import com.ourspace.backend.common.exception.UnpairingPolicyPendingException;
import com.ourspace.backend.identity.entity.UserEntity;
import com.ourspace.backend.pairing.dto.CoupleResponse;
import com.ourspace.backend.pairing.entity.CoupleEntity;
import com.ourspace.backend.pairing.entity.CoupleMemberEntity;
import com.ourspace.backend.pairing.entity.CoupleStatus;
import com.ourspace.backend.pairing.repository.CoupleMemberRepository;
import com.ourspace.backend.pairing.repository.CoupleRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CoupleServiceTest {

    @Mock
    private CoupleRepository coupleRepository;

    @Mock
    private CoupleMemberRepository coupleMemberRepository;

    private CoupleService coupleService;
    private final UUID userId = UUID.randomUUID();
    private final UUID partnerId = UUID.randomUUID();
    private final UUID coupleId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        coupleService = new CoupleService(coupleRepository, coupleMemberRepository);
    }

    @Test
    @DisplayName("Get current couple returns active couple and members")
    void shouldGetCurrentCoupleSuccessfully() {
        CoupleEntity couple = new CoupleEntity(coupleId, CoupleStatus.ACTIVE);
        UserEntity u1 = new UserEntity(userId, "u1@example.com", "hash1", "User 1");
        UserEntity u2 = new UserEntity(partnerId, "u2@example.com", "hash2", "User 2");

        CoupleMemberEntity m1 = new CoupleMemberEntity(couple, u1, "MEMBER");
        CoupleMemberEntity m2 = new CoupleMemberEntity(couple, u2, "MEMBER");

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(coupleMemberRepository.findByIdCoupleIdAndLeftAtIsNull(coupleId)).thenReturn(List.of(m1, m2));

        CoupleResponse response = coupleService.getCurrentCouple(userId);

        assertNotNull(response);
        assertEquals(coupleId, response.getId());
        assertEquals(2, response.getMembers().size());
    }

    @Test
    @DisplayName("Get current couple throws 404 when user is not paired")
    void shouldThrowWhenNotPaired() {
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.empty());

        CoupleNotFoundException ex = assertThrows(CoupleNotFoundException.class,
                () -> coupleService.getCurrentCouple(userId));
        assertEquals("COUPLE_NOT_FOUND", ex.getCode());
    }

    @Test
    @DisplayName("Unpair throws UnpairingPolicyPendingException under OD-03 governance")
    void shouldThrowUnpairingPolicyPending() {
        CoupleEntity couple = new CoupleEntity(coupleId, CoupleStatus.ACTIVE);
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));

        UnpairingPolicyPendingException ex = assertThrows(UnpairingPolicyPendingException.class,
                () -> coupleService.unpair(userId));
        assertEquals("UNPAIRING_POLICY_PENDING", ex.getCode());
    }
}
