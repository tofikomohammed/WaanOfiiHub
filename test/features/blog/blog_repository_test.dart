import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/core/errors/app_exception.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_repository.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_storage_service.dart';

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
      await repo.setPostStatus('p1', 'archived');
    });
  });

  group('BlogStorageService Validation Tests', () {
    test('enforces file size limits and throws AppException on uninitialized client', () async {
      final service = BlogStorageService(null);

      expect(BlogStorageService.maxImageSizeBytes, 5 * 1024 * 1024);
      expect(BlogStorageService.maxAudioSizeBytes, 20 * 1024 * 1024);

      // Throws on uninitialized client
      expect(
        () => service.uploadImageBytes(
          authorId: 'auth-1',
          fileName: 'pic.jpg',
          bytes: Uint8List(100),
        ),
        throwsA(isA<AppException>()),
      );

      expect(
        () => service.uploadAudioBytes(
          authorId: 'auth-1',
          fileName: 'audio.mp3',
          bytes: Uint8List(100),
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
