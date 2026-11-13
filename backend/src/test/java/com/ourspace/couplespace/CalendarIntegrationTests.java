package com.ourspace.couplespace;

import com.fasterxml.jackson.databind.*;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.entity.*;
import com.ourspace.pairing.repository.*;
import com.ourspace.couplespace.repository.EventRepository;
import com.ourspace.security.TokenService;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.*;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class CalendarIntegrationTests {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository users;
    @Autowired CoupleRepository couples;
    @Autowired CoupleMemberRepository members;
    @Autowired TokenService tokens;
    @Autowired EventRepository events;
    User a,b,c,d,solo;
    CoupleEntity ab;
    String ta,tb,tc,ts;

    @BeforeEach void setup() {
        a=user("a"); b=user("b"); c=user("c"); d=user("d"); solo=user("solo");
        ab=pair(a,b); pair(c,d);
        ta=tokens.issue(a.getId()); tb=tokens.issue(b.getId()); tc=tokens.issue(c.getId()); ts=tokens.issue(solo.getId());
    }
    User user(String name) { return users.saveAndFlush(new User(UUID.randomUUID()+"@example.com","hash",name)); }
    CoupleEntity pair(User one,User two) {
        var couple=couples.saveAndFlush(new CoupleEntity(UUID.randomUUID(),CoupleStatus.ACTIVE));
        members.saveAndFlush(new CoupleMemberEntity(couple,one,"MEMBER"));
        members.saveAndFlush(new CoupleMemberEntity(couple,two,"MEMBER"));
        return couple;
    }
    Map<String,Object> data() {
        return Map.of("title","Dinner","description","Our plan","startsAt","2026-10-31T17:00:00Z",
            "endsAt","2026-10-31T18:00:00Z","timezone","Asia/Ho_Chi_Minh");
    }
    JsonNode create() throws Exception {
        return json.readTree(mvc.perform(post("/api/v1/events").header("Authorization","Bearer "+ta)
            .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(data())))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString());
    }
    @Test void sharedCrudAndPartialUpdate() throws Exception {
        var event=create(); var id=event.path("id").asText();
        mvc.perform(get("/api/v1/events/"+id).header("Authorization","Bearer "+tb))
            .andExpect(status().isOk()).andExpect(jsonPath("$.title").value("Dinner"));
        mvc.perform(patch("/api/v1/events/"+id).header("Authorization","Bearer "+tb).contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\":\"New dinner\",\"description\":null,\"version\":0}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.title").value("New dinner"))
            .andExpect(jsonPath("$.description").value(nullValue()))
            .andExpect(jsonPath("$.startsAt").value("2026-10-31T17:00:00Z"))
            .andExpect(jsonPath("$.version").value(1));
        mvc.perform(delete("/api/v1/events/"+id).param("version","1").header("Authorization","Bearer "+ta))
            .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/events/"+id).header("Authorization","Bearer "+tb)).andExpect(status().isNotFound());
    }
    @Test void photoAndCalendarShareTheSameCoupleWithoutLeakingToOutsiders() throws Exception {
        var image = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(2,2,java.awt.image.BufferedImage.TYPE_INT_RGB),"png",image);
        var upload = mvc.perform(multipart("/api/v1/photos")
                .file(new org.springframework.mock.web.MockMultipartFile("file","shared.png","image/png",image.toByteArray()))
                .header("Idempotency-Key",UUID.randomUUID().toString()).header("Authorization","Bearer "+ta))
                .andExpect(status().isCreated()).andReturn();
        var photoId = json.readTree(upload.getResponse().getContentAsString()).path("id").asText();
        var eventId = create().path("id").asText();
        mvc.perform(get("/api/v1/photos/latest").header("Authorization","Bearer "+tb))
                .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(photoId));
        mvc.perform(get("/api/v1/events/"+eventId).header("Authorization","Bearer "+tb))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/photos/"+photoId+"/image").header("Authorization","Bearer "+tc))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/events/"+eventId).header("Authorization","Bearer "+tc))
                .andExpect(status().isNotFound());
    }
    @Test void outsidersCannotReadUpdateOrDelete() throws Exception {
        var event=create(); var id=event.path("id").asText();
        mvc.perform(get("/api/v1/events/"+id).header("Authorization","Bearer "+tc)).andExpect(status().isNotFound());
        mvc.perform(patch("/api/v1/events/"+id).header("Authorization","Bearer "+tc).contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\":\"Hacked\",\"version\":0}")).andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/events/"+id).param("version","0").header("Authorization","Bearer "+tc)).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/events").param("from","2026-10-01T00:00:00Z").param("until","2026-12-01T00:00:00Z")
            .header("Authorization","Bearer "+tc)).andExpect(status().isOk()).andExpect(jsonPath("$.items",hasSize(0)));
        assertThat(events.findById(UUID.fromString(id)).orElseThrow().title).isEqualTo("Dinner");
    }
    @Test void unpairedAndUnauthenticatedAreRejected() throws Exception {
        mvc.perform(get("/api/v1/couple-space")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/events").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(data())))
            .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/couple-space").header("Authorization","Bearer "+ts)).andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/events").header("Authorization","Bearer "+ts).contentType(MediaType.APPLICATION_JSON)
            .content(json.writeValueAsString(data()))).andExpect(status().isNotFound());
    }
    @Test void invalidRangesAndZonesDoNotCreateEvents() throws Exception {
        var bad=new HashMap<>(data()); bad.put("endsAt","2026-10-31T16:00:00Z");
        for(var body: List.of(bad,with("title"," "),with("timezone","Not/AZone"),with("description","x".repeat(2001)))) {
            mvc.perform(post("/api/v1/events").header("Authorization","Bearer "+ta).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(body))).andExpect(status().isUnprocessableEntity());
        }
        mvc.perform(get("/api/v1/events").header("Authorization","Bearer "+ta)
            .param("from","2026-11-01T00:00:00Z").param("until","2026-10-01T00:00:00Z"))
            .andExpect(status().isUnprocessableEntity());
        mvc.perform(get("/api/v1/events").header("Authorization","Bearer "+ta).param("from","bad")).andExpect(status().isBadRequest());
    }
    Map<String,Object> with(String key,Object value) { var body=new HashMap<>(data());body.put(key,value);return body; }
    @Test void staleVersionsCannotOverwriteOrDelete() throws Exception {
        var id=create().path("id").asText();
        mvc.perform(patch("/api/v1/events/"+id).header("Authorization","Bearer "+ta).contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\":\"Updated\",\"version\":0}")).andExpect(status().isOk());
        mvc.perform(patch("/api/v1/events/"+id).header("Authorization","Bearer "+tb).contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\":\"Stale\",\"version\":0}")).andExpect(status().isConflict());
        mvc.perform(delete("/api/v1/events/"+id).param("version","0").header("Authorization","Bearer "+tb)).andExpect(status().isConflict());
    }
    @Test void rangeUsesOverlapAndPagination() throws Exception {
        create();create();
        mvc.perform(get("/api/v1/events").header("Authorization","Bearer "+ta)
            .param("from","2026-10-31T17:30:00Z").param("until","2026-11-01T00:00:00Z").param("size","1"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items",hasSize(1))).andExpect(jsonPath("$.nextPage").value(1));
        mvc.perform(get("/api/v1/events").header("Authorization","Bearer "+ta)
            .param("from","2026-10-31T18:00:00Z").param("until","2026-11-01T00:00:00Z"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items",hasSize(0)));
    }
    @Test void anniversaryAndLoveCounterAreSharedAndTimezoneAware() throws Exception {
        var date=LocalDate.of(2020,2,29);
        mvc.perform(patch("/api/v1/couple-space").header("Authorization","Bearer "+ta).contentType(MediaType.APPLICATION_JSON)
            .content("{\"anniversaryDate\":\"2020-02-29\"}")).andExpect(status().isOk());
        var today=LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
        mvc.perform(get("/api/v1/couple-space").header("Authorization","Bearer "+tb))
            .andExpect(status().isOk()).andExpect(jsonPath("$.anniversaryDate").value(date.toString()))
            .andExpect(jsonPath("$.reminder.occursOn").isString())
            .andExpect(jsonPath("$.reminder.daysUntil").isNumber())
            .andExpect(jsonPath("$.daysTogether").value((int)ChronoUnit.DAYS.between(date,today)));
        mvc.perform(patch("/api/v1/couple-space").header("Authorization","Bearer "+ta).contentType(MediaType.APPLICATION_JSON)
            .content("{\"anniversaryDate\":\"2999-01-01\"}")).andExpect(status().isUnprocessableEntity());
        mvc.perform(get("/api/v1/couple-space").header("Authorization","Bearer "+ta).param("timezone","bad/zone"))
            .andExpect(status().isUnprocessableEntity());
    }
    @Test void endedCoupleAndFormerMemberLoseAccess() throws Exception {
        var id=create().path("id").asText();
        ab.setStatus(CoupleStatus.ENDED); couples.flush();
        mvc.perform(get("/api/v1/events/"+id).header("Authorization","Bearer "+ta)).andExpect(status().isNotFound());
    }
    @Test void formerMemberCannotReadEventsOfAnActiveCouple() throws Exception {
        var id=create().path("id").asText();
        var membership=members.findByIdUserIdAndLeftAtIsNull(a.getId()).orElseThrow();
        membership.setLeftAt(Instant.now()); members.flush();
        mvc.perform(get("/api/v1/events/"+id).header("Authorization","Bearer "+ta)).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/events/"+id).header("Authorization","Bearer "+tb)).andExpect(status().isOk());
    }
    @Test void forgedCoupleAndInvalidPatchCannotChangeData() throws Exception {
        var id=create().path("id").asText();
        for(String body:List.of("{\"coupleId\":\""+UUID.randomUUID()+"\",\"version\":0}",
            "{\"title\":null,\"version\":0}", "{\"title\":\"Missing version\"}", "{}")) {
            mvc.perform(patch("/api/v1/events/"+id).header("Authorization","Bearer "+ta).contentType(MediaType.APPLICATION_JSON)
                .content(body)).andExpect(status().isUnprocessableEntity());
        }
        mvc.perform(get("/api/v1/events/"+id).header("Authorization","Bearer "+tb))
            .andExpect(status().isOk()).andExpect(jsonPath("$.title").value("Dinner"));
    }
}
