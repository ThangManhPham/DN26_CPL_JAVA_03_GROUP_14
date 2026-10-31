package com.ourspace;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.flywaydb.core.Flyway;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class OurSpaceApplicationTests {
    @Autowired Flyway flyway;
    @Test void contextLoadsWithRealMigrations() {
        assertThat(flyway.info().current().getVersion().toString()).isEqualTo("4");
        assertThat(flyway.info().pending()).isEmpty();
    }
}
