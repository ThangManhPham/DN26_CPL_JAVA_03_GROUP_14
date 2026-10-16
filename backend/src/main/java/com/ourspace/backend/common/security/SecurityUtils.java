package com.ourspace.backend.common.security;

import com.ourspace.backend.common.exception.UnauthorizedException;
import java.util.UUID;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * Utility for extracting the authenticated user identity from the security context.
 * Guarantees that userId is NEVER taken from untrusted client requests.
 */
public final class SecurityUtils {

    private SecurityUtils() {
    }

    public static UserPrincipal getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || auth instanceof AnonymousAuthenticationToken) {
            throw new UnauthorizedException("Người dùng chưa được xác thực.");
        }
        Object principal = auth.getPrincipal();
        if (principal instanceof UserPrincipal userPrincipal) {
            return userPrincipal;
        }
        throw new UnauthorizedException("Phiên làm việc không hợp lệ.");
    }

    public static UUID getCurrentUserId() {
        return getCurrentUser().getId();
    }
}
