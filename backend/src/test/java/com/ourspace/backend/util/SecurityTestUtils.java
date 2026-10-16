package com.ourspace.backend.util;

import com.ourspace.backend.common.security.UserPrincipal;
import java.util.UUID;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

public final class SecurityTestUtils {

    private SecurityTestUtils() {
    }

    public static UserPrincipal setMockUser(UUID id, String email, String displayName) {
        UserPrincipal principal = new UserPrincipal(id, email, displayName);
        UsernamePasswordAuthenticationToken auth =
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
        return principal;
    }

    public static void clear() {
        SecurityContextHolder.clearContext();
    }
}
