package com.ourspace.album;

import com.ourspace.album.dto.AlbumResponse;
import com.ourspace.album.dto.CreateAlbumRequest;
import com.ourspace.album.dto.UpdateAlbumRequest;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
import com.ourspace.album.service.AlbumService;
import com.ourspace.common.exception.ApiException;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.photo.Photo;
import com.ourspace.photo.PhotoRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class AlbumConcurrencyAndIntegrityTest {

    @Autowired private AlbumService albumService;
    @Autowired private AlbumRepository albumRepository;
    @Autowired private AlbumPhotoRepository albumPhotoRepository;
    @Autowired private PhotoRepository photoRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private CoupleRepository coupleRepository;
    @Autowired private CoupleMemberRepository memberRepository;

    private User userA;
    private User userB;
    private User userC;
    private CoupleEntity couple1;
    private CoupleEntity couple2;

    @BeforeEach
    void setUp() {
        albumPhotoRepository.deleteAll();
        albumRepository.deleteAll();
        photoRepository.deleteAll();
        memberRepository.deleteAll();
        coupleRepository.deleteAll();
        userRepository.deleteAll();

        userA = userRepository.save(new User("concur-a@example.com", "hash", "Alex"));
        userB = userRepository.save(new User("concur-b@example.com", "hash", "Sam"));
        userC = userRepository.save(new User("concur-c@example.com", "hash", "Charlie"));

        couple1 = coupleRepository.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        memberRepository.save(new CoupleMemberEntity(couple1, userA, "MEMBER"));
        memberRepository.save(new CoupleMemberEntity(couple1, userB, "MEMBER"));

        couple2 = coupleRepository.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        memberRepository.save(new CoupleMemberEntity(couple2, userC, "MEMBER"));
    }

    @AfterEach
    void tearDown() {
        albumPhotoRepository.deleteAll();
        albumRepository.deleteAll();
        photoRepository.deleteAll();
        memberRepository.deleteAll();
        coupleRepository.deleteAll();
        userRepository.deleteAll();
    }

    /**
     * THIẾT KẾ ĐẶC TẢ ĐỒNG THỜI (IDEMPOTENT SPECIFICATION):
     * Theo chuẩn RESTful API, phương thức PUT /api/v1/albums/{id}/photos/{photoId} là một thao tác có tính Idempotent.
     * Khi nhiều request đồng thời yêu cầu thêm cùng 1 ảnh vào album, tất cả các request đều phải hoàn thành
     * thành công (HTTP 200 OK / Idempotent Success), trả về trạng thái album nhất quán (photoCount = 1).
     * Để đảm bảo an toàn đa luồng và tương thích đồng thời trên cả PostgreSQL và H2 test:
     * - AlbumService sử dụng Pessimistic Write Lock trên AlbumEntity (SELECT ... FOR UPDATE)
     *   ngăn chặn triệt để race condition khi cập nhật photoCount, coverPhotoId và liên kết album_photos.
     * - Kiểm tra existsById() trong cùng transaction có khóa bảo đảm chỉ tạo 1 bản ghi duy nhất,
     *   tất cả các luồng đồng thời đều trả về thành công an toàn.
     */
    @Test
    @DisplayName("Thêm đồng thời cùng 1 ảnh vào album: đảm bảo 100% idempotent thành công, không nuốt lỗi")
    void concurrentAddSamePhoto_idempotentNoDuplicates() throws InterruptedException {
        AlbumResponse album = albumService.createAlbum(userA.getId(),
                new CreateAlbumRequest("Album đồng thời", null, null));

        UUID photoId = UUID.randomUUID();
        Photo photo = photoRepository.save(new Photo(photoId, couple1.getId(), userA.getId(),
                UUID.randomUUID(), "photo/key/p1.png", "image/png", 1024));

        int threadCount = 10;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threadCount);
        ConcurrentLinkedQueue<Throwable> exceptions = new ConcurrentLinkedQueue<>();
        AtomicInteger successCount = new AtomicInteger(0);

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    AlbumResponse res = albumService.addPhotoToAlbum(userA.getId(), album.id(), photoId);
                    if (res != null && res.photoCount() == 1) {
                        successCount.incrementAndGet();
                    }
                } catch (Throwable t) {
                    exceptions.add(t);
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        startLatch.countDown();
        boolean finished = doneLatch.await(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(finished).as("Tất cả các thread hoàn thành trong thời gian chờ").isTrue();
        assertThat(exceptions).as("Không có bất kỳ ngoại lệ bất ngờ nào xảy ra trong quá trình thêm đồng thời").isEmpty();
        assertThat(successCount.get()).as("Tất cả 10 request đồng thời đều nhận được phản hồi thành công idempotent").isEqualTo(threadCount);

        // Xác nhận chính xác 1 bản ghi duy nhất được lưu trong DB
        assertThat(albumPhotoRepository.countByIdAlbumId(album.id())).isEqualTo(1);
        assertThat(albumPhotoRepository.existsById(new AlbumPhotoId(album.id(), photoId))).isTrue();
    }

    /**
     * THIẾT KẾ ĐẶC TẢ ĐỒNG THỜI (DISTINCT PHOTOS CONCURRENCY):
     * Khi nhiều request đồng thời thêm các ảnh khác nhau vào cùng một album:
     * - Tất cả 10 request đều phải thành công mà không có bất kỳ ngoại lệ nào (loại bỏ catch-all nuốt lỗi).
     * - Tổng số liên kết ảnh được lưu chính xác bằng số luồng thực thi (10 ảnh).
     * - Batch query listAlbums tính toán photoCount chính xác mà không bị hiện tượng dirty reads hay mất dữ liệu.
     */
    @Test
    @DisplayName("Thêm đồng thời nhiều ảnh khác nhau: bắt lỗi thread-safe, ghi nhận đủ số lượng và batch count chính xác")
    void concurrentAddDifferentPhotos_accurateCountsAndBatchList() throws InterruptedException {
        AlbumResponse album = albumService.createAlbum(userA.getId(),
                new CreateAlbumRequest("Album nhiều ảnh đồng thời", null, null));

        int photoCount = 10;
        List<UUID> photoIds = new ArrayList<>();
        for (int i = 0; i < photoCount; i++) {
            UUID pid = UUID.randomUUID();
            photoRepository.save(new Photo(pid, couple1.getId(), userA.getId(),
                    UUID.randomUUID(), "photo/batch/" + i + ".png", "image/png", 1024 + i));
            photoIds.add(pid);
        }

        ExecutorService executor = Executors.newFixedThreadPool(photoCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(photoCount);
        ConcurrentLinkedQueue<Throwable> exceptions = new ConcurrentLinkedQueue<>();
        AtomicInteger successCount = new AtomicInteger(0);

        for (int i = 0; i < photoCount; i++) {
            final UUID pid = photoIds.get(i);
            executor.submit(() -> {
                try {
                    startLatch.await();
                    AlbumResponse res = albumService.addPhotoToAlbum(userA.getId(), album.id(), pid);
                    if (res != null) {
                        successCount.incrementAndGet();
                    }
                } catch (Throwable t) {
                    exceptions.add(t);
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        startLatch.countDown();
        boolean finished = doneLatch.await(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(finished).as("Tất cả các thread hoàn thành trong thời gian chờ").isTrue();
        assertThat(exceptions).as("Không có bất kỳ ngoại lệ nào xảy ra khi thêm các ảnh khác nhau").isEmpty();
        assertThat(successCount.get()).as("Tất cả 10 ảnh được thêm thành công").isEqualTo(photoCount);
        assertThat(albumPhotoRepository.countByIdAlbumId(album.id())).isEqualTo(photoCount);

        // Kiểm tra listAlbums batch count query hoạt động chính xác
        List<AlbumResponse> list = albumService.listAlbums(userA.getId());
        assertThat(list).hasSize(1);
        assertThat(list.get(0).photoCount()).isEqualTo(photoCount);
    }

    @Test
    @DisplayName("Toàn vẹn cùng cặp đôi: Từ chối ảnh của couple khác cả khi tạo và khi thêm")
    void sameCoupleIntegrity_strictlyEnforced() {
        // Ảnh thuộc Couple 2
        UUID crossPhotoId = UUID.randomUUID();
        photoRepository.save(new Photo(crossPhotoId, couple2.getId(), userC.getId(),
                UUID.randomUUID(), "photo/cross/c2.png", "image/png", 1024));

        // 1. Thử tạo album với coverPhoto thuộc Couple 2
        assertThatThrownBy(() -> albumService.createAlbum(userA.getId(),
                new CreateAlbumRequest("Album vi phạm", null, crossPhotoId)))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("CROSS_COUPLE_PHOTO");
                });

        // 2. Tạo album hợp lệ
        AlbumResponse album = albumService.createAlbum(userA.getId(),
                new CreateAlbumRequest("Album hợp lệ", null, null));

        // 3. Thử thêm ảnh thuộc Couple 2 vào album
        assertThatThrownBy(() -> albumService.addPhotoToAlbum(userA.getId(), album.id(), crossPhotoId))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("CROSS_COUPLE_PHOTO");
                });

        // 4. Thử cập nhật coverPhoto thành ảnh thuộc Couple 2
        assertThatThrownBy(() -> albumService.updateAlbum(userA.getId(), album.id(),
                new UpdateAlbumRequest("Album đổi tên", null, crossPhotoId)))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("CROSS_COUPLE_PHOTO");
                });

        // Verify zero photos in album
        assertThat(albumPhotoRepository.countByIdAlbumId(album.id())).isEqualTo(0);
    }

    @Test
    @DisplayName("Toàn vẹn Cover Photo: Cover photo luôn là thành viên hợp lệ của album")
    void coverPhotoIntegrity_lifecycleConsistency() {
        AlbumResponse album = albumService.createAlbum(userA.getId(),
                new CreateAlbumRequest("Album vòng đời cover", null, null));
        assertThat(album.coverPhotoId()).isNull();

        UUID p1 = UUID.randomUUID();
        UUID p2 = UUID.randomUUID();
        photoRepository.save(new Photo(p1, couple1.getId(), userA.getId(), UUID.randomUUID(), "k1", "image/png", 10));
        photoRepository.save(new Photo(p2, couple1.getId(), userA.getId(), UUID.randomUUID(), "k2", "image/png", 10));

        // Thêm P1 -> Tự động trở thành cover photo
        AlbumResponse res1 = albumService.addPhotoToAlbum(userA.getId(), album.id(), p1);
        assertThat(res1.coverPhotoId()).isEqualTo(p1);

        // Thêm P2 -> P1 vẫn là cover photo
        AlbumResponse res2 = albumService.addPhotoToAlbum(userA.getId(), album.id(), p2);
        assertThat(res2.coverPhotoId()).isEqualTo(p1);

        // Xóa P1 -> P2 tự động được chọn làm cover photo thay thế
        AlbumResponse res3 = albumService.removePhotoFromAlbum(userA.getId(), album.id(), p1);
        assertThat(res3.coverPhotoId()).isEqualTo(p2);

        // Xóa P2 -> Cover photo chuyển về null vì album rỗng
        AlbumResponse res4 = albumService.removePhotoFromAlbum(userA.getId(), album.id(), p2);
        assertThat(res4.coverPhotoId()).isNull();
        assertThat(res4.photoCount()).isEqualTo(0);
    }
}
