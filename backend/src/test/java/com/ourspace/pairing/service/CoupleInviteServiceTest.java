package com.ourspace.pairing.service;

import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.dto.CoupleResponse;
import com.ourspace.pairing.dto.CreateInviteResponse;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleInviteEntity;
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
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CoupleInviteServiceTest {

    @Mock
    private CoupleInviteRepository inviteRepository;

    @Mock
    private CoupleRepository coupleRepository;

    @Mock
    private CoupleMemberRepository coupleMemberRepository;

    @Mock
    private UserRepository userRepository;

    private InviteCodeService inviteCodeService;
    private CoupleInviteService inviteService;

    private User user1;
    private User user2;
    private UUID user1Id;
    private UUID user2Id;

    @BeforeEach
    void setUp() {
        inviteCodeService = new InviteCodeService(6);
        inviteService = new CoupleInviteService(
                inviteRepository,
                coupleRepository,
                coupleMemberRepository,
                userRepository,
                inviteCodeService,
                24
        );

        user1 = new User("alex@example.com", "hash1", "Alex");
        user2 = new User("sam@example.com", "hash2", "Sam");
        user1Id = user1.getId();
        user2Id = user2.getId();
    }

    @Test
    @DisplayName("Create invite successfully when user has no active couple")
    void shouldCreateInviteSuccessfully() {
        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user1Id)).thenReturn(false);
        when(userRepository.findById(user1Id)).thenReturn(Optional.of(user1));
        when(inviteRepository.findByInviterIdAndStatus(user1Id, InviteStatus.PENDING)).thenReturn(List.of());
        when(inviteRepository.save(any(CoupleInviteEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CreateInviteResponse response = inviteService.createInvite(user1Id);

        assertNotNull(response);
        assertNotNull(response.getInviteCode());
        assertEquals(6, response.getInviteCode().length());
        assertTrue(response.getExpiresAt().isAfter(Instant.now()));
        verify(inviteRepository, times(1)).save(any(CoupleInviteEntity.class));
    }

    @Test
    @DisplayName("Create invite fails if user is already in an active couple")
    void shouldFailCreateInviteWhenAlreadyPaired() {
        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user1Id)).thenReturn(true);

        AlreadyPairedException ex = assertThrows(AlreadyPairedException.class,
                () -> inviteService.createInvite(user1Id));
        assertEquals("ALREADY_PAIRED", ex.code());
        verify(inviteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Accept invite successfully pairs two users into an active couple")
    void shouldAcceptInviteSuccessfully() {
        String code = "K7P4R8";
        String hash = inviteCodeService.hashCode(code);
        CoupleInviteEntity invite = new CoupleInviteEntity(user1, hash, Instant.now().plus(2, ChronoUnit.HOURS));

        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user2Id)).thenReturn(false);
        when(userRepository.findById(user2Id)).thenReturn(Optional.of(user2));
        when(inviteRepository.findFirstByCodeHashAndStatusForUpdate(eq(hash), eq(InviteStatus.PENDING)))
                .thenReturn(Optional.of(invite));
        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user1Id)).thenReturn(false);
        when(coupleRepository.save(any(CoupleEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CoupleResponse response = inviteService.acceptInvite(user2Id, code);

        assertNotNull(response);
        assertEquals(CoupleStatus.ACTIVE, response.getStatus());
        assertEquals(2, response.getMembers().size());
        assertEquals(InviteStatus.ACCEPTED, invite.getStatus());
        assertEquals(user2, invite.getAcceptedBy());
        assertNotNull(invite.getAcceptedAt());

        verify(coupleRepository, times(1)).save(any());
        verify(coupleMemberRepository, times(2)).save(any());
        verify(inviteRepository, times(1)).save(invite);
    }

    @Test
    @DisplayName("Accept invite fails with 400 when user tries self-pairing")
    void shouldFailWhenSelfPairing() {
        String code = "K7P4R8";
        String hash = inviteCodeService.hashCode(code);
        CoupleInviteEntity invite = new CoupleInviteEntity(user1, hash, Instant.now().plus(2, ChronoUnit.HOURS));

        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user1Id)).thenReturn(false);
        when(userRepository.findById(user1Id)).thenReturn(Optional.of(user1));
        when(inviteRepository.findFirstByCodeHashAndStatusForUpdate(eq(hash), eq(InviteStatus.PENDING)))
                .thenReturn(Optional.of(invite));

        SelfPairingException ex = assertThrows(SelfPairingException.class,
                () -> inviteService.acceptInvite(user1Id, code));
        assertEquals("CANNOT_PAIR_SELF", ex.code());
    }

    @Test
    @DisplayName("Accept invite fails when code has expired")
    void shouldFailWhenInviteExpired() {
        String code = "K7P4R8";
        String hash = inviteCodeService.hashCode(code);
        CoupleInviteEntity invite = new CoupleInviteEntity(user1, hash, Instant.now().minus(2, ChronoUnit.HOURS));

        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user2Id)).thenReturn(false);
        when(userRepository.findById(user2Id)).thenReturn(Optional.of(user2));
        when(inviteRepository.findFirstByCodeHashAndStatusForUpdate(eq(hash), eq(InviteStatus.PENDING)))
                .thenReturn(Optional.of(invite));

        InviteExpiredException ex = assertThrows(InviteExpiredException.class,
                () -> inviteService.acceptInvite(user2Id, code));
        assertEquals("INVITE_EXPIRED", ex.code());
        assertEquals(InviteStatus.EXPIRED, invite.getStatus());
        verify(inviteRepository, times(1)).save(invite);
    }

    @Test
    @DisplayName("Accept invite fails when joiner already has an active couple")
    void shouldFailWhenJoinerAlreadyPaired() {
        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user2Id)).thenReturn(true);

        AlreadyPairedException ex = assertThrows(AlreadyPairedException.class,
                () -> inviteService.acceptInvite(user2Id, "K7P4R8"));
        assertEquals("ALREADY_PAIRED", ex.code());
    }

    @Test
    @DisplayName("Accept invite fails when inviter was paired elsewhere in the meantime")
    void shouldFailWhenInviterAlreadyPaired() {
        String code = "K7P4R8";
        String hash = inviteCodeService.hashCode(code);
        CoupleInviteEntity invite = new CoupleInviteEntity(user1, hash, Instant.now().plus(2, ChronoUnit.HOURS));

        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user2Id)).thenReturn(false);
        when(userRepository.findById(user2Id)).thenReturn(Optional.of(user2));
        when(inviteRepository.findFirstByCodeHashAndStatusForUpdate(eq(hash), eq(InviteStatus.PENDING)))
                .thenReturn(Optional.of(invite));
        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user1Id)).thenReturn(true);

        InviterAlreadyPairedException ex = assertThrows(InviterAlreadyPairedException.class,
                () -> inviteService.acceptInvite(user2Id, code));
        assertEquals("INVITER_ALREADY_PAIRED", ex.code());
    }

    @Test
    @DisplayName("Accept invite fails when code is non-existent or wrong")
    void shouldFailWhenCodeNotFound() {
        String code = "WRONG1";
        String hash = inviteCodeService.hashCode(code);

        when(coupleMemberRepository.existsByIdUserIdAndLeftAtIsNull(user2Id)).thenReturn(false);
        when(userRepository.findById(user2Id)).thenReturn(Optional.of(user2));
        when(inviteRepository.findFirstByCodeHashAndStatusForUpdate(eq(hash), eq(InviteStatus.PENDING)))
                .thenReturn(Optional.empty());

        InvalidInviteCodeException ex = assertThrows(InvalidInviteCodeException.class,
                () -> inviteService.acceptInvite(user2Id, code));
        assertEquals("INVALID_INVITE_CODE", ex.code());
    }
}
