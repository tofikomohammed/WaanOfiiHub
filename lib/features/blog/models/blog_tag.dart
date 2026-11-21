/// Represents a dynamic blog tag
class BlogTag {
  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;

  const BlogTag({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  factory BlogTag.fromJson(Map<String, dynamic> json) {
    return BlogTag(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
