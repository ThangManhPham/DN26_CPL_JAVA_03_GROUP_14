package com.ourspace.common.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

/**
 * OpenApiConfig -- Cau hinh metadata cho Springdoc OpenAPI / Swagger UI.
 *
 * URL truy cap:
 *   - /v3/api-docs       -> OpenAPI 3.1 JSON spec (de tich hop tool/client gen)
 *   - /swagger-ui.html   -> Swagger UI tuong tac
 *
 * Metadata nay chi mo ta API; cac endpoint thuc su se duoc dang ky
 * boi cac @RestController trong cac module identity, pairing, v.v.
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI ourSpaceOpenAPI() {
        return new OpenAPI()
                .components(new Components().addSecuritySchemes("bearerAuth",
                        new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("Access token from POST /api/v1/auth/login. Default lifetime: 1 hour.")))
                .info(new Info()
                        .title("OurSpace API")
                        .version("v1")
                        .description("""
                                OurSpace -- AI-Powered Couple App backend API.

                                Tat ca endpoint private yeu cau Bearer JWT token trong header:
                                  Authorization: Bearer <token>

                                JWT se duoc cap sau khi dang nhap thanh cong qua POST /api/v1/auth/login.
                                Register returns a user; login returns accessToken, tokenType and user.
                                """)
                        .contact(new Contact()
                                .name("OurSpace Team")
                                .email("team@ourspace.local"))
                        .license(new License()
                                .name("Internal -- Not for distribution")))
                .servers(List.of(
                        new Server()
                                .url("http://localhost:8080")
                                .description("Local development server")
                ));
    }
}
