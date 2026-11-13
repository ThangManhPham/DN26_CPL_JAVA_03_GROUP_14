import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/state/auth_controller.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/data/album_repository.dart';
import 'package:mobile/data/photo_repository.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/pairing/data/pairing_repository.dart';
import 'package:mobile/features/timeline/data/timeline_repository.dart';
import 'package:mobile/main.dart';

/// Dựng app M2 với repository mock, độ trễ = 0 để widget test chạy ổn định.
class AppHarness {
  AppHarness._({
    required this.client,
    required this.auth,
    required this.authRepository,
    required this.couples,
    required this.timeline,
    required this.photos,
    required this.albums,
  });

  factory AppHarness({
    int photoCount = 23,
    MockTimelineScenario timelineScenario = MockTimelineScenario.success,
    bool failReaction = false,
  }) {
    // Xóa trạng thái static để các test không bị ảnh hưởng lẫn nhau.
    MockAuthRepository.clear();
    MockCoupleRepository.clear();
    MockTimelineRepository.clear();

    final client = ApiClient(baseUrl: 'http://localhost:8080');
    final authRepository = MockAuthRepository(latency: Duration.zero)
      ..seed(
        email: 'alex@ourspace.dev',
        password: 'Password123!',
        displayName: 'Alex',
      )
      ..seed(
        email: 'sam@ourspace.dev',
        password: 'Password123!',
        displayName: 'Sam',
      );
    final auth = AuthController(
      repository: authRepository,
      storage: InMemoryTokenStorage(),
      onTokenChanged: (token) => client.token = token,
    );
    client.onUnauthenticated = auth.forceLogout;
    return AppHarness._(
      client: client,
      auth: auth,
      authRepository: authRepository,
      couples: MockCoupleRepository(
        currentUser: () => auth.user,
        latency: Duration.zero,
      ),
      timeline: MockTimelineRepository(
        photoCount: photoCount,
        latency: Duration.zero,
        scenario: timelineScenario,
        failReaction: failReaction,
        currentUserId: () => auth.user?.id ?? 'mock-me',
      ),
      photos: MockPhotoRepository(),
      albums: MockAlbumRepository(),
    );
  }

  final ApiClient client;
  final AuthController auth;
  final MockAuthRepository authRepository;
  final MockCoupleRepository couples;
  final MockTimelineRepository timeline;
  final MockPhotoRepository photos;
  final MockAlbumRepository albums;

  Widget get app => OurSpaceApp(
    auth: auth,
    couples: couples,
    timeline: timeline,
    photos: photos,
    albums: albums,
  );
}
