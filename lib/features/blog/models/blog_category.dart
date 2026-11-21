/// Represents a dynamic blog category managed in the database
class BlogCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final DateTime createdAt;

  const BlogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.createdAt,
  });

  factory BlogCategory.fromJson(Map<String, dynamic> json) {
    return BlogCategory(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
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
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  BlogCategory copyWith({
    String? name,
    String? slug,
    String? description,
  }) {
    return BlogCategory(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
