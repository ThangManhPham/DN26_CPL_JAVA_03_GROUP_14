package com.ourspace.album.controller;

import com.ourspace.album.dto.AlbumDetailResponse;
import com.ourspace.album.dto.AlbumResponse;
import com.ourspace.album.dto.CreateAlbumRequest;
import com.ourspace.album.dto.UpdateAlbumRequest;
import com.ourspace.album.service.AlbumService;
import com.ourspace.photo.PhotoResponse;
import com.ourspace.security.SecurityUtils;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/albums")
public class AlbumController {

    private final AlbumService albumService;

    public AlbumController(AlbumService albumService) {
        this.albumService = albumService;
    }

    @PostMapping
    public ResponseEntity<AlbumResponse> createAlbum(
            Authentication auth,
            @Valid @RequestBody CreateAlbumRequest request) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        AlbumResponse response = albumService.createAlbum(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping
    public List<AlbumResponse> listAlbums(Authentication auth) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return albumService.listAlbums(userId);
    }

    @GetMapping("/available-photos")
    public List<PhotoResponse> getAvailablePhotos(Authentication auth) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return albumService.getAvailablePhotos(userId);
    }

    @GetMapping("/{id}")
    public AlbumDetailResponse getAlbumDetail(
            Authentication auth,
            @PathVariable UUID id) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return albumService.getAlbumDetail(userId, id);
    }

    @PutMapping("/{id}/photos/{photoId}")
    public AlbumResponse addPhotoToAlbum(
            Authentication auth,
            @PathVariable UUID id,
            @PathVariable UUID photoId) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return albumService.addPhotoToAlbum(userId, id, photoId);
    }

    @DeleteMapping("/{id}/photos/{photoId}")
    public AlbumResponse removePhotoFromAlbum(
            Authentication auth,
            @PathVariable UUID id,
            @PathVariable UUID photoId) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return albumService.removePhotoFromAlbum(userId, id, photoId);
    }

    @PutMapping("/{id}")
    public AlbumResponse updateAlbum(
            Authentication auth,
            @PathVariable UUID id,
            @Valid @RequestBody UpdateAlbumRequest request) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return albumService.updateAlbum(userId, id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAlbum(
            Authentication auth,
            @PathVariable UUID id) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        albumService.deleteAlbum(userId, id);
    }
}
