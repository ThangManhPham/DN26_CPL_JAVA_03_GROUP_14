package com.ourspace.photo;

import com.ourspace.common.exception.ApiException;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.push.PhotoPushSender;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class PhotoService {
    private static final Logger log = LoggerFactory.getLogger(PhotoService.class);
    private static final long MAX_BYTES = 10 * 1024 * 1024;
    private final PhotoRepository photos;
    private final CoupleRepository couples;
    private final PhotoStorage storage;
    private final PhotoPushSender push;

    public PhotoService(PhotoRepository photos, CoupleRepository couples, PhotoStorage storage, PhotoPushSender push) {
        this.photos = photos;
        this.couples = couples;
        this.storage = storage;
        this.push = push;
    }

    public PhotoResponse upload(UUID userId, UUID requestId, MultipartFile file) {
        var couple = couples.findActiveCoupleByUserId(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.CONFLICT, "COUPLE_REQUIRED", "Pair with your partner before sharing photos."));
        var previous = photos.findBySenderIdAndClientRequestId(userId, requestId);
        if (previous.isPresent()) return replayForCurrentCouple(previous.get(), couple.getId());
        if (file == null || file.isEmpty() || file.getSize() > MAX_BYTES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PHOTO_SIZE", "Photo must be between 1 byte and 10 MB.");
        }
        String mime = file.getContentType();
        if (!"image/jpeg".equals(mime) && !"image/png".equals(mime)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PHOTO_TYPE", "Only JPEG and PNG photos are supported.");
        }
        UUID id = UUID.randomUUID();
        String key = id.toString();
        boolean uploaded = false;
        try {
            byte[] bytes = file.getBytes();
            if (bytes.length != file.getSize() || bytes.length > MAX_BYTES) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PHOTO_SIZE", "Photo must be between 1 byte and 10 MB.");
            }
            if (!validSignature(mime, bytes, bytes.length)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PHOTO_TYPE", "Photo content does not match its format.");
            }
            validateDecodedImage(bytes, mime);
            storage.put(key, bytes, mime);
            uploaded = true;
            var photo = photos.saveAndFlush(new Photo(id, couple.getId(), userId, requestId, key, mime, file.getSize()));
            try {
                push.photoShared(couple.getId(), userId, id);
            } catch (RuntimeException ex) {
                log.warn("Photo saved but push delivery could not be scheduled");
            }
            return PhotoResponse.from(photo);
        } catch (DataIntegrityViolationException ex) {
            if (uploaded) deleteQuietly(key);
            return photos.findBySenderIdAndClientRequestId(userId, requestId)
                    .map(photo -> replayForCurrentCouple(photo, couple.getId()))
                    .orElseThrow(() -> ex);
        } catch (IOException ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "PHOTO_STORAGE_ERROR", "Could not save photo.");
        } catch (RuntimeException ex) {
            if (uploaded) deleteQuietly(key);
            throw ex;
        }
    }

    public PhotoResponse latest(UUID userId) {
        var couple = couples.findActiveCoupleByUserId(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "PHOTO_NOT_FOUND", "No photo found."));
        return photos.findFirstByCoupleIdOrderByCreatedAtDesc(couple.getId())
                .map(PhotoResponse::from)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "PHOTO_NOT_FOUND", "No photo found."));
    }

    public Photo image(UUID userId, UUID photoId) {
        var couple = couples.findActiveCoupleByUserId(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "PHOTO_NOT_FOUND", "No photo found."));
        var photo = photos.findById(photoId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "PHOTO_NOT_FOUND", "No photo found."));
        if (!photo.getCoupleId().equals(couple.getId())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "PHOTO_NOT_FOUND", "No photo found.");
        }
        return photo;
    }

    public byte[] read(Photo photo) {
        try {
            return storage.get(photo.getStorageKey());
        } catch (RuntimeException ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "PHOTO_STORAGE_ERROR", "Could not read photo.");
        }
    }

    private static boolean validSignature(String mime, byte[] bytes, int count) {
        if ("image/jpeg".equals(mime)) return count >= 3 && (bytes[0] & 255) == 255 && (bytes[1] & 255) == 216 && (bytes[2] & 255) == 255;
        return count >= 8 && (bytes[0] & 255) == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71
                && bytes[4] == 13 && bytes[5] == 10 && bytes[6] == 26 && bytes[7] == 10;
    }

    private static void validateDecodedImage(byte[] bytes, String mime) {
        try (var stream = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
            var readers = ImageIO.getImageReaders(stream);
            if (!readers.hasNext()) throw new IOException("No image decoder");
            var reader = readers.next();
            try {
                reader.setInput(stream);
                String format = reader.getFormatName();
                if (!("image/png".equals(mime) && "png".equalsIgnoreCase(format)) &&
                    !("image/jpeg".equals(mime) && "jpeg".equalsIgnoreCase(format))) {
                    throw new IOException("Format mismatch");
                }
                long pixels = (long) reader.getWidth(0) * reader.getHeight(0);
                if (pixels < 1 || pixels > 16_000_000 || reader.read(0) == null) {
                    throw new IOException("Invalid dimensions or image data");
                }
            } finally {
                reader.dispose();
            }
        } catch (IOException | RuntimeException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PHOTO_TYPE", "Photo content is invalid.");
        }
    }

    private void deleteQuietly(String key) {
        try { storage.delete(key); } catch (RuntimeException ignored) { }
    }

    private static PhotoResponse replayForCurrentCouple(Photo photo, UUID coupleId) {
        if (!photo.getCoupleId().equals(coupleId)) {
            throw new ApiException(HttpStatus.CONFLICT, "PHOTO_REQUEST_REUSED", "This upload request was used in another couple.");
        }
        return PhotoResponse.from(photo);
    }

}
