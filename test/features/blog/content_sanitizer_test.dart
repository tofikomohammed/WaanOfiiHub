import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/blog/utils/content_sanitizer.dart';

void main() {
  group('ContentSanitizer Unit Tests', () {
    test('sanitizeTitle strips HTML, removes control characters, collapses whitespace and limits to 200 chars', () {
      const malicious =
          '<h1>Community Alert!</h1> <script>alert("xss")</script> \x00\x08 Breaking News!   ';
      final clean = ContentSanitizer.sanitizeTitle(malicious);
      expect(clean, 'Community Alert! alert("xss") Breaking News!');

      // Truncation check
      final longTitle = List.generate(50, (_) => 'SuperLongWord').join(' ');
      final truncated = ContentSanitizer.sanitizeTitle(longTitle);
      expect(truncated.length, lessThanOrEqualTo(200));
    });

    test(
      'sanitizeComment strips HTML tags and caps length at 1000 characters',
      () {
        const comment = '<b>Great post!</b> Visit <a href="evil.com">here</a>.';
        final clean = ContentSanitizer.sanitizeComment(comment);
        expect(clean, 'Great post! Visit here.');

        final longComment = 'A' * 1500;
        final capped = ContentSanitizer.sanitizeComment(longComment);
        expect(capped.length, 1000);
      },
    );

    test('sanitizeTag normalizes to lowercase, removes punctuation and limits to 30 chars', () {
      expect(ContentSanitizer.sanitizeTag('#Flutter!'), 'flutter');
      expect(
        ContentSanitizer.sanitizeTag(' AI & Machine-Learning '),
        'ai-machine-learning',
      );
      expect(
        ContentSanitizer.sanitizeTag(
          'SuperDuperExtraExtremelyLongTagWordExceedingThirty',
        ),
        hasLength(30),
      );
    });

    test('sanitizeTags strips duplicates and empty entries', () {
      final tags = ['#flutter', 'Flutter', 'dart', '', '  ', 'AI-ML'];
      final cleaned = ContentSanitizer.sanitizeTags(tags);
      expect(cleaned, ['flutter', 'dart', 'ai-ml']);
    });
  });
}
