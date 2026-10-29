package com.ourspace.pairing;

import com.ourspace.common.exception.ApiException;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.dto.CreateInviteResponse;
import com.ourspace.pairing.repository.CoupleInviteRepository;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.pairing.service.CoupleInviteService;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
class PairingConcurrencyTest {

    @Autowired
    private CoupleInviteService coupleInviteService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CoupleRepository coupleRepository;

    @Autowired
    private CoupleMemberRepository coupleMemberRepository;

    @Autowired
    private CoupleInviteRepository inviteRepository;

    private User userA;
    private User userB;
    private User userC;

    @BeforeEach
    void setUp() {
        coupleMemberRepository.deleteAll();
        inviteRepository.deleteAll();
        coupleRepository.deleteAll();
        userRepository.deleteAll();

        userA = userRepository.save(new User("alex@test.com", "hashA", "Alex"));
        userB = userRepository.save(new User("sam@test.com", "hashB", "Sam"));
        userC = userRepository.save(new User("charlie@test.com", "hashC", "Charlie"));
    }

    @Test
    @DisplayName("Concurrency: Two threads accept the same invite simultaneously -> Exactly 1 succeeds, 1 fails")
    void shouldPreventDoubleAcceptanceRaceCondition() throws Exception {
        CreateInviteResponse invite = coupleInviteService.createInvite(userA.getId());
        String code = invite.getInviteCode();

        int numberOfThreads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(numberOfThreads);
        CountDownLatch readyLatch = new CountDownLatch(numberOfThreads);
        CountDownLatch startLatch = new CountDownLatch(1);

        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failureCount = new AtomicInteger(0);

        // Thread 1: User B tries to accept
        executor.submit(() -> {
            readyLatch.countDown();
            try {
                startLatch.await();
                coupleInviteService.acceptInvite(userB.getId(), code);
                successCount.incrementAndGet();
            } catch (ApiException | DataIntegrityViolationException e) {
                failureCount.incrementAndGet();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        // Thread 2: User C tries to accept the same code
        executor.submit(() -> {
            readyLatch.countDown();
            try {
                startLatch.await();
                coupleInviteService.acceptInvite(userC.getId(), code);
                successCount.incrementAndGet();
            } catch (ApiException | DataIntegrityViolationException e) {
                failureCount.incrementAndGet();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        // Ensure both threads are ready, then unleash simultaneously
        readyLatch.await(5, TimeUnit.SECONDS);
        startLatch.countDown();

        executor.shutdown();
        assertTrue(executor.awaitTermination(10, TimeUnit.SECONDS));

        // Exactly one pair succeeds, the other fails
        assertEquals(1, successCount.get(), "Exactly one join attempt must succeed");
        assertEquals(1, failureCount.get(), "Exactly one join attempt must fail");

        // Verify database state: exactly 1 couple exists with 2 members
        assertEquals(1, coupleRepository.count());
        assertEquals(2, coupleMemberRepository.count());
    }

    @Test
    @DisplayName("Concurrency: Prevent same user from joining two different couples simultaneously")
    void shouldPreventOneUserFromJoiningTwoCouplesConcurrently() throws Exception {
        // User A creates Invite 1
        CreateInviteResponse invite1 = coupleInviteService.createInvite(userA.getId());
        // User B creates Invite 2
        CreateInviteResponse invite2 = coupleInviteService.createInvite(userB.getId());

        int numberOfThreads = 2;
        ExecutorService executor = Executors.newFixedThreadPool(numberOfThreads);
        CountDownLatch readyLatch = new CountDownLatch(numberOfThreads);
        CountDownLatch startLatch = new CountDownLatch(1);

        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failureCount = new AtomicInteger(0);

        // Thread 1: User C tries to join Invite 1
        executor.submit(() -> {
            readyLatch.countDown();
            try {
                startLatch.await();
                coupleInviteService.acceptInvite(userC.getId(), invite1.getInviteCode());
                successCount.incrementAndGet();
            } catch (ApiException | DataIntegrityViolationException e) {
                failureCount.incrementAndGet();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        // Thread 2: User C tries to join Invite 2 concurrently
        executor.submit(() -> {
            readyLatch.countDown();
            try {
                startLatch.await();
                coupleInviteService.acceptInvite(userC.getId(), invite2.getInviteCode());
                successCount.incrementAndGet();
            } catch (ApiException | DataIntegrityViolationException e) {
                failureCount.incrementAndGet();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        readyLatch.await(5, TimeUnit.SECONDS);
        startLatch.countDown();

        executor.shutdown();
        assertTrue(executor.awaitTermination(10, TimeUnit.SECONDS));

        // User C must end up in at most 1 couple
        assertEquals(1, successCount.get(), "User C can only join 1 couple");
        assertEquals(1, failureCount.get(), "The other concurrent join must fail");

        // DB partial unique constraint ensures User C has strictly 1 active membership
        assertEquals(1, coupleMemberRepository.findByIdUserIdAndLeftAtIsNull(userC.getId()).stream().count());
    }
}
