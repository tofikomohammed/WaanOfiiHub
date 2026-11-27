import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/blog/models/post_media.dart';

void main() {
  group('PostMedia Model Tests', () {
    test('parses json correctly and computes public URL from supabaseUrl', () {
      final json = {
        'id': 'med-101',
        'post_id': 'post-555',
        'kind': 'image',
        'storage_path': 'author-1/gallery/123_photo.jpg',
        'mime': 'image/jpeg',
        'size_bytes': 1572864, // 1.5 MB
        'duration_seconds': null,
        'sort_order': 2,
      };

      final media = PostMedia.fromJson(
        json,
        supabaseUrl: 'https://xyz.supabase.co',
      );

      expect(media.id, 'med-101');
      expect(media.postId, 'post-555');
      expect(media.kind, 'image');
      expect(media.storagePath, 'author-1/gallery/123_photo.jpg');
      expect(
        media.publicUrl,
        'https://xyz.supabase.co/storage/v1/object/public/blog-media/author-1/gallery/123_photo.jpg',
      );
      expect(media.mime, 'image/jpeg');
      expect(media.sizeBytes, 1572864);
      expect(media.formattedSize, '1.5 MB');
      expect(media.formattedDuration, isNull);
      expect(media.sortOrder, 2);
    });

    test('formats audio duration correctly as MM:SS', () {
      const audioMedia = PostMedia(
        id: 'aud-1',
        postId: 'post-1',
        kind: 'audio',
        storagePath: 'author-1/audio/rec.mp3',
        mime: 'audio/mpeg',
        sizeBytes: 4500000,
        durationSeconds: 185, // 3m 5s
      );

      expect(audioMedia.formattedDuration, '03:05');
      expect(audioMedia.formattedSize, '4.3 MB');
    });

    test('formats smaller byte sizes accurately', () {
      const smallMedia = PostMedia(
        id: 'sm-1',
        postId: 'post-1',
        kind: 'image',
        storagePath: 'path.png',
        mime: 'image/png',
        sizeBytes: 512,
      );
      expect(smallMedia.formattedSize, '512 B');

      const kbMedia = PostMedia(
        id: 'kb-1',
        postId: 'post-1',
        kind: 'image',
        storagePath: 'path.png',
        mime: 'image/png',
        sizeBytes: 25600,
      );
      expect(kbMedia.formattedSize, '25.0 KB');
    });

    test('copyWith updates sort order and public url', () {
      const media = PostMedia(
        id: 'med-1',
        postId: 'post-1',
        kind: 'image',
        storagePath: 'p.jpg',
        mime: 'image/jpeg',
        sizeBytes: 1000,
        sortOrder: 0,
      );

      final updated = media.copyWith(
        sortOrder: 3,
        publicUrl: 'https://new.com/img.jpg',
      );
      expect(updated.sortOrder, 3);
      expect(updated.publicUrl, 'https://new.com/img.jpg');
      expect(updated.id, 'med-1');
    });
  });
}
