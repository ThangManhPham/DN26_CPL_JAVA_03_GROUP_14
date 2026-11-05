package com.ourspace.photo;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("test")
public class TestPhotoStorage implements PhotoStorage {
    private final Map<String, byte[]> objects = new ConcurrentHashMap<>();
    @Override public void put(String key, byte[] bytes, String mimeType) { objects.put(key, bytes); }
    @Override public byte[] get(String key) { return objects.get(key); }
    @Override public void delete(String key) { objects.remove(key); }
}
