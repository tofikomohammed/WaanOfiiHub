import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/core/errors/app_exception.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_repository.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_storage_service.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';
import 'package:waan_ofii_hub/features/blog/models/post_media.dart';

void main() {
  group('BlogRepository Unit Tests', () {
    test('safely handles uninitialized/null Supabase client without crashing', () async {
      final repo = BlogRepository(null);

      expect(repo.currentUserId, isNull);

      final published = await repo.getPublishedPosts();
      expect(published, isEmpty);

      final drafts = await repo.getMyDrafts();
      expect(drafts, isEmpty);

      final post = await repo.getPostById('non-existent');
      expect(post, isNull);

      final comments = await repo.getComments('non-existent');
      expect(comments, isEmpty);

      // Mutative calls should complete cleanly as no-ops
      await repo.toggleLike('p1', false);
      await repo.addComment('p1', 'Nice post');
      final newId = await repo.createPost(
        title: 'Title',
        body: 'Body',
        type: 'text',
      );
      expect(newId, isNull);

      await repo.updatePost(
        id: 'p1',
        title: 'New',
        body: 'New Body',
        type: 'text',
        category: 'news',
      );
      await repo.deletePost('p1');
      await repo.deletePostMedia('m1', 'path/to/media.jpg');
      await repo.updateMediaOrder([]);
      await repo.setPostCover('p1', 'https://cover.jpg');
      await repo.setPostStatus('p1', 'archived');
    });

    test('BlogPost separates imageMedia and audioMedia correctly', () {
      const media1 = PostMedia(
        id: '1',
        postId: 'p',
        kind: 'image',
        storagePath: 'p1.jpg',
        mime: 'image/jpeg',
        sizeBytes: 100,
        sortOrder: 2,
      );
      const media2 = PostMedia(
        id: '2',
        postId: 'p',
        kind: 'image',
        storagePath: 'p2.jpg',
        mime: 'image/jpeg',
        sizeBytes: 100,
        sortOrder: 1,
      );
      const media3 = PostMedia(
        id: '3',
        postId: 'p',
        kind: 'audio',
        storagePath: 'p3.mp3',
        mime: 'audio/mpeg',
        sizeBytes: 100,
      );

      final post = BlogPost(
        id: 'p',
        authorId: 'auth',
        type: 'image',
        title: 'Gallery Post',
        status: 'published',
        createdAt: DateTime.now(),
        media: [media1, media2, media3],
      );

      expect(post.imageMedia.length, 2);
      expect(post.imageMedia.first.id, '2'); // sorted by sortOrder asc
      expect(post.imageMedia.last.id, '1');
      expect(post.audioMedia.length, 1);
      expect(post.audioMedia.first.id, '3');
    });
  });

  group('BlogStorageService Validation Tests', () {
    test('validates image extensions and file sizes accurately', () {
      // Allowed formats
      expect(
        () => BlogStorageService.validateImageFile('photo.jpg', 1024),
        returnsNormally,
      );
      expect(
        () => BlogStorageService.validateImageFile('photo.jpeg', 1024),
        returnsNormally,
      );
      expect(
        () => BlogStorageService.validateImageFile('graphic.png', 1024),
        returnsNormally,
      );
      expect(
        () => BlogStorageService.validateImageFile('art.webp', 1024),
        returnsNormally,
      );

      // Disallowed formats throw AppException
      expect(
        () => BlogStorageService.validateImageFile('script.exe', 1024),
        throwsA(isA<AppException>()),
      );
      expect(
        () => BlogStorageService.validateImageFile('anim.gif', 1024),
        throwsA(isA<AppException>()),
      );

      // Size limit exceeding 10MB throws
      expect(
        () => BlogStorageService.validateImageFile('large.jpg', 11 * 1024 * 1024),
        throwsA(isA<AppException>()),
      );
    });

    test('validates audio extensions (MP3, M4A, WAV) and 25MB size limit', () {
      // Allowed formats
      expect(
        () => BlogStorageService.validateAudioFile('podcast.mp3', 2048),
        returnsNormally,
      );
      expect(
        () => BlogStorageService.validateAudioFile('voice.m4a', 2048),
        returnsNormally,
      );
      expect(
        () => BlogStorageService.validateAudioFile('recording.wav', 2048),
        returnsNormally,
      );

      // Disallowed audio formats
      expect(
        () => BlogStorageService.validateAudioFile('song.flac', 2048),
        throwsA(isA<AppException>()),
      );
      expect(
        () => BlogStorageService.validateAudioFile('audio.aiff', 2048),
        throwsA(isA<AppException>()),
      );

      // Size limit exceeding 25MB throws
      expect(
        () => BlogStorageService.validateAudioFile('huge.mp3', 26 * 1024 * 1024),
        throwsA(isA<AppException>()),
      );
    });

    test('enforces file size limits and throws AppException on uninitialized client', () async {
      final service = BlogStorageService(null);

      expect(BlogStorageService.maxImageSizeBytes, 10 * 1024 * 1024);
      expect(BlogStorageService.maxAudioSizeBytes, 25 * 1024 * 1024);

      expect(
        () => service.uploadAudio(
          authorId: 'auth-1',
          fileName: 'audio.mp3',
          bytes: Uint8List(100),
        ),
        throwsA(isA<AppException>()),
      );

      expect(
        () => service.pickAndUploadGalleryImages(authorId: 'auth-1'),
        throwsA(isA<AppException>()),
      );

      expect(
        () => service.pickAndUploadCoverImage(authorId: 'auth-1'),
        throwsA(isA<AppException>()),
      );
    });
  });
}
