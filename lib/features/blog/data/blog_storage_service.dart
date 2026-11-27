import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';

class UploadedMediaItem {
  final String storagePath;
  final String publicUrl;
  final String? thumbnailUrl;
  final String kind; // 'image', 'audio'
  final String mime;
  final int sizeBytes;
  final int? durationSeconds;

  const UploadedMediaItem({
    required this.storagePath,
    required this.publicUrl,
    this.thumbnailUrl,
    required this.kind,
    required this.mime,
    required this.sizeBytes,
    this.durationSeconds,
  });
}

class BlogStorageService {
  final SupabaseClient? _client;
  final ImagePicker _picker;

  BlogStorageService(this._client, [ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB raw limit
  static const int maxAudioSizeBytes = 25 * 1024 * 1024; // 25 MB audio limit

  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];
  static const List<String> allowedAudioExtensions = ['mp3', 'm4a', 'wav'];

  static const Map<String, String> imageMimeMap = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const Map<String, String> audioMimeMap = {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'wav': 'audio/wav',
  };

  String get supabaseUrl => EnvConfig.supabaseUrl;

  /// Upload raw image bytes to Supabase storage.
  Future<String> uploadImageBytes({
    required String authorId,
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (_client == null) throw const AppException('Supabase not initialized.');
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$authorId/${timestamp}_$sanitizedName';
    await _client.storage
        .from('blog-media')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return _client.storage.from('blog-media').getPublicUrl(storagePath);
  }

  /// Validates file extension against allowed lists
  static void validateImageFile(String fileName, int sizeBytes) {
    final ext = fileName.split('.').last.toLowerCase();
    if (!allowedImageExtensions.contains(ext)) {
      throw AppException(
        'Invalid image format: .$ext. Only JPG, PNG, and WebP are supported.',
      );
    }
    if (sizeBytes > maxImageSizeBytes) {
      throw const AppException('Image exceeds the 10MB maximum size limit.');
    }
  }

  /// Validates audio file extension against allowed lists
  static void validateAudioFile(String fileName, int sizeBytes) {
    final ext = fileName.split('.').last.toLowerCase();
    if (!allowedAudioExtensions.contains(ext)) {
      throw AppException(
        'Invalid audio format: .$ext. Only MP3, M4A, and WAV are supported.',
      );
    }
    if (sizeBytes > maxAudioSizeBytes) {
      throw const AppException('Audio exceeds the 25MB maximum size limit.');
    }
  }

  /// Compress and resize image bytes on client before upload
  Future<Uint8List> compressImageBytes(
    Uint8List rawBytes,
    String format,
  ) async {
    if (kIsWeb) {
      // On web, browser canvas already processed via ImagePicker maxWidth/maxHeight/quality
      return rawBytes;
    }

    try {
      CompressFormat compressFormat = CompressFormat.jpeg;
      if (format.toLowerCase() == 'png') {
        compressFormat = CompressFormat.png;
      } else if (format.toLowerCase() == 'webp') {
        compressFormat = CompressFormat.webp;
      }

      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 1600,
        minHeight: 1200,
        quality: 80,
        format: compressFormat,
      );
      return compressed.isNotEmpty ? compressed : rawBytes;
    } catch (_) {
      return rawBytes;
    }
  }

  /// Generate a small thumbnail from image bytes
  Future<Uint8List> generateThumbnailBytes(Uint8List rawBytes) async {
    if (kIsWeb) return rawBytes;
    try {
      final thumb = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 320,
        minHeight: 320,
        quality: 65,
        format: CompressFormat.jpeg,
      );
      return thumb.isNotEmpty ? thumb : rawBytes;
    } catch (_) {
      return rawBytes;
    }
  }

  /// Pick multiple images from gallery with validation and compression
  Future<List<UploadedMediaItem>> pickAndUploadGalleryImages({
    required String authorId,
    Function(double progress, String status)? onProgress,
  }) async {
    if (_client == null) throw const AppException('Supabase not initialized.');

    final images = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (images.isEmpty) return [];

    final results = <UploadedMediaItem>[];
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      onProgress?.call((i + 0.2) / images.length, 'Processing ${img.name}...');

      final rawBytes = await img.readAsBytes();
      final ext = img.name.split('.').last.toLowerCase();
      validateImageFile(img.name, rawBytes.lengthInBytes);

      final mimeType = imageMimeMap[ext] ?? 'image/jpeg';
      final compressedBytes = await compressImageBytes(rawBytes, ext);
      final sanitizedName = img.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$authorId/gallery/${timestamp}_$sanitizedName';

      onProgress?.call((i + 0.6) / images.length, 'Uploading ${img.name}...');

      await _client.storage
          .from('blog-media')
          .uploadBinary(
            storagePath,
            compressedBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      final publicUrl = _client.storage
          .from('blog-media')
          .getPublicUrl(storagePath);

      // Generate and upload thumbnail
      String? thumbUrl;
      try {
        final thumbBytes = await generateThumbnailBytes(compressedBytes);
        final thumbPath = '$authorId/thumbs/thumb_${timestamp}_$sanitizedName';
        await _client.storage
            .from('blog-media')
            .uploadBinary(
              thumbPath,
              thumbBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        thumbUrl = _client.storage.from('blog-media').getPublicUrl(thumbPath);
      } catch (_) {}

      results.add(
        UploadedMediaItem(
          storagePath: storagePath,
          publicUrl: publicUrl,
          thumbnailUrl: thumbUrl,
          kind: 'image',
          mime: mimeType,
          sizeBytes: compressedBytes.lengthInBytes,
        ),
      );
    }

    onProgress?.call(1.0, 'Upload complete!');
    return results;
  }

  /// Pick single cover image from gallery or camera
  Future<UploadedMediaItem?> pickAndUploadCoverImage({
    required String authorId,
    ImageSource source = ImageSource.gallery,
    Function(double progress, String status)? onProgress,
  }) async {
    if (_client == null) throw const AppException('Supabase not initialized.');

    final img = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (img == null) return null;

    onProgress?.call(0.2, 'Compressing cover image...');
    final rawBytes = await img.readAsBytes();
    final ext = img.name.split('.').last.toLowerCase();
    validateImageFile(img.name, rawBytes.lengthInBytes);

    final mimeType = imageMimeMap[ext] ?? 'image/jpeg';
    final compressedBytes = await compressImageBytes(rawBytes, ext);
    final sanitizedName = img.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$authorId/${timestamp}_$sanitizedName';

    onProgress?.call(0.6, 'Uploading cover image...');
    await _client.storage
        .from('blog-media')
        .uploadBinary(
          storagePath,
          compressedBytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    final publicUrl = _client.storage
        .from('blog-media')
        .getPublicUrl(storagePath);

    // Thumbnail upload
    String? thumbUrl;
    try {
      final thumbBytes = await generateThumbnailBytes(compressedBytes);
      final thumbPath = '$authorId/thumbs/thumb_${timestamp}_$sanitizedName';
      await _client.storage
          .from('blog-media')
          .uploadBinary(
            thumbPath,
            thumbBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      thumbUrl = _client.storage.from('blog-media').getPublicUrl(thumbPath);
    } catch (_) {}

    onProgress?.call(1.0, 'Done!');
    return UploadedMediaItem(
      storagePath: storagePath,
      publicUrl: publicUrl,
      thumbnailUrl: thumbUrl,
      kind: 'image',
      mime: mimeType,
      sizeBytes: compressedBytes.lengthInBytes,
    );
  }

  /// Upload raw audio file with validation and duration inspection
  Future<UploadedMediaItem> uploadAudio({
    required String authorId,
    required String fileName,
    required Uint8List bytes,
    Function(double progress, String status)? onProgress,
  }) async {
    if (_client == null) throw const AppException('Supabase not initialized.');

    final ext = fileName.split('.').last.toLowerCase();
    validateAudioFile(fileName, bytes.lengthInBytes);

    final mimeType = audioMimeMap[ext] ?? 'audio/mpeg';
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$authorId/audio/${timestamp}_$sanitizedName';

    onProgress?.call(0.4, 'Uploading audio file...');
    await _client.storage
        .from('blog-media')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    final publicUrl = _client.storage
        .from('blog-media')
        .getPublicUrl(storagePath);

    // Try inspecting duration with just_audio if possible
    int? durationSec;
    try {
      final player = AudioPlayer();
      final dur = await player.setUrl(publicUrl);
      if (dur != null) {
        durationSec = dur.inSeconds;
      }
      await player.dispose();
    } catch (_) {}

    onProgress?.call(1.0, 'Audio upload complete!');
    return UploadedMediaItem(
      storagePath: storagePath,
      publicUrl: publicUrl,
      kind: 'audio',
      mime: mimeType,
      sizeBytes: bytes.lengthInBytes,
      durationSeconds: durationSec,
    );
  }

  /// Delete specific storage paths from blog-media bucket
  Future<void> deleteStorageFiles(List<String> paths) async {
    if (_client == null || paths.isEmpty) return;
    try {
      await _client.storage.from('blog-media').remove(paths);
    } catch (_) {}
  }

  /// Admin: List all objects in blog-media bucket
  Future<List<FileObject>> listAllMediaFiles({String path = ''}) async {
    if (_client == null) return [];
    final res = await _client.storage
        .from('blog-media')
        .list(
          path: path,
          searchOptions: const SearchOptions(
            limit: 100,
            sortBy: SortBy(column: 'created_at', order: 'desc'),
          ),
        );
    return res;
  }
}

final blogStorageServiceProvider = Provider<BlogStorageService>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return BlogStorageService(client);
});
