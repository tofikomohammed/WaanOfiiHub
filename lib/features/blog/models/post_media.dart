class PostMedia {
  final String id;
  final String postId;
  final String kind; // 'image', 'audio'
  final String storagePath;
  final String mime;
  final int sizeBytes;
  final int? durationSeconds;
  final int sortOrder;
  final String? publicUrl;

  const PostMedia({
    required this.id,
    required this.postId,
    required this.kind,
    required this.storagePath,
    required this.mime,
    required this.sizeBytes,
    this.durationSeconds,
    this.sortOrder = 0,
    this.publicUrl,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json, {String? supabaseUrl}) {
    final path = json['storage_path'] as String? ?? '';
    String? derivedUrl;
    if (supabaseUrl != null && path.isNotEmpty) {
      derivedUrl = '$supabaseUrl/storage/v1/object/public/blog-media/$path';
    }

    return PostMedia(
      id: json['id'] as String? ?? '',
      postId: json['post_id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'image',
      storagePath: path,
      mime: json['mime'] as String? ?? 'image/jpeg',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      publicUrl: json['public_url'] as String? ?? derivedUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'kind': kind,
      'storage_path': storagePath,
      'mime': mime,
      'size_bytes': sizeBytes,
      'duration_seconds': durationSeconds,
      'sort_order': sortOrder,
    };
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String? get formattedDuration {
    if (durationSeconds == null) return null;
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  PostMedia copyWith({
    int? sortOrder,
    String? publicUrl,
  }) {
    return PostMedia(
      id: id,
      postId: postId,
      kind: kind,
      storagePath: storagePath,
      mime: mime,
      sizeBytes: sizeBytes,
      durationSeconds: durationSeconds,
      sortOrder: sortOrder ?? this.sortOrder,
      publicUrl: publicUrl ?? this.publicUrl,
    );
  }
}
