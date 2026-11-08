package com.ourspace.album.story.ai;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "ourspace.ai")
public class AiStoryProperties {

    private String provider = "gemini";
    private String apiKey = "";
    private String model = "gemini-1.5-flash";
    private int timeoutMs = 15000;
    private int maxTokens = 1024;
    private int rateLimitWindowMinutes = 10;
    private int maxDraftsPerWindow = 5;

    public String getProvider() { return provider; }
    public void setProvider(String provider) { this.provider = provider; }
    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }
    public int getTimeoutMs() { return timeoutMs; }
    public void setTimeoutMs(int timeoutMs) { this.timeoutMs = timeoutMs; }
    public int getMaxTokens() { return maxTokens; }
    public void setMaxTokens(int maxTokens) { this.maxTokens = maxTokens; }
    public int getRateLimitWindowMinutes() { return rateLimitWindowMinutes; }
    public void setRateLimitWindowMinutes(int rateLimitWindowMinutes) { this.rateLimitWindowMinutes = rateLimitWindowMinutes; }
    public int getMaxDraftsPerWindow() { return maxDraftsPerWindow; }
    public void setMaxDraftsPerWindow(int maxDraftsPerWindow) { this.maxDraftsPerWindow = maxDraftsPerWindow; }
}

