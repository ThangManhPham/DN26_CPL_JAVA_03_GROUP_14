package com.ourspace.album.story.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

@Configuration
public class AiStoryConfiguration {

    @Bean
    @ConditionalOnProperty(name = "ourspace.ai.provider", havingValue = "gemini", matchIfMissing = false)
    @Primary
    public AiStoryClient geminiAiStoryClient(AiStoryProperties properties, ObjectMapper objectMapper) {
        return new GeminiAiStoryClient(properties, objectMapper);
    }

    @Bean
    @ConditionalOnProperty(name = "ourspace.ai.provider", havingValue = "mock", matchIfMissing = true)
    public AiStoryClient mockAiStoryClient() {
        return new MockAiStoryClient();
    }
}

