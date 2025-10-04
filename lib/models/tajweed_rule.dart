enum TajweedType { post, video }

extension TajweedTypeExtension on TajweedType {
  String get displayName {
    switch (this) {
      case TajweedType.post:
        return 'منشور';
      case TajweedType.video:
        return 'فيديو';
    }
  }
}

class TajweedRule {
  final String id;
  final String title;
  final String content;
  final TajweedType type;
  final String? videoUrl;
  final String? imageUrl;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const TajweedRule({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.videoUrl,
    this.imageUrl,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory TajweedRule.fromMap(Map<String, dynamic> map) {
    return TajweedRule(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      type: TajweedType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TajweedType.post,
      ),
      videoUrl: map['video_url'] as String?,
      imageUrl: map['image_url'] as String?,
      authorId: map['author_id'] as String,
      authorName: map['author_name'] as String,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: map['is_active'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.name,
      'video_url': videoUrl,
      'image_url': imageUrl,
      'author_id': authorId,
      'author_name': authorName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  TajweedRule copyWith({
    String? id,
    String? title,
    String? content,
    TajweedType? type,
    String? videoUrl,
    String? imageUrl,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return TajweedRule(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'TajweedRule(id: $id, title: $title, content: $content, type: $type, videoUrl: $videoUrl, imageUrl: $imageUrl, authorId: $authorId, authorName: $authorName, createdAt: $createdAt, updatedAt: $updatedAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TajweedRule &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.type == type &&
        other.videoUrl == videoUrl &&
        other.imageUrl == imageUrl &&
        other.authorId == authorId &&
        other.authorName == authorName &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => id.hashCode;
}
