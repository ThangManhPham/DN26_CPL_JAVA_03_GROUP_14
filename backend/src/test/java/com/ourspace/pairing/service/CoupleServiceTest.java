package com.ourspace.pairing.service;

import com.ourspace.identity.entity.User;
import com.ourspace.pairing.dto.CoupleResponse;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.exception.CoupleNotFoundException;
import com.ourspace.pairing.exception.UnpairingPolicyPendingException;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
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
    private final UUID coupleId = UUID.randomUUID();
    private User u1;
    private User u2;

    @BeforeEach
    void setUp() {
        coupleService = new CoupleService(coupleRepository, coupleMemberRepository);
        u1 = new User("u1@example.com", "hash1", "User 1");
        u2 = new User("u2@example.com", "hash2", "User 2");
    }

    @Test
    @DisplayName("Get current couple returns active couple and members")
    void shouldGetCurrentCoupleSuccessfully() {
        CoupleEntity couple = new CoupleEntity(coupleId, CoupleStatus.ACTIVE);
        CoupleMemberEntity m1 = new CoupleMemberEntity(couple, u1, "MEMBER");
        CoupleMemberEntity m2 = new CoupleMemberEntity(couple, u2, "MEMBER");

        when(coupleRepository.findActiveCoupleByUserId(u1.getId())).thenReturn(Optional.of(couple));
        when(coupleMemberRepository.findByIdCoupleIdAndLeftAtIsNull(coupleId)).thenReturn(List.of(m1, m2));

        CoupleResponse response = coupleService.getCurrentCouple(u1.getId());

        assertNotNull(response);
        assertEquals(coupleId, response.getId());
        assertEquals(2, response.getMembers().size());
    }

    @Test
    @DisplayName("Get current couple throws 404 when user is not paired")
    void shouldThrowWhenNotPaired() {
        when(coupleRepository.findActiveCoupleByUserId(u1.getId())).thenReturn(Optional.empty());

        CoupleNotFoundException ex = assertThrows(CoupleNotFoundException.class,
                () -> coupleService.getCurrentCouple(u1.getId()));
        assertEquals("COUPLE_NOT_FOUND", ex.code());
    }

    @Test
    @DisplayName("Unpair throws UnpairingPolicyPendingException under OD-03 governance")
    void shouldThrowUnpairingPolicyPending() {
        CoupleEntity couple = new CoupleEntity(coupleId, CoupleStatus.ACTIVE);
        when(coupleRepository.findActiveCoupleByUserId(u1.getId())).thenReturn(Optional.of(couple));

        UnpairingPolicyPendingException ex = assertThrows(UnpairingPolicyPendingException.class,
                () -> coupleService.unpair(u1.getId()));
        assertEquals("UNPAIRING_POLICY_PENDING", ex.code());
    }
}
