package com.ourspace.photo;

import java.net.URI;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Component
@Profile("!test")
public class S3PhotoStorage implements PhotoStorage {
    private final S3Client s3;
    private final String bucket;

    public S3PhotoStorage(@Value("${ourspace.photos.s3.endpoint}") String endpoint,
                          @Value("${ourspace.photos.s3.region:us-east-1}") String region,
                          @Value("${ourspace.photos.s3.access-key}") String accessKey,
                          @Value("${ourspace.photos.s3.secret-key}") String secretKey,
                          @Value("${ourspace.photos.s3.bucket:ourspace-photos}") String bucket) {
        this.s3 = S3Client.builder()
                .endpointOverride(URI.create(endpoint))
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKey, secretKey)))
                .forcePathStyle(true)
                .build();
        this.bucket = bucket;
    }

    @Override public void put(String key, byte[] bytes, String mimeType) {
        s3.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType(mimeType).build(), RequestBody.fromBytes(bytes));
    }
    @Override public byte[] get(String key) {
        return s3.getObjectAsBytes(GetObjectRequest.builder().bucket(bucket).key(key).build()).asByteArray();
    }
    @Override public void delete(String key) {
        s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
    }
}
