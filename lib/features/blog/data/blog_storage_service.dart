import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';

class BlogStorageService {
  final SupabaseClient? _client;
  final ImagePicker _picker;

  BlogStorageService(this._client, [ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxAudioSizeBytes = 20 * 1024 * 1024; // 20 MB

  static const List<String> allowedImageMimes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  static const List<String> allowedAudioMimes = [
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/ogg',
    'audio/x-m4a',
  ];

  /// Pick an image from gallery or camera and upload it directly to Supabase storage.
  /// Returns the public URL of the uploaded image.
  Future<String?> pickAndUploadCoverImage({
    required String authorId,
    ImageSource source = ImageSource.gallery,
  }) async {
    if (_client == null) {
      throw const AppException('Supabase is not configured.');
    }

    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (xFile == null) return null;

    final bytes = await xFile.readAsBytes();
    if (bytes.lengthInBytes > maxImageSizeBytes) {
      throw const AppException('Image exceeds the 5MB file size limit.');
    }

    final ext = xFile.name.split('.').last.toLowerCase();
    String mimeType = 'image/jpeg';
    if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'webp') {
      mimeType = 'image/webp';
    }

    final sanitizedName = xFile.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '$authorId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    await _client.storage.from('blog-media').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    return _client.storage.from('blog-media').getPublicUrl(storagePath);
  }

  /// Upload raw image bytes to Supabase storage.
  Future<String> uploadImageBytes({
    required String authorId,
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (_client == null) {
      throw const AppException('Supabase is not configured.');
    }

    if (bytes.lengthInBytes > maxImageSizeBytes) {
      throw const AppException('Image exceeds the 5MB file size limit.');
    }

    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '$authorId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    await _client.storage.from('blog-media').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    return _client.storage.from('blog-media').getPublicUrl(storagePath);
  }

  /// Upload raw audio bytes to Supabase storage.
  Future<String> uploadAudioBytes({
    required String authorId,
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'audio/mpeg',
  }) async {
    if (_client == null) {
      throw const AppException('Supabase is not configured.');
    }

    if (bytes.lengthInBytes > maxAudioSizeBytes) {
      throw const AppException('Audio exceeds the 20MB file size limit.');
    }

    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '$authorId/audio/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    await _client.storage.from('blog-media').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    return _client.storage.from('blog-media').getPublicUrl(storagePath);
  }
}

final blogStorageServiceProvider = Provider<BlogStorageService>((ref) {
  final client =
      isSupabaseInitialized ? ref.watch(supabaseClientProvider) : null;
  return BlogStorageService(client);
});
