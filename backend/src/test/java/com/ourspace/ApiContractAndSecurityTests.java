package com.ourspace;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.identity.dto.RegisterRequest;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.identity.service.IdentityService;
import com.ourspace.common.exception.ApiException;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(ApiContractAndSecurityTests.AuthorizationProbe.class)
class ApiContractAndSecurityTests {
    @TestConfiguration
    static class AuthorizationProbe {
        @Bean ProbeController probeController() { return new ProbeController(); }
    }
    @RestController
    static class ProbeController {
        @GetMapping("/test/admin")
        @PreAuthorize("hasRole('ADMIN')")
        public Map<String, String> admin() { return Map.of("status", "ok"); }
    }
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository users;
    @Autowired PasswordEncoder passwords;
    @Autowired IdentityService identity;
    @Autowired JwtEncoder encoder;

    @BeforeEach void resetUsers() { users.deleteAll(); }

    private JsonNode register(String email, String name) throws Exception {
        var result = mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", "Password123!", "displayName", name))))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.password").doesNotExist()).andReturn();
        return json.readTree(result.getResponse().getContentAsString());
    }

    private String login(String email) throws Exception {
        var result = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", "Password123!"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.user.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.user.password").doesNotExist()).andReturn();
        return json.readTree(result.getResponse().getContentAsString()).path("accessToken").asText();
    }

    private String token(String subject, String issuer, Instant issued, Instant expires) {
        var claims = JwtClaimsSet.builder().subject(subject).issuer(issuer)
                .issuedAt(issued).expiresAt(expires).build();
        return encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    @Test void registerLoginAndReadOwnProfileWithRealJwt() throws Exception {
        var profile = register("  ALEX@Example.com  ", " Alex ");
        var id = profile.path("id").asText();
        assertThat(profile.path("email").asText()).isEqualTo("alex@example.com");
        assertThat(profile.path("displayName").asText()).isEqualTo("Alex");
        var saved = users.findById(UUID.fromString(id)).orElseThrow();
        assertThat(saved.getPasswordHash()).isNotEqualTo("Password123!");
        assertThat(passwords.matches("Password123!", saved.getPasswordHash())).isTrue();
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + login("ALEX@example.com")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());
    }

    @Test void duplicateEmailIsCaseInsensitiveAndReturns409() throws Exception {
        register("alex@example.com", "Alex");
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", " ALEX@EXAMPLE.COM ", "password", "Password123!", "displayName", "Other"))))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("EMAIL_ALREADY_EXISTS"));
        assertThat(users.count()).isEqualTo(1);
    }

    @Test void incorrectAndUnknownCredentialsHaveSameError() throws Exception {
        register("alex@example.com", "Alex");
        String expected = null;
        for (String email : List.of("alex@example.com", "absent@example.com")) {
            var result = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(Map.of("email", email, "password", "WrongPassword!"))))
                    .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"))
                    .andExpect(jsonPath("$.accessToken").doesNotExist()).andReturn();
            var message = json.readTree(result.getResponse().getContentAsString()).path("message").asText();
            if (expected != null) assertThat(message).isEqualTo(expected);
            expected = message;
        }
    }

    @Test void profilePatchPreservesOmittedFieldsAndCanClearAvatar() throws Exception {
        var profile = register("alex@example.com", "Alex");
        String auth = "Bearer " + login("alex@example.com");
        String key = "avatars/" + profile.path("id").asText() + "/profile.png";
        mvc.perform(patch("/api/v1/users/me").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("avatarKey", key))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.avatarKey").value(key));
        mvc.perform(patch("/api/v1/users/me").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                .content("{\"displayName\":\" New name \"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.displayName").value("New name"))
                .andExpect(jsonPath("$.avatarKey").value(key));
        mvc.perform(patch("/api/v1/users/me").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                .content("{\"avatarKey\":null}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.avatarKey").value(nullValue()));
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + login("alex@example.com")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.displayName").value("New name"))
                .andExpect(jsonPath("$.avatarKey").value(nullValue()));
    }

    @Test void forgedFieldsCannotModifyAnotherAccount() throws Exception {
        var a = register("a@example.com", "Alice");
        var b = register("b@example.com", "Bob");
        var auth = "Bearer " + login("a@example.com");
        for (String field : List.of("id", "userId", "email", "passwordHash")) {
            mvc.perform(patch("/api/v1/users/me").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(Map.of(field, b.path("id").asText(), "displayName", "Forged"))))
                    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        }
        mvc.perform(get("/api/v1/users/" + b.path("id").asText()).header("Authorization", auth))
                .andExpect(status().isNotFound());
        assertThat(users.findById(UUID.fromString(a.path("id").asText())).orElseThrow().toResponse().displayName()).isEqualTo("Alice");
        assertThat(users.findById(UUID.fromString(b.path("id").asText())).orElseThrow().toResponse().displayName()).isEqualTo("Bob");
    }

    @Test void avatarCannotReferenceOtherNamespaceOrPublicUrl() throws Exception {
        register("a@example.com", "Alice");
        String auth = "Bearer " + login("a@example.com");
        for (String key : List.of("avatars/" + UUID.randomUUID() + "/private.png", "https://example.com/a.png", "../private.png")) {
            mvc.perform(patch("/api/v1/users/me").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                    .content(json.writeValueAsString(Map.of("avatarKey", key))))
                    .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        }
    }

    @Test void invalidRegistrationFieldsReturn422WithoutEchoingPassword() throws Exception {
        var requests = List.of(
            Map.of("email", "bad", "password", "Password123!", "displayName", "Alex"),
            Map.of("email", "alex@example.com", "password", "short", "displayName", "Alex"),
            Map.of("email", "alex@example.com", "password", "Password123!", "displayName", "   "),
            Map.of("email", "alex@example.com", "password", "é".repeat(40), "displayName", "Alex"),
            Map.of("email", "alex@example.com", "password", "x".repeat(73), "displayName", "Alex"),
            Map.of("email", "alex@example.com", "password", "Password123!", "displayName", "x".repeat(101))
        );
        for (var body : requests) {
            mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)))
                    .andExpect(status().isUnprocessableEntity()).andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                    .andExpect(content().string(not(containsString(body.get("password")))));
        }
        assertThat(users.count()).isZero();
    }

    @Test void invalidProfilePatchesReturn422() throws Exception {
        register("alex@example.com", "Alex");
        String auth = "Bearer " + login("alex@example.com");
        for (String body : List.of("{}", "{\"displayName\":null}", "{\"displayName\":\"\"}", "{\"displayName\":\"   \"}")) {
            mvc.perform(patch("/api/v1/users/me").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isUnprocessableEntity());
        }
    }

    @Test void missingAndInvalidTokensReturnStandard401WithCorrelationId() throws Exception {
        var result = mvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized()).andExpect(header().string("WWW-Authenticate", "Bearer"))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED")).andReturn();
        assertThat(json.readTree(result.getResponse().getContentAsString()).path("requestId").asText())
                .isEqualTo(result.getResponse().getHeader("X-Request-Id"));
        for (String value : List.of("Bearer nonsense", "Bearer abc.def.ghi", "Basic YTpi")) {
            mvc.perform(get("/api/v1/users/me").header("Authorization", value))
                    .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        }
        mvc.perform(patch("/api/v1/users/me").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test void expiredWrongIssuerInvalidSubjectAndTamperedTokensAreRejected() throws Exception {
        var profile = register("alex@example.com", "Alex");
        String id = profile.path("id").asText();
        var now = Instant.now();
        var valid = login("alex@example.com");
        for (String value : List.of(
                token(id, "ourspace", now.minusSeconds(120), now.minusSeconds(60)),
                token(id, "wrong-issuer", now.minusSeconds(5), now.plusSeconds(300)),
                token("not-a-uuid", "ourspace", now.minusSeconds(5), now.plusSeconds(300)),
                token(id, "ourspace", now.plusSeconds(120), now.plusSeconds(600)),
                valid.substring(0, valid.lastIndexOf('.') + 1) + "invalidsignature")) {
            mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + value))
                    .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        }
    }

    @Test void tokenWithoutExpirationIsRejected() throws Exception {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("ourspace").subject(UUID.randomUUID().toString()).issuedAt(now).build();
        var value = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + value)).andExpect(status().isUnauthorized());
    }

    @Test void deletedAccountCannotUseOldToken() throws Exception {
        register("alex@example.com", "Alex");
        var auth = "Bearer " + login("alex@example.com");
        users.deleteAll();
        mvc.perform(get("/api/v1/users/me").header("Authorization", auth)).andExpect(status().isUnauthorized());
    }

    @Test void authenticatedUserWithoutRequiredAuthorityGets403() throws Exception {
        register("alex@example.com", "Alex");
        mvc.perform(get("/test/admin").header("Authorization", "Bearer " + login("alex@example.com")))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test void invalidAvatarRollsBackOtherChangesInTheSamePatch() throws Exception {
        register("alex@example.com", "Alex");
        String auth = "Bearer " + login("alex@example.com");
        mvc.perform(patch("/api/v1/users/me").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                .content("{\"displayName\":\"Should rollback\",\"avatarKey\":\"invalid.png\"}"))
                .andExpect(status().isUnprocessableEntity());
        mvc.perform(get("/api/v1/users/me").header("Authorization", auth))
                .andExpect(status().isOk()).andExpect(jsonPath("$.displayName").value("Alex"));
    }

    @Test void malformedMissingAndUnknownJsonReturn400AndWrongContentType415() throws Exception {
        for (String value : List.of("{", "{\"email\":\"a@example.com\",\"unexpected\":true}")) {
            mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content(value))
                    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        }
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.TEXT_PLAIN).content("test"))
                .andExpect(status().isUnsupportedMediaType());
    }

    @Test void concurrentRegistrationStoresExactlyOneUser() throws Exception {
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            Callable<Integer> register = () -> {
                start.await();
                try { identity.register(new RegisterRequest("race@example.com", "Password123!", "Race")); return 201; }
                catch (ApiException ex) { return ex.status().value(); }
            };
            var a = executor.submit(register);
            var b = executor.submit(register);
            start.countDown();
            assertThat(List.of(a.get(20, TimeUnit.SECONDS), b.get(20, TimeUnit.SECONDS)))
                    .containsExactlyInAnyOrder(201, 409);
        }
        assertThat(users.count()).isEqualTo(1);
    }

    @Test void swaggerHealthAndOpenApiAreAccessibleAndDescribeRealContracts() throws Exception {
        mvc.perform(get("/swagger-ui.html")).andExpect(status().is3xxRedirection());
        mvc.perform(get("/swagger-ui/index.html")).andExpect(status().isOk());
        mvc.perform(get("/actuator/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
        var response = mvc.perform(get("/v3/api-docs")).andExpect(status().isOk()).andReturn();
        var spec = json.readTree(response.getResponse().getContentAsString());
        assertThat(spec.at("/components/securitySchemes/bearerAuth/scheme").asText()).isEqualTo("bearer");
        var register = spec.path("paths").path("/api/v1/auth/register").path("post");
        assertThat(register.path("summary").asText()).doesNotContain("STUB");
        assertThat(register.at("/requestBody/content/application~1json/schema/$ref").asText())
                .isEqualTo("#/components/schemas/RegisterRequest");
        assertThat(register.at("/responses/201/content/application~1json/schema/$ref").asText())
                .isEqualTo("#/components/schemas/UserResponse");
        assertThat(register.path("responses").has("501")).isFalse();
        assertThat(spec.path("paths").path("/api/v1/users/me").at("/get/security/0").has("bearerAuth")).isTrue();
        var user = spec.at("/components/schemas/UserResponse/properties");
        assertThat(user.has("password")).isFalse();
        assertThat(user.has("passwordHash")).isFalse();
    }
}
