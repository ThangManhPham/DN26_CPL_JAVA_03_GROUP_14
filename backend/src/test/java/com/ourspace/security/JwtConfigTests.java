package com.ourspace.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import java.util.Base64;
import static org.assertj.core.api.Assertions.*;

class JwtConfigTests {
    private final JwtConfig config = new JwtConfig();

    @Test void missingKeyFailsOutsideDev() {
        var env = new MockEnvironment();
        env.setActiveProfiles("prod");
        assertThatThrownBy(() -> config.jwtKey("", env)).isInstanceOf(IllegalStateException.class);
    }

    @Test void weakAndMalformedKeysFailEvenInDev() {
        var env = new MockEnvironment();
        env.setActiveProfiles("dev");
        for (String secret : new String[]{"not-base64!", Base64.getEncoder().encodeToString(new byte[8])}) {
            assertThatThrownBy(() -> config.jwtKey(secret, env)).isInstanceOf(IllegalStateException.class);
        }
    }

    @Test void devFallbackCreatesDifferentRandomKeys() {
        var env = new MockEnvironment();
        env.setActiveProfiles("dev");
        var a = config.jwtKey("", env).getEncoded();
        var b = config.jwtKey("", env).getEncoded();
        assertThat(a).hasSize(32).isNotEqualTo(b);
    }
}
