package com.ourspace.identity;

import com.ourspace.common.exception.ApiException;
import com.ourspace.identity.dto.*;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.identity.service.IdentityService;
import com.ourspace.security.TokenService;
import org.junit.jupiter.api.*;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.util.Optional;
import java.util.UUID;
import static org.mockito.Mockito.*;
import static org.assertj.core.api.Assertions.*;

class IdentityServiceTests {
    UserRepository users;
    PasswordEncoder passwords;
    TokenService tokens;
    IdentityService service;

    @BeforeEach void setup() {
        users = mock(UserRepository.class);
        passwords = mock(PasswordEncoder.class);
        tokens = mock(TokenService.class);
        when(passwords.encode(anyString())).thenReturn("dummy-hash");
        service = new IdentityService(users, passwords, tokens);
    }

    @Test void unknownEmailStillChecksPasswordAndNeverIssuesToken() {
        when(users.findByEmail("missing@example.com")).thenReturn(Optional.empty());
        when(passwords.matches("wrong", "dummy-hash")).thenReturn(false);
        assertThatThrownBy(() -> service.login(new LoginRequest("missing@example.com", "wrong")))
                .isInstanceOfSatisfying(ApiException.class, ex -> assertThat(ex.code()).isEqualTo("INVALID_CREDENTIALS"));
        verify(passwords).matches("wrong", "dummy-hash");
        verifyNoInteractions(tokens);
    }

    @Test void knownUserWrongPasswordNeverIssuesToken() {
        var user = new User("a@example.com", "saved-hash", "Alice");
        when(users.findByEmail("a@example.com")).thenReturn(Optional.of(user));
        assertThatThrownBy(() -> service.login(new LoginRequest("a@example.com", "wrong"))).isInstanceOf(ApiException.class);
        verify(passwords).matches("wrong", "saved-hash");
        verifyNoInteractions(tokens);
    }

    @Test void registerUsesEncoderAndStoresNormalizedEmail() {
        when(passwords.encode("Password123!")).thenReturn("encoded-password");
        when(users.saveAndFlush(any(User.class))).thenAnswer(invocation -> {
            User saved = invocation.getArgument(0);
            assertThat(saved.getPasswordHash()).isEqualTo("encoded-password");
            assertThat(saved.toResponse().email()).isEqualTo("alex@example.com");
            return saved;
        });
        var result = service.register(new RegisterRequest(" ALEX@EXAMPLE.COM ", "Password123!", " Alex "));
        assertThat(result.displayName()).isEqualTo("Alex");
        verifyNoInteractions(tokens);
    }

    @Test void unrelatedIntegrityFailureIsNotReportedAsDuplicateEmail() {
        var failure = new DataIntegrityViolationException("unrelated constraint");
        when(users.saveAndFlush(any(User.class))).thenThrow(failure);
        when(users.findByEmail(anyString())).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.register(new RegisterRequest("a@example.com", "Password123!", "Alice")))
                .isSameAs(failure);
    }

    @Test void missingUserIsUnauthorized() {
        var id = UUID.randomUUID();
        when(users.findById(id)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.profile(id))
                .isInstanceOfSatisfying(ApiException.class, ex -> assertThat(ex.status().value()).isEqualTo(401));
    }
}
