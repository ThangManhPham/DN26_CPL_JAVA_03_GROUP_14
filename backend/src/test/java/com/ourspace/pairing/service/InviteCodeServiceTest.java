package com.ourspace.pairing.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class InviteCodeServiceTest {

    private final InviteCodeService service = new InviteCodeService(6);

    @Test
    @DisplayName("Generated code should be 6 characters and uppercase alphanumeric without ambiguous chars")
    void shouldGenerateValidCode() {
        String code = service.generateCode();

        assertNotNull(code);
        assertEquals(6, code.length());
        assertTrue(code.matches("^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$"));
        assertFalse(code.contains("0"));
        assertFalse(code.contains("O"));
        assertFalse(code.contains("1"));
        assertFalse(code.contains("I"));
    }

    @Test
    @DisplayName("Generated codes should have high entropy and uniqueness")
    void shouldGenerateUniqueCodes() {
        Set<String> set = new HashSet<>();
        for (int i = 0; i < 500; i++) {
            set.add(service.generateCode());
        }
        assertEquals(500, set.size(), "Codes should not collide in small batches");
    }

    @Test
    @DisplayName("Code hashing should be deterministic and case-insensitive")
    void shouldHashConsistently() {
        String hash1 = service.hashCode("K7P4R8");
        String hash2 = service.hashCode("k7p4r8");
        String hash3 = service.hashCode("  K7P4R8  ");

        assertNotNull(hash1);
        assertEquals(64, hash1.length(), "SHA-256 hex string should be 64 characters");
        assertEquals(hash1, hash2, "Hashing must be case-insensitive");
        assertEquals(hash1, hash3, "Hashing must trim whitespace");
    }
}
