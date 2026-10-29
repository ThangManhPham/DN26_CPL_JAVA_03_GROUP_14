package com.ourspace.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Service;
import java.time.Clock;
import java.time.Duration;
import java.util.UUID;

@Service
public class TokenService {
    private final JwtEncoder encoder;
    private final Clock clock;
    private final String issuer;
    private final Duration lifetime;
    public TokenService(JwtEncoder encoder, Clock clock,
            @Value("${app.jwt.issuer:ourspace}") String issuer,
            @Value("${app.jwt.ttl-seconds:3600}") long ttl) {
        if (ttl < 60 || ttl > 86400) throw new IllegalStateException("JWT TTL must be between 60 and 86400 seconds.");
        this.encoder = encoder; this.clock = clock; this.issuer = issuer;
        this.lifetime = Duration.ofSeconds(ttl);
    }
    public String issue(UUID userId) {
        var now = clock.instant();
        var claims = JwtClaimsSet.builder().issuer(issuer).subject(userId.toString())
                .issuedAt(now).expiresAt(now.plus(lifetime)).id(UUID.randomUUID().toString()).build();
        return encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }
}
