import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/admin/presentation/admin_media_screen.dart';
import 'package:waan_ofii_hub/features/blog/models/post_media.dart';
import 'package:waan_ofii_hub/features/blog/presentation/widgets/audio_player_widget.dart';
import 'package:waan_ofii_hub/features/blog/presentation/widgets/multi_image_gallery_widget.dart';

void main() {
  group('MultiImageGalleryWidget Tests', () {
    testWidgets('renders single image cleanly without ribbon', (tester) async {
      const singleImage = [
        PostMedia(
          id: '1',
          postId: 'p',
          kind: 'image',
          storagePath: 'author/img1.jpg',
          publicUrl: 'https://example.com/img1.jpg',
          mime: 'image/jpeg',
          sizeBytes: 1000,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MultiImageGalleryWidget(images: singleImage),
          ),
        ),
      );

      // Verify no multiple images counter
      expect(find.text('1 / 1'), findsNothing);
    });

    testWidgets('renders multiple images with counter pill and thumbnail ribbon',
        (tester) async {
      const multiImages = [
        PostMedia(
          id: '1',
          postId: 'p',
          kind: 'image',
          storagePath: 'author/img1.jpg',
          publicUrl: 'https://example.com/img1.jpg',
          mime: 'image/jpeg',
          sizeBytes: 1000,
          sortOrder: 0,
        ),
        PostMedia(
          id: '2',
          postId: 'p',
          kind: 'image',
          storagePath: 'author/img2.jpg',
          publicUrl: 'https://example.com/img2.jpg',
          mime: 'image/jpeg',
          sizeBytes: 2000,
          sortOrder: 1,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MultiImageGalleryWidget(images: multiImages),
          ),
        ),
      );

      // Verify counter pill
      expect(find.text('1 / 2'), findsOneWidget);

      // Verify thumbnail ribbon
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('AudioPlayerWidget Tests', () {
    testWidgets('renders title, play button and playback speed button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(
              audioUrl: 'https://example.com/audio.mp3',
              title: 'Community Health Podcast',
            ),
          ),
        ),
      );

      expect(find.text('Community Health Podcast'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget); // Default speed
      expect(find.byType(Slider), findsOneWidget);

      // Tap speed button to cycle
      await tester.tap(find.text('1.0x'));
      await tester.pump();

      expect(find.text('1.25x'), findsOneWidget);
    });
  });

  group('AdminMediaScreen Tests', () {
    testWidgets('renders filter chips and empty state when bucket is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminMediaListProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: AdminMediaScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Media Manager'), findsOneWidget);
      expect(find.text('All Files'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('No Media Files Found'), findsOneWidget);
    });
  });
}
