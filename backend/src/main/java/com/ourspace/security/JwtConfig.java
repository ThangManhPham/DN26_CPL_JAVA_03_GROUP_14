package com.ourspace.security;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.util.Base64;
import java.util.UUID;

@Configuration
public class JwtConfig {
    @Bean
    public Clock clock() { return Clock.systemUTC(); }

    @Bean
    public SecretKey jwtKey(@Value("${app.jwt.secret:}") String secret, Environment environment) {
        byte[] bytes;
        if (secret.isBlank() && environment.acceptsProfiles(Profiles.of("dev"))) {
            bytes = new byte[32];
            new SecureRandom().nextBytes(bytes);
        } else {
            try { bytes = Base64.getDecoder().decode(secret); }
            catch (IllegalArgumentException ex) { throw new IllegalStateException("JWT_SECRET must be Base64 encoded."); }
            if (bytes.length < 32) throw new IllegalStateException("JWT_SECRET must contain at least 32 random bytes (Base64).");
        }
        return new SecretKeySpec(bytes, "HmacSHA256");
    }

    @Bean
    public JwtEncoder jwtEncoder(SecretKey jwtKey) {
        return new NimbusJwtEncoder(new ImmutableSecret<>(jwtKey));
    }

    @Bean
    public JwtDecoder jwtDecoder(SecretKey jwtKey, Clock clock,
            @Value("${app.jwt.issuer:ourspace}") String issuer) {
        var decoder = NimbusJwtDecoder.withSecretKey(jwtKey).macAlgorithm(MacAlgorithm.HS256).build();
        var timestamp = new JwtTimestampValidator(Duration.ZERO);
        timestamp.setClock(clock);
        OAuth2TokenValidator<Jwt> requiredClaims = jwt -> {
            try {
                UUID.fromString(jwt.getSubject());
                if (jwt.getExpiresAt() == null || jwt.getIssuedAt() == null ||
                        !jwt.getExpiresAt().isAfter(jwt.getIssuedAt()) ||
                        jwt.getIssuedAt().isAfter(clock.instant())) throw new IllegalArgumentException();
                return OAuth2TokenValidatorResult.success();
            } catch (RuntimeException ex) {
                return OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "Invalid token claims.", null));
            }
        };
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                timestamp, new JwtIssuerValidator(issuer), requiredClaims));
        return decoder;
    }
}
