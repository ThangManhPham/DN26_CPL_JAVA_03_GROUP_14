package com.ourspace.album.story.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import com.ourspace.common.exception.ApiException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.io.IOException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class GeminiAiStoryClientTest {

    @Mock
    private HttpClient httpClient;

    @Mock
    private HttpResponse<String> httpResponse;

    private ObjectMapper objectMapper;
    private AiStoryProperties properties;
    private GeminiAiStoryClient client;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        properties = new AiStoryProperties();
        properties.setProvider("gemini");
        properties.setApiKey("test-secret-gemini-api-key");
        properties.setModel("gemini-2.0-flash");
        properties.setTimeoutMs(10000);
        properties.setMaxTokens(1000);

        client = new GeminiAiStoryClient(properties, objectMapper, httpClient);
    }

    @Test
    @DisplayName("generateStory parses valid Gemini JSON response correctly")
    void generateStory_ValidResponse_ParsesCorrectly() throws Exception {
        String geminiResponseBody = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\"title\\": \\"Chuyến Đi Đà Lạt\\", \\"story\\": \\"Một ngày mưa lãng mạn...\\", \\"highlights\\": [\\"Cà phê sương mù\\", \\"Đồi thông\\"], \\"tone\\": \\"ROMANTIC\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        when(httpResponse.statusCode()).thenReturn(200);
        when(httpResponse.body()).thenReturn(geminiResponseBody);
        doReturn(httpResponse).when(httpClient).send(any(HttpRequest.class), any());

        AiGeneratedStoryDto result = client.generateStory("Đà Lạt", 3, List.of("2026-04-10"), "Mưa lạnh", "ROMANTIC");

        assertThat(result.title()).isEqualTo("Chuyến Đi Đà Lạt");
        assertThat(result.story()).isEqualTo("Một ngày mưa lãng mạn...");
        assertThat(result.highlights()).containsExactly("Cà phê sương mù", "Đồi thông");
        assertThat(result.tone()).isEqualTo("ROMANTIC");
    }

    @Test
    @DisplayName("generateStory throws AI_NOT_CONFIGURED when apiKey is missing or blank")
    void generateStory_MissingApiKey_ThrowsServiceUnavailable() {
        properties.setApiKey("   ");
        client = new GeminiAiStoryClient(properties, objectMapper, httpClient);

        assertThatThrownBy(() -> client.generateStory("Album", 1, List.of(), "Notes", "ROMANTIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(apiEx.code()).isEqualTo("AI_NOT_CONFIGURED");
                });
    }

    @Test
    @DisplayName("generateStory handles HTTP 429 Too Many Requests cleanly")
    void generateStory_Http429_ThrowsRateLimitException() throws Exception {
        when(httpResponse.statusCode()).thenReturn(429);
        doReturn(httpResponse).when(httpClient).send(any(HttpRequest.class), any());

        assertThatThrownBy(() -> client.generateStory("Album", 2, List.of(), "Notes", "NOSTALGIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(apiEx.code()).isEqualTo("AI_RATE_LIMIT");
                });
    }

    @Test
    @DisplayName("generateStory handles HTTP 500 error from provider")
    void generateStory_Http500_ThrowsBadGateway() throws Exception {
        when(httpResponse.statusCode()).thenReturn(500);
        doReturn(httpResponse).when(httpClient).send(any(HttpRequest.class), any());

        assertThatThrownBy(() -> client.generateStory("Album", 2, List.of(), "Notes", "NOSTALGIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(apiEx.code()).isEqualTo("AI_PROVIDER_ERROR");
                });
    }

    @Test
    @DisplayName("generateStory handles timeout with GATEWAY_TIMEOUT and AI_TIMEOUT")
    void generateStory_Timeout_ThrowsGatewayTimeout() throws Exception {
        when(httpClient.send(any(HttpRequest.class), any()))
                .thenThrow(new HttpTimeoutException("Request timed out"));

        assertThatThrownBy(() -> client.generateStory("Album", 2, List.of(), "Notes", "NOSTALGIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.GATEWAY_TIMEOUT);
                    assertThat(apiEx.code()).isEqualTo("AI_TIMEOUT");
                });
    }

    @Test
    @DisplayName("generateStory handles network exception without leaking secret API key or URL")
    void generateStory_NetworkException_DoesNotLeakSensitiveInfo() throws Exception {
        when(httpClient.send(any(HttpRequest.class), any()))
                .thenThrow(new IOException("Connect to https://generativelanguage.googleapis.com/...key=test-secret-gemini-api-key failed"));

        assertThatThrownBy(() -> client.generateStory("Album", 2, List.of(), "Notes", "NOSTALGIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
                    assertThat(apiEx.code()).isEqualTo("AI_CALL_FAILED");
                    assertThat(apiEx.getMessage()).doesNotContain("test-secret-gemini-api-key");
                    assertThat(apiEx.getMessage()).doesNotContain("generativelanguage.googleapis.com");
                });
    }

    @Test
    @DisplayName("parseGeminiResponse strips markdown fences from LLM output")
    void parseGeminiResponse_MarkdownWrappedJson_ParsesSuccessfully() {
        String wrappedJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "```json\\n{\\"title\\": \\"Hà Nội Thu\\", \\"story\\": \\"Hồ Gươm gió lạnh...\\", \\"highlights\\": [\\"Gió mùa\\"], \\"tone\\": \\"POETIC\\"}\\n```"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        AiGeneratedStoryDto dto = client.parseGeminiResponse(wrappedJson, "POETIC");
        assertThat(dto.title()).isEqualTo("Hà Nội Thu");
        assertThat(dto.story()).isEqualTo("Hồ Gươm gió lạnh...");
        assertThat(dto.highlights()).containsExactly("Gió mùa");
        assertThat(dto.tone()).isEqualTo("POETIC");
    }

    @Test
    @DisplayName("parseGeminiResponse throws AI_INVALID_RESPONSE when title is missing")
    void parseGeminiResponse_MissingTitle_ThrowsInvalidResponse() {
        String missingTitleJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\"story\\": \\"Thiếu tiêu đề...\\", \\"highlights\\": [\\"H1\\"]}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        assertThatThrownBy(() -> client.parseGeminiResponse(missingTitleJson, "ROMANTIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(apiEx.code()).isEqualTo("AI_INVALID_RESPONSE");
                });
    }

    @Test
    @DisplayName("parseGeminiResponse throws AI_INVALID_RESPONSE when story is missing")
    void parseGeminiResponse_MissingStory_ThrowsInvalidResponse() {
        String missingStoryJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\"title\\": \\"Tiêu đề có sẵn\\", \\"highlights\\": [\\"H1\\"]}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        assertThatThrownBy(() -> client.parseGeminiResponse(missingStoryJson, "ROMANTIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(apiEx.code()).isEqualTo("AI_INVALID_RESPONSE");
                });
    }

    @Test
    @DisplayName("parseGeminiResponse throws AI_INVALID_RESPONSE when highlights is not an array")
    void parseGeminiResponse_HighlightsNotArray_ThrowsInvalidResponse() {
        String invalidHighlightsJson = """
                {
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\"title\\": \\"T\\", \\"story\\": \\"S\\", \\"highlights\\": \\"Khong phai array\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;

        assertThatThrownBy(() -> client.parseGeminiResponse(invalidHighlightsJson, "ROMANTIC"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(apiEx.code()).isEqualTo("AI_INVALID_RESPONSE");
                });
    }
}
