package com.ourspace.identity.service;

import com.ourspace.common.exception.ApiException;
import com.ourspace.identity.dto.*;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.security.TokenService;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;

@Service
public class IdentityService {
    private final UserRepository users;
    private final PasswordEncoder passwords;
    private final TokenService tokens;
    private final String dummyHash;

    public IdentityService(UserRepository users, PasswordEncoder passwords, TokenService tokens) {
        this.users = users; this.passwords = passwords; this.tokens = tokens;
        // Perform the same BCrypt check for unknown email to reduce account enumeration via timing.
        this.dummyHash = passwords.encode(UUID.randomUUID().toString());
    }

    public UserResponse register(RegisterRequest request) {
        var user = new User(request.email(), passwords.encode(request.password()), request.displayName().strip());
        try { return users.saveAndFlush(user).toResponse(); }
        catch (DataIntegrityViolationException ex) {
            // The repository transaction has rolled back before this lookup.
            // Do not misreport unrelated integrity/database errors as duplicate emails.
            if (users.findByEmail(request.email()).isPresent())
                throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_EXISTS", "Email is already registered.");
            throw ex;
        }
    }

    @Transactional(readOnly = true)
    public LoginResponse login(LoginRequest request) {
        var user = users.findByEmail(request.email());
        boolean matches = passwords.matches(request.password(), user.map(User::getPasswordHash).orElse(dummyHash));
        if (!matches || user.isEmpty())
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Email or password is incorrect.");
        return new LoginResponse(tokens.issue(user.get().getId()), "Bearer", user.get().toResponse());
    }

    @Transactional(readOnly = true)
    public UserResponse profile(UUID userId) { return requireUser(userId).toResponse(); }

    @Transactional
    public UserResponse update(UUID userId, UpdateProfileRequest request) {
        var user = requireUser(userId);
        if (request.getDisplayName() != null) user.setDisplayName(request.getDisplayName().strip());
        if (request.isAvatarKeyPresent()) {
            var key = request.getAvatarKey();
            if (key != null && (!key.startsWith("avatars/" + userId + "/") ||
                    key.contains("..") || !key.matches("[a-zA-Z0-9/_-]+\\.[a-zA-Z0-9]+")))
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR",
                        "Avatar key must reference your own avatars/{userId}/ namespace.");
            user.setAvatarKey(key);
        }
        return user.toResponse();
    }

    private User requireUser(UUID id) {
        return users.findById(id).orElseThrow(() -> new ApiException(
                HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Account is no longer available."));
    }
}
