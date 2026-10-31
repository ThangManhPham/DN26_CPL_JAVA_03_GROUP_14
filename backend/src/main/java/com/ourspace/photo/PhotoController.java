package com.ourspace.photo;

import com.ourspace.security.SecurityUtils;
import java.util.UUID;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/photos")
public class PhotoController {
    private final PhotoService service;
    public PhotoController(PhotoService service) { this.service = service; }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<PhotoResponse> upload(Authentication auth,
            @RequestHeader("Idempotency-Key") UUID requestId,
            @RequestPart("file") MultipartFile file) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.upload(SecurityUtils.resolveUserId(auth), requestId, file));
    }

    @GetMapping("/latest")
    public PhotoResponse latest(Authentication auth) {
        return service.latest(SecurityUtils.resolveUserId(auth));
    }

    @GetMapping("/{id}/image")
    public ResponseEntity<byte[]> image(Authentication auth, @PathVariable UUID id) {
        Photo photo = service.image(SecurityUtils.resolveUserId(auth), id);
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
                .contentType(MediaType.parseMediaType(photo.getMimeType()))
                .body(service.read(photo));
    }
}
