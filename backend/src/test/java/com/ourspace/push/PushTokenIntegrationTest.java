package com.ourspace.push;

import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.security.TokenService;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class PushTokenIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired TokenService jwt;
    @Autowired PushTokenRepository tokens;

    @Test void onlyAuthenticatedOwnerCanRemoveADeviceToken() throws Exception {
        User a = users.save(new User("push-a-" + UUID.randomUUID() + "@example.com", "hash", "Alex"));
        User b = users.save(new User("push-b-" + UUID.randomUUID() + "@example.com", "hash", "Sam"));
        String authA = "Bearer " + jwt.issue(a.getId());
        String authB = "Bearer " + jwt.issue(b.getId());
        String body = "{\"token\":\"some-device-registration-token-123456\",\"platform\":\"android\"}";
        mvc.perform(put("/api/v1/devices/push-token").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isUnauthorized());
        mvc.perform(put("/api/v1/devices/push-token").header(HttpHeaders.AUTHORIZATION, authA)
                .contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNoContent());
        assertThat(tokens.findByUserId(a.getId())).hasSize(1);
        mvc.perform(delete("/api/v1/devices/push-token").header(HttpHeaders.AUTHORIZATION, authB)
                .contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNoContent());
        assertThat(tokens.findByUserId(a.getId())).hasSize(1);
        mvc.perform(delete("/api/v1/devices/push-token").header(HttpHeaders.AUTHORIZATION, authA)
                .contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNoContent());
        assertThat(tokens.findByUserId(a.getId())).isEmpty();
    }
}
