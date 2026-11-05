package com.ourspace.photo;

public interface PhotoStorage {
    void put(String key, byte[] bytes, String mimeType);
    byte[] get(String key);
    void delete(String key);
}
