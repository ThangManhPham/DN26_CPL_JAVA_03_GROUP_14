package com.ourspace.push;

import com.ourspace.security.SecurityUtils;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/devices/push-token")
public class PushTokenController {
    private final PushTokenRepository tokens;
    public PushTokenController(PushTokenRepository tokens) { this.tokens = tokens; }

    @PutMapping
    public ResponseEntity<Void> register(Authentication auth, @Valid @RequestBody PushTokenRequest request) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        tokens.save(new PushToken(request.token(), userId, request.platform()));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping
    public ResponseEntity<Void> remove(Authentication auth, @Valid @RequestBody PushTokenRequest request) {
        tokens.deleteByTokenAndUserId(request.token(), SecurityUtils.resolveUserId(auth));
        return ResponseEntity.noContent().build();
    }
}
