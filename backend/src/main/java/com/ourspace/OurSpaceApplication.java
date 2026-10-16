package com.ourspace;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * OurSpaceApplication -- Entry point cua Spring Boot backend.
 *
 * @SpringBootApplication la composite annotation gom:
 *   - @Configuration:    class nay la nguon cau hinh Bean
 *   - @EnableAutoConfiguration: Spring Boot tu dong cau hinh cac starter
 *   - @ComponentScan:    quet cac @Component, @Service, @Repository, @Controller
 *                        trong package com.ourspace va cac sub-package
 *
 * Khong co gi duoc hardcode o day. Moi config thuc su nam trong:
 *   - application.yml          (cau hinh chung)
 *   - application-dev.yml      (cau hinh local dev)
 *   - common/config/*.java     (SecurityConfig, OpenApiConfig, v.v.)
 */
@SpringBootApplication
public class OurSpaceApplication {

    public static void main(String[] args) {
        SpringApplication.run(OurSpaceApplication.class, args);
    }
}
