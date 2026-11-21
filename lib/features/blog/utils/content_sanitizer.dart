/// Utility to validate and sanitize user-generated content for blog posts, comments, and tags.
class ContentSanitizer {
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>', multiLine: true);
  static final RegExp _controlCharsRegex = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// Sanitizes post title: strips HTML, strips control characters, collapses whitespace, limits to 200 chars.
  static String sanitizeTitle(String raw) {
    var cleaned = raw
        .replaceAll(_htmlTagRegex, '')
        .replaceAll(_controlCharsRegex, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length > 200) {
      cleaned = cleaned.substring(0, 200).trim();
    }
    return cleaned;
  }

  /// Sanitizes post body: removes null bytes and control chars, preserves formatting, trims.
  static String sanitizeBody(String raw) {
    var cleaned = raw.replaceAll(_controlCharsRegex, '').trim();
    if (cleaned.length > 50000) {
      cleaned = cleaned.substring(0, 50000).trim();
    }
    return cleaned;
  }

  /// Sanitizes comment body: strips HTML, strips control chars, enforces max 1000 chars.
  static String sanitizeComment(String raw) {
    var cleaned = raw
        .replaceAll(_htmlTagRegex, '')
        .replaceAll(_controlCharsRegex, '')
        .trim();
    if (cleaned.length > 1000) {
      cleaned = cleaned.substring(0, 1000).trim();
    }
    return cleaned;
  }

  /// Sanitizes individual tag: lowercases, converts spaces/punctuation to hyphens, limits to 30 chars.
  static String sanitizeTag(String raw) {
    var cleaned = raw
        .replaceAll('#', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .trim()
        .toLowerCase();
    if (cleaned.length > 30) {
      cleaned = cleaned.substring(0, 30);
    }
    return cleaned;
  }

  /// Sanitizes list of tags and eliminates duplicates.
  static List<String> sanitizeTags(List<String> rawTags) {
    final result = <String>{};
    for (final tag in rawTags) {
      final cleaned = sanitizeTag(tag);
      if (cleaned.isNotEmpty) {
        result.add(cleaned);
      }
    }
    return result.toList();
  }
}
