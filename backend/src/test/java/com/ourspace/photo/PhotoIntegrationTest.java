package com.ourspace.photo;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.security.TokenService;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class PhotoIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository users;
    @Autowired CoupleRepository couples;
    @Autowired CoupleMemberRepository members;
    @Autowired PhotoRepository photos;
    @Autowired TokenService tokens;
    private String tokenA;
    private String tokenB;
    private String tokenC;
    private static final byte[] PNG = makePng();

    private static byte[] makePng() {
        try {
            var output = new ByteArrayOutputStream();
            ImageIO.write(new BufferedImage(2, 2, BufferedImage.TYPE_INT_RGB), "png", output);
            return output.toByteArray();
        } catch (Exception ex) {
            throw new IllegalStateException(ex);
        }
    }

    @BeforeEach void setup() {
        User a = users.save(new User("photo-a@example.com", "hash", "Alex"));
        User b = users.save(new User("photo-b@example.com", "hash", "Sam"));
        User c = users.save(new User("photo-c@example.com", "hash", "Charlie"));
        CoupleEntity couple = couples.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        members.save(new CoupleMemberEntity(couple, a, "MEMBER"));
        members.save(new CoupleMemberEntity(couple, b, "MEMBER"));
        tokenA = tokens.issue(a.getId());
        tokenB = tokens.issue(b.getId());
        tokenC = tokens.issue(c.getId());
    }

    @Test void partnerCanSeeLatestButOutsiderCannot() throws Exception {
        String id = json.readTree(mvc.perform(multipart("/api/v1/photos")
                .file(new MockMultipartFile("file", "photo.png", "image/png", PNG))
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                .header("Idempotency-Key", UUID.randomUUID()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.storageKey").doesNotExist())
                .andReturn().getResponse().getContentAsString()).get("id").asText();
        mvc.perform(get("/api/v1/photos/latest").header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(id));
        mvc.perform(get("/api/v1/photos/" + id + "/image").header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk()).andExpect(content().bytes(PNG));
        mvc.perform(get("/api/v1/photos/" + id + "/image").header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/photos/" + id + "/image")).andExpect(status().isUnauthorized());
    }

    @Test void duplicateRequestDoesNotCreateSecondPhoto() throws Exception {
        UUID requestId = UUID.randomUUID();
        for (int i = 0; i < 2; i++) {
            mvc.perform(multipart("/api/v1/photos")
                    .file(new MockMultipartFile("file", "photo.png", "image/png", PNG))
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                    .header("Idempotency-Key", requestId))
                    .andExpect(status().isCreated());
        }
        org.assertj.core.api.Assertions.assertThat(photos.count()).isEqualTo(1);
    }

    @Test void rejectsInvalidContentAndUnpairedUpload() throws Exception {
        mvc.perform(multipart("/api/v1/photos")
                .file(new MockMultipartFile("file", "fake.png", "image/png", "not a png".getBytes()))
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                .header("Idempotency-Key", UUID.randomUUID()))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_PHOTO_TYPE"));
        mvc.perform(multipart("/api/v1/photos")
                .file(new MockMultipartFile("file", "photo.png", "image/png", PNG))
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC)
                .header("Idempotency-Key", UUID.randomUUID()))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("COUPLE_REQUIRED"));
    }
}
