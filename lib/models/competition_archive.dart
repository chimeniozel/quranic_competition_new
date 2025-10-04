import 'package:flutter/foundation.dart';
import 'package:quranic_competition/models/archive_media.dart';

@immutable
class CompetitionArchive {
  final String id;
  final String versionId;
  final String versionName;
  final String title;
  final String description;
  final List<ArchiveMedia> media; // Liste des médias (vidéos et images)
  final DateTime eventDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompetitionArchive({
    required this.id,
    required this.versionId,
    required this.versionName,
    required this.title,
    required this.description,
    required this.media,
    required this.eventDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompetitionArchive.fromMap(Map<String, dynamic> map) {
    return CompetitionArchive(
      id: map['id'] as String,
      versionId: map['version_id'] as String,
      versionName: map['version_name'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      media: [], // Les médias seront chargés séparément
      eventDate: DateTime.parse(map['event_date']),
      isActive: map['is_active'] as bool,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version_id': versionId,
      'version_name': versionName,
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CompetitionArchive copyWith({
    String? id,
    String? versionId,
    String? versionName,
    String? title,
    String? description,
    List<ArchiveMedia>? media,
    DateTime? eventDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompetitionArchive(
      id: id ?? this.id,
      versionId: versionId ?? this.versionId,
      versionName: versionName ?? this.versionName,
      title: title ?? this.title,
      description: description ?? this.description,
      media: media ?? this.media,
      eventDate: eventDate ?? this.eventDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CompetitionArchive(id: $id, version: $versionName, title: $title, eventDate: $eventDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CompetitionArchive &&
        other.id == id &&
        other.versionId == versionId &&
        other.versionName == versionName &&
        other.title == title &&
        other.description == description &&
        listEquals(other.media, media) &&
        other.eventDate == eventDate &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => id.hashCode;
}
