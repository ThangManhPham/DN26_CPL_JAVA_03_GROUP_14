package com.ourspace.pairing;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.dto.JoinCoupleRequest;
import com.ourspace.pairing.entity.CoupleInviteEntity;
import com.ourspace.pairing.repository.CoupleInviteRepository;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.pairing.service.InviteCodeService;
import com.ourspace.security.TokenService;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class PairingIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CoupleRepository coupleRepository;

    @Autowired
    private CoupleMemberRepository coupleMemberRepository;

    @Autowired
    private CoupleInviteRepository inviteRepository;

    @Autowired
    private InviteCodeService inviteCodeService;

    @Autowired
    private TokenService tokenService;

    private User userA;
    private User userB;
    private User userC;

    private String tokenA;
    private String tokenB;
    private String tokenC;

    @BeforeEach
    void setUp() {
        coupleMemberRepository.deleteAll();
        inviteRepository.deleteAll();
        coupleRepository.deleteAll();
        userRepository.deleteAll();

        userA = userRepository.save(new User("alex@example.com", "hashA", "Alex"));
        userB = userRepository.save(new User("sam@example.com", "hashB", "Sam"));
        userC = userRepository.save(new User("charlie@example.com", "hashC", "Charlie"));

        tokenA = tokenService.issue(userA.getId());
        tokenB = tokenService.issue(userB.getId());
        tokenC = tokenService.issue(userC.getId());
    }

    @Test
    @DisplayName("Unauthenticated request to pairing endpoints should return 401")
    void shouldReturn401WhenUnauthenticated() throws Exception {
        mockMvc.perform(post("/api/v1/couple-invites"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code", is("UNAUTHORIZED")));

        mockMvc.perform(post("/api/v1/couples/join")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"inviteCode\":\"TEST12\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code", is("UNAUTHORIZED")));

        mockMvc.perform(get("/api/v1/couples/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code", is("UNAUTHORIZED")));
    }

    @Test
    @DisplayName("Full successful pairing flow: User A generates invite, User B joins, both get couple")
    void shouldCompletePairingFlowSuccessfully() throws Exception {
        // 1. User A generates invite
        String inviteJson = mockMvc.perform(post("/api/v1/couple-invites")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.inviteCode", notNullValue()))
                .andExpect(jsonPath("$.expiresAt", notNullValue()))
                .andReturn().getResponse().getContentAsString();

        JsonNode inviteNode = objectMapper.readTree(inviteJson);
        String inviteCode = inviteNode.get("inviteCode").asText();

        // 2. User B joins using invite code
        JoinCoupleRequest joinRequest = new JoinCoupleRequest(inviteCode);
        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(joinRequest)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status", is("ACTIVE")))
                .andExpect(jsonPath("$.members", hasSize(2)));

        // 3. User A queries current couple
        mockMvc.perform(get("/api/v1/couples/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("ACTIVE")))
                .andExpect(jsonPath("$.members", hasSize(2)));

        // 4. User B queries current couple
        mockMvc.perform(get("/api/v1/couples/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("ACTIVE")))
                .andExpect(jsonPath("$.members", hasSize(2)));

        // 5. User C (unpaired) queries current couple -> 404
        mockMvc.perform(get("/api/v1/couples/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code", is("COUPLE_NOT_FOUND")));
    }

    @Test
    @DisplayName("Self-pairing rejection: User A cannot use own invite code")
    void shouldRejectSelfPairing() throws Exception {
        String inviteJson = mockMvc.perform(post("/api/v1/couple-invites")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        String inviteCode = objectMapper.readTree(inviteJson).get("inviteCode").asText();

        JoinCoupleRequest joinRequest = new JoinCoupleRequest(inviteCode);
        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(joinRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code", is("CANNOT_PAIR_SELF")));
    }

    @Test
    @DisplayName("Expired code rejection: User B cannot join using expired invite")
    void shouldRejectExpiredInvite() throws Exception {
        String code = "EXPIRE1";
        String codeHash = inviteCodeService.hashCode(code);
        CoupleInviteEntity expiredInvite = new CoupleInviteEntity(
                userA,
                codeHash,
                Instant.now().minus(1, ChronoUnit.HOURS)
        );
        inviteRepository.save(expiredInvite);

        JoinCoupleRequest joinRequest = new JoinCoupleRequest(code);
        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(joinRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code", is("INVITE_EXPIRED")));
    }

    @Test
    @DisplayName("Reuse rejection: A code cannot be used twice")
    void shouldRejectCodeReuse() throws Exception {
        // User A generates invite
        String inviteJson = mockMvc.perform(post("/api/v1/couple-invites")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        String inviteCode = objectMapper.readTree(inviteJson).get("inviteCode").asText();

        // User B joins successfully
        JoinCoupleRequest joinRequest = new JoinCoupleRequest(inviteCode);
        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(joinRequest)))
                .andExpect(status().isCreated());

        // User C attempts to use the same code -> rejected
        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(joinRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code", is("INVALID_INVITE_CODE")));
    }

    @Test
    @DisplayName("Already paired user cannot create new invite or join another couple")
    void shouldRejectWhenAlreadyPaired() throws Exception {
        // Pair A and B
        String inviteJson = mockMvc.perform(post("/api/v1/couple-invites")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        String inviteCode = objectMapper.readTree(inviteJson).get("inviteCode").asText();

        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new JoinCoupleRequest(inviteCode))))
                .andExpect(status().isCreated());

        // Now User A tries to create another invite -> 409 ALREADY_PAIRED
        mockMvc.perform(post("/api/v1/couple-invites")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code", is("ALREADY_PAIRED")));

        // User C creates an invite
        String inviteCJson = mockMvc.perform(post("/api/v1/couple-invites")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String inviteCCode = objectMapper.readTree(inviteCJson).get("inviteCode").asText();

        // User B tries to join User C's invite -> 409 ALREADY_PAIRED
        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new JoinCoupleRequest(inviteCCode))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code", is("ALREADY_PAIRED")));
    }

    @Test
    @DisplayName("Unpair endpoint returns 501 UNPAIRING_POLICY_PENDING under OD-03")
    void shouldReturn501ForUnpairPendingDecision() throws Exception {
        // Pair A and B first
        String inviteJson = mockMvc.perform(post("/api/v1/couple-invites")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        String inviteCode = objectMapper.readTree(inviteJson).get("inviteCode").asText();

        mockMvc.perform(post("/api/v1/couples/join")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new JoinCoupleRequest(inviteCode))))
                .andExpect(status().isCreated());

        // User A calls DELETE /api/v1/couples/me
        mockMvc.perform(delete("/api/v1/couples/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isNotImplemented())
                .andExpect(jsonPath("$.code", is("UNPAIRING_POLICY_PENDING")));
    }
}
