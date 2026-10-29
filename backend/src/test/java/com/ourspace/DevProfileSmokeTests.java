package com.ourspace;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Verifies the documented local mode with its actual dev configuration. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class DevProfileSmokeTests {
    @Autowired
    private MockMvc mockMvc;

    @Test
    void devStartsWithH2AndFlywayWithoutPostgres() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.components.db.details.database").value("H2"));
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk());
    }
}
