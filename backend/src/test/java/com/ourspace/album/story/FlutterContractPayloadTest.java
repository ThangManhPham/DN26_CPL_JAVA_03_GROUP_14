package com.ourspace.album.story;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.entity.Album;
import com.ourspace.album.entity.AlbumPhoto;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
import com.ourspace.album.story.service.AiStoryRateLimiter;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.photo.Photo;
import com.ourspace.photo.PhotoRepository;
import com.ourspace.security.TokenService;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class FlutterContractPayloadTest {

    @Autowired private MockMvc mvc;
    @Autowired private UserRepository users;
    @Autowired private CoupleRepository couples;
    @Autowired private CoupleMemberRepository members;
    @Autowired private AlbumRepository albums;
    @Autowired private AlbumPhotoRepository albumPhotos;
    @Autowired private PhotoRepository photos;
    @Autowired private TokenService tokens;
    @Autowired private AiStoryRateLimiter rateLimiter;

    private User user;
    private CoupleEntity couple;
    private Album album;
    private Photo photo;
    private String token;

    @BeforeEach
    void setup() {
        user = users.save(new User("flutter-user@example.com", "hash", "Flutter Dev"));
        couple = couples.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        members.save(new CoupleMemberEntity(couple, user, "MEMBER"));
        token = tokens.issue(user.getId());

        rateLimiter.resetForTest(user.getId());

        album = albums.save(new Album(UUID.randomUUID(), couple.getId(), "Album Test Contract", null, null, user.getId()));
        photo = photos.save(new Photo(UUID.randomUUID(), couple.getId(), user.getId(), UUID.randomUUID(), "k.jpg", "image/jpeg", 1024));
        albumPhotos.save(new AlbumPhoto(new AlbumPhotoId(album.getId(), photo.getId())));
    }

    @ParameterizedTest
    @ValueSource(strings = {"ROMANTIC", "PLAYFUL", "SENTIMENTAL", "POETIC"})
    @DisplayName("Payload JSON chính xác từ Flutter (kèm tone) phải được Jackson chấp nhận mà không lỗi unknown property")
    void exactFlutterJsonPayload_withVariousTones_succeeds(String tone) throws Exception {
        rateLimiter.resetForTest(user.getId());

        // Payload giống hệt Flutter HttpMemoryStoryRepository gửi qua Dio/Http
        String flutterJson = """
                {
                  "albumId": "%s",
                  "selectedPhotoIds": ["%s"],
                  "notes": "Chuyến đi đáng nhớ của hai đứa mình",
                  "tone": "%s",
                  "consent": true
                }
                """.formatted(album.getId(), photo.getId(), tone);

        mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(flutterJson))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.tone").value(tone))
                .andExpect(jsonPath("$.selectedPhotoIds[0]").value(photo.getId().toString()));
    }

    @Test
    @DisplayName("Nếu Flutter không gửi tone thì backend tự gán default ROMANTIC")
    void payloadWithoutTone_defaultsToRomantic() throws Exception {
        String flutterJsonWithoutTone = """
                {
                  "albumId": "%s",
                  "selectedPhotoIds": ["%s"],
                  "notes": "Kỷ niệm không có tone cụ thể",
                  "consent": true
                }
                """.formatted(album.getId(), photo.getId());

        mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(flutterJsonWithoutTone))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tone").value("ROMANTIC"));
    }
}

