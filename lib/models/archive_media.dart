import 'package:flutter/foundation.dart';

enum MediaType { video, image }

@immutable
class ArchiveMedia {
  final String id;
  final String archiveId;
  final MediaType type;
  final String url;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final int order;
  final DateTime createdAt;

  const ArchiveMedia({
    required this.id,
    required this.archiveId,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.title,
    this.description,
    required this.order,
    required this.createdAt,
  });

  factory ArchiveMedia.fromMap(Map<String, dynamic> map) {
    return ArchiveMedia(
      id: map['id'] as String,
      archiveId: map['archive_id'] as String,
      type: MediaType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MediaType.image,
      ),
      url: map['url'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      title: map['title'] as String?,
      description: map['description'] as String?,
      order: map['order'] as int,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'archive_id': archiveId,
      'type': type.name,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'title': title,
      'description': description,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ArchiveMedia copyWith({
    String? id,
    String? archiveId,
    MediaType? type,
    String? url,
    String? thumbnailUrl,
    String? title,
    String? description,
    int? order,
    DateTime? createdAt,
  }) {
    return ArchiveMedia(
      id: id ?? this.id,
      archiveId: archiveId ?? this.archiveId,
      type: type ?? this.type,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ArchiveMedia(id: $id, type: $type, url: $url, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ArchiveMedia &&
        other.id == id &&
        other.archiveId == archiveId &&
        other.type == type &&
        other.url == url &&
        other.thumbnailUrl == thumbnailUrl &&
        other.title == title &&
        other.description == description &&
        other.order == order &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => id.hashCode;
}
